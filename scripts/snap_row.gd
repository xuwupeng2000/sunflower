@tool
extends Control

signal selected(index: int)

var labels: PackedStringArray = PackedStringArray()
@export var index := 0:
	set(value):
		index = value
		if is_inside_tree():
			_place()
var _drag := 0.0
var _dragging := false

const CARD_RATIO := 0.46


func _ready() -> void:
	custom_minimum_size = Vector2(0, 52)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)
	resized.connect(_place)
	call_deferred("_place")


func _card() -> float:
	return maxf(size.x * CARD_RATIO, 140.0)


func _count() -> int:
	if get_child_count() > 0:
		return get_child_count()
	return labels.size()


func set_index(current: int) -> void:
	_drag = 0.0
	index = clampi(current, 0, maxi(_count() - 1, 0))


func set_labels(next_labels: PackedStringArray, current: int) -> void:
	labels = next_labels
	for item_index in mini(get_child_count(), next_labels.size()):
		var label := get_child(item_index) as Label
		if label:
			label.text = next_labels[item_index]
	set_index(current)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _count() == 0:
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
		_place()
		accept_event()


func _process(delta: float) -> void:
	if _dragging or absf(_drag) < 0.5:
		_drag = 0.0
		set_process(false)
		_place()
		return
	_drag = lerpf(_drag, 0.0, 1.0 - exp(-14.0 * delta))
	_place()


func _absorb() -> void:
	var card := _card()
	while _drag <= -card * 0.5 and index < _count() - 1:
		_drag += card
		index += 1
		selected.emit(index)
	while _drag >= card * 0.5 and index > 0:
		_drag -= card
		index -= 1
		selected.emit(index)


func _settle() -> void:
	var card := _card()
	if _drag <= -card * 0.5 and index < _count() - 1:
		index += 1
		selected.emit(index)
	elif _drag >= card * 0.5 and index > 0:
		index -= 1
		selected.emit(index)
	_drag = 0.0


func _place() -> void:
	if get_child_count() == 0:
		queue_redraw()
		return
	var card := _card()
	var center_x := size.x * 0.5
	for item_index in get_child_count():
		var child := get_child(item_index) as Control
		if child == null:
			continue
		var x := center_x + (float(item_index - index) * card + _drag) - card * 0.42
		child.position = Vector2(x, size.y * 0.04)
		child.size = Vector2(card * 0.84, size.y * 0.92)
		var distance := absf(x + card * 0.42 - center_x) / card
		child.modulate.a = clampf(1.0 - distance * 0.35, 0.4, 1.0)
	queue_redraw()


func _draw() -> void:
	if get_child_count() > 0 or labels.is_empty() or size.x < 10.0:
		return
	var font := get_theme_default_font()
	var card := _card()
	var center_x := size.x * 0.5
	var band := Rect2(center_x - card * 0.5, size.y * 0.08, card, size.y * 0.84)
	draw_rect(band, Color("9ec4e0"), true)
	var font_size := int(clampf(size.y * 0.46, 18, 28))
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
