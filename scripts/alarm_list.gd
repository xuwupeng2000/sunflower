extends PanelContainer

signal edit_requested(alarm: Dictionary)

var _rows: VBoxContainer
var _editor: PanelContainer
var _hour: SpinBox
var _minute: SpinBox
var _label: LineEdit
var _day_buttons: Array[Button] = []
var _editing_id := ""
var _heading: Label
var _delete_button: Button


func _ready() -> void:
	var store: Node = get_node("/root/AlarmStore")
	store.changed.connect(_rebuild)
	_build()
	_rebuild()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "闹钟"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)

	var add := Button.new()
	add.text = "添加闹钟"
	add.pressed.connect(_open_editor.bind(""))
	box.add_child(add)

	var preview := Button.new()
	preview.text = "试听铃声"
	preview.pressed.connect(func() -> void:
		get_node("/root/AlarmService").preview_ring()
	)
	box.add_child(preview)

	var snooze := Button.new()
	snooze.text = "记一次贪睡"
	snooze.pressed.connect(func() -> void:
		var service: Node = get_node("/root/AlarmService")
		var store: Node = get_node("/root/AlarmStore")
		var alarm_id := ""
		if store.alarms.size() > 0:
			alarm_id = str(store.alarms[0].get("id", ""))
		if service.using_native:
			return
		service.record_desktop_snooze(alarm_id)
	)
	box.add_child(snooze)

	_editor = _build_editor()
	_editor.visible = false
	box.add_child(_editor)


func _build_editor() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "添加闹钟"
	box.add_child(heading)
	_heading = heading

	var time_row := HBoxContainer.new()
	_hour = SpinBox.new()
	_hour.min_value = 0
	_hour.max_value = 23
	_hour.value = 7
	_hour.custom_arrow_step = 1
	_minute = SpinBox.new()
	_minute.min_value = 0
	_minute.max_value = 59
	_minute.value = 0
	time_row.add_child(_hour)
	var colon := Label.new()
	colon.text = ":"
	time_row.add_child(colon)
	time_row.add_child(_minute)
	box.add_child(time_row)

	var days := HBoxContainer.new()
	days.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in 7:
		var button := Button.new()
		button.toggle_mode = true
		button.text = AlarmStore.WEEKDAY_NAMES[index]
		button.button_pressed = index < 5
		button.custom_minimum_size = Vector2(36, 36)
		_day_buttons.append(button)
		days.add_child(button)
	box.add_child(days)

	_label = LineEdit.new()
	_label.placeholder_text = "标签，例如起床"
	box.add_child(_label)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(func() -> void: _editor.visible = false)
	var delete_alarm := Button.new()
	delete_alarm.text = "删除"
	delete_alarm.pressed.connect(_delete_editing)
	_delete_button = delete_alarm
	var save := Button.new()
	save.text = "存储"
	save.pressed.connect(_save_editor)
	actions.add_child(cancel)
	actions.add_child(delete_alarm)
	actions.add_child(save)
	box.add_child(actions)
	return panel


func _rebuild() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	var store: Node = get_node("/root/AlarmStore")
	if store.alarms.is_empty():
		var empty := Label.new()
		empty.text = "还没有闹钟"
		_rows.add_child(empty)
		return
	for alarm in store.alarms:
		_rows.add_child(_make_row(alarm))


func _make_row(alarm: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var time := Label.new()
	time.text = AlarmStore.format_time(int(alarm["hour"]), int(alarm["minute"]))
	time.add_theme_font_size_override("font_size", 32)
	var detail := Label.new()
	detail.text = "%s  %s" % [AlarmStore.format_weekdays(alarm["weekdays"]), alarm["label"]]
	text.add_child(time)
	text.add_child(detail)
	row.add_child(text)
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(alarm["enabled"])
	toggle.toggled.connect(func(on: bool) -> void:
		AlarmStore.set_enabled(str(alarm["id"]), on)
		AlarmService.schedule(AlarmStore.find_alarm(str(alarm["id"])))
	)
	row.add_child(toggle)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_editor(str(alarm["id"]))
	)
	return panel


func _open_editor(alarm_id: String) -> void:
	_editing_id = alarm_id
	if alarm_id.is_empty():
		_heading.text = "添加闹钟"
		_hour.value = 7
		_minute.value = 0
		_label.text = ""
		for index in _day_buttons.size():
			_day_buttons[index].button_pressed = index < 5
		_delete_button.visible = false
	else:
		var alarm: Dictionary = AlarmStore.find_alarm(alarm_id)
		_heading.text = "编辑闹钟"
		_hour.value = int(alarm.get("hour", 7))
		_minute.value = int(alarm.get("minute", 0))
		_label.text = str(alarm.get("label", ""))
		var days: Array = alarm.get("weekdays", [])
		for index in _day_buttons.size():
			_day_buttons[index].button_pressed = (index + 1) in days
		_delete_button.visible = true
	_editor.visible = true


func _delete_editing() -> void:
	if _editing_id.is_empty():
		return
	AlarmService.cancel(_editing_id)
	AlarmStore.remove_alarm(_editing_id)
	_editor.visible = false


func _save_editor() -> void:
	var days: Array[int] = []
	for index in _day_buttons.size():
		if _day_buttons[index].button_pressed:
			days.append(index + 1)
	var hour := int(_hour.value)
	var minute := int(_minute.value)
	var label := _label.text.strip_edges()
	var alarm: Dictionary
	if _editing_id.is_empty():
		alarm = AlarmStore.add_alarm(hour, minute, days, label)
	else:
		alarm = AlarmStore.update_alarm(_editing_id, hour, minute, days, label)
	if not alarm.is_empty():
		AlarmService.schedule(alarm)
	_editor.visible = false
