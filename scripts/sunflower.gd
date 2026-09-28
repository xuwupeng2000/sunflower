@tool
extends Node3D

const VoxModel = preload("res://scripts/vox_model.gd")
const SEGMENT_HEIGHT := 0.8
const BASE_SEGMENTS := 3
const MAX_EXTRA := 24

const FLOWER_KINDS := [
	{"name": "白掌", "stem": "res://models/stem_peace.vox", "flower": "res://models/flower_peace.vox"},
	{
		"name": "向日葵",
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
	{"name": "兰花", "stem": "res://models/stem_orchid.vox", "flower": "res://models/flower_orchid.vox"},
]
const POT_KINDS := [
	{
		"name": "陶盆",
		"pot": "res://assets/pots/clay.glb",
		"pot_materials": ["res://assets/pots/clay.tres", "res://assets/pots/soil.tres"],
	},
	{"name": "白瓷", "pot": "res://models/pot_white.vox"},
	{"name": "彩釉盆", "pot": "res://models/pot_glaze.vox"},
]

var _voxel_mat: Material
var _stem_mesh: Mesh
var _flower_mesh: Mesh
var _stem_materials: Array[Material] = []
var _flower_materials: Array[Material] = []
var _pot_materials: Array[Material] = []
var _stem_height := 0.8
var _flower_height := 1.2
var _turntable: Node3D
var _plant: Node3D
var _head: MeshInstance3D
const ZOOM_LEVELS := [1.45, 1.0, 0.68]
var _zoom_level := 1
var _framed_segments := BASE_SEGMENTS
var _camera: Camera3D
var _pot: MeshInstance3D
var _grow_player: AudioStreamPlayer
var _token := 0
var _dragging := false
var flower_index := 1
var pot_index := 0


func _ready() -> void:
	_camera = $相机
	_turntable = $转台
	_pot = $转台/花盆
	_plant = $转台/植株
	_grow_player = $生长音效
	_voxel_mat = load("res://shaders/voxel_plastic.tres")
	_load_voxel_meshes()
	_show_base_flower()


func _show_base_flower() -> void:
	for child in _plant.get_children():
		child.free()
	for index in BASE_SEGMENTS:
		_plant.add_child(_make_segment(index))
	_head = _make_head()
	_head.position.y = float(BASE_SEGMENTS) * _stem_height
	_plant.add_child(_head)
	_frame_camera(BASE_SEGMENTS)


func play_count(count: int) -> void:
	_token += 1
	var token := _token
	for child in _plant.get_children():
		child.queue_free()
	_head = null
	await get_tree().process_frame
	if token != _token:
		return
	for index in BASE_SEGMENTS:
		var piece := _make_segment(index)
		_plant.add_child(piece)
	_head = _make_head()
	_head.position.y = float(BASE_SEGMENTS) * _stem_height
	_plant.add_child(_head)
	_frame_camera(BASE_SEGMENTS)
	var extra := clampi(count, 0, MAX_EXTRA)
	if extra == 0:
		return
	if _grow_player and _grow_player.stream:
		_grow_player.play()
	for index in extra:
		var piece := _make_segment(BASE_SEGMENTS + index)
		_plant.add_child(piece)
		piece.scale = Vector3(1, 0.02, 1)
		_head.position.y = float(BASE_SEGMENTS + index + 1) * _stem_height
		var tween := create_tween()
		tween.tween_property(piece, "scale", Vector3.ONE, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_frame_camera(BASE_SEGMENTS + index + 1)
		await tween.finished
		if token != _token:
			return


func flower_kinds() -> Array:
	return FLOWER_KINDS


func pot_kinds() -> Array:
	return POT_KINDS


func apply_style(next_flower: int, next_pot: int) -> void:
	flower_index = clampi(next_flower, 0, FLOWER_KINDS.size() - 1)
	pot_index = clampi(next_pot, 0, POT_KINDS.size() - 1)
	_load_voxel_meshes()
	if _pot:
		_pot.mesh = _pot_mesh()
		_apply_materials(_pot, _pot_materials)
	if _head:
		_head.mesh = _flower_mesh
		_apply_materials(_head, _flower_materials)
	for child in _plant.get_children():
		if child == _head:
			continue
		var stem := child as MeshInstance3D
		if stem:
			stem.mesh = _stem_mesh
			_apply_materials(stem, _stem_materials)


func _load_voxel_meshes() -> void:
	var flower: Dictionary = FLOWER_KINDS[flower_index]
	var pot: Dictionary = POT_KINDS[pot_index]
	var stem := _load_piece(str(flower["stem"]))
	var bloom := _load_piece(str(flower["flower"]))
	_stem_mesh = stem["mesh"]
	_flower_mesh = bloom["mesh"]
	_stem_height = float(stem["height"])
	_flower_height = float(bloom["height"])
	_stem_materials = _materials_from(flower.get("stem_materials", []))
	_flower_materials = _materials_from(flower.get("flower_materials", []))
	_pot_materials = _materials_from(pot.get("pot_materials", []))
	if _pot:
		_pot.mesh = _load_piece(str(pot["pot"]))["mesh"]
		_apply_materials(_pot, _pot_materials)


func _pot_mesh() -> Mesh:
	return _load_piece(str(POT_KINDS[pot_index]["pot"]))["mesh"]


func _load_piece(path: String) -> Dictionary:
	if path.ends_with(".vox"):
		return VoxModel.load_mesh(path)
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
	if mats.is_empty() and _voxel_mat:
		mats.append(_voxel_mat)
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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_level + 1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_level - 1)
	elif event is InputEventMouseMotion and _dragging:
		_turntable.rotate_y(-event.relative.x * 0.012)
	elif event is InputEventMagnifyGesture:
		if event.factor > 1.05:
			_set_zoom(_zoom_level + 1)
		elif event.factor < 0.95:
			_set_zoom(_zoom_level - 1)


func _set_zoom(level: int) -> void:
	var next := clampi(level, 0, ZOOM_LEVELS.size() - 1)
	if next == _zoom_level:
		return
	_zoom_level = next
	_frame_camera(_framed_segments)


func _make_segment(index: int) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = _stem_mesh
	_apply_materials(piece, _stem_materials)
	piece.position = Vector3(0, index * _stem_height, 0)
	piece.rotation.y = float(index) * 0.9
	return piece


func _make_head() -> MeshInstance3D:
	var head := MeshInstance3D.new()
	head.mesh = _flower_mesh
	_apply_materials(head, _flower_materials)
	return head


func _frame_camera(segments: int) -> void:
	_framed_segments = segments
	var bloom := float(segments) * _stem_height + _flower_height
	var pot_height := 0.8
	if _pot and _pot.mesh:
		pot_height = maxf(_pot.mesh.get_aabb().size.y, 0.01)
	var base_bloom := float(BASE_SEGMENTS) * _stem_height + _flower_height
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


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	return material


func _lathe(profile: Array, sides: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in profile.size() - 1:
		var a: Vector2 = profile[ring]
		var b: Vector2 = profile[ring + 1]
		for side in sides:
			var t0 := float(side) / float(sides) * TAU
			var t1 := float(side + 1) / float(sides) * TAU
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p01 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p10 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			tool.set_smooth_group(-1)
			tool.add_vertex(p00)
			tool.add_vertex(p10)
			tool.add_vertex(p11)
			tool.add_vertex(p00)
			tool.add_vertex(p11)
			tool.add_vertex(p01)
	tool.generate_normals()
	return tool.commit()


func _leaf_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [
		Vector3(0, 0, 0), Vector3(0.08, 0.05, 0.02), Vector3(0.16, 0.16, 0.03),
		Vector3(0.12, 0.30, 0.02), Vector3(0, 0.42, 0), Vector3(-0.10, 0.28, 0.02),
		Vector3(-0.12, 0.12, 0.025),
	]
	for i in outline.size() - 1:
		tool.add_vertex(outline[0])
		tool.add_vertex(outline[i])
		tool.add_vertex(outline[(i + 1) % outline.size()])
	tool.generate_normals()
	return tool.commit()


func _petal_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		Vector3(0, 0, 0),
		Vector3(0.045, 0.02, 0.08),
		Vector3(0.03, 0.05, 0.20),
		Vector3(0, 0.07, 0.30),
		Vector3(-0.03, 0.05, 0.20),
		Vector3(-0.045, 0.02, 0.08),
	]
	for i in range(1, pts.size() - 1):
		tool.add_vertex(pts[0])
		tool.add_vertex(pts[i])
		tool.add_vertex(pts[i + 1])
	tool.generate_normals()
	return tool.commit()


func _disk_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 5
	var sides := 16
	for ring in rings:
		var r0 := float(ring) / float(rings) * 0.16
		var r1 := float(ring + 1) / float(rings) * 0.16
		var y0 := sin(float(ring) / float(rings) * PI) * 0.045
		var y1 := sin(float(ring + 1) / float(rings) * PI) * 0.03
		for side in sides:
			var t0 := float(side) / float(sides) * TAU
			var t1 := float(side + 1) / float(sides) * TAU
			var p00 := Vector3(cos(t0) * r0, y0, sin(t0) * r0)
			var p01 := Vector3(cos(t1) * r0, y0, sin(t1) * r0)
			var p10 := Vector3(cos(t0) * r1, y1, sin(t0) * r1)
			var p11 := Vector3(cos(t1) * r1, y1, sin(t1) * r1)
			tool.add_vertex(p00)
			tool.add_vertex(p10)
			tool.add_vertex(p11)
			tool.add_vertex(p00)
			tool.add_vertex(p11)
			tool.add_vertex(p01)
	tool.generate_normals()
	return tool.commit()
