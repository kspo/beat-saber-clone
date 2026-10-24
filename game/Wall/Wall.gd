extends PooledNode3D
class_name Wall

var despawn_z: float
var speed: float

var _origin := Vector3.ZERO
var _beat := 0.0

func _physics_process(_delta: float) -> void:
	if Scoreboard.paused or is_released(): return
	position = _origin + transform.basis.orthonormalized().z * (SongClock.beat() - _beat) * Map.distance_per_beat
	if position.dot(transform.basis.orthonormalized().z) > despawn_z:
		clear_from_track()

func clear_from_track() -> void:
	($WallMeshOrientation/WallArea/CollisionShape3D as CollisionShape3D).set_deferred("disabled", true)
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED
	if not is_released(): release()

func spawn(wall_info: ObstacleInfo, current_beat: float) -> void:
	transform = Transform3D.IDENTITY
	show()
	($WallMeshOrientation/WallArea/CollisionShape3D as CollisionShape3D).set_deferred("disabled", false)
	var mesh := $WallMeshOrientation/WallMesh as MeshInstance3D
	var m := mesh.mesh as BoxMesh
	var shape := ($WallMeshOrientation/WallArea/CollisionShape3D as CollisionShape3D).shape as BoxShape3D
	
	var x_size := wall_info.width * Settings.LANE_DISTANCE_X
	var y_size := wall_info.height * Constants.LANE_DISTANCE_Y
	var z_size := wall_info.duration * Map.distance_per_beat
	var depth := z_size * 0.5
	m.size.x = x_size
	shape.size.x = x_size
	m.size.y = y_size
	shape.size.y = y_size
	m.size.z = z_size
	shape.size.z = z_size
	despawn_z = Constants.MISS_Z + depth
	(mesh.material_override as ShaderMaterial).set_shader_parameter(&"size", Vector3(x_size, y_size, z_size))
	
	var x := (0.5 * wall_info.width + wall_info.line_index - 2) * Settings.LANE_DISTANCE_X
	var y := (0.5 * wall_info.height + wall_info.line_layer) * Constants.LANE_DISTANCE_Y
	var z := (current_beat - wall_info.beat) * Map.distance_per_beat - depth
	
	var c := cos(wall_info.rotation)
	var s := sin(wall_info.rotation)
	
	transform.origin.x = c * x - s * z
	transform.origin.y = y
	transform.origin.z = s * x + c * z
		
	rotation.y = -wall_info.rotation
	
	speed = Map.distance_per_beat * Map.current_info.beats_per_minute / 60.0
	($AnimationPlayer as AnimationPlayer).play(&"Spawn")

	_origin = position
	_beat = current_beat
	process_physics_priority = -50
