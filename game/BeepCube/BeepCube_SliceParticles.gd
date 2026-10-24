extends Node3D
class_name BeepCubeSliceParticles

@onready var c1 := $Particles3D as CPUParticles3D

func _ready() -> void:
	c1.finished.connect(reset)
	reset()

func reset() -> void:
	visible = false
	c1.emitting = false
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED

func fire(at: Vector3 = Vector3.ZERO, velocity: Vector3 = Vector3.DOWN, tint: Color = Color.WHITE) -> void:
	# Independent of the note's disabled processing after a cut. Reused with it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN, velocity.normalized() if velocity.length_squared() > 0.001 else Vector3.DOWN)), at)
	c1.color = tint.lerp(Color.WHITE, 0.88)
	c1.speed_scale = 1.0
	visible = true
	set_process(true)
	c1.restart()
	c1.emitting = true

func _process(_delta: float) -> void:
	c1.speed_scale = 0.0 if Scoreboard.paused else 1.0
