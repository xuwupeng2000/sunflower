extends Node3D

const APPEAR_HOUR := 4
const APPEAR_MINUTE := 20
const STAY_MINUTES := 20

var _goal_x := 0.0
var _goal_z := 0.0
var _speed := 0.3
var _out := false


func _ready() -> void:
	_out = _is_cloud_time()
	visible = _out
	if _out:
		_begin_pass()


func _process(delta: float) -> void:
	var show := _is_cloud_time()
	if show != _out:
		_out = show
		visible = show
		if show:
			_begin_pass()
	if not show:
		return
	var here := Vector2(position.x, position.z)
	var goal := Vector2(_goal_x, _goal_z)
	var next := here.move_toward(goal, _speed * delta)
	position.x = next.x
	position.z = next.y
	if here.distance_to(goal) <= _speed * delta + 0.02:
		_pick_goal()


func _is_cloud_time() -> bool:
	var now := Time.get_time_dict_from_system()
	var minutes := int(now.hour) * 60 + int(now.minute)
	var start := APPEAR_HOUR * 60 + APPEAR_MINUTE
	return minutes >= start and minutes < start + STAY_MINUTES


func _begin_pass() -> void:
	position.x = randf_range(-1.6, 1.6)
	position.z = randf_range(-1.0, 1.0)
	_pick_goal()


func _pick_goal() -> void:
	_goal_x = randf_range(-1.8, 1.8)
	_goal_z = randf_range(-1.15, 1.15)
	_speed = randf_range(0.16, 0.46)
