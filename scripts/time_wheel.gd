extends Control

signal settled(value: int)

@export var minimum := 0
@export var maximum := 23
@export_range(0.5, 6.0, 0.1) var sensitivity := 1.0
@export var coast := false
## 不为空时按下标画这些字（会过翻译表），比如上午/下午；为空画两位数字。
@export var labels: PackedStringArray = []
## 关掉后到头就停，不会从 12 绕回 1。
@export var wrap := true
@export var wheel_width := 96.0
var value := 0
var _drag_y := 0.0
var _velocity := 0.0
var _dragging := false
var _coasting := false
var _snapping := false
var _samples: Array[Vector2] = []

const ROW := 44.0
const COAST_DRAG := 3.4
const COAST_STOP := 80.0
const SAMPLE_WINDOW := 0.09


func _ready() -> void:
	custom_minimum_size = Vector2(wheel_width, ROW * 5.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func commit_value() -> int:
	_dragging = false
	_coasting = false
	_snapping = false
	_velocity = 0.0
	_samples.clear()
	_align_nearest()
	_drag_y = 0.0
	set_process(false)
	queue_redraw()
	return value


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_coasting = false
			_snapping = false
			_velocity = 0.0
			_samples.clear()
			set_process(false)
		else:
			_dragging = false
			if coast:
				_begin_coast()
			else:
				set_process(true)
				settled.emit(value)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var step := motion.relative.y * sensitivity
		_drag_y += step
		_samples.append(Vector2(Time.get_ticks_msec() / 1000.0, step))
		if _samples.size() > 8:
			_samples.remove_at(0)
		_absorb_rows()
		queue_redraw()
		accept_event()


func _process(delta: float) -> void:
	if _dragging:
		return
	if _coasting:
		_drag_y += _velocity * delta
		_absorb_rows()
		_velocity *= exp(-COAST_DRAG * delta)
		if absf(_velocity) < COAST_STOP:
			_coasting = false
			_snapping = true
			_align_nearest()
		queue_redraw()
		return
	if _snapping:
		_drag_y = lerpf(_drag_y, 0.0, 1.0 - exp(-18.0 * delta))
		if absf(_drag_y) < 0.4:
			_drag_y = 0.0
			_snapping = false
			set_process(false)
			settled.emit(value)
		queue_redraw()
		return
	if absf(_drag_y) < 0.4:
		_drag_y = 0.0
		set_process(false)
		queue_redraw()
		return
	_drag_y = lerpf(_drag_y, 0.0, 1.0 - exp(-16.0 * delta))
	queue_redraw()


func _begin_coast() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var moved := 0.0
	var oldest := now
	var used := false
	for sample in _samples:
		if now - sample.x <= SAMPLE_WINDOW:
			moved += sample.y
			oldest = minf(oldest, sample.x)
			used = true
	_samples.clear()
	var elapsed := maxf(now - oldest, 0.016) if used else 0.016
	_velocity = clampf(moved / elapsed, -4200.0, 4200.0)
	if absf(_velocity) < 160.0:
		_snapping = true
		_align_nearest()
	else:
		_coasting = true
	set_process(true)


func _align_nearest() -> void:
	if _drag_y <= -ROW * 0.5 and _can_step(1):
		_drag_y += ROW
		value = _wrap(value + 1)
	elif _drag_y >= ROW * 0.5 and _can_step(-1):
		_drag_y -= ROW
		value = _wrap(value - 1)


func _absorb_rows() -> void:
	while _drag_y <= -ROW and _can_step(1):
		_drag_y += ROW
		value = _wrap(value + 1)
	while _drag_y >= ROW and _can_step(-1):
		_drag_y -= ROW
		value = _wrap(value - 1)
	if not wrap:
		# 到头了就别再往外拖，最多只能拉出一小段回弹。
		if value == maximum:
			_drag_y = maxf(_drag_y, -ROW * 0.35)
		if value == minimum:
			_drag_y = minf(_drag_y, ROW * 0.35)


func _can_step(direction: int) -> bool:
	if wrap:
		return true
	var next := value + direction
	return next >= minimum and next <= maximum


func _wrap(number: int) -> int:
	var span := maximum - minimum + 1
	return minimum + posmod(number - minimum, span)


func _draw() -> void:
	var font := get_theme_font("font")
	var center_y := size.y * 0.5
	for delta in range(-3, 4):
		var raw := value + delta
		if not wrap and (raw < minimum or raw > maximum):
			continue
		var number := _wrap(raw)
		var y := center_y + float(delta) * ROW + _drag_y
		var distance := absf(y - center_y) / ROW
		if distance > 2.6:
			continue
		var alpha := clampf(1.0 - distance * 0.34, 0.18, 1.0)
		var font_size := 28 if distance < 0.45 else 22
		var text := "%02d" % number
		if not labels.is_empty():
			text = tr(labels[clampi(number - minimum, 0, labels.size() - 1)])
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var position := Vector2((size.x - text_width) * 0.5, y + font_size * 0.32)
		font.draw_string(get_canvas_item(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.15, 0.16, 0.18, alpha))
