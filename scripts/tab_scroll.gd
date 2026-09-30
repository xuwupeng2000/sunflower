extends ScrollContainer

func _ready() -> void:
	clip_contents = true


func _get_minimum_size() -> Vector2:
	return Vector2(0, 56)
