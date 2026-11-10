extends Node3D
## Picking, a local leaf/flower response, and surface beads that drain into the pot.
const PICK_LAYER = 1 << 19
const MAX_DROPS = 48
var display: Node3D
var _model_id = 0
var _pot_mesh_id = 0
var _impacts: Array[Dictionary] = []
var _wet_local = Vector3.ZERO
var _wet = 0.0
var _pouring = false
var _pour_screen = Vector2.ZERO
var _emit_clock = 0.0
var _drops: Array[Dictionary] = []
var _drop_mesh: SphereMesh
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
 _rng.randomize()
 _drop_mesh = SphereMesh.new()
 _drop_mesh.radius = 0.012
 _drop_mesh.height = 0.024
 _drop_mesh.radial_segments = 8
 _drop_mesh.rings = 4
 var mat = StandardMaterial3D.new()
 mat.albedo_color = Color(0.63,0.86,1.0,0.82)
 mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.roughness = 0.12
 mat.metallic_specular = 0.6
 _drop_mesh.material = mat

func _sync_geometry() -> void:
 if not is_instance_valid(display._model): return
 var model_id: int = display._model.get_instance_id()
 if model_id != _model_id:
  _model_id = model_id
  _impacts.clear()
  _wet = 0.0
  for drop in _drops: drop.node.queue_free()
  _drops.clear()
  _add_pickers(display._model)
 var pot_id: int = display._pot.mesh.get_instance_id()
 if pot_id != _pot_mesh_id:
  _pot_mesh_id = pot_id
  var old = display._pot.get_node_or_null("SurfacePicker")
  if old: old.free()
  _add_picker(display._pot)

func _add_pickers(node: Node) -> void:
 if node is MeshInstance3D: _add_picker(node)
 for child in node.get_children():
  if not child is StaticBody3D: _add_pickers(child)

func _add_picker(piece: MeshInstance3D) -> void:
 if piece.mesh == null or piece.get_node_or_null("SurfacePicker") != null: return
 var shape = piece.mesh.create_trimesh_shape()
 if shape == null: return
 if shape is ConcavePolygonShape3D: shape.backface_collision = true
 var body = StaticBody3D.new()
 body.name = "SurfacePicker"
 body.collision_layer = PICK_LAYER
 body.collision_mask = 0
 var collision = CollisionShape3D.new()
 collision.shape = shape
 body.add_child(collision)
 piece.add_child(body)

func surface_hit(screen: Vector2) -> Dictionary:
 var origin: Vector3 = display._camera.project_ray_origin(screen)
 var direction: Vector3 = display._camera.project_ray_normal(screen)
 var query = PhysicsRayQueryParameters3D.create(origin, origin+direction*100.0, PICK_LAYER)
 return get_world_3d().direct_space_state.intersect_ray(query)

func tap_at(screen: Vector2) -> bool:
 var hit = surface_hit(screen)
 if hit.is_empty(): return false
 if display._plant.is_ancestor_of(hit.collider):
  var direction: Vector3=display._camera.project_ray_normal(screen)
  push_at(hit.position,direction-hit.normal*0.25)
 else:
  var pot: Node3D = display._pot
  var rest = pot.rotation
  var tween = create_tween()
  for angle in [0.025,-0.018,0.008,0.0]:
   tween.tween_property(pot,"rotation:z",rest.z+angle,0.10)
 return true

func pour_at(screen: Vector2) -> void:
 _pour_screen = screen
 _pouring = true

func stop_pour() -> void:
 _pouring = false

func _physics_process(delta: float) -> void:
 if display == null or not is_instance_valid(display._model): return
 _sync_geometry()
 display._model.set_planter_contact(display._pot)
 _step_impacts(delta)
 display._model.apply_impacts(_impacts)
 _wet = maxf(0.0,_wet-delta/9.0)
 display._model.wet_at(display._plant.to_global(_wet_local),_wet)
 _emit_clock -= delta
 if _pouring and _emit_clock <= 0.0:
  _emit_clock = 0.045
  var hit = surface_hit(_pour_screen+Vector2(_rng.randf_range(-8,8),_rng.randf_range(-6,6)))
  var centre: Vector3
  if not hit.is_empty():
   centre=hit.position+Vector3.UP*0.28
  else:
   var camera: Camera3D=display._camera
   var depth: float=(display._plant.global_position-camera.global_position).dot(-camera.global_basis.z)
   centre=camera.project_position(_pour_screen,depth)
  for i in 2:
   if _drops.size() >= MAX_DROPS: break
   var source: Vector3 = centre+Vector3(_rng.randf_range(-0.015,0.015),_rng.randf_range(0.0,0.04),0.0)
   _spawn_bead(source,Vector3.ZERO)
   var drop: Dictionary = _drops[-1]
   drop.hold=0.0
   drop.velocity=Vector3(0.0,-0.65,0.0)
   drop.node.scale=Vector3(0.65,1.6,0.65)
 _update_drops(delta)

func _spawn_bead(point: Vector3, normal: Vector3, surface: Node3D = null) -> void:
 if _drops.size() >= MAX_DROPS: return
 var bead = MeshInstance3D.new()
 bead.mesh = _drop_mesh
 bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(bead)
 bead.global_position = point+normal*0.014
 _drops.append({"node":bead,"age":0.0,"hold":_rng.randf_range(0.22,0.50),"velocity":Vector3.ZERO,"normal":normal,"landed":false,"last_rid":surface.get_rid() if surface is CollisionObject3D else RID(),"contact_age":0.0,"contacts":0,"life":0.0})

func _update_drops(delta: float) -> void:
 for i in range(_drops.size()-1,-1,-1):
  var drop = _drops[i]
  var bead: MeshInstance3D = drop.node
  drop.age += delta
  drop.life += delta
  drop.contact_age += delta
  if drop.age < drop.hold:
   # A short run along the leaf's downhill tangent before detaching.
   var downhill = Vector3.DOWN-Vector3(drop.normal)*Vector3.DOWN.dot(drop.normal)
   bead.global_position += downhill*delta*0.035
  elif not drop.landed:
   drop.velocity += Vector3.DOWN*delta*2.4
   var next = bead.global_position+(Vector3(drop.velocity)+Vector3(drop.normal)*0.035)*delta
   var query = PhysicsRayQueryParameters3D.create(bead.global_position,next,PICK_LAYER)
   if drop.contact_age < drop.hold+0.16 and drop.last_rid.is_valid():
    query.exclude = [drop.last_rid]
   var hit = get_world_3d().direct_space_state.intersect_ray(query)
   if not hit.is_empty():
    bead.global_position=hit.position+hit.normal*0.014
    if display._plant.is_ancestor_of(hit.collider) and drop.contacts < 3:
     drop.contacts+=1
     bead.scale=Vector3.ONE
     _wet_local=display._plant.to_local(hit.position)
     _wet=1.0
     drop.velocity=Vector3.ZERO
     drop.normal=hit.normal
     drop.hold=_rng.randf_range(0.22,0.50) if drop.contacts==1 else _rng.randf_range(0.08,0.18)
     drop.age=0.0
     drop.contact_age=0.0
     drop.last_rid=hit.rid
    else:
     drop.landed=true
     bead.scale=Vector3(1.7,0.18,1.7)
     drop.age=drop.hold+0.9
   else:
    bead.global_position=next

  else:
   bead.scale *= maxf(0.0,1.0-delta*5.0)
  if drop.age > drop.hold+1.5 or drop.life > 2.0:
   bead.queue_free()
   _drops.remove_at(i)


func push_at(world_point: Vector3, world_direction: Vector3, strength: float = 1.0) -> void:
 var point: Vector3=display._plant.to_local(world_point)
 var direction: Vector3=(display._plant.global_basis.inverse()*world_direction).normalized()
 var ceiling: float=float(display._model._profile.get("leaf_ceiling",{"sunflower-new":0.98,"phalaenopsis-new":0.56,"clivia":0.93}.get(str(display.FLOWER_KINDS[display.flower_index]["scene"]).get_file().get_basename(),0.56)))
 var flower: bool=point.y>ceiling
 var pivot=Vector3(0.0,maxf(0.05,point.y-(0.24 if flower else 0.10)),0.0)
 var compliance=clampf(point.y/0.75,0.12,1.0)
 var impulse=direction*0.42*clampf(strength,0.0,1.5)*compliance
 if _impacts.size()>=4: _impacts.pop_front()
 _impacts.append({"center":point,"pivot":pivot,"offset":Vector3.ZERO,"velocity":impulse,"rotation":Vector3.ZERO,"angular_velocity":(point-pivot).cross(impulse)*4.0,"radius":0.38 if flower else 0.23,"stiffness":100.0 if flower else 165.0,"damping":8.5 if flower else 12.0,"age":0.0})

func _step_impacts(delta: float) -> void:
 # Semi-implicit Euler with bounded steps keeps fast taps and frame drops stable.
 var steps=maxi(1,ceili(delta*120.0))
 var dt=minf(delta,0.10)/float(steps)
 for i in range(_impacts.size()-1,-1,-1):
  var impact: Dictionary=_impacts[i]
  impact.age+=delta
  for step in steps:
   impact.velocity+=(-Vector3(impact.offset)*impact.stiffness-Vector3(impact.velocity)*impact.damping)*dt
   impact.offset+=Vector3(impact.velocity)*dt
   impact.angular_velocity+=(-Vector3(impact.rotation)*impact.stiffness*0.65-Vector3(impact.angular_velocity)*impact.damping)*dt
   impact.rotation+=Vector3(impact.angular_velocity)*dt
  impact.offset=Vector3(impact.offset).limit_length(0.045)
  impact.rotation=Vector3(impact.rotation).limit_length(0.10)
  if impact.age>=1.8 or (impact.age>0.30 and Vector3(impact.offset).length()+Vector3(impact.velocity).length()+Vector3(impact.rotation).length()+Vector3(impact.angular_velocity).length()<0.0005):
   _impacts.remove_at(i)
