extends Node

var _date_key := ""
var _date_label: Label
var _count_label: Label
var _due_label: Label
var _sunflower: Node3D
var _flower_page: Control
var _pot_page: Control
var _wip_note: Control
var _wip_tween: Tween
var _alarm_page: Control
var _selected_day := 0
var _current_tab := ""
var _ring_popup: Control
var _ring_names: Label
var _cancel_snooze: Button
var _triggered_id := ""
var _dismissed_ring := ""
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
var _name_dialog: Control
var _name_field: LineEdit
var _selected_task := -1
var _rename_mode := false
var _name_holding := false
var _name_held := false
var _hold_button: Button
var _reordering := false
var _order_dirty := false
var _ignore_tab_press := false
const TaskTabScene := preload("res://scenes/task_tab.tscn")
const QUICK_END_MINUTES := [15, 30, 60]
const TABS := ["flower", "pot", "alarm", "timer"]
## 按下缩一点、松手弹回来，按钮才有软绵绵的手感。
const PRESS_SCALE := 0.96
const PRESS_IN := 0.08
const PRESS_OUT := 0.28
const NO_SQUISH := [&"TabIcon", &"CareButton", &"ClockButton"]
const SMALLEST_FONT := 11
const HOLD_SECONDS := 0.28
## 长按标签或星期多久弹出菜单；弹出后手指挪开这么远就当成拖动排序。
const MENU_HOLD := 0.8
const DRAG_SLOP := 12.0
var _editing_kind := "wake"
var _picker_hour := 7
var _picker_minute := 0
var _day_buttons: Array[Button] = []
var _week_drag := false
var _week_days: Control
var _tab_buttons: Array[Button] = []
var _prev_button: Button
var _next_button: Button
var _playback := -1
var _times: Control
var _time_fade: Tween
var _hour_wheel: Control
var _minute_wheel: Control
var _ampm_wheel: Control
var _picker: Control
var _picker_warn: Label
var _picker_done: Button
var _apply_dialog: Control
var _apply_days: Array[Button] = []
var _pending_task_apply := false
var _guide: Control
var _guide_step := 0
var _hold_menu: Control
var _remove_dialog: Control
var _remove_index := -1
var _pause_note: Label
var _menu_task := -1
var _press_at := Vector2.ZERO
var _day_hold := 0
var _start_title: Label
var _add_end_row: Button
var _end_row: Control
var _end_button: Button
var _picker_tabs: Control
var _start_tab: Button
var _end_tab: Button
var _end_area: Control
var _end_options: Control
var _add_end_button: Button
var _quick_ends: Array[Button] = []
var _picker_tab := "start"
var _picker_has_end := false
var _picker_end_hour := 10
var _picker_end_minute := 0
var _water_button: Button
var _feed_button: Button
var _feed_count: Label
var _care_layer: Control
var _care_ghost: TextureRect
var _care_spout: Marker2D
var _care_mouth: Marker2D
var _feeding := false
var _care_kind := ""
var _care_home := Vector2.ZERO
var _care_poured := false
var _tip_tween: Tween
const GUIDE_PAD := 6.0
const GUIDE_STEPS := [
	["加号框", "加号说明"],
	["星期框", "星期说明", "时间框", "时间说明"],
	["长按框", "长按说明"],
]


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
	get_tree().node_added.connect(_soften)
	for node in $UI.find_children("*", "Button", true, false):
		_soften(node)
	_start_forest()
	var ring := load("res://ios/sounds/sunflower.wav")
	if ring:
		$RingPlayer.stream = ring
	_date_key = AlarmStore.today_key()
	AlarmStore.changed.connect(_refresh)
	AlarmService.snoozes_updated.connect(_refresh)
	_fill_pot_rows()
	_select_day(_today_alarm_index(), false)
	shift_date(0)
	_show_tab("flower")
	_catch_ringing()
	_schedule_days()
	set_process(false)


func _soften(node: Node) -> void:
	var button := node as Button
	if button == null or button.flat or button.has_meta("soft") or NO_SQUISH.has(button.theme_type_variation):
		return
	button.set_meta("soft", true)
	button.button_down.connect(_squish.bind(button, true))
	button.button_up.connect(_squish.bind(button, false))
	button.visibility_changed.connect(func() -> void: button.scale = Vector2.ONE)


func _squish(button: Button, down: bool) -> void:
	if button.has_meta("squish"):
		var old := button.get_meta("squish") as Tween
		if old != null and old.is_valid():
			old.kill()
	button.pivot_offset = button.size / 2.0
	var tween := button.create_tween()
	if down:
		tween.tween_property(button, "scale", Vector2.ONE * PRESS_SCALE, PRESS_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(button, "scale", Vector2.ONE, PRESS_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	button.set_meta("squish", tween)


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	if _date_label != null and AlarmStore.apply_system_setting():
		_refresh()
		_update_time_label()
		_apply_task_chrome()
		_schedule_days()
	if _ring_popup != null:
		_catch_ringing()


func _bind_nodes() -> void:
	var root := $UI/界面
	_date_label = root.get_node("看花页/顶部/日期行/日期")
	_count_label = root.get_node("看花页/顶部/次数")
	_due_label = root.get_node("看花页/顶部/到点事项")
	_prev_button = root.get_node("看花页/顶部/日期行/前一天")
	_next_button = root.get_node("看花页/顶部/日期行/后一天")
	_prev_button.pressed.connect(func() -> void: shift_date(-1))
	_next_button.pressed.connect(func() -> void: shift_date(1))
	_flower_page = root.get_node("看花页")
	_water_button = _flower_page.get_node("照料/浇水")
	_feed_button = _flower_page.get_node("照料/施肥")
	_feed_count = _feed_button.get_node("数量")
	_care_layer = _flower_page.get_node("拖拽层")
	_care_ghost = _care_layer.get_node("图标")
	_care_spout = _care_ghost.get_node("壶嘴")
	_care_mouth = _care_ghost.get_node("袋口")
	_water_button.button_down.connect(_on_care_button_down.bind("water"))
	_feed_button.button_down.connect(_on_care_button_down.bind("feed"))
	_water_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_feed_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_water_button.focus_mode = Control.FOCUS_NONE
	_feed_button.focus_mode = Control.FOCUS_NONE
	_pot_page = root.get_node("花盆页/花盆")
	_wip_note = root.get_node("研发中")
	_alarm_page = root.get_node("定时页/定时")
	var days := _alarm_page.get_node("边框/内容/行列/星期") as Control
	days.mouse_filter = Control.MOUSE_FILTER_STOP
	days.gui_input.connect(_on_week_gesture.bind(days))
	for index in days.get_child_count():
		var button := days.get_child(index) as Button
		button.toggle_mode = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_day_buttons.append(button)
	_times = _alarm_page.get_node("边框/内容/行列/时间")
	_wake_button = _times.get_node("起床/钟点")
	_sleep_button = _times.get_node("睡觉/钟点")
	_wake_row = _times.get_node("起床")
	_sleep_row = _times.get_node("睡觉")
	_task_row = _times.get_node("任务时间")
	_start_title = _task_row.get_node("标题")
	_add_end_row = _task_row.get_node("添加结束")
	_end_row = _times.get_node("结束")
	_end_button = _end_row.get_node("钟点")
	_end_button.pressed.connect(_open_time_picker.bind("task", "end"))
	_add_end_row.pressed.connect(func() -> void:
		_open_time_picker("task")
		_add_picker_end()
	)
	_task_name = _alarm_page.get_node("边框/内容/行列/时间/提醒标题")
	_task_name.mouse_filter = Control.MOUSE_FILTER_STOP
	_task_name.gui_input.connect(_on_task_name_input)
	_task_button = _task_row.get_node("钟点")
	_wake_button.pressed.connect(_open_time_picker.bind("wake"))
	_sleep_button.pressed.connect(_open_time_picker.bind("sleep"))
	_task_button.pressed.connect(_open_time_picker.bind("task"))
	_pause_note = _times.get_node("暂停说明")
	_tab_scroll = _alarm_page.get_node("边框/内容/标签行/滚动")
	_task_tabs = _tab_scroll.get_node("边距/任务")
	_sleep_tab = _task_tabs.get_node("睡觉")
	_sleep_tab.toggle_mode = true
	_sleep_tab.pressed.connect(_show_sleep_task)
	_sleep_tab.gui_input.connect(_on_task_tab_input.bind(_sleep_tab))
	_tab_template = _task_tabs.get_node_or_null("样例") as Button
	for child in _task_tabs.get_children():
		if child != _sleep_tab and child != _tab_template:
			_tab_previews.append(child)
	_alarm_page.get_node("边框/内容/标签行/加号").pressed.connect(_open_task_name)
	_rebuild_task_tabs()
	_show_default_task()
	var debug_snooze := _alarm_page.get_node("边框/内容/操作/按钮/记一次贪睡") as Button
	debug_snooze.visible = OS.has_feature("editor")
	debug_snooze.pressed.connect(_record_snooze)
	_ring_popup = root.get_node("到点弹窗")
	_ring_names = _ring_popup.get_node("居中/面板/内容/名单")
	_ring_popup.get_node("居中/面板/内容/去改").pressed.connect(_open_triggered_alarm)
	_ring_popup.get_node("居中/面板/内容/看花").pressed.connect(_dismiss_ring)
	_cancel_snooze = _ring_popup.get_node("居中/面板/内容/取消推迟")
	_cancel_snooze.pressed.connect(_cancel_current_snooze)
	var icons := root.get_node("底栏/图标")
	var specs := TABS
	for index in icons.get_child_count():
		var button := icons.get_child(index) as Button
		button.pressed.connect(_show_tab.bind(specs[index]))
		_tab_buttons.append(button)
	_picker = root.get_node("时间选择")
	_picker.gui_input.connect(_close_picker_on_click)
	_name_dialog = root.get_node("任务命名")
	_name_dialog.gui_input.connect(_close_name_on_click)
	_name_field = _name_dialog.get_node("居中/面板/内容/名字")
	_hold_menu = root.get_node("长按菜单")
	_remove_dialog = root.get_node("删除提醒")
	_remove_dialog.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_remove_dialog.visible = false
	)
	_remove_dialog.get_node("居中/面板/内容/按钮/取消").pressed.connect(func() -> void: _remove_dialog.visible = false)
	_remove_dialog.get_node("居中/面板/内容/按钮/删除").pressed.connect(_confirm_remove_task)
	_name_dialog.get_node("居中/面板/内容/健身").pressed.connect(_confirm_new_task.bind(tr("💪 健身")))
	_name_dialog.get_node("居中/面板/内容/接娃").pressed.connect(_confirm_new_task.bind(tr("👶 接娃")))
	_name_dialog.get_node("居中/面板/内容/吃药").pressed.connect(_confirm_new_task.bind(tr("💊 吃药")))
	_name_dialog.get_node("居中/面板/内容/完成").pressed.connect(_confirm_typed_task)
	_ampm_wheel = _picker.get_node("居中/面板/内容/滚轮区/列/上下午")
	_hour_wheel = _picker.get_node("居中/面板/内容/滚轮区/列/时")
	_minute_wheel = _picker.get_node("居中/面板/内容/滚轮区/列/分")
	_ampm_wheel.settled.connect(_on_hour_wheel)
	_hour_wheel.settled.connect(_on_hour_wheel)
	_minute_wheel.settled.connect(_on_minute)
	_picker_warn = _picker.get_node("居中/面板/内容/时间提示")
	_picker_done = _picker.get_node("居中/面板/内容/完成")
	_picker_done.pressed.connect(_finish_picker)
	_picker_tabs = _picker.get_node("居中/面板/内容/页签")
	_start_tab = _picker_tabs.get_node("开始")
	_end_tab = _picker_tabs.get_node("结束")
	var tab_group := ButtonGroup.new()
	_start_tab.button_group = tab_group
	_end_tab.button_group = tab_group
	_start_tab.pressed.connect(_switch_picker_tab.bind("start"))
	_end_tab.pressed.connect(_switch_picker_tab.bind("end"))
	_start_tab.resized.connect(func() -> void: _fit_font(_start_tab, 18))
	_end_tab.resized.connect(func() -> void: _fit_font(_end_tab, 18))
	_end_area = _picker.get_node("居中/面板/内容/结束区")
	_end_options = _end_area.get_node("选项")
	for index in QUICK_END_MINUTES.size():
		var quick := _end_options.get_child(index) as Button
		quick.pressed.connect(_pick_quick_end.bind(int(QUICK_END_MINUTES[index])))
		_quick_ends.append(quick)
	_end_options.get_node("没有结束").pressed.connect(_remove_picker_end)
	_add_end_button = _picker.get_node("居中/面板/内容/增加结束")
	_add_end_button.pressed.connect(_add_picker_end)
	_apply_dialog = root.get_node("应用到")
	_apply_dialog.gui_input.connect(_close_apply_on_click)
	var weekday_row := _apply_dialog.get_node("居中/面板/内容/星期")
	for child in weekday_row.get_children():
		_apply_days.append(child as Button)
	_apply_dialog.get_node("居中/面板/内容/完成").pressed.connect(_confirm_weekday_apply)
	_guide = root.get_node_or_null("教程")
	if _guide != null:
		_guide.gui_input.connect(_on_guide_input)


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
		_pending_task_apply = false
		_picker.visible = false


func _finish_picker() -> void:
	var hour := _hour_from_wheels(_ampm_wheel.commit_value(), _hour_wheel.commit_value())
	var minute: int = _minute_wheel.commit_value()
	_store_wheel_time(hour, minute)
	if not _picker_problem().is_empty():
		return
	_picker.visible = false
	if _pending_task_apply:
		_open_weekday_apply()
		return
	_commit_time()


func _on_hour_wheel(_number: int) -> void:
	# 上下午和 1–12 两个轮子合出 0–23 存起来，存档一直是 24 小时制。
	var hour := _hour_from_wheels(_ampm_wheel.value, _hour_wheel.value)
	var minute := _picker_end_minute if _picker_tab == "end" else _picker_minute
	_store_wheel_time(hour, minute)
	_commit_time()


func _hour_from_wheels(ampm: int, hour12: int) -> int:
	return (hour12 % 12) + 12 * ampm


func _on_minute(number: int) -> void:
	var hour := _picker_end_hour if _picker_tab == "end" else _picker_hour
	_store_wheel_time(hour, number)
	_commit_time()


func _store_wheel_time(hour: int, minute: int) -> void:
	if _picker_tab == "end":
		_picker_end_hour = hour
		_picker_end_minute = minute
	else:
		_picker_hour = hour
		_picker_minute = minute
	_refresh_picker_tabs()


func _commit_time() -> void:
	if _pending_task_apply or not _picker_problem().is_empty():
		return
	if _editing_kind == "task":
		AlarmStore.set_task_time(_selected_task, _selected_day, _picker_hour, _picker_minute)
		if _picker_has_end:
			AlarmStore.set_task_end(_selected_task, _selected_day, _picker_end_hour, _picker_end_minute)
	else:
		AlarmStore.set_day_time(_selected_day, _editing_kind, _picker_hour, _picker_minute)
	_update_time_label()
	_schedule_days()


func _set_wheels(hour: int, minute: int) -> void:
	_ampm_wheel.value = 1 if hour >= 12 else 0
	_hour_wheel.value = 12 if hour % 12 == 0 else hour % 12
	_minute_wheel.value = minute
	_ampm_wheel.queue_redraw()
	_hour_wheel.queue_redraw()
	_minute_wheel.queue_redraw()


func _switch_picker_tab(tab: String) -> void:
	if _picker.visible and tab != _picker_tab:
		var hour := _hour_from_wheels(_ampm_wheel.commit_value(), _hour_wheel.commit_value())
		var minute: int = _minute_wheel.commit_value()
		var was_end := _picker_tab == "end"
		if hour != (_picker_end_hour if was_end else _picker_hour) or minute != (_picker_end_minute if was_end else _picker_minute):
			_store_wheel_time(hour, minute)
			_commit_time()
	_picker_tab = tab
	if tab == "end":
		_set_wheels(_picker_end_hour, _picker_end_minute)
	else:
		_set_wheels(_picker_hour, _picker_minute)
	_refresh_picker_tabs()


func _add_picker_end() -> void:
	_picker_has_end = true
	_pick_quick_end(60)
	_switch_picker_tab("end")


func _pick_quick_end(minutes: int) -> void:
	var total := _picker_hour * 60 + _picker_minute + minutes
	_picker_end_hour = floori(total / 60.0) % 24
	_picker_end_minute = total % 60
	if _picker_tab == "end":
		_set_wheels(_picker_end_hour, _picker_end_minute)
	var tab := _picker_tab
	_picker_tab = "end"
	_commit_time()
	_picker_tab = tab
	_refresh_picker_tabs()


func _remove_picker_end() -> void:
	_picker_has_end = false
	if not _pending_task_apply:
		AlarmStore.clear_task_end(_selected_task, _selected_day)
		_commit_time()
	_switch_picker_tab("start")


## 结束要晚于开始、睡觉要晚于起床，都算在同一天里；不对就返回要提示的话。
func _picker_problem() -> String:
	var picked := _picker_hour * 60 + _picker_minute
	if _editing_kind == "task":
		if _picker_has_end and _picker_end_hour * 60 + _picker_end_minute <= picked:
			return tr("结束时间要晚于开始时间")
		return ""
	var slot: Dictionary = AlarmStore.day_slot(_selected_day)
	var wake := int(slot["wake_hour"]) * 60 + int(slot["wake_minute"])
	var sleep := int(slot["sleep_hour"]) * 60 + int(slot["sleep_minute"])
	if _editing_kind == "wake":
		wake = picked
	else:
		sleep = picked
	if sleep <= wake:
		return tr("睡觉时间要晚于起床时间")
	return ""


func _refresh_picker_tabs() -> void:
	var problem := _picker_problem()
	_picker_warn.text = problem
	_picker_warn.visible = not problem.is_empty()
	_picker_done.disabled = not problem.is_empty()
	var task := _editing_kind == "task"
	_picker_tabs.visible = task and _picker_has_end
	_end_area.visible = task and _picker_has_end
	_end_options.visible = _picker_tab == "end"
	_add_end_button.visible = task and not _picker_has_end
	_start_tab.set_pressed_no_signal(_picker_tab == "start")
	_end_tab.set_pressed_no_signal(_picker_tab == "end")
	_start_tab.text = "%s  %s" % [tr("开始"), _clock_text(_picker_hour, _picker_minute)]
	_end_tab.text = "%s  %s" % [tr("结束"), _clock_text(_picker_end_hour, _picker_end_minute)]
	_fit_font(_start_tab, 18)
	_fit_font(_end_tab, 18)
	var gap := posmod(_picker_end_hour * 60 + _picker_end_minute - _picker_hour * 60 - _picker_minute, 1440)
	for index in _quick_ends.size():
		_quick_ends[index].set_pressed_no_signal(gap == int(QUICK_END_MINUTES[index]))


func _clock_text(hour: int, minute: int) -> String:
	var hour12 := 12 if hour % 12 == 0 else hour % 12
	return "%s %d:%02d" % [tr("上午") if hour < 12 else tr("下午"), hour12, minute]


# 字多的按钮不变宽，只把字号调小到放得下。
func _fit_font(button: Button, largest: int) -> void:
	var font := button.get_theme_font("font")
	var style := button.get_theme_stylebox("normal")
	var room := maxf(button.size.x, button.custom_minimum_size.x) - style.get_minimum_size().x
	if room <= 0.0:
		return
	var font_size := largest
	while font_size > SMALLEST_FONT and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	button.add_theme_font_size_override("font_size", font_size)


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


func _today_alarm_index() -> int:
	var godot_day := int(Time.get_datetime_dict_from_system().get("weekday", 0))
	return 6 if godot_day == 0 else godot_day - 1


func _show_tab(tab: String, pin_today: bool = true) -> void:
	if tab == "pot":
		_tab_buttons[TABS.find("pot")].set_pressed_no_signal(false)
		_show_wip()
		return
	if pin_today and tab != "flower" and _current_tab == tab:
		tab = "flower"
	_current_tab = tab
	if tab == "alarm" and pin_today:
		_select_day(_today_alarm_index(), false)
	for index in _tab_buttons.size():
		_tab_buttons[index].set_pressed_no_signal(TABS[index] == tab)
	_flower_page.visible = tab == "flower" or tab == "pot"
	_pot_page.get_parent().visible = tab == "pot"
	_alarm_page.get_parent().visible = tab == "alarm"
	$UI/界面/计时页.visible = tab == "timer"
	if _water_button:
		_flower_page.get_node("照料").visible = tab == "flower"
	if tab == "alarm":
		_show_guide()


## 换花换盆是高级功能，还没做好，先只提示一下。
func _show_wip() -> void:
	if _wip_tween and _wip_tween.is_valid():
		_wip_tween.kill()
	_wip_note.visible = true
	_wip_note.modulate.a = 0.0
	_wip_tween = create_tween()
	_wip_tween.tween_property(_wip_note, "modulate:a", 1.0, 0.15)
	_wip_tween.tween_interval(1.6)
	_wip_tween.tween_property(_wip_note, "modulate:a", 0.0, 0.35)
	_wip_tween.tween_callback(_wip_note.hide)


func _show_guide() -> void:
	if _guide == null or _guide.visible:
		return
	if AlarmStore.tutorial_seen and not AlarmStore.replay_tutorials():
		return
	# 容器要跑完一帧才有位置，圈框照着真实位置贴。
	await get_tree().process_frame
	await get_tree().process_frame
	if _current_tab != "alarm":
		return
	var plus := _alarm_page.get_node("边框/内容/标签行/加号") as Control
	var days := _alarm_page.get_node("边框/内容/行列/星期") as Control
	var actions := _tab_scroll as Control
	_ring_target(_guide.get_node("加号框"), plus)
	_ring_target(_guide.get_node("星期框"), days)
	_ring_target(_guide.get_node("时间框"), _times)
	_ring_target(_guide.get_node("长按框"), actions)
	var plus_rect := plus.get_global_rect()
	var days_rect := days.get_global_rect()
	var times_rect := _times.get_global_rect()
	var actions_rect := actions.get_global_rect()
	var column_x := times_rect.position.x
	var column_w := times_rect.size.x
	_place_note(_guide.get_node("加号说明"), plus_rect.end.x - 240.0, plus_rect.end.y + GUIDE_PAD + 10.0, 240.0)
	_place_note(_guide.get_node("星期说明"), column_x, days_rect.position.y + 8.0, column_w)
	_place_note(_guide.get_node("时间说明"), column_x, times_rect.end.y + GUIDE_PAD + 12.0, column_w)
	_place_note(_guide.get_node("长按说明"), actions_rect.position.x, actions_rect.end.y + GUIDE_PAD + 10.0, actions_rect.size.x)
	_guide_step = 0
	_apply_guide_step()
	_guide.visible = true
	AlarmStore.mark_tutorial_seen()


func _apply_guide_step() -> void:
	for index in GUIDE_STEPS.size():
		for node_name in GUIDE_STEPS[index]:
			var part := _guide.get_node(node_name) as Control
			part.visible = index == _guide_step


func _ring_target(ring: Control, target: Control) -> void:
	var rect := target.get_global_rect().grow(GUIDE_PAD)
	ring.global_position = rect.position
	ring.size = rect.size


func _place_note(note: Control, x: float, y: float, width: float) -> void:
	note.size = Vector2(width, 0.0)
	note.global_position = Vector2(x, y)


func _on_guide_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	_guide.accept_event()
	_guide_step += 1
	if _guide_step < GUIDE_STEPS.size():
		_apply_guide_step()
		return
	_guide.visible = false


func _on_week_gesture(event: InputEvent, days: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_week_drag = true
		_week_days = days
		_press_at = days.get_global_mouse_position()
		_preview_week(days.get_local_mouse_position())
		days.accept_event()
		_day_hold += 1
		var token := _day_hold
		get_tree().create_timer(MENU_HOLD).timeout.connect(func() -> void:
			if token == _day_hold and _week_drag and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_open_day_menu(_day_index_at(days, days.get_local_mouse_position()))
		)


func _open_day_menu(day: int) -> void:
	_week_drag = false
	_select_day(day)
	if not _day_reminds(day):
		return
	var text := tr("继续这天") if _day_paused(day) else tr("暂停这天")
	_hold_menu.open(_day_buttons[day], text, false, _on_day_menu.bind(day))


func _on_day_menu(_action: String, day: int) -> void:
	var paused := not _day_paused(day)
	if _selected_task < 0:
		AlarmStore.set_day_enabled(day, not paused)
	else:
		AlarmStore.set_task_day_paused(_selected_task, day, paused)
	_update_time_label()
	_schedule_days()


func _input(event: InputEvent) -> void:
	if not _care_kind.is_empty():
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			_drag_care_pointer()
			get_viewport().set_input_as_handled()
		elif _is_pointer_up(event):
			_finish_care_drag_pointer()
			get_viewport().set_input_as_handled()
		return
	if not _week_drag or _week_days == null:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _week_days.get_global_mouse_position().distance_to(_press_at) > 8.0:
			_day_hold += 1
		_preview_week(_week_days.get_local_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_week_drag = false
		_select_day(_day_index_at(_week_days, _week_days.get_local_mouse_position()))
		get_viewport().set_input_as_handled()


func _preview_week(local: Vector2) -> void:
	var index := _day_index_at(_week_days, local)
	for day_index in _day_buttons.size():
		_day_buttons[day_index].set_pressed_no_signal(day_index == index)


func _day_index_at(days: Control, local: Vector2) -> int:
	var best := 0
	var best_dist := INF
	for index in days.get_child_count():
		var child := days.get_child(index) as Control
		var middle := child.position.y + child.size.y * 0.5
		var dist := absf(local.y - middle)
		if dist < best_dist:
			best_dist = dist
			best = index
	return best


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


func _open_time_picker(kind: String, tab: String = "start") -> void:
	_editing_kind = kind
	_pending_task_apply = false
	_picker_has_end = false
	# 滚轮先停在此刻，往前往后拨都近；不点完成不会改到存档。
	var now := Time.get_time_dict_from_system()
	_picker_hour = int(now["hour"])
	_picker_minute = int(now["minute"])
	if kind == "task":
		if _selected_task < 0:
			return
		var times: Array = AlarmStore.task_at(_selected_task).get("times", [])
		if _selected_day < 0 or _selected_day >= times.size():
			return
		_pending_task_apply = not AlarmStore.task_has_reminder(_selected_task)
		if not _pending_task_apply:
			var moment: Dictionary = times[_selected_day]
			_picker_hour = int(moment["hour"])
			_picker_minute = int(moment["minute"])
			_picker_has_end = moment.has("end_hour")
			if _picker_has_end:
				_picker_end_hour = int(moment["end_hour"])
				_picker_end_minute = int(moment["end_minute"])
	_picker_tab = tab if _picker_has_end else "start"
	_switch_picker_tab(_picker_tab)
	_picker.visible = true


func _open_weekday_apply() -> void:
	if _apply_dialog == null:
		_pending_task_apply = false
		_commit_time()
		return
	for index in _apply_days.size():
		_apply_days[index].set_pressed_no_signal(index == _selected_day)
	_apply_dialog.visible = true


func _close_apply_on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_pending_task_apply = false
		_apply_dialog.visible = false


func _confirm_weekday_apply() -> void:
	var days: Array[int] = []
	for index in _apply_days.size():
		if _apply_days[index].button_pressed:
			days.append(index)
	_apply_dialog.visible = false
	_pending_task_apply = false
	if days.is_empty() or _selected_task < 0:
		_update_time_label()
		return
	var end := {}
	if _picker_has_end:
		end = {"hour": _picker_end_hour, "minute": _picker_end_minute}
	AlarmStore.set_task_times_on_days(_selected_task, days, _picker_hour, _picker_minute, end)
	_update_time_label()
	_schedule_days()


func _update_time_label() -> void:
	if _wake_button == null or _sleep_button == null:
		return
	var all_paused := _whole_paused()
	var day_paused := _day_paused(_selected_day)
	if _selected_task < 0:
		var slot: Dictionary = AlarmStore.day_slot(_selected_day)
		_show_clock(_wake_button, int(slot["wake_hour"]), int(slot["wake_minute"]), true)
		_show_clock(_sleep_button, int(slot["sleep_hour"]), int(slot["sleep_minute"]), true)
	elif _task_button != null:
		var task := AlarmStore.task_at(_selected_task)
		var times: Array = task.get("times", [])
		if _selected_day >= 0 and _selected_day < times.size():
			var moment: Dictionary = times[_selected_day]
			var reminding := bool(moment.get("enabled", true))
			_show_clock(_task_button, int(moment["hour"]), int(moment["minute"]), reminding)
			var has_end := moment.has("end_hour")
			if has_end:
				_show_clock(_end_button, int(moment["end_hour"]), int(moment["end_minute"]), reminding)
			_start_title.visible = has_end
			_end_row.visible = has_end
			_add_end_row.visible = reminding and not has_end and not all_paused and not day_paused
	var faint := all_paused or day_paused
	for button in [_wake_button, _sleep_button, _task_button, _end_button]:
		if button != null:
			button.get_node("读数").modulate.a = 0.35 if faint else 1.0
	_pause_note.visible = faint
	_pause_note.text = tr("整个提醒已暂停 · 长按标签可以继续") if all_paused else tr("暂停中 · 长按星期可以继续")
	for index in _day_buttons.size():
		var off := all_paused or _day_paused(index)
		_day_buttons[index].theme_type_variation = &"PausedButton" if off else &""
		_day_buttons[index].get_node("暂停").visible = off and not all_paused


func _whole_paused() -> bool:
	return AlarmStore.sleep_paused if _selected_task < 0 else AlarmStore.task_paused(_selected_task)


func _day_paused(day: int) -> bool:
	if _selected_task < 0:
		return not bool(AlarmStore.day_slot(day).get("enabled", true))
	return AlarmStore.task_day_paused(_selected_task, day)


func _day_reminds(day: int) -> bool:
	if _selected_task < 0:
		return true
	var times: Array = AlarmStore.task_at(_selected_task).get("times", [])
	return day >= 0 and day < times.size() and bool(times[day].get("enabled", false))


func _schedule_days() -> void:
	AlarmService.sync_alarms()


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
	_name_field.text = tr("新的提醒")
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
		return tr("新的提醒")
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
	# 字体和字号都在 theme/ui.tres 的“ClockDigits / ClockMeridiem / ClockOff”里，这里只切类型。
	var meridiem := button.get_node("读数/上下午") as Label
	var digits := button.get_node("读数/数字") as Label
	if not enabled:
		meridiem.visible = false
		digits.theme_type_variation = &"ClockOff"
		digits.text = tr("不提醒")
		return
	meridiem.visible = true
	meridiem.text = tr("上午") if hour < 12 else tr("下午")
	digits.theme_type_variation = &"ClockDigits"
	var hour12 := 12 if hour % 12 == 0 else hour % 12
	digits.text = "%02d:%02d" % [hour12, minute]


func _show_sleep_task() -> void:
	_selected_task = -1
	_apply_task_chrome()


func _show_custom_task(index: int) -> void:
	_selected_task = index
	_apply_task_chrome()


func _show_default_task() -> void:
	if AlarmStore.sleep_present or AlarmStore.task_count() == 0:
		_show_sleep_task()
	else:
		_show_custom_task(0)


func _apply_task_chrome() -> void:
	var custom := _selected_task >= 0
	var sleep := not custom
	var empty := false
	if _wake_row:
		_wake_row.visible = sleep
	if _sleep_row:
		_sleep_row.visible = sleep
	if _task_row:
		_task_row.visible = custom
	if _end_row and not custom:
		_end_row.visible = false
	if _task_name:
		_task_name.visible = custom or empty
		if custom:
			_task_name.text = str(AlarmStore.task_at(_selected_task).get("name", ""))
		elif empty:
			_task_name.text = tr("点 + 添加提醒")
	if _sleep_tab:
		_sleep_tab.set_pressed_no_signal(sleep)
		_paint_paused_tab(_sleep_tab, AlarmStore.sleep_paused)
	for index in _task_buttons.size():
		_task_buttons[index].set_pressed_no_signal(index == _selected_task)
		_paint_paused_tab(_task_buttons[index], AlarmStore.task_paused(index))
	_update_time_label()


func _paint_paused_tab(button: Button, paused: bool) -> void:
	button.theme_type_variation = &"PausedButton" if paused else &""
	button.get_node("暂停").visible = paused


func _style_tab(button: Button, full: String) -> void:
	button.text = full
	button.clip_text = true
	_fit_font(button, 18)


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
		button.pressed.connect(_on_task_tab_pressed.bind(button))
		button.gui_input.connect(_on_task_tab_input.bind(button))
		_task_tabs.add_child(button)
		_style_tab(button, AlarmStore.task_label(AlarmStore.task_at(index)))
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
			_press_at = button.get_global_mouse_position()
			var holder := button
			get_tree().create_timer(MENU_HOLD).timeout.connect(func() -> void:
				if _hold_button == holder and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					_open_tab_menu(holder)
			)
		elif not _reordering:
			_hold_button = null
	elif event is InputEventMouseMotion and not _reordering and _hold_button == button:
		if button.get_global_mouse_position().distance_to(_press_at) > 8.0:
			_hold_button = null


func _open_tab_menu(button: Button) -> void:
	_menu_task = _task_buttons.find(button)
	var paused := AlarmStore.sleep_paused if _menu_task < 0 else AlarmStore.task_paused(_menu_task)
	_hold_menu.open(button, tr("继续提醒") if paused else tr("暂停提醒"), _menu_task >= 0, _on_tab_menu)
	if _menu_task >= 0:
		_begin_reorder()
	else:
		_hold_button = null


func _on_tab_menu(action: String) -> void:
	if action == "delete":
		_ask_remove_task(_menu_task)
		return
	if _menu_task < 0:
		AlarmStore.set_sleep_paused(not AlarmStore.sleep_paused)
	else:
		AlarmStore.set_task_paused(_menu_task, not AlarmStore.task_paused(_menu_task))
	_apply_task_chrome()
	_schedule_days()


func _ask_remove_task(index: int) -> void:
	if index < 0 or index >= AlarmStore.task_count():
		return
	_remove_index = index
	var label := AlarmStore.task_label(AlarmStore.task_at(index))
	_remove_dialog.get_node("居中/面板/内容/提示").text = tr("删除「%s」？") % label
	_remove_dialog.visible = true


func _confirm_remove_task() -> void:
	_remove_dialog.visible = false
	if _remove_index < 0 or _remove_index >= AlarmStore.task_count():
		return
	var task_id := str(AlarmStore.task_at(_remove_index).get("id", ""))
	for weekday in range(1, 8):
		AlarmService.cancel(AlarmStore.task_alarm_id(task_id, weekday))
		AlarmService.cancel(AlarmStore.task_end_alarm_id(task_id, weekday))
	AlarmStore.remove_task(task_id)
	_remove_index = -1
	_rebuild_task_tabs()
	_show_default_task()
	_schedule_days()


func _begin_reorder() -> void:
	_reordering = true
	_order_dirty = false
	if _tab_scroll:
		_tab_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	if not _reordering or _hold_button == null:
		return
	var pointer := _alarm_page.get_global_mouse_position()
	if _hold_menu.visible:
		if pointer.distance_to(_press_at) < DRAG_SLOP:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_finish_reorder()
			return
		_hold_menu.close()
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


func _catch_ringing() -> void:
	var ringing: Array = AlarmService.note_ringing()
	if ringing.is_empty() or _ring_popup == null:
		return
	var names := PackedStringArray()
	var first_id := ""
	var first_state := ""
	var ring_left := 0.0
	for item in ringing:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var group_id := str(item.get("id", ""))
		if first_id.is_empty():
			first_id = group_id
			first_state = str(item.get("state", ""))
			ring_left = float(item.get("ring_left", 0.0))
		for event in AlarmStore.due_group(group_id).get("events", []):
			var label := str(event.get("label", ""))
			if not label.is_empty() and label not in names:
				names.append(label)
	if first_id.is_empty() or first_id == _dismissed_ring:
		return
	_triggered_id = first_id
	_ring_names.text = "\n".join(names) if names.size() > 0 else tr("提醒")
	_cancel_snooze.visible = first_state == "countdown" or first_state == "paused"
	_ring_popup.visible = true
	if first_state == "alerting" and ring_left > 0.0:
		get_tree().create_timer(ring_left).timeout.connect(_on_ring_max.bind(first_id))


func _on_ring_max(group_id: String) -> void:
	if group_id != _triggered_id or not _ring_popup.visible:
		return
	AlarmService.stop(group_id)
	_dismissed_ring = group_id
	_ring_popup.visible = false


func _dismiss_ring() -> void:
	_dismissed_ring = _triggered_id
	if _ring_popup:
		_ring_popup.visible = false
	_show_tab("flower", false)


func _cancel_current_snooze() -> void:
	AlarmService.stop(_triggered_id)
	_dismiss_ring()


func _open_triggered_alarm() -> void:
	var group_id := _triggered_id
	_dismissed_ring = group_id
	if _ring_popup:
		_ring_popup.visible = false
	var parts := group_id.split("-")
	var weekday := int(parts[1]) if parts.size() >= 2 else _today_alarm_index() + 1
	_show_tab("alarm", false)
	_select_day(clampi(weekday - 1, 0, 6), false)
	var event_id := ""
	for event in AlarmStore.due_group(group_id).get("events", []):
		var candidate := str(event.get("id", ""))
		if candidate.begins_with("task-"):
			event_id = candidate
			break
		if event_id.is_empty():
			event_id = candidate
	if event_id.begins_with("task-"):
		var index := AlarmStore.task_index_for_alarm(event_id, weekday)
		if index >= 0:
			_show_custom_task(index)
			return
	_show_default_task()


func _record_snooze() -> void:
	if AlarmService.using_native:
		return
	var alarm_id := "sleep-1"
	for alarm in AlarmStore.alarms:
		var id := str(alarm.get("id", ""))
		if id.begins_with("sleep-"):
			alarm_id = id
			break
	AlarmService.record_desktop_snooze(alarm_id)
	_show_tab("flower")


func _on_care_button_down(kind: String) -> void:
	if not _care_kind.is_empty():
		return
	if not _can_drag_care(kind):
		return
	var button := _water_button if kind == "water" else _feed_button
	_start_care_drag(kind, button)


func _can_drag_care(kind: String) -> bool:
	if _date_key != AlarmStore.today_key():
		return false
	if kind == "feed" and (AlarmStore.fertilizer <= 0 or _feeding):
		return false
	return true


func _is_pointer_up(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return not event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return not event.pressed
	return false


func _start_care_drag(kind: String, button: Button) -> void:
	_care_kind = kind
	_care_home = button.global_position
	_care_poured = false
	button.modulate.a = 0.25
	_care_ghost.texture = button.icon
	_care_ghost.rotation = 0.0
	_set_can_pouring(false)
	_care_layer.visible = true
	_drag_care_pointer()


func _place_care_ghost(global_pos: Vector2) -> void:
	_care_ghost.size = _care_ghost.custom_minimum_size
	_care_ghost.pivot_offset = _care_ghost.size * 0.5
	var local := _care_layer.get_global_transform_with_canvas().affine_inverse() * global_pos
	_care_ghost.position = local - _care_ghost.size * 0.5


func _drag_care_pointer() -> void:
	_drag_care_to(_care_layer.get_global_mouse_position(), get_viewport().get_mouse_position())


func _drag_care_to(global_pos: Vector2, screen_pos: Vector2) -> void:
	_place_care_ghost(global_pos)
	if _care_kind != "water":
		return
	var over: bool = _sunflower.hits_plant(screen_pos)
	_set_can_pouring(over)
	if not over or _care_poured:
		return
	_care_poured = true
	_apply_care("water", global_pos)


func _set_can_pouring(over: bool) -> void:
	_care_ghost.rotation = 0.7 if over else 0.0
	if not over:
		_sunflower.stop_pour()
		return
	_sunflower.pour_at(_care_spout.get_global_transform_with_canvas().origin)


func _finish_care_drag_pointer() -> void:
	_finish_care_drag(_care_layer.get_global_mouse_position(), get_viewport().get_mouse_position())


func _finish_care_drag(global_pos: Vector2, screen_pos: Vector2) -> void:
	var kind := _care_kind
	var poured := _care_poured
	_care_kind = ""
	_care_poured = false
	_set_can_pouring(false)
	if kind == "feed" and _sunflower.hits_plant(screen_pos):
		_pour_feed(global_pos)
		return
	_hide_care_ghost()
	if kind == "water":
		if not poured and _sunflower.hits_plant(screen_pos):
			_apply_care("water", global_pos)
	_refresh_care()


func _hide_care_ghost() -> void:
	_care_ghost.rotation = 0.0
	_care_layer.visible = false
	_water_button.modulate.a = 1.0
	_feed_button.modulate.a = 1.0


# 袋子歪一下，💩 从袋口掉到盆上，消失以后才算用掉一包、花才长高。
func _pour_feed(global_pos: Vector2) -> void:
	_feeding = true
	var tween := create_tween()
	tween.tween_property(_care_ghost, "rotation", 0.6, 0.15)
	tween.tween_callback(func() -> void:
		var mouth := _care_mouth.get_global_transform_with_canvas().origin
		_sunflower.drop_fertilizer(mouth, _on_feed_landed.bind(global_pos))
	)
	tween.tween_interval(0.25)
	tween.tween_callback(func() -> void:
		_hide_care_ghost()
		_refresh_care()
	)


func _on_feed_landed(global_pos: Vector2) -> void:
	_feeding = false
	_apply_care("feed", global_pos)


func _apply_care(kind: String, global_pos: Vector2) -> void:
	if kind == "water":
		_float_tip(tr("浇水不枯萎"), global_pos)
		if AlarmStore.record_water():
			_sunflower.water()
		return
	if AlarmStore.use_fertilizer():
		_float_tip(tr("施肥会长高"), global_pos)


func _float_tip(text: String, global_pos: Vector2) -> void:
	var tip := _flower_page.get_node("飘字") as Label
	if _tip_tween and _tip_tween.is_valid():
		_tip_tween.kill()
	tip.text = text
	tip.reset_size()
	var local := _flower_page.get_global_transform_with_canvas().affine_inverse() * global_pos
	var start := local - Vector2(tip.size.x * 0.5, 70.0)
	var width := _flower_page.size.x
	start.x = clampf(start.x, 8.0, maxf(8.0, width - tip.size.x - 8.0))
	tip.position = start
	tip.modulate.a = 0.0
	tip.visible = true
	_tip_tween = create_tween()
	_tip_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tip_tween.tween_property(tip, "modulate:a", 1.0, 0.25)
	_tip_tween.parallel().tween_property(tip, "position:y", start.y - 60.0, 1.8)
	_tip_tween.parallel().tween_property(tip, "position:x", start.x + 10.0, 0.9)
	_tip_tween.chain().tween_property(tip, "modulate:a", 0.0, 0.4)
	_tip_tween.tween_callback(func() -> void: tip.visible = false)


func _refresh() -> void:
	var count := AlarmStore.sleep_snooze_on(_date_key)
	var growth := AlarmStore.growth_on(_date_key)
	var when := AlarmStore.format_date(_date_key)
	_date_label.text = when
	_count_label.visible = count > 0
	if _date_key == AlarmStore.today_key():
		_count_label.text = tr("今天贪睡了 %d 次") % count
	else:
		_count_label.text = tr("%s贪睡了 %d 次") % [when, count]
	if _playback != growth:
		_playback = growth
		_sunflower.play_count(growth)
	_sunflower.apply_wilt(AlarmStore.wilt_level())
	_sunflower.set_bend(count)
	_refresh_care()
	_show_due_list()


func _refresh_care() -> void:
	if _water_button == null or _feed_button == null:
		return
	var today := _date_key == AlarmStore.today_key()
	_water_button.modulate.a = 1.0 if today and not AlarmStore.watered_today() else 0.35
	var packs := AlarmStore.fertilizer
	_feed_button.modulate.a = 1.0 if today and packs > 0 else 0.35
	if _feed_count:
		_feed_count.text = "× %d" % packs
	_flower_page.get_node("照料").visible = _current_tab == "flower" or _current_tab == ""


func _show_due_list() -> void:
	if _due_label == null:
		return
	if _date_key != AlarmStore.today_key():
		_due_label.visible = false
		return
	var labels := AlarmStore.current_due_labels()
	if labels.is_empty():
		_due_label.visible = false
		return
	_due_label.text = tr("现在要做\n%s") % "\n".join(labels)
	_due_label.visible = true


func shift_date(days: int) -> void:
	var today := AlarmStore.today_key()
	var earliest := AlarmStore.shift_date(today, -6)
	var next := AlarmStore.shift_date(_date_key, days)
	if next > today:
		next = today
	if next < earliest:
		next = earliest
	_date_key = next
	_refresh()
	if _prev_button:
		_prev_button.disabled = _date_key <= earliest
	if _next_button:
		_next_button.disabled = _date_key >= today
