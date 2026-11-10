extends Node3D

@export_enum("sunflower", "orchid") var plant_kind := "sunflower"

var turntable: Node3D
var dragging := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("c6d8e3"))
	turntable = Node3D.new()
	add_child(turntable)
	var pot := load("res://assets/tripo/cat-pot.glb").instantiate() as Node3D
	turntable.add_child(pot)
	var plant := load("res://assets/tripo/%s.glb" % plant_kind).instantiate() as Node3D
	turntable.add_child(plant)
	plant.scale = Vector3.ONE * (0.65 if plant_kind == "orchid" else 0.70)
	plant.position.y = 0.51
	var soil := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.27
	cylinder.bottom_radius = 0.27
	cylinder.height = 0.035
	soil.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("493124")
	material.roughness = 1.0
	soil.material_override = material
	soil.position.y = 0.52
	turntable.add_child(soil)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.4, 1.35, 4.4)
	camera.look_at(Vector3(0, 1.08, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.7
	camera.current = true
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.1
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("c6d8e3")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var ui := CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.text = ("新兰花" if plant_kind == "orchid" else "新向日葵") + " · 三花猫花盆\n拖动旋转查看"
	label.position = Vector2(20, 25)
	label.add_theme_color_override("font_color", Color("34434b"))
	ui.add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		turntable.rotate_y(event.relative.x * 0.01)
	elif event is InputEventScreenDrag:
		turntable.rotate_y(event.relative.x * 0.01)
