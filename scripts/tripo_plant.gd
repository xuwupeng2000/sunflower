@tool
extends Node3D
## Imported base and flower crown remain rigid. Growth adds separate stalk sections.
signal height_changed(height: float)

var _section_height := 0.12
var _profile: Dictionary
var _crown: Node3D
var _sections: Node3D
var _joints: Node3D
var _pivot := Vector3.ZERO
var _growth := 0.0
var _wilt := 0.0
var _wilt_goal := -1.0
var _bend := 0.0
var _pose_tween: Tween
var _interfaces: Array = []
var _connector_material: StandardMaterial3D
var _skin_materials: Array[Material] = []
var _leaf_materials: Array[ShaderMaterial] = []

func configure(asset: String) -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tripo/animated/profiles.json"))
	_profile = profiles[asset]
	_section_height = float(_profile["section_height"])
	_interfaces = []
	if _profile.has("interfaces"):
		_interfaces = JSON.parse_string(FileAccess.get_file_as_string(str(_profile["interfaces"])))
	_connector_material = StandardMaterial3D.new()
	_connector_material.vertex_color_use_as_albedo = true
	_connector_material.vertex_color_is_srgb = false
	_connector_material.roughness = 1.0
	_skin_materials.clear()
	for spec in _profile["stems"]:
		var material: Material = _connector_material
		if spec.has("skin"):
			var textured := ShaderMaterial.new()
			textured.shader = load("res://shaders/stem_skin.gdshader")
			textured.set_shader_parameter("stalk_skin", load(str(spec["skin"])))
			material = textured
		_skin_materials.append(material)
	_connector_material.metallic_specular = 0.0
	var p: Array = _profile["pivot"]
	_pivot = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var packed := load(str(_profile.get("whole_scene", "res://assets/tripo/animated/%s.glb" % asset))) as PackedScene
	var model := packed.instantiate() as Node3D
	add_child(model)
	model.position.y = -float(_profile.get("planting_depth", 0.0))
	_crown = model.find_child("Crown", true, false) as Node3D
	if _crown == null and _profile.has("whole_scene"):
		_crown = Node3D.new()
		model.add_child(_crown)
	assert(_crown != null, "Missing flower crown in %s" % asset)
	_leaf_materials.clear()
	_prepare_leaf_materials(model, model, float(_profile.get("leaf_ceiling", {"sunflower-new": 0.98, "phalaenopsis-new": 0.56, "clivia": 0.93}.get(asset, 0.56))))
	_sections = Node3D.new()
	_sections.name = "新增花茎"
	model.add_child(_sections)
	_joints = Node3D.new()
	_joints.name = "花梗弯曲连接"
	model.add_child(_joints)
	_rebuild()

func set_growth(value: float) -> void:
	_growth = maxf(value, 0.0)
	_rebuild()
	height_changed.emit(plant_height())

func plant_height() -> float:
	return float(_profile.get("height", 1.6)) - float(_profile.get("planting_depth", 0.0)) + (_growth * _section_height if bool(_profile.get("extend_stems", true)) else 0.0)

func section_count() -> int:
	return ceili(_growth) if bool(_profile.get("extend_stems", true)) else 0

func set_wilt(level: float, bend: float, animate: bool) -> void:
	var goal := clampf(level, 0.0, 3.0)
	_bend = clampf(bend, 0.0, 1.0)
	if _pose_tween and _pose_tween.is_valid():
		if is_equal_approx(goal, _wilt_goal):
			_rebuild()
			return
		_pose_tween.kill()
	_wilt_goal = goal
	if not animate or not is_inside_tree():
		_pose_amount(goal)
		return
	_pose_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var recovering := goal < _wilt
	if recovering:
		_pose_tween.tween_interval(0.20)
	_pose_tween.tween_method(_pose_amount, _wilt, goal, 3.0 if recovering else 0.65)

func _pose_amount(amount: float) -> void:
	_wilt = amount
	for material in _leaf_materials:
		material.set_shader_parameter("dry", amount / 3.0)
		material.set_shader_parameter("flower_bend", amount / 3.0 * 0.38 if _profile.has("whole_scene") else 0.0)
	_rebuild()

func _rebuild() -> void:
	if _sections == null or _crown == null:
		return
	for child in _sections.get_children():
		child.free()
	for child in _joints.get_children():
		child.free()
	var count := section_count()
	var end := _pivot
	var angle := minf(0.48, _wilt * 0.13 + _bend * 0.24)
	for index in count:
		var fraction := clampf(_growth - float(index), 0.0, 1.0)
		var length := _section_height * fraction
		var turn := angle * float(index + 1) / float(maxi(count, 1))
		var direction := Vector3(-sin(turn), cos(turn), 0.0)
		var previous_turn := angle * float(index) / float(maxi(count, 1))
		var next_end := end + direction * length
		for stem_index in _profile["stems"].size():
			var spec: Dictionary = _profile["stems"][stem_index]
			var offset := Vector3(float(spec["x"]) - _pivot.x, 0, float(spec["z"]) - _pivot.z)
			var from := end + offset.rotated(Vector3.BACK, previous_turn)
			var to := next_end + offset.rotated(Vector3.BACK, turn)
			_add_bridge(_sections, from, to, _interfaces[stem_index], float(index) * _section_height, _growth * _section_height, previous_turn, turn, _skin_materials[stem_index], "茎节_%d" % (index + 1))
		end = next_end
	if count == 0 and angle > 0.0001:
		for stem_index in _profile["stems"].size():
			var spec: Dictionary = _profile["stems"][stem_index]
			var offset := Vector3(float(spec["x"]) - _pivot.x, 0, float(spec["z"]) - _pivot.z)
			_add_bridge(_joints, _pivot + offset, _pivot + offset.rotated(Vector3.BACK, angle), _interfaces[stem_index], 0.0, 0.0, 0.0, angle, _skin_materials[stem_index], "弯曲连接")
	_crown.position = end
	_crown.rotation.z = angle

func _add_bridge(parent: Node3D, from: Vector3, to: Vector3, interface: Dictionary, start: float, total: float, from_angle: float, to_angle: float, material: Material, label: String) -> void:
	if from.distance_to(to) < 0.00001:
		return
	var sides := int(interface["sides"])
	var levels: Array = interface["levels"]
	var steps := 8
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var blends := PackedVector2Array()
	var indices := PackedInt32Array()
	var length := from.distance_to(to)
	for row in steps + 1:
		var t := float(row) / float(steps)
		var y := start + t * length
		var edge := smoothstep(0.0, 0.025, y) * smoothstep(0.0, 0.025, maxf(0.0, total - y))
		var variation := (sin(y * 24.0) * 0.5 + 0.5) * edge
		var theta := lerpf(from_angle, to_angle, t)
		var center := from.lerp(to, t)
		for column in sides + 1:
			var side := column % sides
			uvs.append(Vector2(float(column) / float(sides), 0.5 + 0.45 * sin(y * PI / _section_height)))
			blends.append(Vector2(1.0 - edge, 0.0))
			var actual: Array = levels[1]["ring"][side]
			var lower: Array = levels[0]["ring"][side]
			var upper: Array = levels[2]["ring"][side]
			var radial := Vector3(float(actual[0]), 0, float(actual[1]))
			var sampled := Vector3(lerpf(float(lower[0]), float(upper[0]), variation), 0, lerpf(float(lower[1]), float(upper[1]), variation))
			radial = radial.lerp(sampled, edge * 0.25)
			vertices.append(center + radial.rotated(Vector3.BACK, theta))
			var n: Array = levels[1]["normals"][side]
			normals.append(Vector3(float(n[0]), float(n[1]), float(n[2])).normalized().rotated(Vector3.BACK, theta))
			var c: Array = levels[1]["colors"][side]
			var a: Array = levels[0]["colors"][side]
			var b: Array = levels[2]["colors"][side]
			var original := Color(float(c[0]), float(c[1]), float(c[2]))
			var sampled_color := Color(lerpf(float(a[0]), float(b[0]), variation), lerpf(float(a[1]), float(b[1]), variation), lerpf(float(a[2]), float(b[2]), variation))
			colors.append(original.lerp(sampled_color, edge * 0.55).srgb_to_linear())
	for row in steps:
		for side in sides:
			var stride := sides + 1
			var a := row * stride + side
			var b := a + 1
			indices.append_array(PackedInt32Array([a, b, b + stride, a, b + stride, a + stride]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = blends
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var section := MeshInstance3D.new()
	section.name = label
	section.mesh = mesh
	parent.add_child(section)

func _prepare_leaf_materials(node: Node, model: Node3D, ceiling: float) -> void:
	if node is MeshInstance3D:
		var piece := node as MeshInstance3D
		for surface in piece.mesh.get_surface_count():
			var original := piece.mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null or original.albedo_texture == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = load("res://shaders/plant_leaf_wilt.gdshader")
			material.set_shader_parameter("original_albedo", original.albedo_texture)
			material.set_shader_parameter("original_tint", original.albedo_color)
			material.set_shader_parameter("rest_from_mesh", model.global_transform.affine_inverse() * piece.global_transform)
			material.set_shader_parameter("leaf_ceiling", ceiling)
			material.set_shader_parameter("dry", _wilt / 3.0)
			piece.set_surface_override_material(surface, material)
			_leaf_materials.append(material)
	for child in node.get_children():
		_prepare_leaf_materials(child, model, ceiling)


func wet_at(world_point: Vector3, amount: float) -> void:
	for material in _leaf_materials:
		material.set_shader_parameter("wet_center", world_point)
		material.set_shader_parameter("wet_amount", amount)


static var _planter_maps: Dictionary = {}

func set_planter_contact(pot: MeshInstance3D) -> void:
	var key := pot.mesh.get_instance_id()
	if not _planter_maps.has(key):
		var bounds := pot.mesh.get_aabb()
		var size := 64
		var image := Image.create(size, size, false, Image.FORMAT_RF)
		var triangles := pot.mesh.generate_triangle_mesh()
		for row in size:
			for column in size:
				var x := bounds.position.x + (float(column)+0.5)/float(size)*bounds.size.x
				var z := bounds.position.z + (float(row)+0.5)/float(size)*bounds.size.z
				var hit := triangles.intersect_segment(Vector3(x,bounds.end.y+0.1,z),Vector3(x,bounds.position.y-0.1,z))
				image.set_pixel(column,row,Color(float(hit.position.y) if not hit.is_empty() else -5.0,0,0))
		# Conservatively cover thin rims and decorations between adjacent samples.
		var guarded := Image.create(size,size,false,Image.FORMAT_RF)
		for row in size:
			for column in size:
				var support := -5.0
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						support=maxf(support,image.get_pixel(clampi(column+dx,0,size-1),clampi(row+dy,0,size-1)).r)
				guarded.set_pixel(column,row,Color(support,0,0))
		_planter_maps[key] = {"texture":ImageTexture.create_from_image(guarded),"bounds":Vector4(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)}
	var data: Dictionary = _planter_maps[key]
	for material in _leaf_materials:
		material.set_shader_parameter("planter_height",data.texture)
		material.set_shader_parameter("planter_bounds",data.bounds)
		material.set_shader_parameter("planter_from_world",pot.global_transform.affine_inverse())
		material.set_shader_parameter("planter_to_world",pot.global_transform)
		material.set_shader_parameter("planter_contact",true)


func apply_impacts(impacts: Array[Dictionary]) -> void:
	var centers := PackedVector3Array()
	var pivots := PackedVector3Array()
	var offsets := PackedVector3Array()
	var rotations := PackedVector3Array()
	var radii := PackedFloat32Array()
	var magnitude := 0.0
	for index in 4:
		if index<impacts.size():
			var impact: Dictionary=impacts[index]
			centers.append(to_global(impact.center))
			pivots.append(to_global(impact.pivot))
			offsets.append(global_basis*Vector3(impact.offset))
			rotations.append(global_basis*Vector3(impact.rotation))
			radii.append(float(impact.radius))
			magnitude+=Vector3(impact.offset).length()+Vector3(impact.rotation).length()
		else:
			centers.append(Vector3.ZERO)
			pivots.append(Vector3.ZERO)
			offsets.append(Vector3.ZERO)
			rotations.append(Vector3.ZERO)
			radii.append(0.0)
	var materials: Array[Material]=[]
	materials.append_array(_leaf_materials)
	for skin in _skin_materials:
		if skin is ShaderMaterial: materials.append(skin)
	for material in materials:
		material.set_shader_parameter("impact_centers",centers)
		material.set_shader_parameter("impact_pivots",pivots)
		material.set_shader_parameter("impact_offsets",offsets)
		material.set_shader_parameter("impact_rotations",rotations)
		material.set_shader_parameter("impact_radii",radii)
		material.set_shader_parameter("plant_from_world",global_transform.affine_inverse())
		if material in _leaf_materials: material.set_shader_parameter("tap_amount",magnitude)
