extends Node

var _date_key := ""
var _date_label: Label
var _count_label: Label
var _sunflower: Node3D
var _flower_page: Control
var _pot_page: Control
var _alarm_page: Control
var _selected_day := 0
var _wake_button: Button
var _sleep_button: Button
var _task_button: Button
var _task_name: Label
var _task_row: Control
var _wake_row: Control
var _sleep_row: Control
var _sleep_tab: Button
var _task_tabs: HBoxContainer
var _tab_scroll: ScrollContainer
var _tab_template: Button
var _tab_previews: Array[Node] = []
var _task_buttons: Array[Button] = []
var _delete_button: Button
var _skip_button: Button
var _name_dialog: Control
var _name_field: LineEdit
var _selected_task := -1
var _rename_mode := false
var _name_holding := false
var _name_held := false
var _armed_button: Button
var _armed_hold := 0.0
var _armed_limit := 2.0
var _armed_action := ""
var _armed_fill: StyleBoxFlat
var _armed_rest: StyleBoxFlat
var _button_rest: Dictionary = {}
var _button_goal: Dictionary = {}
var _armed_from := Color()
var _armed_to := Color()
var _armed_border_from := Color()
var _armed_border_to := Color()
var _armed_font_from := Color()
var _armed_font_to := Color()
var _hold_button: Button
var _reordering := false
var _order_dirty := false
var _ignore_tab_press := false
const DigitFont := preload("res://fonts/DSEG7Classic-Regular.ttf")
const TaskTabScene := preload("res://scenes/task_tab.tscn")
const TAB_SHOW := 4
const HOLD_SECONDS := 0.28
const DELETE_HOLD := 2.0
const SKIP_HOLD := 1.5
var _editing_kind := "wake"
var _picker_hour := 7
var _picker_minute := 0
var _day_buttons: Array[Button] = []
var _tab_buttons: Array[Button] = []
var _prev_button: Button
var _next_button: Button
var _playback := -1
var _times: Control
var _time_fade: Tween
var _hour_wheel: Control
var _minute_wheel: Control
var _picker: Control


func _enter_tree() -> void:
	if OS.get_name() != "Android":
		return
	var screen := get_node_or_null("UI/界面") as Control
	if screen == null or screen.theme == null:
		return
	var font := load("res://theme/font_android.tres") as Font
	if font == null:
		return
	var theme := screen.theme.duplicate()
	theme.default_font = font
	screen.theme = theme


func _ready() -> void:
	_sunflower = $Sunflower
	_bind_nodes()
	_start_forest()
	var ring := load("res://ios/sounds/sunflower.wav")
	if ring:
		$RingPlayer.stream = ring
	_date_key = AlarmStore.today_key()
	AlarmStore.changed.connect(_refresh)
	AlarmService.snoozes_updated.connect(_refresh)
	_fill_pot_rows()
	_select_day(0, false)
	shift_date(0)
	_show_tab("flower")
	_schedule_days()
	set_process(false)


func _bind_nodes() -> void:
	var root := $UI/界面
	_date_label = root.get_node("看花页/顶部/日期行/日期")
	_count_label = root.get_node("看花页/顶部/次数")
	_prev_button = root.get_node("看花页/顶部/日期行/前一天")
	_next_button = root.get_node("看花页/顶部/日期行/后一天")
	_prev_button.pressed.connect(func() -> void: shift_date(-1))
	_next_button.pressed.connect(func() -> void: shift_date(1))
	_flower_page = root.get_node("看花页")
	_pot_page = root.get_node("花盆页/花盆")
	_alarm_page = root.get_node("定时页/定时")
	var days := _alarm_page.get_node("边框/内容/行列/星期")
	for index in days.get_child_count():
		var button := days.get_child(index) as Button
		button.toggle_mode = true
		button.pressed.connect(_select_day.bind(index))
		_day_buttons.append(button)
	_times = _alarm_page.get_node("边框/内容/行列/时间")
	_wake_button = _times.get_node("起床/钟点")
	_sleep_button = _times.get_node("睡觉/钟点")
	_wake_row = _times.get_node("起床")
	_sleep_row = _times.get_node("睡觉")
	_task_row = _times.get_node("任务时间")
	_task_name = _alarm_page.get_node("边框/内容/行列/时间/提醒标题")
	_task_name.mouse_filter = Control.MOUSE_FILTER_STOP
	_task_name.gui_input.connect(_on_task_name_input)
	_task_button = _task_row.get_node("钟点")
	_wake_button.pressed.connect(_open_time_picker.bind("wake"))
	_sleep_button.pressed.connect(_open_time_picker.bind("sleep"))
	_task_button.pressed.connect(_open_time_picker.bind("task"))
	_delete_button = _alarm_page.get_node("边框/内容/操作/按钮/删除")
	_remember_button(_delete_button)
	_delete_button.gui_input.connect(_on_hold_input.bind(_delete_button, DELETE_HOLD, "delete"))
	_delete_button.mouse_exited.connect(_cancel_armed_hold)
	_skip_button = _alarm_page.get_node("边框/内容/操作/按钮/这天不提醒")
	_remember_button(_skip_button)
	_skip_button.gui_input.connect(_on_hold_input.bind(_skip_button, SKIP_HOLD, "skip"))
	_skip_button.mouse_exited.connect(_cancel_armed_hold)
	_tab_scroll = _alarm_page.get_node("边框/内容/标签行/滚动")
	_task_tabs = _tab_scroll.get_node("任务")
	_sleep_tab = _task_tabs.get_node("睡觉")
	_sleep_tab.toggle_mode = true
	_sleep_tab.pressed.connect(_show_sleep_task)
	_tab_template = _task_tabs.get_node_or_null("样例") as Button
	for child in _task_tabs.get_children():
		if child != _sleep_tab and child != _tab_template:
			_tab_previews.append(child)
	_alarm_page.get_node("边框/内容/标签行/加号").pressed.connect(_open_task_name)
	_rebuild_task_tabs()
	_show_sleep_task()
	_alarm_page.get_node("边框/内容/操作/按钮/记一次贪睡").pressed.connect(_record_snooze)
	var icons := root.get_node("底栏/图标")
	var specs := ["flower", "pot", "alarm"]
	for index in icons.get_child_count():
		var button := icons.get_child(index) as Button
		button.pressed.connect(_show_tab.bind(specs[index]))
		_tab_buttons.append(button)
	_picker = root.get_node("时间选择")
	_picker.gui_input.connect(_close_picker_on_click)
	_name_dialog = root.get_node("任务命名")
	_name_dialog.gui_input.connect(_close_name_on_click)
	_name_field = _name_dialog.get_node("居中/面板/内容/名字")
	_name_dialog.get_node("居中/面板/内容/健身").pressed.connect(_confirm_new_task.bind("💪 健身"))
	_name_dialog.get_node("居中/面板/内容/接娃").pressed.connect(_confirm_new_task.bind("👶 接娃"))
	_name_dialog.get_node("居中/面板/内容/吃药").pressed.connect(_confirm_new_task.bind("💊 吃药"))
	_name_dialog.get_node("居中/面板/内容/完成").pressed.connect(_confirm_typed_task)
	_hour_wheel = _picker.get_node("居中/面板/内容/滚轮区/列/时")
	_minute_wheel = _picker.get_node("居中/面板/内容/滚轮区/列/分")
	_hour_wheel.settled.connect(_on_hour)
	_minute_wheel.settled.connect(_on_minute)
	_picker.get_node("居中/面板/内容/完成").pressed.connect(_finish_picker)


func _fill_pot_rows() -> void:
	var flower_row := _pot_page.get_node("边框/列表/花")
	var pot_row := _pot_page.get_node("边框/列表/盆")
	var flower_names := PackedStringArray()
	var pot_names := PackedStringArray()
	for kind in _sunflower.flower_kinds():
		flower_names.append(str(kind["name"]))
	for kind in _sunflower.pot_kinds():
		pot_names.append(str(kind["name"]))
	flower_row.set_labels(flower_names, _sunflower.flower_index)
	pot_row.set_labels(pot_names, _sunflower.pot_index)
	flower_row.selected.connect(func(index: int) -> void:
		_sunflower.apply_style(index, pot_row.index)
	)
	pot_row.selected.connect(func(index: int) -> void:
		_sunflower.apply_style(flower_row.index, index)
	)


func _close_picker_on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_picker.visible = false


func _finish_picker() -> void:
	_picker.visible = false


func _on_hour(number: int) -> void:
	_picker_hour = number
	_commit_time()


func _on_minute(number: int) -> void:
	_picker_minute = number
	_commit_time()


func _commit_time() -> void:
	if _editing_kind == "task":
		AlarmStore.set_task_time(_selected_task, _selected_day, _picker_hour, _picker_minute)
	else:
		AlarmStore.set_day_time(_selected_day, _editing_kind, _picker_hour, _picker_minute)
	_update_time_label()
	_schedule_days()


func _start_forest() -> void:
	var forest := AudioStreamPlayer.new()
	forest.name = "Forest"
	forest.volume_db = -12.0
	var stream := load("res://ios/sounds/forest.wav")
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	forest.stream = stream
	add_child(forest)
	if forest.stream:
		forest.play()


func _show_tab(tab: String) -> void:
	for index in _tab_buttons.size():
		_tab_buttons[index].set_pressed_no_signal(["flower", "pot", "alarm"][index] == tab)
	_flower_page.visible = tab != "alarm"
	_pot_page.get_parent().visible = tab == "pot"
	_alarm_page.get_parent().visible = tab == "alarm"


func _select_day(index: int, animate: bool = true) -> void:
	var changed := animate and _times != null and index != _selected_day
	_selected_day = index
	for day_index in _day_buttons.size():
		_day_buttons[day_index].set_pressed_no_signal(day_index == index)
	if not changed:
		_update_time_label()
		return
	if _time_fade:
		_time_fade.kill()
	_time_fade = create_tween()
	_time_fade.tween_property(_times, "modulate:a", 0.0, 0.14)
	_time_fade.tween_callback(_update_time_label)
	_time_fade.tween_property(_times, "modulate:a", 1.0, 0.22)


func _open_time_picker(kind: String) -> void:
	_editing_kind = kind
	if kind == "task":
		var task := AlarmStore.task_at(_selected_task)
		var times: Array = task.get("times", [])
		if _selected_day < 0 or _selected_day >= times.size():
			return
		var moment: Dictionary = times[_selected_day]
		_picker_hour = int(moment["hour"])
		_picker_minute = int(moment["minute"])
	else:
		var slot: Dictionary = AlarmStore.day_slot(_selected_day)
		_picker_hour = int(slot[kind + "_hour"])
		_picker_minute = int(slot[kind + "_minute"])
	_hour_wheel.value = _picker_hour
	_minute_wheel.value = _picker_minute
	_hour_wheel.queue_redraw()
	_minute_wheel.queue_redraw()
	_picker.visible = true


func _update_time_label() -> void:
	if _wake_button == null or _sleep_button == null:
		return
	var slot: Dictionary = AlarmStore.day_slot(_selected_day)
	var day_on := bool(slot.get("enabled", true))
	_show_clock(_wake_button, int(slot["wake_hour"]), int(slot["wake_minute"]), day_on)
	_show_clock(_sleep_button, int(slot["sleep_hour"]), int(slot["sleep_minute"]), day_on)
	var reminding := day_on
	if _task_button != null and _selected_task >= 0:
		var task := AlarmStore.task_at(_selected_task)
		var times: Array = task.get("times", [])
		if _selected_day >= 0 and _selected_day < times.size():
			var moment: Dictionary = times[_selected_day]
			reminding = bool(moment.get("enabled", true))
			_show_clock(_task_button, int(moment["hour"]), int(moment["minute"]), reminding)
	if _skip_button:
		_skip_button.visible = reminding


func _schedule_days() -> void:
	for alarm in AlarmStore.alarms:
		AlarmService.schedule(alarm)


func _on_task_name_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _name_holding and event.relative.length() > 8.0:
		_name_holding = false
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_name_holding = true
		_name_held = false
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func() -> void:
			if _name_holding:
				_name_held = true
		)
		return
	var rename := _name_held and _name_holding
	_name_holding = false
	_name_held = false
	if rename:
		_open_rename()


func _open_task_name() -> void:
	_rename_mode = false
	_name_field.text = "新的提醒"
	_name_dialog.visible = true


func _open_rename() -> void:
	if _selected_task < 0:
		return
	_rename_mode = true
	var current := str(AlarmStore.task_at(_selected_task).get("name", ""))
	_name_field.text = current
	_name_dialog.visible = true


func _close_name_on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_name_dialog.visible = false
		_rename_mode = false


func _confirm_typed_task() -> void:
	_confirm_new_task(_name_field.text)


func _limit_name(task_name: String) -> String:
	var trimmed := task_name.strip_edges()
	if trimmed.is_empty():
		return "新的提醒"
	return trimmed


func _confirm_new_task(task_name: String) -> void:
	var trimmed := _limit_name(task_name)
	_name_dialog.visible = false
	if _rename_mode:
		_rename_mode = false
		if _selected_task < 0:
			return
		var task_id := str(AlarmStore.task_at(_selected_task).get("id", ""))
		AlarmStore.rename_task(task_id, trimmed)
		if _selected_task < _task_buttons.size():
			_style_tab(_task_buttons[_selected_task], trimmed)
		_apply_task_chrome()
		_schedule_days()
		return
	AlarmStore.add_task(trimmed)
	_rebuild_task_tabs()
	_show_custom_task(AlarmStore.task_count() - 1)
	_schedule_days()
	if not _task_buttons.is_empty():
		_tab_scroll.ensure_control_visible(_task_buttons[_task_buttons.size() - 1])


func _show_clock(button: Button, hour: int, minute: int, enabled: bool) -> void:
	if not enabled:
		button.remove_theme_font_override("font")
		button.add_theme_font_size_override("font_size", 20)
		button.text = "不提醒"
		return
	button.add_theme_font_override("font", DigitFont)
	button.add_theme_font_size_override("font_size", 32)
	button.text = "%02d:%02d" % [hour, minute]


func _on_hold_input(event: InputEvent, button: Button, limit: float, action: String) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_begin_armed(button, limit, action)
		return
	if _armed_button == button:
		_end_armed(false)
		return
	_clear_armed_paint(button)


func _remember_button(button: Button) -> void:
	var rest := button.get_theme_stylebox("normal") as StyleBoxFlat
	var goal := button.get_theme_stylebox("pressed") as StyleBoxFlat
	_button_rest[button] = rest.duplicate()
	_button_goal[button] = goal.duplicate()


func _begin_armed(button: Button, limit: float, action: String) -> void:
	if _armed_button != null and _armed_button != button:
		_end_armed(false)
	var rest := _button_rest[button] as StyleBoxFlat
	var goal := _button_goal[button] as StyleBoxFlat
	_armed_rest = rest
	_armed_fill = rest.duplicate()
	_armed_from = rest.bg_color
	_armed_border_from = rest.border_color
	_armed_to = goal.bg_color
	_armed_border_to = goal.border_color
	_armed_font_from = button.get_theme_color("font_color")
	_armed_font_to = button.get_theme_color("font_pressed_color")
	_armed_button = button
	_armed_hold = 0.0
	_armed_limit = limit
	_armed_action = action
	_paint_armed(0.0)
	set_process(true)


func _cancel_armed_hold() -> void:
	if _armed_button == null:
		return
	if _armed_button.get_global_rect().has_point(_armed_button.get_global_mouse_position()):
		return
	_end_armed(false)


func _paint_armed(amount: float) -> void:
	if _armed_button == null or _armed_fill == null:
		return
	_armed_fill.bg_color = _armed_from.lerp(_armed_to, amount)
	_armed_fill.border_color = _armed_border_from.lerp(_armed_border_to, amount)
	var font := _armed_font_from.lerp(_armed_font_to, amount)
	for style_name in ["normal", "hover", "pressed", "focus"]:
		_armed_button.add_theme_stylebox_override(style_name, _armed_fill)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		_armed_button.add_theme_color_override(color_name, font)


func _clear_armed_paint(button: Button) -> void:
	if button == null:
		return
	var rest := _button_rest.get(button) as StyleBoxFlat
	var goal := _button_goal.get(button) as StyleBoxFlat
	if rest != null:
		button.add_theme_stylebox_override("normal", rest)
		button.add_theme_stylebox_override("hover", rest)
		button.add_theme_stylebox_override("focus", rest)
	if goal != null:
		button.add_theme_stylebox_override("pressed", goal)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.remove_theme_color_override(color_name)


func _end_armed(commit: bool) -> void:
	var action := _armed_action
	var button := _armed_button
	_armed_button = null
	_armed_hold = 0.0
	_armed_action = ""
	_clear_armed_paint(button)
	if not _reordering:
		set_process(false)
	if not commit or button == null:
		return
	_play_burst(button, _armed_to)
	for style_name in ["pressed", "hover", "focus"]:
		button.add_theme_stylebox_override(style_name, _armed_rest)
	if action == "delete":
		_delete_task()
	elif action == "skip":
		_skip_selected_day()


func _play_burst(button: Button, color: Color) -> void:
	var flash := _alarm_page.get_node("生效光") as Panel
	var rect := button.get_global_rect()
	flash.size = rect.size
	flash.pivot_offset = rect.size * 0.5
	flash.global_position = rect.position
	flash.scale = Vector2(1, 1)
	flash.modulate = Color(color.r, color.g, color.b, 0.72)
	flash.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.7, 2.1), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		flash.visible = false
		flash.scale = Vector2.ONE
	)


func _delete_task() -> void:
	if _selected_task < 0:
		return
	var task_id := str(AlarmStore.task_at(_selected_task).get("id", ""))
	for weekday in 7:
		AlarmService.cancel(AlarmStore.task_alarm_id(task_id, weekday + 1))
	AlarmStore.remove_task(task_id)
	_rebuild_task_tabs()
	_show_sleep_task()
	_schedule_days()


func _skip_selected_day() -> void:
	var weekday := _selected_day + 1
	if _selected_task < 0:
		AlarmService.cancel("wake-%d" % weekday)
		AlarmService.cancel("sleep-%d" % weekday)
		AlarmStore.set_day_enabled(_selected_day, false)
	else:
		var task_id := str(AlarmStore.task_at(_selected_task).get("id", ""))
		AlarmService.cancel(AlarmStore.task_alarm_id(task_id, weekday))
		AlarmStore.set_task_day_enabled(_selected_task, _selected_day, false)
	_update_time_label()
	_schedule_days()


func _show_sleep_task() -> void:
	_selected_task = -1
	_apply_task_chrome()


func _show_custom_task(index: int) -> void:
	_selected_task = index
	_apply_task_chrome()


func _apply_task_chrome() -> void:
	var custom := _selected_task >= 0
	if _wake_row:
		_wake_row.visible = not custom
	if _sleep_row:
		_sleep_row.visible = not custom
	if _task_row:
		_task_row.visible = custom
	if _delete_button:
		_delete_button.visible = custom
	if _task_name:
		_task_name.visible = custom
		if custom:
			_task_name.text = str(AlarmStore.task_at(_selected_task).get("name", ""))
	if _sleep_tab:
		_sleep_tab.set_pressed_no_signal(not custom)
	for index in _task_buttons.size():
		_task_buttons[index].set_pressed_no_signal(index == _selected_task)
	_update_time_label()


func _style_tab(button: Button, full: String) -> void:
	var shown := full
	if shown.length() > TAB_SHOW:
		shown = shown.substr(0, TAB_SHOW)
	button.text = shown
	button.clip_text = false
	if shown.length() > 2:
		button.add_theme_font_size_override("font_size", 14)
	else:
		button.remove_theme_font_size_override("font_size")


func _rebuild_task_tabs() -> void:
	if _task_tabs == null:
		return
	for child in _task_tabs.get_children():
		if child == _sleep_tab or _tab_previews.has(child) or child == _tab_template:
			if child != _sleep_tab:
				child.visible = false
			continue
		child.free()
	_task_buttons.clear()
	for index in AlarmStore.task_count():
		var button := _tab_template.duplicate() as Button if _tab_template else TaskTabScene.instantiate() as Button
		button.visible = true
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.set_meta("task_id", str(AlarmStore.task_at(index).get("id", "")))
		_style_tab(button, AlarmStore.task_label(AlarmStore.task_at(index)))
		button.pressed.connect(_on_task_tab_pressed.bind(button))
		button.gui_input.connect(_on_task_tab_input.bind(button))
		_task_tabs.add_child(button)
		_task_buttons.append(button)
	for preview in _tab_previews:
		_task_tabs.move_child(preview, _task_tabs.get_child_count() - 1)


func _on_task_tab_pressed(button: Button) -> void:
	if _ignore_tab_press:
		_ignore_tab_press = false
		return
	var index := _task_buttons.find(button)
	if index >= 0:
		_show_custom_task(index)


func _on_task_tab_input(event: InputEvent, button: Button) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_hold_button = button
			var holder := button
			get_tree().create_timer(HOLD_SECONDS).timeout.connect(func() -> void:
				if _hold_button == holder:
					_begin_reorder()
			)
		elif not _reordering:
			_hold_button = null
	elif event is InputEventMouseMotion and not _reordering and _hold_button == button:
		if event.relative.length() > 8.0:
			_hold_button = null


func _begin_reorder() -> void:
	_reordering = true
	_order_dirty = false
	if _tab_scroll:
		_tab_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	if _armed_button != null:
		_armed_hold += delta
		_paint_armed(clampf(_armed_hold / _armed_limit, 0.0, 1.0))
		if _armed_hold >= _armed_limit:
			_end_armed(true)
		elif not _armed_button.get_global_rect().has_point(_armed_button.get_global_mouse_position()):
			_end_armed(false)
		elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_armed(false)
	if not _reordering or _hold_button == null:
		return
	var pointer := _alarm_page.get_global_mouse_position()
	_drag_tab_to(_hold_button, pointer)
	_autoscroll_tabs(pointer)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_reorder()


func _drag_tab_to(button: Button, global_pos: Vector2) -> void:
	var from := _task_buttons.find(button)
	if from < 0:
		return
	var target := from
	for index in _task_buttons.size():
		var center := _task_buttons[index].get_global_rect().get_center().x
		if global_pos.x < center:
			target = index
			break
		target = index
	if target == from:
		return
	_task_buttons.remove_at(from)
	_task_buttons.insert(target, button)
	_task_tabs.move_child(button, target + 1)
	if _selected_task == from:
		_selected_task = target
	elif from < target and _selected_task > from and _selected_task <= target:
		_selected_task -= 1
	elif from > target and _selected_task >= target and _selected_task < from:
		_selected_task += 1
	_order_dirty = true


func _autoscroll_tabs(global_pos: Vector2) -> void:
	if _tab_scroll == null:
		return
	var rect := _tab_scroll.get_global_rect()
	var edge := 28.0
	if global_pos.x < rect.position.x + edge:
		_tab_scroll.scroll_horizontal = maxi(_tab_scroll.scroll_horizontal - 14, 0)
	elif global_pos.x > rect.end.x - edge:
		_tab_scroll.scroll_horizontal += 14


func _finish_reorder() -> void:
	_reordering = false
	_hold_button = null
	if _armed_button == null:
		set_process(false)
	if _tab_scroll:
		_tab_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _order_dirty:
		return
	_order_dirty = false
	_ignore_tab_press = true
	var ids: Array = []
	for button in _task_buttons:
		ids.append(str(button.get_meta("task_id")))
	AlarmStore.reorder_tasks(ids)
	_apply_task_chrome()
	_schedule_days()


func _record_snooze() -> void:
	if AlarmService.using_native:
		return
	var alarm_id := "desktop"
	if not AlarmStore.alarms.is_empty():
		alarm_id = str(AlarmStore.alarms[0]["id"])
	AlarmService.record_desktop_snooze(alarm_id)
	_show_tab("flower")


func _refresh() -> void:
	var count := AlarmStore.count_on(_date_key)
	var when := AlarmStore.format_date(_date_key)
	_date_label.text = when
	if when == "今天":
		_count_label.text = "今天贪睡了 %d 次" % count
	else:
		_count_label.text = "%s贪睡了 %d 次" % [when, count]
	if _playback != count:
		_playback = count
		_sunflower.play_count(count)


func shift_date(days: int) -> void:
	var today := AlarmStore.today_key()
	var earliest := AlarmStore.shift_date(today, -6)
	var next := AlarmStore.shift_date(_date_key, days)
	if next > today:
		next = today
	if next < earliest:
		next = earliest
	_date_key = next
	_playback = -1
	_refresh()
	if _prev_button:
		_prev_button.disabled = _date_key <= earliest
	if _next_button:
		_next_button.disabled = _date_key >= today
