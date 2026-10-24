extends Cuttable
class_name Bomb

@export var min_speed := 0.5
@onready var collision_shape := $Area3D/CollisionShape3D as CollisionShape3D

func set_collision_disabled(value: bool) -> void:
	collision_shape.disabled = value

@warning_ignore("unused_parameter")
func cut(saber: LightSaber, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	if resolved or Scoreboard.paused: return
	resolved = true
	Scoreboard.bad_cut(transform.origin, lane_rotation, "bomb")
	clear_from_track()

func on_miss() -> void:
	clear_from_track()

func spawn(info: BombInfo, current_beat: float) -> void:
	transform = Transform3D.IDENTITY
	show()
	speed = Map.distance_per_beat * Map.current_info.beats_per_minute / 60.0
	beat = info.beat
	
	var distance: float = info.beat - current_beat
	
	transform.origin.x = Settings.LANE_DISTANCE_X * float(info.line_index) + Settings.LANE_ZERO_X
	transform.origin.y = Constants.LANE_DISTANCE_Y * float(info.line_layer) + Constants.LAYER_ZERO_Y
	transform.origin.z = -distance * Map.distance_per_beat
	
	add_lane_rotation(info.rotation)
	
	var anim := $AnimationPlayer as AnimationPlayer
	var anim_speed := Map.current_difficulty.note_jump_movement_speed / 9.0
	anim.speed_scale = maxf(min_speed, anim_speed)
	anim.play(&"Spawn")

	begin_motion(current_beat)

func clear_from_track() -> void:
	resolved = true
	set_collision_disabled(true)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	if not is_released():
		release()
