extends Control

signal add_once
signal edit_once(once_id: String)
signal open_alarm(alarm_id: String)
signal guide_preview_edit(once_id: String)
signal guide_close_edit

const UNDO_SECONDS := 8.0
const HOLD_SECONDS := 0.4
const DRAG_SLOP := 12.0
const GUIDE_PAD := 6.0
const GUIDE_STEPS := [
	["颜色框蓝", "颜色框黄", "颜色说明"],
	["跳转框", "跳转说明"],
	["添加框", "添加说明"],
	["删除框", "删除说明"],
]
const OnceRow := preload("res://scenes/once_row.tscn")
const WEEKDAY_KEYS := ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

@export var hold_menu: Control
@export var guide: Control

@onready var _scroll: ScrollContainer = $边框/内容/滚动
@onready var _list: VBoxContainer = $边框/内容/滚动/边距/列表
@onready var _empty: Label = $边框/内容/滚动/边距/列表/空提示
@onready var _this_days: VBoxContainer = $边框/内容/滚动/边距/列表/本周条/内容/本周天
@onready var _next_days: VBoxContainer = $边框/内容/滚动/边距/列表/下周条/内容/下周天
@onready var _after_rows: VBoxContainer = $边框/内容/滚动/边距/列表/下下周条/内容/条目
@onready var _later_rows: VBoxContainer = $边框/内容/滚动/边距/列表/更远条/内容/条目
@onready var _hide_button: Button = $边框/内容/添加行/隐藏
@onready var _add_button: Button = $边框/内容/添加行/动作/添加
@onready var _delete_button: Button = $边框/内容/添加行/动作/删除
@onready var _undo_button: Button = $边框/内容/添加行/动作/撤销

var _hide_weekly := false
var _selected_id := ""
var _undo: Dictionary = {}
var _undo_left := 0.0
var _hold_row: Button
var _hold_time := 0.0
var _held := false
var _press_at := Vector2.ZERO
var _headers: Dictionary = {}
var _later_note: Label
var _guide_step := 0
var _guide_running := false


func _ready() -> void:
	_hide_button.pressed.connect(_toggle_weekly)
	_add_button.pressed.connect(func() -> void:
		_clear_select()
		add_once.emit()
	)
	_delete_button.visible = false
	_undo_button.pressed.connect(_undo_delete)
	_headers = {
		"this": $边框/内容/滚动/边距/列表/本周条/内容/本周,
		"next": $边框/内容/滚动/边距/列表/下周条/内容/下周,
		"after": $边框/内容/滚动/边距/列表/下下周条/内容/下下周,
		"later": $边框/内容/滚动/边距/列表/更远条/内容/更远,
		"done": $边框/内容/滚动/边距/列表/已完成,
	}
	_later_note = $边框/内容/滚动/边距/列表/更远条/内容/更远说明
	AlarmStore.changed.connect(refresh)
	_scroll.gui_input.connect(_on_scroll_input)
	if guide != null:
		guide.gui_input.connect(_on_guide_input)
	visibility_changed.connect(show_guide)
	set_process(true)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
		_relabel_actions()


func _process(delta: float) -> void:
	if _undo_left > 0.0:
		_undo_left -= delta
		if _undo_left <= 0.0:
			_undo.clear()
			_refresh_actions()
	if _hold_row == null:
		return
	_hold_time += delta
	if _hold_time < HOLD_SECONDS:
		return
	var row := _hold_row
	_hold_row = null
	_held = true
	_on_hold(row)


func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_hold_row = _row_at(event.global_position)
			_hold_time = 0.0
			_held = false
			_press_at = event.global_position
			if _hold_row == null:
				_clear_select()
		else:
			_hold_row = null
		return
	if event is InputEventMouseMotion and _hold_row != null:
		if event.global_position.distance_to(_press_at) > DRAG_SLOP:
			_hold_row = null
			_held = false


func leave() -> void:
	_clear_select()
	_undo.clear()
	_undo_left = 0.0
	_refresh_actions()
	if hold_menu:
		hold_menu.close()
	_hide_guide()


func refresh() -> void:
	for row in _all_rows():
		row.free()
	var groups := {
		"this": [],
		"next": [],
		"after": [],
		"later": [],
		"done": [],
	}
	for item in AlarmStore.agenda():
		var bucket := "done" if bool(item.get("done", false)) else AlarmStore.week_bucket(str(item.get("date", "")))
		if not groups.has(bucket):
			bucket = "later"
		if bucket == "later" and str(item.get("kind", "")) != "once":
			continue
		groups[bucket].append(item)
	for key in groups:
		groups[key] = _fold_sleep(groups[key])
		if _hide_weekly:
			var kept: Array = []
			for item in groups[key]:
				if str(item.get("kind", "")) == "weekly":
					continue
				kept.append(item)
			groups[key] = kept
	_empty.visible = false
	_show_header("this", true)
	_show_header("next", true)
	_this_days.visible = true
	_next_days.visible = true
	var selected_found := false
	selected_found = _fill_days(_this_days, 0, groups["this"]) or selected_found
	selected_found = _fill_days(_next_days, 7, groups["next"]) or selected_found
	_show_header("after", not (groups["after"] as Array).is_empty())
	selected_found = _fill_bucket(_after_rows, groups["after"]) or selected_found
	_show_header("later", not (groups["later"] as Array).is_empty())
	_later_note.visible = true
	selected_found = _fill_bucket(_later_rows, groups["later"]) or selected_found
	_show_header("done", not (groups["done"] as Array).is_empty())
	var insert_at := _list_index_after(_headers["done"])
	for item in groups["done"]:
		var row := _make_row(item, false)
		_list.add_child(row)
		_pad_row(row, str(item.get("kind", "")) == "weekly")
		_list.move_child(row, insert_at)
		insert_at += 1
		if _row_selected(item):
			selected_found = true
	if not selected_found:
		_selected_id = ""
	_relabel_actions()
	_refresh_actions()


func _show_header(key: String, show: bool) -> void:
	_section_of(_headers[key]).visible = show


func _section_of(header: Node) -> Node:
	var top := header
	while top.get_parent() != null and top.get_parent() != _list:
		top = top.get_parent()
	return top


func _list_index_after(header: Node) -> int:
	return _section_of(header).get_index() + 1


func _fill_bucket(box: VBoxContainer, items: Array) -> bool:
	var selected_found := false
	for item in items:
		var row := _make_row(item, false)
		box.add_child(row)
		_pad_row(row, str(item.get("kind", "")) == "weekly")
		if _row_selected(item):
			selected_found = true
	return selected_found


func _fill_days(box: VBoxContainer, week_offset: int, items: Array) -> bool:
	var note := box.get_parent().get_node("无提醒") as Label
	note.text = tr("此周无提醒")
	note.visible = items.is_empty()
	box.visible = not items.is_empty()
	if items.is_empty():
		return false
	var monday := AlarmStore.monday_of(AlarmStore.local_today_key())
	var by_date := {}
	for item in items:
		var date := str(item.get("date", ""))
		var bucket: Array = by_date.get(date, [])
		bucket.append(item)
		by_date[date] = bucket
	var selected_found := false
	for index in 7:
		var day := box.get_child(index) as VBoxContainer
		var date_key := AlarmStore.shift_date(monday, week_offset + index)
		var title := day.get_node("标题") as Label
		var empty := day.get_node("空") as Label
		var name := tr(WEEKDAY_KEYS[index])
		title.text = "%s · %s" % [name, tr("今天")] if date_key == AlarmStore.local_today_key() else name
		empty.text = tr("没有行程")
		var day_items: Array = by_date.get(date_key, [])
		empty.visible = day_items.is_empty()
		for item in day_items:
			var row := _make_row(item, true)
			day.add_child(row)
			_pad_row(row, str(item.get("kind", "")) == "weekly")
			day.move_child(row, empty.get_index())
			if _row_selected(item):
				selected_found = true
	return selected_found


func _make_row(item: Dictionary, in_day: bool) -> Button:
	var row := OnceRow.instantiate() as Button
	row.set_meta("soft", true)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint_row(row, item, in_day)
	return row


func _row_selected(item: Dictionary) -> bool:
	return str(item.get("id", "")) == _selected_id and str(item.get("kind", "")) == "once" and not bool(item.get("done", false))


## 同一天的起床和睡觉合成一行。长按仍打开那天的闹钟页。
func _fold_sleep(rows: Array) -> Array:
	var wake_by_date := {}
	var sleep_by_date := {}
	for item in rows:
		var alarm_id := str(item.get("alarm_id", ""))
		var date := str(item.get("date", ""))
		if alarm_id.begins_with("wake-"):
			wake_by_date[date] = item
		elif alarm_id.begins_with("sleep-"):
			sleep_by_date[date] = item
	var folded: Array = []
	var used := {}
	for item in rows:
		var alarm_id := str(item.get("alarm_id", ""))
		if not alarm_id.begins_with("wake-") and not alarm_id.begins_with("sleep-"):
			folded.append(item)
			continue
		var date := str(item.get("date", ""))
		if used.has(date):
			continue
		used[date] = true
		var wake: Dictionary = wake_by_date.get(date, {})
		var sleep: Dictionary = sleep_by_date.get(date, {})
		var base: Dictionary = wake if not wake.is_empty() else sleep
		var pair := base.duplicate()
		pair["pair"] = true
		if not wake.is_empty():
			pair["wake_time"] = AlarmStore.format_time(int(wake.get("hour", 0)), int(wake.get("minute", 0)))
			pair["alarm_id"] = str(wake.get("alarm_id", ""))
		if not sleep.is_empty():
			pair["sleep_time"] = AlarmStore.format_time(int(sleep.get("hour", 0)), int(sleep.get("minute", 0)))
			if wake.is_empty():
				pair["alarm_id"] = str(sleep.get("alarm_id", ""))
		folded.append(pair)
	return folded


func _all_rows() -> Array[Button]:
	var rows: Array[Button] = []
	_gather_rows(_list, rows)
	return rows


func _gather_rows(node: Node, rows: Array[Button]) -> void:
	for child in node.get_children():
		var row := child as Button
		if row != null:
			rows.append(row)
		elif child.get_child_count() > 0:
			_gather_rows(child, rows)


func _paint_row(row: Button, item: Dictionary, in_day: bool = false) -> void:
	if bool(item.get("pair", false)):
		var bits: PackedStringArray = []
		if item.has("wake_time"):
			bits.append("%s %s" % [tr("起床"), str(item["wake_time"])])
		if item.has("sleep_time"):
			bits.append("%s %s" % [tr("睡觉"), str(item["sleep_time"])])
		var line := "🛏️ " + " · ".join(bits)
		row.text = line if in_day else "%s · %s" % [AlarmStore.agenda_when(str(item.get("date", ""))), line]
		row.theme_type_variation = "DayButton"
		row.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.clip_text = true
		row.add_theme_font_size_override("font_size", 13)
		row.custom_minimum_size.y = 36
		_finish_row(row, item)
		return
	var label := str(item.get("label", ""))
	var lead := int(item.get("lead_minutes", 0))
	var ring := AlarmStore.format_time(int(item.get("hour", 0)), int(item.get("minute", 0)))
	var event := AlarmStore.format_time(int(item.get("event_hour", item.get("hour", 0))), int(item.get("event_minute", item.get("minute", 0))))
	var once := str(item.get("kind", "")) == "once"
	var when := ring
	if once and lead > 0:
		when = "%s · %s" % [tr("%s 到") % event, tr("%s 响") % ring]
	elif item.has("end_hour"):
		when = tr("开始 %s · 结束 %s") % [event, AlarmStore.format_time(int(item["end_hour"]), int(item["end_minute"]))]
		if lead > 0:
			when = "%s · %s" % [when, tr("%s 响") % ring]
	elif lead > 0:
		label = "%s · %s" % [label, tr("%s 到") % event]
		when = tr("%s 响") % ring
	if not in_day:
		when = "%s · %s" % [AlarmStore.agenda_when(str(item.get("date", ""))), when]
	if bool(item.get("done", false)):
		row.text = "%s\n%s · %s" % [label, when, tr("已完成")]
		row.theme_type_variation = "PausedButton"
	elif once:
		row.text = "%s\n%s" % [label, when]
		row.theme_type_variation = "SkipButton"
	else:
		row.text = "%s · %s" % [label, when]
		row.theme_type_variation = "DayButton"
		row.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.clip_text = true
		row.add_theme_font_size_override("font_size", 13)
		row.custom_minimum_size.y = 36
	_finish_row(row, item)


func _finish_row(row: Button, item: Dictionary) -> void:
	row.toggle_mode = false
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("item", item)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _pad_row(row: Button, slim: bool = false) -> void:
	var box := row.get_theme_stylebox("normal")
	if box == null:
		return
	var padded := box.duplicate() as StyleBox
	var pad := 8 if slim else 14
	padded.content_margin_left = 16
	padded.content_margin_right = 16
	padded.content_margin_top = pad
	padded.content_margin_bottom = pad
	for name in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		row.add_theme_stylebox_override(name, padded)


func _row_at(global_pos: Vector2) -> Button:
	for row in _all_rows():
		if row.visible and row.get_global_rect().has_point(global_pos):
			return row
	return null


func _on_hold(row: Button) -> void:
	var item: Dictionary = row.get_meta("item", {})
	if str(item.get("kind", "")) == "weekly":
		var alarm_id := str(item.get("alarm_id", ""))
		if hold_menu and not alarm_id.is_empty():
			hold_menu.open(row, "", false, func(action: String) -> void:
				if action == "detail":
					open_alarm.emit(alarm_id)
			, false, false, true)
		return
	if str(item.get("kind", "")) != "once" or bool(item.get("done", false)):
		return
	var once_id := str(item.get("id", ""))
	_selected_id = once_id
	if hold_menu:
		hold_menu.open(row, "", true, func(action: String) -> void:
			if action == "edit":
				edit_once.emit(once_id)
			elif action == "delete":
				_delete_selected()
		, false, true)


func _delete_selected() -> void:
	if _selected_id.is_empty():
		return
	var removed := AlarmStore.remove_once(_selected_id)
	if removed.is_empty():
		return
	_undo = removed
	_undo_left = UNDO_SECONDS
	_selected_id = ""
	AlarmService.resync_alarms()
	_refresh_actions()


func _undo_delete() -> void:
	if _undo.is_empty():
		return
	AlarmStore.restore_once(_undo)
	_undo.clear()
	_undo_left = 0.0
	AlarmService.resync_alarms()
	_refresh_actions()


func _clear_select() -> void:
	_selected_id = ""
	_refresh_actions()


func _toggle_weekly() -> void:
	_hide_weekly = not _hide_weekly
	refresh()


func _refresh_actions() -> void:
	var undoing := _undo_left > 0.0 and not _undo.is_empty()
	_undo_button.visible = undoing
	_add_button.visible = not undoing
	_delete_button.visible = false


func _relabel_actions() -> void:
	_hide_button.text = tr("显示每周日常提醒") if _hide_weekly else tr("隐藏每周日常提醒")
	_add_button.text = tr("+ 添加")
	_delete_button.text = tr("删除")
	_undo_button.text = tr("撤销")
	_empty.text = tr("还没有行程。点 + 加一个只响一次的提醒。")
	(_headers["this"] as Label).text = tr("本周")
	(_headers["next"] as Label).text = tr("下周")
	(_headers["after"] as Label).text = tr("下下周")
	(_headers["later"] as Label).text = tr("更远")
	_later_note.text = tr("您的一般周提醒不会在这里显示的哦")
	(_headers["done"] as Label).text = tr("已完成")


func show_guide() -> void:
	if guide == null or guide.visible or _guide_running or not is_visible_in_tree():
		return
	if AlarmStore.once_tutorial_seen and not AlarmStore.replay_tutorials():
		return
	_guide_running = true
	AlarmStore.ensure_sample_once()
	# 容器要跑完一帧才有位置，圈框照着真实位置贴。
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_visible_in_tree():
		_guide_running = false
		return
	await _reveal_rows()
	_guide_step = 0
	_apply_guide_step()
	guide.visible = true
	_guide_running = false
	AlarmStore.mark_once_tutorial_seen()


func _guide_rows() -> Dictionary:
	var yellow: Button
	var before: Button
	var after: Button
	for row in _all_rows():
		if not row.visible:
			continue
		var item: Dictionary = row.get_meta("item", {})
		if str(item.get("id", "")) == AlarmStore.SAMPLE_ONCE_ID:
			yellow = row
			continue
		if str(item.get("kind", "")) != "weekly" or bool(item.get("done", false)):
			continue
		if yellow == null:
			before = row
		elif after == null:
			after = row
	var blue: Button = before if before != null else after
	return {"blue": blue, "yellow": yellow}


func _reveal_rows() -> void:
	var rows := _guide_rows()
	var blue: Button = rows["blue"]
	var yellow: Button = rows["yellow"]
	if blue:
		_scroll.ensure_control_visible(blue)
		await get_tree().process_frame
	if yellow:
		_scroll.ensure_control_visible(yellow)
		await get_tree().process_frame
	blue = _guide_rows()["blue"]
	if blue == null:
		return
	var gap := _scroll.get_global_rect().position.y + 4.0 - blue.get_global_rect().position.y
	if gap > 1.0:
		_scroll.scroll_vertical = maxi(_scroll.scroll_vertical - int(ceil(gap)), 0)
		await get_tree().process_frame


func _apply_guide_step() -> void:
	var rows := _guide_rows()
	var blue: Button = rows["blue"]
	var yellow: Button = rows["yellow"]
	guide.color.a = 0.7
	for index in GUIDE_STEPS.size():
		for node_name in GUIDE_STEPS[index]:
			var part := guide.get_node(node_name) as Control
			var show := index == _guide_step
			if node_name in ["颜色框蓝", "跳转框"] and blue == null:
				show = false
			if node_name in ["颜色框黄", "删除框"] and yellow == null:
				show = false
			part.visible = show
	if blue:
		_ring_target(guide.get_node("颜色框蓝"), blue)
		_ring_target(guide.get_node("跳转框"), blue)
	if yellow:
		_ring_target(guide.get_node("颜色框黄"), yellow)
		_ring_target(guide.get_node("删除框"), yellow)
	_ring_target(guide.get_node("添加框"), _add_button)
	_note_above(guide.get_node("添加说明"), _hide_button.get_global_rect().merge(_add_button.get_global_rect()))
	var color_anchor: Control = yellow if yellow else blue
	if color_anchor:
		var color_rect := color_anchor.get_global_rect()
		if blue and yellow:
			color_rect = color_rect.merge(blue.get_global_rect())
		_note_under(guide.get_node("颜色说明"), color_rect)
	if _guide_step == 1 and blue != null and hold_menu:
		hold_menu.open(blue, "", false, Callable(), true, false, true)
		_note_under(guide.get_node("跳转说明"), blue.get_global_rect())
		_note_below_menu(guide.get_node("跳转说明"))
		return
	if _guide_step == 3 and yellow != null and hold_menu:
		hold_menu.open(yellow, "", true, Callable(), true, true)
		_note_under(guide.get_node("删除说明"), yellow.get_global_rect())
		_note_below_menu(guide.get_node("删除说明"))
		return
	if hold_menu:
		hold_menu.close()


func _note_height(note: Control) -> float:
	var label := note as Label
	if label == null:
		return 48.0
	return label.get_line_height() * maxi(label.get_line_count(), 1)


func _note_under(note: Control, rect: Rect2) -> void:
	var width := minf(maxf(rect.size.x, 220.0), guide.size.x - 32.0)
	note.size = Vector2(width, 0.0)
	var height := _note_height(note)
	var y := rect.end.y + GUIDE_PAD + 10.0
	var bottom := guide.get_global_rect().end.y - 80.0
	if y + height > bottom:
		y = maxf(guide.global_position.y + 12.0, rect.position.y - GUIDE_PAD - 10.0 - height)
	note.global_position = Vector2(clampf(rect.position.x, guide.global_position.x + 16.0, guide.get_global_rect().end.x - width - 16.0), y)


func _note_above(note: Control, rect: Rect2) -> void:
	var width := minf(maxf(rect.size.x, 240.0), guide.size.x - 32.0)
	note.size = Vector2(width, 0.0)
	var height := _note_height(note)
	note.global_position = Vector2(clampf(rect.position.x, guide.global_position.x + 16.0, guide.get_global_rect().end.x - width - 16.0), rect.position.y - GUIDE_PAD - 10.0 - height)


func _note_below_menu(note: Control) -> void:
	var menu: Rect2 = hold_menu.menu_rect()
	var left := note.global_position.x
	var overlaps_x := left < menu.end.x and left + note.size.x > menu.position.x
	if overlaps_x and note.global_position.y < menu.end.y:
		note.global_position.y = menu.end.y + GUIDE_PAD + 10.0


func _ring_target(ring: Control, target: Control) -> void:
	var rect := target.get_global_rect()
	if _scroll.is_ancestor_of(target):
		var shown := rect.intersection(_scroll.get_global_rect())
		if shown.size.x >= 8.0 and shown.size.y >= 8.0:
			rect = shown
	rect = rect.grow(GUIDE_PAD)
	ring.custom_minimum_size = rect.size
	ring.global_position = rect.position
	ring.size = rect.size


func _on_guide_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	guide.accept_event()
	_guide_step += 1
	if _guide_step < GUIDE_STEPS.size():
		_apply_guide_step()
		return
	_hide_guide()
	var removed := AlarmStore.remove_once(AlarmStore.SAMPLE_ONCE_ID)
	if not removed.is_empty():
		AlarmService.resync_alarms()


func _hide_guide() -> void:
	if guide == null or not guide.visible:
		return
	guide.visible = false
	guide.color.a = 0.7
	guide_close_edit.emit()
	if hold_menu:
		hold_menu.close()
