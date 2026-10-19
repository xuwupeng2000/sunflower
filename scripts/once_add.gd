extends ColorRect

signal date_picked(date_key: String, once_name: String)

const DRAG_SLOP := 12.0
const DAY_PATHS := [
	"行1/周一", "行1/周二", "行1/周三",
	"行2/周四", "行2/周五",
	"行3/周六", "行3/周日",
]

@onready var _this: VBoxContainer = $居中/面板/内容/滚动/块/本周
@onready var _next: VBoxContainer = $居中/面板/内容/滚动/块/下周
@onready var _after: VBoxContainer = $居中/面板/内容/滚动/块/下下周
@onready var _this_title: Label = $居中/面板/内容/滚动/块/本周/标题
@onready var _next_title: Label = $居中/面板/内容/滚动/块/下周/标题
@onready var _after_title: Label = $居中/面板/内容/滚动/块/下下周/标题
@onready var _scroll: ScrollContainer = $居中/面板/内容/滚动
@onready var _custom_button: Button = $居中/面板/内容/滚动/块/自选边距/自选日期
@onready var _popup: Control = $自选弹窗
@onready var _popup_panel: Control = $自选弹窗/居中/面板
@onready var _popup_hint: Label = $自选弹窗/居中/面板/内容/提示
@onready var _year: Control = $自选弹窗/居中/面板/内容/滚轮区/列/年
@onready var _month: Control = $自选弹窗/居中/面板/内容/滚轮区/列/月
@onready var _day: Control = $自选弹窗/居中/面板/内容/滚轮区/列/日
@onready var _done: Button = $自选弹窗/居中/面板/内容/完成
@onready var _hint: Label = $居中/面板/内容/提示
@onready var _name: LineEdit = $居中/面板/内容/名字
@onready var _confirm: Button = $居中/面板/内容/确认

var _selected := ""
var _press_at := Vector2.ZERO
var _press_hit: Control
var _dragged := false
var _weeks: Array[VBoxContainer] = []


func _ready() -> void:
	visible = false
	_weeks = [_this, _next, _after]
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and not _popup.visible:
			visible = false
	)
	_popup.get_node("居中").gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and not _popup_panel.get_global_rect().has_point(event.global_position):
			_hide_wheels()
			_popup.get_node("居中").accept_event()
	)
	_scroll.gui_input.connect(_on_scroll_input)
	_custom_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_done.pressed.connect(_pick_custom)
	_confirm.pressed.connect(_confirm_date)
	_year.settled.connect(func(_value: int) -> void: _fit_day())
	_month.settled.connect(func(_value: int) -> void: _fit_day())
	_hide_wheels()


func _input(event: InputEvent) -> void:
	if not visible or not _is_press(event) or not _keyboard_open():
		return
	var at := _press_point(event)
	if _name.get_global_rect().has_point(at):
		return
	_hide_keyboard()
	var panel := $居中/面板 as Control
	if panel and not panel.get_global_rect().has_point(at):
		get_viewport().set_input_as_handled()


func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	return event is InputEventScreenTouch and event.pressed


func _press_point(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return event.position
	return (event as InputEventScreenTouch).position


func _keyboard_open() -> bool:
	if _name.has_focus() and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return true
	return DisplayServer.virtual_keyboard_get_height() > 0


func _hide_keyboard() -> void:
	_name.release_focus()
	DisplayServer.virtual_keyboard_hide()


func open(once_name: String = "", date_key: String = "") -> void:
	_selected = date_key
	_rebuild()
	_hide_wheels()
	_name.text = once_name
	_name.placeholder_text = tr("输入提醒名称")
	visible = true
	_mark_selected(true)


func _rebuild() -> void:
	_this_title.text = tr("本周")
	_next_title.text = tr("下周")
	_after_title.text = tr("下下周")
	_hint.text = tr("哪一天？")
	_custom_button.text = tr("自选日期")
	_popup_hint.text = tr("自选日期")
	_done.text = tr("确认")
	var today := AlarmStore.local_today_key()
	var this_monday := AlarmStore.monday_of(today)
	_fill_week(_this, this_monday, today)
	_fill_week(_next, AlarmStore.shift_date(this_monday, 7), today)
	_fill_week(_after, AlarmStore.shift_date(this_monday, 14), today)
	_this.visible = today < AlarmStore.shift_date(this_monday, 6)


func _fill_week(box: VBoxContainer, monday: String, today: String) -> void:
	for index in DAY_PATHS.size():
		var button := box.get_node(DAY_PATHS[index]) as Button
		var date_key := AlarmStore.shift_date(monday, index)
		var parts := date_key.split("-")
		var month_day := "%d/%d" % [int(parts[1]), int(parts[2])] if parts.size() == 3 else date_key
		button.text = "%s\n%s" % [tr("周" + AlarmStore.WEEKDAY_NAMES[index]), month_day]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.set_meta("soft", true)
		button.theme_type_variation = "DayButton"
		button.custom_minimum_size = Vector2(0, 35)
		var open := date_key >= today
		button.visible = open
		if open:
			button.set_meta("date", date_key)
		else:
			button.remove_meta("date")
	for row_name in ["行1", "行2", "行3"]:
		var row := box.get_node(row_name) as Control
		var shown := false
		for child in row.get_children():
			if child.visible:
				shown = true
				break
		row.visible = shown
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.custom_minimum_size.x = 250


func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.global_position
			_press_hit = _hit_at(event.global_position)
			_dragged = false
		elif not _dragged:
			_activate(_press_hit)
			_press_hit = null
		return
	if event is InputEventMouseMotion and _press_hit != null:
		if event.global_position.distance_to(_press_at) > DRAG_SLOP:
			_dragged = true
			_press_hit = null


func _hit_at(global_pos: Vector2) -> Control:
	if _custom_button.visible and _custom_button.get_global_rect().has_point(global_pos):
		return _custom_button
	for box in _weeks:
		if not box.visible:
			continue
		for path in DAY_PATHS:
			var button := box.get_node(path) as Button
			if button.visible and button.get_global_rect().has_point(global_pos):
				return button
	return null


func _activate(hit: Control) -> void:
	if hit == null:
		return
	if hit == _custom_button:
		if _named():
			_show_wheels()
		return
	var date_key := str(hit.get_meta("date", ""))
	if date_key.is_empty():
		return
	_selected = date_key
	_mark_selected(false)


func _named() -> bool:
	if _name.text.strip_edges().is_empty():
		_name.grab_focus()
		return false
	return true


func _confirm_date() -> void:
	if _selected.is_empty():
		return
	_pick(_selected)


func _mark_selected(scroll: bool) -> void:
	var found: Button = null
	for box in _weeks:
		for path in DAY_PATHS:
			var button := box.get_node(path) as Button
			var chosen := button.visible and str(button.get_meta("date", "")) == _selected
			button.toggle_mode = true
			button.set_pressed_no_signal(chosen)
			if chosen:
				found = button
	_confirm.disabled = _selected.is_empty()
	_confirm.text = tr("确认")
	if _selected.is_empty():
		_hint.text = tr("哪一天？")
	else:
		_hint.text = "%s · %s" % [tr("哪一天？"), AlarmStore.agenda_when(_selected)]
	if scroll and found != null:
		_scroll.call_deferred("ensure_control_visible", found)


func _pick(date_key: String) -> void:
	if not _named():
		return
	_name.release_focus()
	visible = false
	_hide_wheels()
	date_picked.emit(date_key, _name.text.strip_edges())


func _show_wheels() -> void:
	var now := Time.get_date_dict_from_system()
	_year.minimum = int(now.year)
	_year.maximum = int(now.year) + 1
	_year.value = int(now.year)
	_month.value = int(now.month)
	_day.value = int(now.day)
	_fit_day()
	_popup.visible = true


func _hide_wheels() -> void:
	_popup.visible = false


func _fit_day() -> void:
	var year: int = _year.value
	var month: int = _month.value
	var last := _days_in(year, month)
	_day.maximum = last
	if _day.value > last:
		_day.value = last
	_year.queue_redraw()
	_month.queue_redraw()
	_day.queue_redraw()


func _days_in(year: int, month: int) -> int:
	if month == 2:
		var leap := year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
		return 29 if leap else 28
	if month in [4, 6, 9, 11]:
		return 30
	return 31


func _wheel_value(wheel: Control) -> int:
	var number := int(wheel.commit_value())
	var minimum := int(wheel.minimum)
	var maximum := int(wheel.maximum)
	if number < minimum or number > maximum:
		var span := maxi(1, maximum - minimum + 1)
		number = minimum + posmod(number - minimum, span)
	return number


func _pick_custom() -> void:
	var year := _wheel_value(_year)
	var month := _wheel_value(_month)
	var day := _wheel_value(_day)
	var last := _days_in(year, month)
	if day > last:
		day = last
	var date_key := "%04d-%02d-%02d" % [year, month, day]
	if date_key < AlarmStore.local_today_key():
		return
	_pick(date_key)
