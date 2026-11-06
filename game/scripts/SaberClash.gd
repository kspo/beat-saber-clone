extends Node3D
class_name SaberClash

const PULSE_INTERVAL := 0.12
var cooldown := 0.0
var touching := false
# Hot, slightly warm white so blade contact reads apart from coloured cut sparks.
var sparks := SparkVfx.make_streaks(30, 180.0, 1.6, 4.5)
var flash := SparkVfx.make_flash(0.3, 0.1)

func _ready() -> void:
	SparkVfx.set_tint(sparks, Color(1.0, 0.82, 0.45), 0.2)
	SparkVfx.set_tint(flash, Color(1.0, 0.85, 0.6), 0.3)
	add_child(sparks)
	add_child(flash)

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
	flash.global_position = sparks.global_position
	flash.restart()
	flash.emitting = true
	for controller in [left.controller, right.controller]:
		# Preserve stronger note-cut feedback already in progress.
		if not controller.is_simple_rumbling():
			controller.simple_rumble(0.5, 0.06)

func reset() -> void:
	touching = false
	cooldown = 0.0
	sparks.emitting = false
	sparks.visible = false
	flash.emitting = false
