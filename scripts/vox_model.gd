extends RefCounted

const VOXEL_SIZE := 0.1


static func load_mesh(path: String) -> Dictionary:
	var parsed := _read(path)
	var voxels: Array = parsed["voxels"]
	var palette: Array = parsed["palette"]
	var occupied := {}
	for voxel in voxels:
		occupied[_key(int(voxel["x"]), int(voxel["y"]), int(voxel["z"]))] = true
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size: Vector3i = parsed["size"]
	for voxel in voxels:
		var color: Color = palette[int(voxel["c"])]
		_add_cube(tool, occupied, int(voxel["x"]), int(voxel["y"]), int(voxel["z"]), color, size)
	tool.generate_normals()
	return {
		"mesh": tool.commit(),
		"height": float(size.z) * VOXEL_SIZE,
	}


static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("打不开体素文件 %s" % path)
		return {"voxels": [], "palette": _default_palette(), "size": Vector3i.ONE}
	file.get_buffer(4)
	file.get_32()
	file.get_buffer(4)
	file.get_32()
	var children := file.get_32()
	var end := file.get_position() + children
	var voxels: Array = []
	var palette := _default_palette()
	var size := Vector3i.ONE
	while file.get_position() < end and file.get_position() < file.get_length():
		var tag := file.get_buffer(4).get_string_from_ascii()
		var content := file.get_32()
		var nested := file.get_32()
		var start := file.get_position()
		if tag == "SIZE":
			size = Vector3i(file.get_32(), file.get_32(), file.get_32())
		elif tag == "XYZI":
			var count := file.get_32()
			for _i in count:
				voxels.append({
					"x": file.get_8(),
					"y": file.get_8(),
					"z": file.get_8(),
					"c": file.get_8(),
				})
		elif tag == "RGBA":
			for index in 255:
				palette[index + 1] = Color8(file.get_8(), file.get_8(), file.get_8(), file.get_8())
			file.get_32()
		file.seek(start + content + nested)
	return {"voxels": voxels, "palette": palette, "size": size}


static func _add_cube(tool: SurfaceTool, occupied: Dictionary, x: int, y: int, z: int, color: Color, size: Vector3i) -> void:
	var origin := Vector3(x, z, y) * VOXEL_SIZE - Vector3(size.x, 0, size.y) * VOXEL_SIZE * 0.5
	var faces := [
		[Vector3i(0, 1, 0), [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[Vector3i(0, -1, 0), [Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]],
		[Vector3i(1, 0, 0), [Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]],
		[Vector3i(-1, 0, 0), [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)]],
		[Vector3i(0, 0, 1), [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[Vector3i(0, 0, -1), [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
	]
	for face in faces:
		var offset: Vector3i = face[0]
		if occupied.has(_key(x + offset.x, y + offset.y, z + offset.z)):
			continue
		var corners: Array = face[1]
		var positions: Array[Vector3] = []
		for corner in corners:
			positions.append(origin + Vector3(corner) * VOXEL_SIZE)
		_quad(tool, positions[0], positions[1], positions[2], positions[3], color)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tool.set_color(color)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(d)


static func _key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


static func _default_palette() -> Array:
	var palette: Array[Color] = []
	palette.resize(256)
	for index in 256:
		palette[index] = Color.WHITE
	return palette
