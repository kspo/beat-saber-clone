extends Node3D

# Render the actual gameplay materials without requiring a headset.
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080c18")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.70, 0.85)
	environment.ambient_light_energy = 0.22
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_color = Color(1, 0.95, 0.90)
	light.light_energy = 1.15
	var rim_light := DirectionalLight3D.new()
	add_child(rim_light)
	rim_light.rotation_degrees = Vector3(-15, 135, 0)
	rim_light.light_color = Color(0.48, 0.67, 1)
	rim_light.light_energy = 0.35
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.0, 4.1)
	camera.look_at(Vector3(0, 0.45, 0))
	camera.fov = 48
	camera.current = true
	for i in 4:
		var cube := preload("res://game/BeepCube/BeepCube.tscn").instantiate() as BeepCube
		add_child(cube)
		cube.position = Vector3(-0.95 + (i % 2) * 1.0, 0.2 + (i / 2) * 0.75, 0)
		cube.scale = Vector3.ONE * 1.2
		cube.mi.scale = Vector3.ONE
		cube.rotation_degrees.y = -12 if i % 2 == 0 else 12
		cube._mat.set_shader_parameter("color", Color("e52d45") if i % 2 == 0 else Color("168bff"))
		cube._mat.set_shader_parameter("is_dot", i >= 2)
		cube.set_physics_process(false)
	var bomb := preload("res://game/Bomb/BombMesh.tscn").instantiate() as Node3D
	add_child(bomb)
	bomb.position = Vector3(1.05, 0.65, 0)
	bomb.scale = Vector3.ONE * 0.22
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	(wall.mesh as BoxMesh).size = Vector3(0.65, 1.7, 0.3)
	wall.material_override = preload("res://game/Wall/Wall_readable.tres").duplicate()
	wall.material_override.set_shader_parameter("size", Vector3(0.65, 1.7, 0.3))
	add_child(wall)
	wall.position = Vector3(1.15, 0.6, -0.65)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(12, 12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("101522")
	mat.roughness = 0.65
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	floor_mesh.position.y = -0.25
	for i in 2:
		var saber := preload("res://game/sabers/default/default_saber.tscn").instantiate() as DefaultSaber
		add_child(saber)
		saber._anim.stop()
		saber.position = Vector3(-1.7 if i == 0 else 1.7, -0.1, 0)
		saber.rotation_degrees.z = -12 if i == 0 else 12
		saber.visible = true
		saber.set_color(Color("e52d45") if i == 0 else Color("168bff"))
		(saber.light_mesh.mesh as CapsuleMesh).height = 1.2
		(saber.light_mesh.mesh as CapsuleMesh).radius = 0.012
		saber.light_mesh.position.y = 0.65
	for frame in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var capture := get_viewport().get_texture().get_image()
		if capture != null and not capture.is_empty():
			capture.save_png(args[0])
		get_tree().quit()
