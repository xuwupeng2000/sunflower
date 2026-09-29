@tool
extends Node3D
const SEGMENT_HEIGHT := 0.8
const BASE_SEGMENTS := 3
const MAX_EXTRA := 24

const SPIKE_LIFT := 0.34
const ORCHID_SINK := 0.70
const ORCHID_BASE_DROP := 0.32
const ORCHID_ROOT_TUCK := {
	"Root_1": Vector3(-0.06, 0.0, -0.006),
}
const ORCHID_BRANCHES := [
	{"uniform": 1.0, "at": 0, "offset": Vector3(0, 0, 0), "yaw": 0.0},
	{"uniform": 0.62, "at": 1, "offset": Vector3(0.24, 0, -0.1), "yaw": 0.85},
	{"uniform": 0.45, "at": 2, "offset": Vector3(-0.22, 0, 0.12), "yaw": -0.75},
	{"uniform": 0.48, "at": 4, "offset": Vector3(0.08, 0, 0.22), "yaw": 2.0},
]
const FLOWER_KINDS := [
	{
		"name": "蜀葵",
		"mode": "stack",
		"stem": "res://assets/hollyhock/stem.glb",
		"flower": "res://assets/hollyhock/flower.glb",
		"base": "res://assets/hollyhock/base.glb",
		"height": 0.30,
		"stem_materials": [
			"res://assets/hollyhock/stem.tres",
			"res://assets/hollyhock/leaf.tres",
			"res://assets/hollyhock/petal.tres",
			"res://assets/hollyhock/eye.tres",
		],
		"flower_materials": ["res://assets/hollyhock/stem.tres", "res://assets/hollyhock/leaf.tres"],
		"base_materials": ["res://assets/hollyhock/leaf.tres"],
		"crown": true,
		"squash": false,
		"yaw_step": 0.55,
		"node_bloom": false,
	},
	{
		"name": "向日葵",
		"mode": "stack",
		"stem": "res://assets/sunflower/stem.glb",
		"flower": "res://assets/sunflower/flower.glb",
		"stem_materials": ["res://assets/sunflower/stem.tres", "res://assets/sunflower/leaf.tres"],
		"flower_materials": [
			"res://assets/sunflower/petal.tres",
			"res://assets/sunflower/disk.tres",
			"res://assets/sunflower/stem.tres",
			"res://assets/sunflower/leaf.tres",
		],
	},
	{
		"name": "兰花",
		"mode": "spike",
		"scene": "res://assets/orchid/flower.glb",
		"petal": "res://assets/orchid/petal.tres",
		"lip": "res://assets/orchid/lip.tres",
		"bud": "res://assets/orchid/bud.tres",
		"leaf": "res://assets/orchid/leaf.tres",
		"stem": "res://assets/orchid/stem.tres",
	},
]
const POT_KINDS := [
	{
		"name": "陶盆",
		"pot": "res://assets/pots/clay.glb",
		"pot_materials": ["res://assets/pots/clay.tres", "res://assets/pots/soil.tres"],
	},
	{
		"name": "白瓷",
		"pot": "res://assets/pots/clay.glb",
		"pot_materials": ["res://assets/pots/white.tres", "res://assets/pots/soil.tres"],
	},
	{
		"name": "彩釉盆",
		"pot": "res://assets/pots/clay.glb",
		"pot_materials": ["res://assets/pots/glaze.tres", "res://assets/pots/soil.tres"],
	},
]

var _stem_mesh: Mesh
var _base_mesh: Mesh
var _flower_mesh: Mesh
var _side_bloom_mesh: Mesh
var _side_bloom_on := 0
var _node_bloom := false
var _crown := true
var _squash := true
var _yaw_step := 0.9
var _plant_mode := "stack"
var _growth_extra := 0
var _stem_materials: Array[Material] = []
var _base_materials: Array[Material] = []
var _mate_materials: Array[Material] = []
var _stalks: Array = []
var _flower_materials: Array[Material] = []
var _pot_materials: Array[Material] = []
var _orchid_petal: Material
var _orchid_lip: Material
var _orchid_bud: Material
var _orchid_leaf: Material
var _orchid_stem: Material
var _branches: Array = []
var _roots: Array = []
var _spike: MeshInstance3D
var _cluster: Node3D
var _new_bloom: MeshInstance3D
var _spike_base_y := 0.7
var _spike_span := 1.5
var _orchid_rest_top := 1.6
var _stem_height := 0.8
var _flower_height := 1.2
var _framed_bloom := 1.0
var _framed_base := 1.0
var _motion: Tween
var _spark: GPUParticles3D
var _turntable: Node3D
var _plant: Node3D
var _head: MeshInstance3D
const ZOOM_LEVELS := [1.45, 1.0, 0.68]
var _zoom_level := 1
var _framed_segments := BASE_SEGMENTS
var _camera: Camera3D
var _pot: MeshInstance3D
var _rain_cloud: Node3D
var _grow_player: AudioStreamPlayer
var _token := 0
var _dragging := false
var _pinch_points := {}
var _pinch_span := 0.0
var flower_index := 1
var pot_index := 0


func _ready() -> void:
	_camera = $相机
	_turntable = $转台
	_pot = $转台/花盆
	_plant = $转台/植株
	_rain_cloud = get_node_or_null("雨云") as Node3D
	_spark = get_node_or_null("星光") as GPUParticles3D
	_grow_player = $生长音效
	_load_plant_meshes()
	_present(_growth_extra)


func _halt() -> void:
	_token += 1
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = null


func _present(extra: int) -> void:
	if _plant_mode == "spike":
		_mount_orchid()
		_apply_orchid_pose(extra)
		_frame_orchid(extra)
	else:
		_show_stack(extra)


func play_count(count: int) -> void:
	_halt()
	var token := _token
	_growth_extra = clampi(count, 0, MAX_EXTRA)
	if _plant_mode == "spike":
		await _grow_orchid(token)
	else:
		await _grow_stack(token)


func _grow_stack(token: int) -> void:
	for child in _plant.get_children():
		child.queue_free()
	_head = null
	await get_tree().process_frame
	if token != _token:
		return
	_place_base()
	for index in BASE_SEGMENTS:
		if _stalks.is_empty():
			_plant.add_child(_make_segment(index))
			if _node_bloom:
				_plant.add_child(_place_node_bloom(index, _node_bloom_size(index)))
		else:
			_spawn_level(index)
	_place_crown(BASE_SEGMENTS)
	_frame_camera(BASE_SEGMENTS)
	if _growth_extra == 0:
		return
	if _grow_player and _grow_player.stream:
		_grow_player.play()
	for index in _growth_extra:
		var pieces: Array = _spawn_level(BASE_SEGMENTS + index) if not _stalks.is_empty() else [_make_segment(BASE_SEGMENTS + index)]
		if _stalks.is_empty():
			_plant.add_child(pieces[0])
		if _head:
			_head.position.y = float(BASE_SEGMENTS + index + 1) * _stem_height
		var tween := _begin_motion()
		var lead := true
		for piece in pieces:
			var node := piece as Node3D
			var full := node.scale
			if not _squash:
				node.scale = full * 0.04
			else:
				node.scale = Vector3(1, 0.02, 1)
				full = Vector3.ONE
			if lead:
				tween.tween_property(node, "scale", full, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				lead = false
			else:
				tween.parallel().tween_property(node, "scale", full, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if _node_bloom:
			var bloom := _place_node_bloom(BASE_SEGMENTS + index, 0.04)
			_plant.add_child(bloom)
			var bloom_size := _node_bloom_size(BASE_SEGMENTS + index)
			tween.parallel().tween_property(bloom, "scale", Vector3(bloom_size, bloom_size, bloom_size), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_callback(_spark_node.bind(bloom)).set_delay(0.12)
		elif _side_bloom_on > 0 and index + 1 == _side_bloom_on:
			var side := _make_side_bloom()
			side.position = Vector3(0.32, pieces[0].position.y + _stem_height * 0.55, 0.06)
			side.rotation.y = -0.5
			side.scale = Vector3(0.05, 0.05, 0.05)
			_plant.add_child(side)
			tween.parallel().tween_property(side, "scale", Vector3(0.7, 0.7, 0.7), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_callback(_spark_node.bind(side)).set_delay(0.18)
		else:
			_spark_at(pieces[0].global_position + Vector3(0, _stem_height * 0.7, 0))
		_frame_camera(BASE_SEGMENTS + index + 1)
		await tween.finished
		if token != _token:
			return


func _grow_orchid(token: int) -> void:
	_mount_orchid()
	_apply_orchid_pose(0)
	_frame_orchid(0)
	if _growth_extra == 0 or _branches.is_empty():
		return
	if _grow_player and _grow_player.stream:
		_grow_player.play()
	for step in _growth_extra:
		var next := step + 1
		var from_s := _spike_scale(next - 1)
		var to_s := _spike_scale(next)
		var tween := _begin_motion()
		var chained := false
		for branch in _branches:
			var info: Dictionary = branch
			if int(info["at"]) > next:
				continue
			var holder := info["holder"] as Node3D
			var spike := info["spike"] as MeshInstance3D
			var cluster := info["cluster"] as Node3D
			_set_branch_height(info, to_s if int(info["at"]) == next else from_s)
			if int(info["at"]) == next:
				holder.visible = true
				holder.scale = Vector3(0.04, 0.04, 0.04)
				var full := float(info["uniform"])
				if chained:
					tween.parallel().tween_property(holder, "scale", Vector3(full, full, full), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				else:
					tween.tween_property(holder, "scale", Vector3(full, full, full), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					chained = true
				tween.parallel().tween_callback(_spark_node.bind(cluster)).set_delay(0.12)
			else:
				if chained:
					tween.parallel().tween_property(spike, "scale:y", to_s, 0.38)
				else:
					tween.tween_property(spike, "scale:y", to_s, 0.38)
					chained = true
				tween.parallel().tween_property(spike, "position:y", _spike_position(to_s), 0.38)
				tween.parallel().tween_property(cluster, "position:y", _orchid_lift(next), 0.38)
		for root_info in _roots:
			var root: Dictionary = root_info
			var node := root["node"] as MeshInstance3D
			node.scale = Vector3(1, from_s, 1)
			node.position.y = _root_position(root, from_s)
			if chained:
				tween.parallel().tween_property(node, "scale:y", to_s, 0.38)
			else:
				tween.tween_property(node, "scale:y", to_s, 0.38)
				chained = true
			tween.parallel().tween_property(node, "position:y", _root_position(root, to_s), 0.38)
		_frame_orchid(next)
		await tween.finished
		if token != _token:
			return


func flower_kinds() -> Array:
	return FLOWER_KINDS


func pot_kinds() -> Array:
	return POT_KINDS


func apply_style(next_flower: int, next_pot: int) -> void:
	_halt()
	flower_index = clampi(next_flower, 0, FLOWER_KINDS.size() - 1)
	pot_index = clampi(next_pot, 0, POT_KINDS.size() - 1)
	_load_plant_meshes()
	_present(_growth_extra)


func _load_plant_meshes() -> void:
	var flower: Dictionary = FLOWER_KINDS[flower_index]
	var pot: Dictionary = POT_KINDS[pot_index]
	_plant_mode = str(flower.get("mode", "stack"))
	_stalks = []
	_mate_materials = []
	_pot_materials = _materials_from(pot.get("pot_materials", []))
	if _pot:
		_pot.mesh = _load_piece(str(pot["pot"]))["mesh"]
		_apply_materials(_pot, _pot_materials)
	if _plant_mode == "spike":
		_orchid_petal = load(str(flower["petal"]))
		_orchid_lip = load(str(flower["lip"]))
		_orchid_bud = load(str(flower["bud"]))
		_orchid_leaf = load(str(flower["leaf"]))
		_orchid_stem = load(str(flower["stem"]))
		_side_bloom_on = 0
		_node_bloom = false
		return
	var stem := _load_piece(str(flower["stem"]))
	var bloom := _load_bloom(flower)
	_stem_mesh = stem["mesh"]
	_flower_mesh = bloom["mesh"]
	_side_bloom_on = int(flower.get("side_bloom_on", 0))
	_node_bloom = bool(flower.get("node_bloom", false))
	_crown = bool(flower.get("crown", true))
	_squash = bool(flower.get("squash", true))
	_yaw_step = float(flower.get("yaw_step", 0.9))
	_base_mesh = null
	_base_materials = []
	if str(flower.get("base", "")) != "":
		_base_mesh = _load_piece(str(flower["base"]))["mesh"]
		_base_materials = _materials_from(flower.get("base_materials", []))
	_side_bloom_mesh = _flower_mesh
	_stem_height = float(flower.get("height", stem["height"]))
	_flower_height = float(bloom["height"])
	_stem_materials = _materials_from(flower.get("stem_materials", []))
	_flower_materials = _materials_from(flower.get("flower_materials", []))
	_mate_materials = _materials_from(flower.get("mate_materials", []))
	_stalks = flower.get("stalks", [])


func _pot_mesh() -> Mesh:
	return _load_piece(str(POT_KINDS[pot_index]["pot"]))["mesh"]


func _load_piece(path: String) -> Dictionary:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("打不开模型 %s" % path)
		return {"mesh": ArrayMesh.new(), "height": 0.8}
	var node := packed.instantiate()
	var mesh := _find_mesh(node)
	var height := 0.8
	if mesh:
		height = maxf(mesh.get_aabb().size.y, 0.01)
	node.free()
	return {"mesh": mesh if mesh != null else ArrayMesh.new(), "height": height}


func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var inst := node as MeshInstance3D
		if inst.mesh:
			return inst.mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


func _materials_from(paths: Variant) -> Array[Material]:
	var mats: Array[Material] = []
	if paths is Array:
		for path in paths:
			var mat := load(str(path)) as Material
			if mat:
				mats.append(mat)
	return mats


func _apply_materials(piece: MeshInstance3D, materials: Array[Material]) -> void:
	if piece == null or piece.mesh == null:
		return
	piece.material_override = null
	if materials.is_empty():
		return
	if materials.size() == 1 or piece.mesh.get_surface_count() <= 1:
		piece.material_override = materials[0]
		return
	for index in piece.mesh.get_surface_count():
		var mat: Material = materials[index] if index < materials.size() else materials[-1]
		piece.set_surface_override_material(index, mat)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _pinch(event):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_level + 1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_level - 1)
	elif event is InputEventMouseMotion and _dragging and _pinch_points.size() < 2:
		_turntable.rotate_y(-event.relative.x * 0.012)
	elif event is InputEventMagnifyGesture:
		if event.factor > 1.05:
			_set_zoom(_zoom_level + 1)
		elif event.factor < 0.95:
			_set_zoom(_zoom_level - 1)


func _pinch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pinch_points[event.index] = event.position
		else:
			_pinch_points.erase(event.index)
		_pinch_span = _pinch_distance()
		return _pinch_points.size() >= 2
	if event is InputEventScreenDrag:
		_pinch_points[event.index] = event.position
		if _pinch_points.size() < 2:
			return false
		var span := _pinch_distance()
		if _pinch_span > 8.0:
			var ratio := span / _pinch_span
			if ratio >= 1.1:
				_set_zoom(_zoom_level + 1)
				_pinch_span = span
			elif ratio <= 0.9:
				_set_zoom(_zoom_level - 1)
				_pinch_span = span
		else:
			_pinch_span = span
		_dragging = false
		return true
	return false


func _pinch_distance() -> float:
	var points: Array = _pinch_points.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1])


func _set_zoom(level: int) -> void:
	var next := clampi(level, 0, ZOOM_LEVELS.size() - 1)
	if next == _zoom_level:
		return
	_zoom_level = next
	_frame_height(_framed_bloom, _framed_base)


func _show_stack(extra: int) -> void:
	for child in _plant.get_children():
		child.free()
	var total := BASE_SEGMENTS + extra
	_place_base()
	for index in total:
		if _stalks.is_empty():
			_plant.add_child(_make_segment(index))
			if _node_bloom:
				_plant.add_child(_place_node_bloom(index, _node_bloom_size(index)))
		else:
			_spawn_level(index)
	_place_crown(total)
	if _side_bloom_on > 0 and extra >= _side_bloom_on:
		var bloom := _make_side_bloom()
		var at := BASE_SEGMENTS + _side_bloom_on - 1
		bloom.position = Vector3(0.32, float(at) * _stem_height + _stem_height * 0.55, 0.06)
		bloom.rotation.y = -0.5
		bloom.scale = Vector3(0.7, 0.7, 0.7)
		_plant.add_child(bloom)
	_frame_camera(total)


func _mount_orchid() -> void:
	for child in _plant.get_children():
		child.free()
	var built := _populate_orchid(_plant)
	_branches = built["branches"]
	_roots = built["roots"]
	_spike = built["spike"]
	_cluster = built["cluster"]
	_orchid_rest_top = built["rest_top"]
	_head = null
	_new_bloom = null


func _populate_orchid(plant: Node3D) -> Dictionary:
	var packed := load("res://assets/orchid/flower.glb") as PackedScene
	var branches: Array = []
	var roots: Array = []
	var rest_top := 0.2
	if packed == null:
		return {"branches": branches, "roots": roots, "spike": null, "cluster": null, "rest_top": rest_top}
	var root := packed.instantiate()
	plant.add_child(root)
	var base := Node3D.new()
	base.name = "基部"
	plant.add_child(base)
	var cluster := Node3D.new()
	cluster.name = "花串"
	var holder := Node3D.new()
	holder.name = "花枝"
	plant.add_child(holder)
	holder.add_child(cluster)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	var spike: MeshInstance3D = null
	for mesh_node in meshes:
		var label := str(mesh_node.name)
		if label.begins_with("Leaf"):
			mesh_node.reparent(base, true)
			mesh_node.position.y -= ORCHID_SINK + ORCHID_BASE_DROP
			_paint(mesh_node, _orchid_leaf)
		elif label.begins_with("Root"):
			mesh_node.reparent(plant, true)
			mesh_node.position.y -= ORCHID_SINK + ORCHID_BASE_DROP
			mesh_node.position += ORCHID_ROOT_TUCK.get(label, Vector3.ZERO)
			_paint(mesh_node, _orchid_stem)
			var bounds := mesh_node.mesh.get_aabb()
			roots.append({"node": mesh_node, "rest_y": mesh_node.position.y, "base_y": bounds.position.y})
		elif label.begins_with("Spike"):
			mesh_node.reparent(holder, true)
			mesh_node.position.y -= ORCHID_SINK
			_paint(mesh_node, _orchid_stem)
			spike = mesh_node
		elif label.begins_with("BloomLip"):
			mesh_node.reparent(cluster, true)
			mesh_node.position.y -= ORCHID_SINK
			_paint(mesh_node, _orchid_lip)
		elif label.begins_with("Bloom"):
			mesh_node.reparent(cluster, true)
			mesh_node.position.y -= ORCHID_SINK
			_paint(mesh_node, _orchid_petal)
		elif label.begins_with("Bud"):
			mesh_node.reparent(cluster, true)
			mesh_node.position.y -= ORCHID_SINK
			_paint(mesh_node, _orchid_bud)
	root.free()
	if spike != null and spike.mesh != null:
		var aabb := spike.mesh.get_aabb()
		_spike_base_y = aabb.position.y
		_spike_span = maxf(aabb.size.y, 0.01)
	for child in cluster.get_children():
		var piece := child as MeshInstance3D
		if piece == null or piece.mesh == null:
			continue
		var bounds := piece.mesh.get_aabb()
		rest_top = maxf(rest_top, piece.position.y + bounds.position.y + bounds.size.y)
	if spike == null:
		return {"branches": branches, "roots": roots, "spike": null, "cluster": cluster, "rest_top": rest_top}
	var specs: Array = ORCHID_BRANCHES
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var branch_holder := holder
		var branch_spike := spike
		var branch_cluster := cluster
		if index > 0:
			branch_holder = holder.duplicate() as Node3D
			branch_holder.name = "花枝%d" % index
			plant.add_child(branch_holder)
			branch_spike = branch_holder.get_node("Spike") as MeshInstance3D
			branch_cluster = branch_holder.get_node("花串") as Node3D
		branch_holder.position = spec["offset"]
		branch_holder.rotation.y = float(spec["yaw"])
		branches.append({
			"holder": branch_holder,
			"spike": branch_spike,
			"cluster": branch_cluster,
			"uniform": float(spec["uniform"]),
			"at": int(spec["at"]),
			"offset": spec["offset"],
			"yaw": float(spec["yaw"]),
		})
	return {"branches": branches, "roots": roots, "spike": spike, "cluster": cluster, "rest_top": rest_top}


func _collect_meshes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		into.append(node)
	for child in node.get_children():
		_collect_meshes(child, into)


func _paint(piece: MeshInstance3D, material: Material) -> void:
	if piece == null or material == null:
		return
	piece.material_override = material


func _orchid_lift(extra: int) -> float:
	return float(extra) * SPIKE_LIFT


func _spike_scale(extra: int) -> float:
	return 1.0 + _orchid_lift(extra) / _spike_span


func _spike_position(scale_y: float) -> float:
	return -ORCHID_SINK + _spike_base_y * (1.0 - scale_y)


func _spike_tip(scale_y: float) -> float:
	return -ORCHID_SINK + _spike_base_y + _spike_span * scale_y


func _root_position(info: Dictionary, scale_y: float) -> float:
	return float(info["rest_y"]) + float(info["base_y"]) * (1.0 - scale_y)


func _set_branch_height(info: Dictionary, scale_y: float) -> void:
	var spike := info["spike"] as MeshInstance3D
	var cluster := info["cluster"] as Node3D
	if spike == null or cluster == null:
		return
	spike.scale = Vector3(1, scale_y, 1)
	spike.position.y = _spike_position(scale_y)
	cluster.position.y = (scale_y - 1.0) * _spike_span


func _pose_orchid(branches: Array, roots: Array, extra: int) -> void:
	var scale_y := _spike_scale(extra)
	for branch in branches:
		var info: Dictionary = branch
		var holder := info["holder"] as Node3D
		var shown := extra >= int(info["at"])
		holder.visible = shown
		if not shown:
			holder.scale = Vector3.ZERO
			continue
		var uniform := float(info["uniform"])
		holder.scale = Vector3(uniform, uniform, uniform)
		holder.position = info["offset"]
		holder.rotation.y = float(info["yaw"])
		var spike := info["spike"] as MeshInstance3D
		var cluster := info["cluster"] as Node3D
		spike.scale = Vector3(1, scale_y, 1)
		spike.position.y = _spike_position(scale_y)
		cluster.position.y = _orchid_lift(extra)
	for root_info in roots:
		var root: Dictionary = root_info
		var node := root["node"] as MeshInstance3D
		node.scale = Vector3(1, scale_y, 1)
		node.position.y = _root_position(root, scale_y)


func _apply_orchid_pose(extra: int) -> void:
	if _branches.is_empty():
		return
	_pose_orchid(_branches, _roots, extra)


func _frame_orchid(extra: int) -> void:
	var bloom := _orchid_rest_top + _orchid_lift(extra)
	_frame_height(bloom, _orchid_rest_top)


func _begin_motion() -> Tween:
	if _motion and _motion.is_valid():
		_motion.kill()
	_motion = create_tween()
	return _motion


func _spark_at(at: Vector3) -> void:
	if _spark == null:
		return
	_spark.global_position = at
	_spark.emitting = true
	_spark.restart()


func _spark_node(node: Node3D) -> void:
	if is_instance_valid(node):
		_spark_at(node.global_position)


func _spark_new_bloom() -> void:
	_spark_node(_new_bloom)


func _node_bloom_size(index: int) -> float:
	return 1.35 if index % 2 == 0 else 0.95


func _place_node_bloom(index: int, size: float) -> MeshInstance3D:
	var bloom := _make_side_bloom()
	bloom.name = "节花%d" % index
	var yaw := float(index) * 0.9
	var outward := Vector3(cos(yaw), 0.0, -sin(yaw))
	bloom.position = outward * 0.36 + Vector3(0, float(index) * _stem_height + _stem_height * 0.55, 0)
	bloom.rotation = Vector3(-0.45, yaw, 0)
	bloom.scale = Vector3(size, size, size)
	return bloom


func _place_base() -> void:
	if _base_mesh == null:
		return
	var base := MeshInstance3D.new()
	base.name = "基叶"
	base.mesh = _base_mesh
	_apply_materials(base, _base_materials)
	_plant.add_child(base)


func _make_segment(index: int) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = _stem_mesh
	_apply_materials(piece, _stem_materials)
	piece.position = Vector3(0, index * _stem_height, 0)
	piece.rotation.y = float(index) * _yaw_step
	return piece


func _spawn_level(index: int) -> Array:
	var made: Array = []
	for stalk in _stalks:
		made.append(_add_stalk(_plant, _stem_mesh, _stem_materials, _mate_materials, index, _stem_height, stalk))
	return made


func _add_stalk(parent: Node3D, mesh: Mesh, stem_materials: Array[Material], mate_materials: Array[Material], index: int, height: float, stalk: Dictionary) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	if bool(stalk.get("mate", false)) and not mate_materials.is_empty():
		_apply_materials(piece, mate_materials)
	else:
		_apply_materials(piece, stem_materials)
	var offset: Vector3 = stalk.get("offset", Vector3.ZERO)
	piece.position = offset + Vector3(0, float(index) * height, 0)
	piece.rotation.y = float(index) * 0.9 + float(stalk.get("yaw", 0.0))
	var size := float(stalk.get("scale", 1.0))
	piece.scale = Vector3(size, size, size)
	parent.add_child(piece)
	return piece


func _make_head() -> MeshInstance3D:
	var head := MeshInstance3D.new()
	head.mesh = _flower_mesh
	_apply_materials(head, _flower_materials)
	return head


func _make_side_bloom() -> MeshInstance3D:
	var bloom := MeshInstance3D.new()
	bloom.name = "侧花"
	bloom.mesh = _side_bloom_mesh
	if _side_bloom_mesh == _flower_mesh:
		_apply_materials(bloom, _flower_materials)
	return bloom


func _place_crown(segments: int) -> void:
	_head = null
	if not _crown:
		return
	_head = _make_head()
	_head.position.y = float(segments) * _stem_height
	_plant.add_child(_head)


func _frame_camera(segments: int) -> void:
	_framed_segments = segments
	var top := _flower_height if _crown else 0.0
	var bloom := float(segments) * _stem_height + top
	var base_bloom := float(BASE_SEGMENTS) * _stem_height + top
	_frame_height(bloom, base_bloom)


func _frame_height(bloom: float, base_bloom: float) -> void:
	_framed_bloom = bloom
	_framed_base = base_bloom
	var pot_height := 0.8
	if _pot and _pot.mesh:
		pot_height = maxf(_pot.mesh.get_aabb().size.y, 0.01)
	var target_pot := base_bloom / 2.0
	var pot_scale := target_pot / pot_height
	_pot.scale = Vector3(pot_scale, pot_scale, pot_scale)
	_plant.position.y = target_pot
	var head_top := target_pot + bloom
	var fov := deg_to_rad(_camera.fov if _camera.fov > 0.0 else 75.0)
	var half := tan(fov * 0.5)
	var ndc_bottom := 0.10 * 2.0 - 1.0
	var ndc_top := 0.96 * 2.0 - 1.0
	var view_h := head_top / maxf(ndc_top - ndc_bottom, 0.01)
	var look_y := -ndc_bottom * view_h
	var fit := view_h / maxf(half, 0.01)
	var closest := float(ZOOM_LEVELS[ZOOM_LEVELS.size() - 1])
	var distance := fit * float(ZOOM_LEVELS[_zoom_level]) / closest
	_camera.position = Vector3(distance * 0.28, look_y, distance)
	_camera.look_at(Vector3(0, look_y, 0))
	if _rain_cloud:
		_rain_cloud.position.y = head_top + 0.85



func _load_bloom(flower: Dictionary) -> Dictionary:
	var path := str(flower.get("flower", ""))
	if path == "":
		return {"mesh": null, "height": 0.0}
	return _load_piece(path)
