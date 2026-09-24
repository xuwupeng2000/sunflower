extends Control

signal selected(index: int)

var labels: PackedStringArray = PackedStringArray()
var index := 0
var _drag := 0.0
var _dragging := false

const CARD_RATIO := 0.46


func _ready() -> void:
	custom_minimum_size = Vector2(0, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	resized.connect(queue_redraw)


func _card() -> float:
	return maxf(size.x * CARD_RATIO, 120.0)


func set_labels(next_labels: PackedStringArray, current: int) -> void:
	labels = next_labels
	index = clampi(current, 0, maxi(labels.size() - 1, 0))
	_drag = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if labels.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if not event.pressed:
			_settle()
			set_process(true)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag += event.relative.x
		_absorb()
		queue_redraw()
		accept_event()


func _process(delta: float) -> void:
	if _dragging or absf(_drag) < 0.5:
		_drag = 0.0
		set_process(false)
		queue_redraw()
		return
	_drag = lerpf(_drag, 0.0, 1.0 - exp(-14.0 * delta))
	queue_redraw()


func _absorb() -> void:
	var card := _card()
	while _drag <= -card * 0.5 and index < labels.size() - 1:
		_drag += card
		index += 1
		selected.emit(index)
	while _drag >= card * 0.5 and index > 0:
		_drag -= card
		index -= 1
		selected.emit(index)


func _settle() -> void:
	var card := _card()
	if _drag <= -card * 0.5 and index < labels.size() - 1:
		index += 1
		selected.emit(index)
	elif _drag >= card * 0.5 and index > 0:
		index -= 1
		selected.emit(index)
	_drag = 0.0


func _draw() -> void:
	if labels.is_empty() or size.x < 10.0:
		return
	var font := get_theme_default_font()
	var card := _card()
	var center_x := size.x * 0.5
	var band := Rect2(center_x - card * 0.5, size.y * 0.08, card, size.y * 0.84)
	draw_rect(band, Color("9ec4e0"), true)
	var font_size := int(clampf(size.y * 0.28, 28, 54))
	for item_index in labels.size():
		var x := center_x + (float(item_index - index) * card + _drag)
		var distance := absf(x - center_x) / card
		if distance > 1.6:
			continue
		var text := labels[item_index]
		var font_size_here := font_size if distance < 0.35 else int(font_size * 0.72)
		var alpha := clampf(1.0 - distance * 0.45, 0.28, 1.0)
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_here).x
		var position := Vector2(x - text_width * 0.5, size.y * 0.5 + float(font_size_here) * 0.32)
		font.draw_string(get_canvas_item(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_here, Color(0.15, 0.16, 0.18, alpha))
