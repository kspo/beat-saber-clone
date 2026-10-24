extends Node3D
class_name SaberClash

const PULSE_INTERVAL := 0.12
var cooldown := 0.0
var touching := false
var sparks := CPUParticles3D.new()

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.75)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.009, 0.09, 0.009)
	mesh.material = material
	sparks.mesh = mesh
	sparks.emitting = false
	sparks.amount = 32
	sparks.lifetime = 0.28
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.local_coords = false
	sparks.fixed_fps = 36
	sparks.spread = 180.0
	sparks.gravity = Vector3(0, -2, 0)
	sparks.initial_velocity_min = 1.8
	sparks.initial_velocity_max = 3.8
	sparks.scale_amount_min = 0.65
	sparks.scale_amount_max = 1.0
	sparks.particle_flag_align_y = true
	sparks.layers = 3
	add_child(sparks)

func update_contact(left: LightSaber, right: LightSaber, delta: float, enabled: bool) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not enabled or not left.is_extended() or not right.is_extended():
		reset()
		return
	# Animated tips also handle short blades and extension/retraction.
	var points := Geometry3D.get_closest_points_between_segments(
		left.to_global(Vector3(0, 0.027, 0)), left.saber_visual.tip.global_position,
		right.to_global(Vector3(0, 0.027, 0)), right.saber_visual.tip.global_position)
	var radius := 0.015 * Settings.thickness
	if points[0].distance_squared_to(points[1]) > pow(2.0 * radius, 2):
		touching = false
		cooldown = 0.0
		return
	touching = true
	if cooldown > 0.0:
		return
	cooldown = PULSE_INTERVAL
	sparks.visible = true
	sparks.global_position = (points[0] + points[1]) * 0.5
	sparks.restart()
	sparks.emitting = true
	for controller in [left.controller, right.controller]:
		# Preserve stronger note-cut feedback already in progress.
		if not controller.is_simple_rumbling():
			controller.simple_rumble(0.5, 0.06)

func reset() -> void:
	touching = false
	cooldown = 0.0
	sparks.emitting = false
	sparks.visible = false
