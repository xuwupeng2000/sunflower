extends GdUnitTestSuite

func _fixture() -> Node3D:
	var scene := load("res://scenes/sunflower.tscn").instantiate() as Node3D
	add_child(auto_free(scene))
	return scene

func test_feeding_adds_sections_without_scaling_original_plant() -> void:
	var scene = _fixture()
	for flower in [0]:
		scene.apply_style(flower, 5)
		var model = scene._model
		var crown: Node3D = model._crown
		var rest := crown.position
		for count in [1, 3, 10]:
			model.set_growth(float(count))
			assert_int(model.section_count()).is_equal(count)
			assert_int(model._sections.get_child_count()).is_equal(count * model._profile["stems"].size())
			assert_float(crown.position.y - rest.y).is_equal_approx(float(count) * float(model._profile["section_height"]), 0.0001)
			assert_vector(crown.scale).is_equal(Vector3.ONE)
			for section in model._sections.get_children():
				assert_float(section.scale.y).is_equal_approx(1.0, 0.0001)
				assert_float(section.mesh.get_aabb().size.y).is_equal_approx(float(model._profile["section_height"]), 0.0001)
				assert_object(section.material_override).is_null()
				var material: Material = section.mesh.surface_get_material(0)
				if flower in [0, 1]:
					assert_bool(material is ShaderMaterial).is_true()
					assert_object(material.get_shader_parameter("stalk_skin")).is_not_null()
				else:
					assert_bool(material is StandardMaterial3D).is_true()
					assert_bool(material.vertex_color_use_as_albedo).is_true()

func test_orchid_wilt_keeps_leaf_fan_and_bloom_geometry_unchanged() -> void:
	var scene = _fixture()
	scene.apply_style(1, 5)
	var model = scene._model
	var crown: Node3D = model._crown
	var base: MeshInstance3D = model.find_child("Base_*", true, false)
	var flower: MeshInstance3D = model.find_child("Top_*", true, false)
	assert_object(base).is_not_null()
	assert_object(flower).is_not_null()
	var base_transform := base.global_transform
	var flower_bounds := flower.mesh.get_aabb()
	var material := flower.mesh.surface_get_material(0)
	model.set_growth(3.0)
	scene.apply_wilt(3, false)
	assert_vector(base.global_position).is_equal(base_transform.origin)
	assert_vector(base.global_basis.x).is_equal(base_transform.basis.x)
	assert_vector(crown.scale).is_equal(Vector3.ONE)
	assert_vector(flower.mesh.get_aabb().size).is_equal(flower_bounds.size)
	assert_object(flower.mesh.surface_get_material(0)).is_same(material)
	assert_object(flower.material_overlay).is_null()
	assert_float(absf(crown.rotation.z)).is_greater(0.0)
	scene.apply_wilt(0, false)
	assert_float(crown.rotation.z).is_equal_approx(0.0, 0.0001)

func test_generated_sections_share_exact_interface_rings() -> void:
	var scene = _fixture()
	for flower in [0]:
		scene.apply_style(flower, 5)
		var model = scene._model
		model.set_growth(4.0)
		var stems: int = model._profile["stems"].size()
		var sections: Array = model._sections.get_children()
		assert_int(sections.size()).is_equal(4 * stems)
		for stem in stems:
			var sides: int = model._interfaces[stem]["sides"]
			for index in 3:
				var previous: PackedVector3Array = sections[index * stems + stem].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var next: PackedVector3Array = sections[(index + 1) * stems + stem].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for side in sides:
					assert_vector(previous[previous.size() - (sides + 1) + side]).is_equal_approx(next[side], Vector3.ONE * 0.00001)
			var first: PackedVector3Array = sections[stem].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var spec: Dictionary = model._profile["stems"][stem]
			var offset := Vector3(float(spec["x"]), model._pivot.y, float(spec["z"]))
			for side in sides:
				var ring: Array = model._interfaces[stem]["levels"][1]["ring"][side]
				assert_vector(first[side]).is_equal_approx(offset + Vector3(float(ring[0]),0,float(ring[1])), Vector3.ONE * 0.00001)


func test_leaf_yellowing_uses_original_uv_texture_and_recovers() -> void:
	var scene = _fixture()
	for flower in 5:
		scene.apply_style(flower, 5)
		var model = scene._model
		assert_int(model._leaf_materials.size()).is_greater(0)
		var original: Texture2D = model._leaf_materials[0].get_shader_parameter("original_albedo")
		for level in [1, 2, 3]:
			scene.apply_wilt(level, false)
			for material in model._leaf_materials:
				assert_float(float(material.get_shader_parameter("dry"))).is_equal_approx(float(level) / 3.0, 0.0001)
		assert_object(model._leaf_materials[0].get_shader_parameter("original_albedo")).is_same(original)
		scene.apply_wilt(0, false)
		for material in model._leaf_materials:
			assert_float(float(material.get_shader_parameter("dry"))).is_equal_approx(0.0, 0.0001)


func test_cyclamen_loads_as_compact_rosette_with_leaf_wilt() -> void:
	var scene = _fixture()
	scene.apply_style(3, 5)
	var model = scene._model
	assert_int(model._leaf_materials.size()).is_greater(0)
	var height: float = model.plant_height()
	model.set_growth(4.0)
	assert_float(model.plant_height()).is_equal_approx(height, 0.0001)
	assert_int(model.section_count()).is_equal(0)
	scene.apply_wilt(3, false)
	for material in model._leaf_materials:
		assert_float(float(material.get_shader_parameter("dry"))).is_equal_approx(1.0, 0.0001)


func test_pot_and_flower_rotate_together() -> void:
	var scene = _fixture()
	scene.apply_style(0, 5)
	var pot: Node3D = scene.get_node("转台/花盆")
	var plant: Node3D = scene.get_node("转台/植株")
	assert_object(pot.get_parent()).is_same(plant.get_parent())
	var relative := pot.global_transform.affine_inverse() * plant.global_transform
	pot.get_parent().rotate_y(1.2)
	var after := pot.global_transform.affine_inverse() * plant.global_transform
	assert_vector(after.origin).is_equal_approx(relative.origin, Vector3.ONE * 0.0001)
	assert_vector(after.basis.x).is_equal_approx(relative.basis.x, Vector3.ONE * 0.0001)


func test_only_sunflower_grows_and_new_flowers_wilt_without_changing_height() -> void:
	var scene = _fixture()
	for flower in [1,2,3,4]:
		scene.apply_style(flower,5)
		var model = scene._model
		var height: float = model.plant_height()
		model.set_growth(200.0)
		assert_int(model.section_count()).is_equal(0)
		assert_float(model.plant_height()).is_equal_approx(height,0.0001)
		scene.apply_wilt(3,false)
		for material in model._leaf_materials:
			assert_float(float(material.get_shader_parameter("dry"))).is_equal_approx(1.0,0.0001)
			if flower in [3,4]:
				assert_float(float(material.get_shader_parameter("flower_bend"))).is_greater(0.0)
		scene.apply_wilt(0,false)
		for material in model._leaf_materials:
			assert_float(float(material.get_shader_parameter("dry"))).is_equal_approx(0.0,0.0001)


func test_buried_sunflower_stem_joins_are_continuous_in_world_space() -> void:
	var scene = _fixture()
	scene.apply_style(0,5)
	var model=scene._model
	assert_object(model._sections.get_parent()).is_same(model._crown.get_parent())
	assert_object(model._joints.get_parent()).is_same(model._crown.get_parent())
	for growth in [0.2,1.0,5.0,10.0]:
		for wilt in [0,3]:
			model.set_growth(growth)
			scene.apply_wilt(wilt,false)
			var first: MeshInstance3D=model._sections.get_child(0)
			var last: MeshInstance3D=model._sections.get_child(model._sections.get_child_count()-1)
			var lower: PackedVector3Array=first.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var upper: PackedVector3Array=last.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var sides: int=model._interfaces[0]["sides"]
			for side in sides:
				var ring: Array=model._interfaces[0]["levels"][1]["ring"][side]
				var offset=Vector3(float(ring[0]),0,float(ring[1]))
				var base_world: Vector3=model._crown.get_parent().to_global(model._pivot+offset)
				assert_vector(first.to_global(lower[side])).is_equal_approx(base_world,Vector3.ONE*0.00001)
				var crown_world: Vector3=model._crown.to_global(offset)
				assert_vector(last.to_global(upper[upper.size()-(sides+1)+side])).is_equal_approx(crown_world,Vector3.ONE*0.00001)
