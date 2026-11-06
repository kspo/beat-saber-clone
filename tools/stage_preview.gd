extends Node3D

# Player-eye render of the real gameplay stage (environment, lights, floor,
# event-driven lasers, notes, obstacle, sabers) without a headset.
# Usage: Godot --path . tools/stage_preview.tscn -- out.png [dark]
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var game_scene := load("res://game/BeepSaber_Game.tscn") as PackedScene
	var state := game_scene.get_state()
	var environment: Environment = null
	for i in state.get_node_count():
		if state.get_node_name(i) == &"WorldEnvironment":
			for p in state.get_node_property_count(i):
				if state.get_node_property_name(i, p) == &"environment":
					environment = (state.get_node_property_value(i, p) as Environment).duplicate()
	environment.glow_enabled = false
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.70, 0.85)
	environment.ambient_light_energy = 0.22
	var world := WorldEnvironment.new()
	world.environment = environment
	world.add_to_group(&"enviroment")
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.610865, -0.436332, 0)
	key.light_color = Color(1, 0.95, 0.90)
	key.light_energy = 1.15
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.261799, 2.356194, 0)
	rim.light_color = Color(0.48, 0.67, 1)
	rim.light_energy = 0.35
	add_child(rim)
	add_child(preload("res://game/floor.tscn").instantiate())
	var stage := preload("res://game/event_driver.tscn").instantiate() as EventDriver
	add_child(stage)
	Settings.background = "dynamic"
	stage.set_background()
	stage.set_all_on(Color("e52d45"), Color("168bff"))
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.7, 0.4)
	camera.look_at(Vector3(0, 1.1, -6))
	camera.fov = 80
	camera.current = true
	var colors := [Color("e52d45"), Color("168bff")]
	var layout := [
		[-0.9, 0.85, -2.6, 0, 0.0, false], [0.3, 0.85, -2.6, 1, 180.0, false],
		[-0.3, 1.45, -4.2, 0, 90.0, true], [0.9, 1.45, -4.2, 1, -45.0, false],
		[-0.9, 0.85, -6.5, 1, 0.0, false], [0.3, 1.45, -8.5, 0, 0.0, true],
	]
	for entry in layout:
		var cube := preload("res://game/BeepCube/BeepCube.tscn").instantiate() as BeepCube
		add_child(cube)
		cube.position = Vector3(entry[0], entry[1], entry[2])
		cube.mi.scale = Vector3.ONE
		cube.mi.rotation_degrees.z = entry[4]
		cube._mat.set_shader_parameter("color", colors[entry[3]])
		cube._mat.set_shader_parameter("is_dot", entry[5])
		cube.set_physics_process(false)
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	(wall.mesh as BoxMesh).size = Vector3(0.6, 2.2, 1.6)
	wall.material_override = preload("res://game/Wall/Wall_readable.tres").duplicate()
	wall.material_override.set_shader_parameter("size", Vector3(0.6, 2.2, 1.6))
	add_child(wall)
	wall.position = Vector3(1.9, 1.1, -7.0)
	var bomb := preload("res://game/Bomb/BombMesh.tscn").instantiate() as Node3D
	add_child(bomb)
	bomb.position = Vector3(-1.5, 1.4, -7.5)
	bomb.scale = Vector3.ONE * 0.22
	var sabers: Array[DefaultSaber] = []
	for i in 2:
		var saber := preload("res://game/sabers/default/default_saber.tscn").instantiate() as DefaultSaber
		add_child(saber)
		saber._anim.play(&"Show")
		saber._anim.seek(saber._anim.current_animation_length, true)
		saber.set_color(colors[i])
		saber.position = Vector3(-0.38 if i == 0 else 0.38, 0.95, -0.35)
		saber.rotation_degrees = Vector3(-55, 0, 28 if i == 0 else -28)
		sabers.append(saber)
	for frame in 8: await get_tree().process_frame
	# Sweep the right saber so its trail is visible, then cut a note mid-air.
	Scoreboard.paused = false # Effects freeze while the scoreboard is paused.
	var burst := preload("res://game/BeepCube/BeepCube_SliceParticles.tscn").instantiate() as BeepCubeSliceParticles
	add_child(burst)
	for frame in 10:
		sabers[1].rotation_degrees = Vector3(-55 + frame * 2.0, 0, -60 + frame * 7.0)
		if frame == 6:
			burst.fire(Vector3(-0.25, 1.45, -2.2), Vector3(-1, -0.3, 0), colors[1])
		await get_tree().physics_frame
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		get_viewport().get_texture().get_image().save_png(args[0])
		get_tree().quit()
