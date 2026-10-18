extends SkeletonModifier3D
## 施肥只拔高茎：每节「茎N」沿茎的方向往上推，「头」跟着最后一节走，花头、叶子大小不变。
## stretch = 0 原长；= 1 每节茎变成两倍长。跑在动画之后，不会和动画打架。

@export_range(0.0, 6.0, 0.01) var stretch := 0.0:
	set(value):
		stretch = maxf(value, 0.0)
		var skeleton := get_skeleton()
		if skeleton:
			skeleton.notify_property_list_changed()

var _targets: Array[int] = []
var _rest_total := 0.0


func _ready() -> void:
	_collect()


func _collect() -> void:
	_targets.clear()
	_rest_total = 0.0
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(bone)
		if parent < 0 or not skeleton.get_bone_name(parent).begins_with("茎"):
			continue
		# 茎顶那一小段是最后一节茎骨带着的，不会跟着拉长；头离它的距离要保持原样，不然花头会飘起来。
		if skeleton.get_bone_name(bone) == "头":
			continue
		_targets.append(bone)
		if skeleton.get_bone_name(bone).begins_with("茎"):
			_rest_total += skeleton.get_bone_rest(bone).origin.y


## 茎从根到花头原本一共多长；拔高后的总长是 stem_length() * (1 + stretch)。
func stem_length() -> float:
	if _targets.is_empty():
		_collect()
	return _rest_total


func _process_modification() -> void:
	if stretch <= 0.0:
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _targets.is_empty():
		_collect()
	var factor := 1.0 + stretch
	for bone in _targets:
		var pos := skeleton.get_bone_pose_position(bone)
		pos.y *= factor
		skeleton.set_bone_pose_position(bone, pos)
