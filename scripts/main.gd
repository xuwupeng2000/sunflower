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
var _click: AudioStreamPlayer
var _hour_wheel: Control
var _minute_wheel: Control
var _picker: Control


func _ready() -> void:
	_sunflower = $Sunflower
	_bind_nodes()
	_bind_clicks(self)
	get_tree().node_added.connect(_wire_click)
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
	_wake_button.pressed.connect(_open_time_picker.bind("wake"))
	_sleep_button.pressed.connect(_open_time_picker.bind("sleep"))
	_alarm_page.get_node("边框/内容/记一次贪睡").pressed.connect(_record_snooze)
	var icons := root.get_node("底栏/图标")
	var specs := ["flower", "pot", "alarm"]
	for index in icons.get_child_count():
		var button := icons.get_child(index) as Button
		button.pressed.connect(_show_tab.bind(specs[index]))
		_tab_buttons.append(button)
	_picker = root.get_node("时间选择")
	_picker.gui_input.connect(_close_picker_on_click)
	_hour_wheel = _picker.get_node("居中/面板/内容/滚轮区/列/时")
	_minute_wheel = _picker.get_node("居中/面板/内容/滚轮区/列/分")
	_hour_wheel.settled.connect(_on_hour)
	_minute_wheel.settled.connect(_on_minute)
	_picker.get_node("居中/面板/内容/完成").pressed.connect(func() -> void: _picker.visible = false)


func _fill_pot_rows() -> void:
	var flower_names := PackedStringArray()
	for kind in _sunflower.flower_kinds():
		flower_names.append(str(kind["name"]))
	var pot_names := PackedStringArray()
	for kind in _sunflower.pot_kinds():
		pot_names.append(str(kind["name"]))
	var flower_row := _pot_page.get_node("边框/列表/花")
	var pot_row := _pot_page.get_node("边框/列表/盆")
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


func _on_hour(number: int) -> void:
	_picker_hour = number
	AlarmStore.set_day_time(_selected_day, _editing_kind, _picker_hour, _picker_minute)
	_update_time_label()
	_schedule_days()


func _on_minute(number: int) -> void:
	_picker_minute = number
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
	var click := AudioStreamPlayer.new()
	click.name = "Click"
	click.stream = load("res://ios/sounds/underwater_click.wav")
	add_child(click)
	_click = click


func _bind_clicks(node: Node) -> void:
	_wire_click(node)
	for child in node.get_children():
		_bind_clicks(child)


func _wire_click(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_play_click):
		node.pressed.connect(_play_click)


func _play_click() -> void:
	if _click and _click.stream:
		_click.play()


func _show_tab(tab: String) -> void:
	for index in _tab_buttons.size():
		_tab_buttons[index].set_pressed_no_signal(["flower", "pot", "alarm"][index] == tab)
	_flower_page.visible = tab == "flower"
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
	_wake_button.text = "%02d:%02d" % [int(slot["wake_hour"]), int(slot["wake_minute"])]
	_sleep_button.text = "%02d:%02d" % [int(slot["sleep_hour"]), int(slot["sleep_minute"])]


func _schedule_days() -> void:
	for alarm in AlarmStore.alarms:
		AlarmService.schedule(alarm)


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
