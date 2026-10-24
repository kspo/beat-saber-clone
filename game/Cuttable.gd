extends PooledNode3D
class_name Cuttable

var speed: float
var beat: float
var lane_rotation := 0.

# used to release the cube once both of it's cut pieces have died off
# Note: serves no purpose for bombs
var _piece_death_count := 0

# overridden by bombs and cubes
@warning_ignore("unused_parameter")
func set_collision_disabled(value: bool) -> void:
	return

# overriden by bombs and cubes
@warning_ignore("unused_parameter")
func cut(saber: LightSaber, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	return

# this too
func on_miss() -> void:
	return

func _on_cut_piece_died():
	_piece_death_count += 1
	if _piece_death_count >= 2:
		release()
		
func add_lane_rotation(angle):
	var c := cos(angle)
	var s := sin(angle)
	
	var x := transform.origin.x
	var z := transform.origin.z
	transform.origin.x = c * x - s * z
	transform.origin.z = s * x + c * z
	
	rotation.y = -angle
	
	lane_rotation = angle

var resolved := true
var _motion_origin := Vector3.ZERO
var _motion_direction := Vector3.FORWARD
var _spawn_beat := 0.0

func begin_motion(current_beat: float) -> void:
	resolved = false
	_spawn_beat = current_beat
	_motion_origin = position
	_motion_direction = transform.basis.orthonormalized().z
	set_collision_disabled(true)
	process_physics_priority = -50

func _physics_process(_delta: float) -> void:
	if Scoreboard.paused or resolved or not Map.current_info:
		return
	position = _motion_origin + _motion_direction * (SongClock.beat() - _spawn_beat) * Map.distance_per_beat
	var distance := position.dot(_motion_direction)
	if distance > -3.0:
		set_collision_disabled(false)
	if distance > Constants.MISS_Z:
		on_miss()
