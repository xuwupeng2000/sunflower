extends Node3D
## Same-source foliage-only juvenile, leafy plant, then bloom. No juvenile model or smoke.
@export_range(0.0, 1.0) var maturity := 0.0
@export var autoplay := true
var display: Node3D
var elapsed := 0.0
var stage := 0
var materials: Array[ShaderMaterial] = []
var caption: Label
var anchors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tripo/animated/sunflower-maturity-leaves.json"))

func _ready() -> void:
 display = load("res://scenes/sunflower.tscn").instantiate()
 add_child(display)
 display.apply_style(0, 5)
 display._zoom_level = 2
 display._model.visible = false
 var plant = load("res://assets/tripo/animated/sunflower-maturity.glb").instantiate()
 display._plant.add_child(plant)
 _prepare(plant, plant)
 var overlay := CanvasLayer.new()
 add_child(overlay)
 caption = Label.new()
 caption.position = Vector2(0, 14)
 caption.size = Vector2(500, 40)
 caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 caption.add_theme_font_size_override("font_size", 20)
 caption.add_theme_color_override("font_color", Color(0.22, 0.30, 0.35))
 overlay.add_child(caption)
 set_maturity(maturity)

func _prepare(node: Node, model: Node3D) -> void:
 if node is MeshInstance3D:
  for surface in node.mesh.get_surface_count():
   var original = node.mesh.surface_get_material(surface) as BaseMaterial3D
   if original == null: continue
   var material := ShaderMaterial.new()
   material.shader = load("res://shaders/sunflower_maturity.gdshader")
   material.set_shader_parameter("albedo_texture", original.albedo_texture)
   material.set_shader_parameter("rest_from_mesh", model.global_transform.affine_inverse()*node.global_transform)
   var kind := 2 if str(node.name).begins_with("Bloom") else (1 if str(node.name).begins_with("Leaf") else 0)
   material.set_shader_parameter("part_kind", kind)
   if anchors.has(str(node.name)):
    var p: Array = anchors[str(node.name)]
    material.set_shader_parameter("anchor", Vector3(p[0], p[1], p[2]))
   node.set_surface_override_material(surface, material)
   materials.append(material)
 for child in node.get_children(): _prepare(child, model)

func set_maturity(value: float) -> void:
 maturity = clampf(value, 0.0, 1.0)
 if display == null: return
 # Hold three readable stages, grow smoothly between them.
 var leaf_growth := smoothstep(0.18, 0.42, maturity)
 var bloom_growth := smoothstep(0.58, 0.88, maturity)
 var pose := 0.40+0.25*leaf_growth+0.35*bloom_growth
 for material in materials: material.set_shader_parameter("maturity", pose)
 display._frame_height(1.6, 1.6)
 stage = 0 if maturity < 0.42 else (1 if maturity < 0.68 else 2)
 caption.text = ["幼株 · 只有茎叶", "成长期 · 茎叶长成", "开花期"][stage]

func _process(delta: float) -> void:
 if autoplay:
  elapsed += delta
  set_maturity(clampf((fmod(elapsed, 11.0)-0.5)/9.5, 0.0, 1.0))
