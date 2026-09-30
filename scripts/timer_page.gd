extends Control
## 计时页：点一个任务就开始倒计时，一次只走一个；到点发通知（在前台就直接响一声）。

const TimerButtonScene := preload("res://scenes/timer_button.tscn")
const HOLD_SECONDS := 0.8
const DONE_SHOW := 5.0
## 打开 app 时已经过点好一阵的计时，只收掉，不再响。
const LATE_SILENT := 3.0
const SMALLEST_FONT := 11

@export var custom_dialog: Control
@export var delete_dialog: Control
@export var confirm_dialog: Control
@export var hold_menu: Control
@export var guide: Control
@export var ring_player: AudioStreamPlayer

const GUIDE_PAD := 6.0
const GUIDE_STEPS := [
	["模板框", "模板说明"],
	["长按框", "长按说明"],
	["自定框", "自定说明"],
]

@onready var _name: Label = $边框/内容/大字/名字
@onready var _time: Label = $边框/内容/大字/倒计时
@onready var _note: Label = $边框/内容/大字/说明
@onready var _cancel: Button = $边框/内容/大字/取消
@onready var _grid: GridContainer = $边框/内容/滚动/按钮
@onready var _custom_button: Button = $边框/内容/滚动/按钮/自定

var _hold_button: Button
var _hold_time := 0.0
var _held_button: Button
var _delete_index := -1
var _done_left := 0.0
var _name_field: LineEdit
var _hour_wheel: Control
var _minute_wheel: Control
var _delete_prompt: Label
var _pending_title := ""
var _pending_minutes := 0
var _guide_step := 0


func _ready() -> void:
	_cancel.pressed.connect(cancel_timer)
	_custom_button.pressed.connect(_open_custom)
	for child in _grid.get_children():
		if child.has_meta("template"):
			var template := child.get_meta("template") as TimerTemplate
			_wire(child as Button, template.title, template.minutes, -1)
	_rebuild_custom()
	if custom_dialog != null:
		custom_dialog.gui_input.connect(_close_on_click.bind(custom_dialog))
		_name_field = custom_dialog.get_node("居中/面板/内容/名字")
		_hour_wheel = custom_dialog.get_node("居中/面板/内容/滚轮区/列/时")
		_minute_wheel = custom_dialog.get_node("居中/面板/内容/滚轮区/列/分")
		custom_dialog.get_node("居中/面板/内容/开始").pressed.connect(_start_custom)
	if delete_dialog != null:
		delete_dialog.gui_input.connect(_close_on_click.bind(delete_dialog))
		_delete_prompt = delete_dialog.get_node("居中/面板/内容/提示")
		delete_dialog.get_node("居中/面板/内容/按钮/取消").pressed.connect(func() -> void: delete_dialog.visible = false)
		delete_dialog.get_node("居中/面板/内容/按钮/删除").pressed.connect(_confirm_delete)
	if confirm_dialog != null:
		confirm_dialog.gui_input.connect(_close_on_click.bind(confirm_dialog))
		confirm_dialog.get_node("居中/面板/内容/按钮/取消").pressed.connect(func() -> void: confirm_dialog.visible = false)
		confirm_dialog.get_node("居中/面板/内容/按钮/开始").pressed.connect(_confirm_start)
	if guide != null:
		guide.gui_input.connect(_on_guide_input)
	visibility_changed.connect(_show_guide)
	_refresh()


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN or not is_node_ready():
		return
	var cancelled := AlarmService.take_cancelled_timer()
	if not cancelled.is_empty() and str(AlarmStore.active_timer.get("id", "")) == cancelled:
		AlarmStore.clear_timer()
		_refresh()
	_tick()


func _process(delta: float) -> void:
	if _hold_button != null:
		_hold_time += delta
		if _hold_time >= HOLD_SECONDS:
			_held_button = _hold_button
			_hold_button = null
			var index := int(_held_button.get_meta("custom_index", -1))
			if hold_menu != null:
				hold_menu.open(_held_button, "", true, func(_action: String) -> void: _ask_delete(index))
			else:
				_ask_delete(index)
	if _done_left > 0.0:
		_done_left -= delta
		if _done_left <= 0.0:
			_refresh()
	_tick()


func start_timer(title: String, minutes: int) -> void:
	if not AlarmStore.active_timer.is_empty():
		AlarmService.cancel_timer(AlarmStore.active_timer)
	AlarmService.start_timer(AlarmStore.start_timer(title, minutes))
	_done_left = 0.0
	_refresh()


func cancel_timer() -> void:
	AlarmService.cancel_timer(AlarmStore.active_timer)
	AlarmStore.clear_timer()
	_done_left = 0.0
	_refresh()


func _tick() -> void:
	var active := AlarmStore.active_timer
	if active.is_empty():
		return
	var left := float(active.ends_at) - Time.get_unix_time_from_system()
	if left > 0.0:
		_time.text = _countdown(ceili(left))
		return
	AlarmStore.clear_timer()
	AlarmService.finish_timer(active)
	if left < -LATE_SILENT:
		_refresh()
		return
	_done_left = DONE_SHOW
	_name.text = tr("%s 时间到了") % str(active.title)
	_time.text = "00:00"
	_time.modulate.a = 1.0
	_note.text = ""
	_cancel.visible = false
	if ring_player != null and ring_player.stream != null:
		ring_player.play()


func _refresh() -> void:
	var active := AlarmStore.active_timer
	if active.is_empty():
		if _done_left > 0.0:
			return
		_name.text = tr("选一个任务，开始计时")
		_time.text = "00:00"
		_time.modulate.a = 0.25
		_note.text = ""
		_cancel.visible = false
		return
	_name.text = str(active.title)
	_time.modulate.a = 1.0
	_time.text = _countdown(ceili(float(active.ends_at) - Time.get_unix_time_from_system()))
	_note.text = tr("共 %s · %s 到") % [_length_text(int(active.minutes)), _clock_text(float(active.ends_at))]
	_cancel.visible = true


func _wire(button: Button, title: String, minutes: int, custom_index: int) -> void:
	button.text = "%s\n%s" % [tr(title), _length_text(minutes)]
	button.resized.connect(_fit_font.bind(button))
	button.pressed.connect(_on_timer_pressed.bind(button, tr(title), minutes))
	if custom_index >= 0:
		button.set_meta("custom_index", custom_index)
		button.button_down.connect(func() -> void:
			_hold_button = button
			_hold_time = 0.0
		)
		button.button_up.connect(func() -> void:
			if _hold_button == button:
				_hold_button = null
		)


func _on_timer_pressed(button: Button, title: String, minutes: int) -> void:
	if _held_button == button:
		_held_button = null
		return
	_ask_start(title, minutes)


func _ask_start(title: String, minutes: int) -> void:
	if confirm_dialog == null:
		start_timer(title, minutes)
		return
	_pending_title = title
	_pending_minutes = minutes
	var content := confirm_dialog.get_node("居中/面板/内容")
	var ends := Time.get_unix_time_from_system() + minutes * 60.0
	(content.get_node("提示") as Label).text = tr("开始「%s」？") % title
	(content.get_node("说明") as Label).text = tr("%s · %s 到") % [_length_text(minutes), _clock_text(ends)]
	var running := AlarmStore.active_timer
	var replace := content.get_node("替换") as Label
	replace.visible = not running.is_empty()
	if replace.visible:
		replace.text = tr("会停掉正在走的「%s」") % str(running.title)
	confirm_dialog.visible = true


func _confirm_start() -> void:
	confirm_dialog.visible = false
	start_timer(_pending_title, _pending_minutes)


func _rebuild_custom() -> void:
	for child in _grid.get_children():
		if child.has_meta("custom_index"):
			_grid.remove_child(child)
			child.queue_free()
	for index in AlarmStore.custom_timers.size():
		var item: Dictionary = AlarmStore.custom_timers[index]
		var button := TimerButtonScene.instantiate() as Button
		_grid.add_child(button)
		_grid.move_child(button, _custom_button.get_index())
		_wire(button, str(item.title), int(item.minutes), index)


func _open_custom() -> void:
	if custom_dialog == null:
		return
	_name_field.text = ""
	_hour_wheel.value = 0
	_minute_wheel.value = 20
	_hour_wheel.queue_redraw()
	_minute_wheel.queue_redraw()
	custom_dialog.visible = true


func _start_custom() -> void:
	var minutes := maxi(1, int(_hour_wheel.commit_value()) * 60 + int(_minute_wheel.commit_value()))
	var title := _name_field.text.strip_edges()
	if title.is_empty():
		title = tr("⏳ 计时")
	custom_dialog.visible = false
	AlarmStore.add_custom_timer(title, minutes)
	_rebuild_custom()
	start_timer(title, minutes)


func _ask_delete(index: int) -> void:
	if delete_dialog == null or index < 0 or index >= AlarmStore.custom_timers.size():
		return
	_delete_index = index
	_delete_prompt.text = tr("删除「%s」？") % str(AlarmStore.custom_timers[index].title)
	delete_dialog.visible = true


func _confirm_delete() -> void:
	delete_dialog.visible = false
	if _delete_index < 0 or _delete_index >= AlarmStore.custom_timers.size():
		return
	var item: Dictionary = AlarmStore.custom_timers[_delete_index]
	var active := AlarmStore.active_timer
	if not active.is_empty() and str(active.title) == str(item.title) and int(active.minutes) == int(item.minutes):
		cancel_timer()
	AlarmStore.remove_custom_timer(_delete_index)
	_delete_index = -1
	_rebuild_custom()


func _show_guide() -> void:
	if guide == null or guide.visible or not is_visible_in_tree():
		return
	if AlarmStore.timer_tutorial_seen and not AlarmStore.replay_tutorials():
		return
	# 容器要跑完一帧才有位置，圈框照着真实位置贴。
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_visible_in_tree():
		return
	# 自带的三个排成 L 形，只圈第一行，免得把自己加的也圈进去。
	var templates := Rect2()
	var customs := Rect2()
	for child in _grid.get_children():
		var rect := (child as Control).get_global_rect()
		if child.has_meta("template"):
			if templates.size == Vector2.ZERO:
				templates = rect
			elif is_equal_approx(rect.position.y, templates.position.y):
				templates = templates.merge(rect)
		elif child.has_meta("custom_index") and customs.size == Vector2.ZERO:
			customs = rect
	if customs.size == Vector2.ZERO:
		customs = _grid.get_global_rect()
	var custom_rect := _custom_button.get_global_rect()
	_ring_rect(guide.get_node("模板框"), templates)
	_ring_rect(guide.get_node("长按框"), customs)
	_ring_rect(guide.get_node("自定框"), custom_rect)
	_note_above(guide.get_node("模板说明"))
	_note_above(guide.get_node("长按说明"))
	_note_above(guide.get_node("自定说明"))
	_guide_step = 0
	_apply_guide_step()
	guide.visible = true
	AlarmStore.mark_timer_tutorial_seen()


func _apply_guide_step() -> void:
	for index in GUIDE_STEPS.size():
		for node_name in GUIDE_STEPS[index]:
			(guide.get_node(node_name) as Control).visible = index == _guide_step


func _ring_rect(ring: Control, rect: Rect2) -> void:
	rect = rect.grow(GUIDE_PAD)
	ring.global_position = rect.position
	ring.size = rect.size


## 按钮行间太挤，说明都放在按钮区上方的空白里。
func _note_above(note: Label) -> void:
	var area := _grid.get_global_rect()
	note.size = Vector2(area.size.x, 0.0)
	var height := note.get_line_height() * note.get_line_count()
	note.global_position = Vector2(area.position.x, area.position.y - GUIDE_PAD - 22.0 - height)


func _on_guide_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	guide.accept_event()
	_guide_step += 1
	if _guide_step < GUIDE_STEPS.size():
		_apply_guide_step()
		return
	guide.visible = false


func _close_on_click(event: InputEvent, dialog: Control) -> void:
	if event is InputEventMouseButton and event.pressed:
		dialog.visible = false


## 名字长就把字缩小，按钮不变宽。
func _fit_font(button: Button) -> void:
	var room := button.size.x - 16.0
	if room <= 0.0:
		return
	var font := button.get_theme_font("font")
	button.remove_theme_font_size_override("font_size")
	var largest := button.get_theme_font_size("font_size")
	var widest := 0.0
	for line in button.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, largest).x)
	if widest > room:
		var fitted := maxi(SMALLEST_FONT, int(floor(largest * room / widest)))
		button.add_theme_font_size_override("font_size", fitted)


func _countdown(seconds: int) -> String:
	seconds = maxi(0, seconds)
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func _length_text(minutes: int) -> String:
	if minutes < 60:
		return tr("%d 分钟") % minutes
	if minutes % 60 == 0:
		return tr("%d 小时") % (minutes / 60)
	return tr("%d 小时 %d 分钟") % [minutes / 60, minutes % 60]


func _clock_text(unix: float) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var moment := Time.get_datetime_dict_from_unix_time(int(unix) + bias)
	var hour := int(moment.hour)
	var meridiem := tr("上午") if hour < 12 else tr("下午")
	var shown := hour % 12
	if shown == 0:
		shown = 12
	return "%s %d:%02d" % [meridiem, shown, int(moment.minute)]
