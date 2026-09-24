extends Control

signal settled(value: int)

var minimum := 0
var maximum := 23
var value := 0
var _drag_y := 0.0
var _dragging := false

const ROW := 44.0


func _ready() -> void:
	custom_minimum_size = Vector2(96, ROW * 5.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if not event.pressed:
			set_process(true)
			settled.emit(value)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_y += event.relative.y
		_absorb_rows()
		queue_redraw()
		accept_event()


func _process(delta: float) -> void:
	if _dragging or absf(_drag_y) < 0.4:
		_drag_y = 0.0
		set_process(false)
		queue_redraw()
		return
	_drag_y = lerpf(_drag_y, 0.0, 1.0 - exp(-16.0 * delta))
	queue_redraw()


func _absorb_rows() -> void:
	while _drag_y <= -ROW:
		_drag_y += ROW
		value = _wrap(value + 1)
	while _drag_y >= ROW:
		_drag_y -= ROW
		value = _wrap(value - 1)


func _wrap(number: int) -> int:
	var span := maximum - minimum + 1
	return minimum + posmod(number - minimum, span)


func _draw() -> void:
	var font := get_theme_font("font")
	var center_y := size.y * 0.5
	for delta in range(-3, 4):
		var number := _wrap(value + delta)
		var y := center_y + float(delta) * ROW + _drag_y
		var distance := absf(y - center_y) / ROW
		if distance > 2.6:
			continue
		var alpha := clampf(1.0 - distance * 0.34, 0.18, 1.0)
		var font_size := 28 if distance < 0.45 else 22
		var text := "%02d" % number
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var position := Vector2((size.x - text_width) * 0.5, y + font_size * 0.32)
		font.draw_string(get_canvas_item(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.15, 0.16, 0.18, alpha))
