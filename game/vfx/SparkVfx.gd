extends RefCounted
class_name SparkVfx
## Shared builders for impact effects: hot streak sparks, slow embers and a
## brief additive flash. CPU particles only (Quest-safe, no GPU emitters).

const STREAK_SHADER := preload("res://game/vfx/SparkStreak.gdshader")
const FLASH_SHADER := preload("res://game/vfx/FlashSprite.gdshader")

static func fade_ramp(tint: Color, hot_until: float = 0.12) -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, hot_until, 0.55, 1.0])
	ramp.colors = PackedColorArray([Color.WHITE, tint.lerp(Color.WHITE, 0.35), tint * 0.55, Color.BLACK])
	return ramp

static func streak_mesh(length: float, width: float) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, length, width)
	var material := ShaderMaterial.new()
	material.shader = STREAK_SHADER
	material.set_shader_parameter(&"half_length", length * 0.5)
	mesh.material = material
	return mesh

static func flash_mesh(size: float) -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := ShaderMaterial.new()
	material.shader = FLASH_SHADER
	mesh.material = material
	return mesh

static func shrink_curve(hold: float = 0.45) -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(hold, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	return curve

static func configure_burst(p: CPUParticles3D, amount: int, lifetime: float) -> void:
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.4
	p.local_coords = false
	p.fixed_fps = 60
	p.layers = 3
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Fast, long, decelerating streaks.
static func make_streaks(amount: int, spread: float, v_min: float, v_max: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	configure_burst(p, amount, 0.34)
	p.mesh = streak_mesh(0.16, 0.009)
	p.direction = Vector3(0, -1, 0)
	p.spread = spread
	p.gravity = Vector3(0, -2.0, 0)
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.damping_min = 6.0
	p.damping_max = 12.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.15
	p.scale_amount_curve = shrink_curve()
	p.particle_flag_align_y = true
	return p

## Slow glowing embers that drift and fall after the impact.
static func make_embers(amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	configure_burst(p, amount, 0.9)
	p.mesh = streak_mesh(0.022, 0.009)
	p.direction = Vector3(0, -1, 0)
	p.spread = 180.0
	p.gravity = Vector3(0, -1.6, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.6
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.scale_amount_curve = shrink_curve(0.7)
	p.particle_flag_align_y = true
	return p

## A single expanding additive flash at the impact point.
static func make_flash(size: float, lifetime: float = 0.13) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	configure_burst(p, 1, lifetime)
	p.randomness = 0.0
	p.mesh = flash_mesh(size)
	p.spread = 0.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(0.35, 1.0))
	grow.add_point(Vector2(1.0, 1.25))
	p.scale_amount_curve = grow
	return p

static func set_tint(p: CPUParticles3D, tint: Color, hot_until: float = 0.12) -> void:
	p.color = Color.WHITE
	p.color_ramp = fade_ramp(tint, hot_until)
