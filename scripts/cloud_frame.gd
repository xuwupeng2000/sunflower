extends Control

var _clouds: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _index in 18:
		_clouds.append({
			"x": randf(),
			"y": randf(),
			"speed": randf_range(0.035, 0.08),
			"sway": randf_range(0.04, 0.1),
			"phase": randf() * TAU,
			"rate": randf_range(0.5, 1.3),
			"radius": randf_range(10.0, 18.0),
		})
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	for cloud in _clouds:
		cloud["y"] = float(cloud["y"]) + float(cloud["speed"]) * delta
		if float(cloud["y"]) > 1.15:
			cloud["y"] = -0.12
			cloud["x"] = randf()
	queue_redraw()


func _draw() -> void:
	for cloud in _clouds:
		var sway := sin(_time * float(cloud["rate"]) + float(cloud["phase"])) * float(cloud["sway"]) * size.x
		var at := Vector2(float(cloud["x"]) * size.x + sway, float(cloud["y"]) * size.y)
		_puff(at, float(cloud["radius"]))


func _puff(at: Vector2, radius: float) -> void:
	var shadow := Color(0.42, 0.58, 0.74, 0.32)
	draw_circle(at + Vector2(radius * 0.28, radius * 0.55), radius * 1.08, shadow)
	var body := Color(0.9, 0.96, 1.0, 0.78)
	draw_circle(at, radius, body)
	draw_circle(at + Vector2(radius * 0.72, radius * 0.1), radius * 0.7, body)
	draw_circle(at + Vector2(-radius * 0.64, radius * 0.16), radius * 0.64, body)
	var light := Color(1, 1, 1, 0.9)
	draw_circle(at + Vector2(-radius * 0.28, -radius * 0.34), radius * 0.38, light)
