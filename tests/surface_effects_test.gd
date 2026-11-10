extends GdUnitTestSuite

func test_surface_pick_local_feedback_and_water_cleanup() -> void:
 var scene = load("res://scenes/sunflower.tscn").instantiate()
 add_child(auto_free(scene))
 scene.apply_style(0,5)
 for i in 5: await get_tree().physics_frame
 var effects = scene._surface_effects
 var screen: Vector2 = scene._camera.unproject_position(scene._plant.to_global(Vector3(0,1.32,0)))
 var hit: Dictionary = effects.surface_hit(screen)
 assert_bool(hit.is_empty()).is_false()
 assert_bool(effects.tap_at(screen)).is_true()
 assert_bool(effects.tap_at(Vector2(-500,-500))).is_false()
 var basis: Basis = scene._plant.basis
 for i in 8: await get_tree().physics_frame
 assert_float(absf(float(scene._model._leaf_materials[0].get_shader_parameter("tap_amount")))).is_greater(0.00001)
 assert_vector(scene._plant.basis.x).is_equal(basis.x)
 effects._spawn_bead(hit.position,hit.normal)
 assert_int(effects._drops.size()).is_equal(1)
 for i in 8: await get_tree().physics_frame
 assert_int(effects._drops.size()).is_equal(1)
 for i in 130: await get_tree().physics_frame
 assert_int(effects._drops.size()).is_equal(0)
 assert_float(float(scene._model._leaf_materials[0].get_shader_parameter("tap_amount"))).is_equal_approx(0.0,0.0001)

func test_flower_proportion_stays_fixed_when_sunflower_grows() -> void:
 var scene = load("res://scenes/sunflower.tscn").instantiate()
 add_child(auto_free(scene))
 for flower in 5:
  for pot in [5,6,7]:
   scene.apply_style(flower,pot)
   var expected: float = float(scene.FLOWER_KINDS[flower]["height"])*float(scene.FLOWER_KINDS[flower]["pot_ratio"])*float(scene.POT_KINDS[pot].get("size_scale",1.0))
   var height: float = scene._pot.mesh.get_aabb().size.y*scene._pot.scale.y
   assert_float(height).is_equal_approx(expected,0.0001)
   var pot_scale: Vector3 = scene._pot.scale
   scene._model.set_growth(10.0)
   assert_vector(scene._pot.scale).is_equal_approx(pot_scale,Vector3.ONE*0.0001)


func test_water_recovers_gradually_and_refresh_does_not_skip_animation() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 add_child(auto_free(main))
 main._sunflower.apply_wilt(3,false)
 var model = main._sunflower._model
 main._apply_care("water",Vector2(100,100))
 assert_float(model._wilt).is_equal_approx(3.0,0.0001)
 await get_tree().create_timer(1.0).timeout
 assert_float(model._wilt).is_greater(0.0)
 assert_float(model._wilt).is_less(3.0)
 main._refresh()
 assert_float(model._wilt).is_greater(0.0)
 await get_tree().create_timer(2.4).timeout
 assert_float(model._wilt).is_equal_approx(0.0,0.0001)
 for material in model._leaf_materials:
  assert_float(float(material.get_shader_parameter("dry"))).is_equal_approx(0.0,0.0001)


func test_new_planter_soil_catches_a_falling_drop() -> void:
 var scene = load("res://scenes/sunflower.tscn").instantiate()
 add_child(auto_free(scene))
 for pot in [6,7]:
  scene.apply_style(0,pot)
  for i in 5: await get_tree().physics_frame
  var effects = scene._surface_effects
  var soil_y: float=scene._plant.global_position.y
  effects._spawn_bead(Vector3(0.12,soil_y+0.06,0.12),Vector3.ZERO)
  effects._drops[0].hold=0.0
  for i in 24: await get_tree().physics_frame
  assert_int(effects._drops.size()).is_equal(1)
  assert_bool(effects._drops[0].landed).is_true()
  assert_float(effects._drops[0].node.global_position.y).is_greater(soil_y-0.02)


func test_leaf_support_is_built_from_each_planter_and_rotates_with_it() -> void:
 var scene = load("res://scenes/sunflower.tscn").instantiate()
 add_child(auto_free(scene))
 for pot in [5,6,7]:
  scene.apply_style(4,pot)
  for i in 5: await get_tree().physics_frame
  for material in scene._model._leaf_materials:
   assert_bool(material.get_shader_parameter("planter_contact")).is_true()
   var texture: Texture2D=material.get_shader_parameter("planter_height")
   assert_int(texture.get_width()).is_equal(64)
   var support: float=texture.get_image().get_pixel(32,32).r
   assert_float(support).is_greater(0.0)
  scene.get_node("转台").rotate_y(0.5)
  for i in 2: await get_tree().physics_frame
  var contact: Transform3D=scene._model._leaf_materials[0].get_shader_parameter("planter_to_world")
  assert_vector(contact.origin).is_equal_approx(scene._pot.global_position,Vector3.ONE*0.0001)
  assert_vector(contact.basis.x).is_equal_approx(scene._pot.global_basis.x,Vector3.ONE*0.0001)

func test_elastic_impulse_follows_force_rebounds_and_settles() -> void:
 var scene=load("res://scenes/sunflower.tscn").instantiate()
 add_child(auto_free(scene))
 scene.apply_style(0,5)
 var effects=scene._surface_effects
 effects._sync_geometry()
 effects.push_at(scene._plant.to_global(Vector3(0.2,1.25,0)),Vector3.RIGHT)
 effects._step_impacts(1.0/120.0)
 assert_float(effects._impacts[0].offset.x).is_greater(0.0)
 assert_float(Vector3(effects._impacts[0].angular_velocity).length()).is_greater(0.0)
 var rebounded=false
 for i in 240:
  effects._step_impacts(1.0/120.0)
  if not effects._impacts.is_empty():
   var offset:Vector3=effects._impacts[0].offset
   assert_float(offset.length()).is_less_equal(0.04501)
   if offset.x<0.0:rebounded=true
 assert_bool(rebounded).is_true()
 assert_int(effects._impacts.size()).is_equal(0)
 for i in 6:effects.push_at(scene._plant.to_global(Vector3(float(i)*0.02,1.25,0)),Vector3.LEFT)
 assert_int(effects._impacts.size()).is_equal(4)
 effects._step_impacts(0.25)
 for impact in effects._impacts:assert_float(Vector3(impact.offset).length()).is_less_equal(0.04501)

func test_original_stem_and_added_sections_share_elastic_motion() -> void:
 var scene=load("res://scenes/sunflower.tscn").instantiate()
 add_child(auto_free(scene))
 scene.apply_style(0,5)
 var model=scene._model
 model.set_growth(5.0)
 var effects=scene._surface_effects
 effects._sync_geometry()
 effects.push_at(scene._plant.to_global(Vector3(0.0,0.72,0.0)),Vector3.RIGHT)
 effects._step_impacts(1.0/60.0)
 model.apply_impacts(effects._impacts)
 var leaf:ShaderMaterial=model._leaf_materials[0]
 var stalk:ShaderMaterial=model._skin_materials[0]
 var source_offsets:PackedVector3Array=leaf.get_shader_parameter("impact_offsets")
 var section_offsets:PackedVector3Array=stalk.get_shader_parameter("impact_offsets")
 assert_vector(source_offsets[0]).is_equal_approx(section_offsets[0],Vector3.ONE*0.000001)
 var source_frame:Transform3D=leaf.get_shader_parameter("plant_from_world")
 var section_frame:Transform3D=stalk.get_shader_parameter("plant_from_world")
 assert_vector(source_frame.origin).is_equal_approx(section_frame.origin,Vector3.ONE*0.000001)
