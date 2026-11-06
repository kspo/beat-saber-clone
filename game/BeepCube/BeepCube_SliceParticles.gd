extends Node3D
class_name BeepCubeSliceParticles
## Cut impact: directional streak spray (c1), radial starburst, slow embers and
## a short additive flash. All CPU particles, pooled with the note.

@onready var c1 := $Particles3D as CPUParticles3D
var burst := SparkVfx.make_streaks(20, 180.0, 1.5, 4.5)
var embers := SparkVfx.make_embers(12)
var flash := SparkVfx.make_flash(0.55)
var _emitters: Array[CPUParticles3D] = []

func _ready() -> void:
	# Directional spray follows the swing; restyle the scene emitter in place.
	c1.mesh = SparkVfx.streak_mesh(0.2, 0.009)
	c1.amount = 40
	c1.lifetime = 0.36
	c1.spread = 55.0
	c1.initial_velocity_min = 3.0
	c1.initial_velocity_max = 8.0
	c1.damping_min = 5.0
	c1.damping_max = 11.0
	c1.gravity = Vector3(0, -2.0, 0)
	c1.fixed_fps = 60
	c1.scale_amount_curve = SparkVfx.shrink_curve()
	for extra in [burst, embers, flash]:
		add_child(extra)
	_emitters = [c1, burst, embers, flash]
	c1.finished.connect(reset)
	reset()

func reset() -> void:
	visible = false
	for p in _emitters:
		p.emitting = false
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED

func fire(at: Vector3 = Vector3.ZERO, velocity: Vector3 = Vector3.DOWN, tint: Color = Color.WHITE) -> void:
	# Independent of the note's disabled processing after a cut. Reused with it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN, velocity.normalized() if velocity.length_squared() > 0.001 else Vector3.DOWN)), at)
	SparkVfx.set_tint(c1, tint)
	SparkVfx.set_tint(burst, tint)
	SparkVfx.set_tint(embers, tint, 0.05)
	SparkVfx.set_tint(flash, tint, 0.25)
	visible = true
	set_process(true)
	for p in _emitters:
		p.speed_scale = 1.0
		p.restart()
		p.emitting = true

func _process(_delta: float) -> void:
	var scale_value := 0.0 if Scoreboard.paused else 1.0
	for p in _emitters:
		p.speed_scale = scale_value
