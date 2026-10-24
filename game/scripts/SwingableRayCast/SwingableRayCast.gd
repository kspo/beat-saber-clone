extends RayCast3D
class_name SwingableRayCast

signal area_collided(area: Area3D)
@export_range(2, 32) var num_collision_raycasts: int = 8
const MIN_SWEPT_LENGTH_SQUARED := 0.001 * 0.001
var core_ray_collision_count := 0
var aux_ray_collision_count := 0
var adjust_segments := true
var last_query_count := 0
var last_cost_usec := 0
var _casts_enabled := false
var _prev_ray_positions: Array[Vector3] = []
var _rays: Array[RayCast3D] = []
var _emitted_ids: Dictionary = {}

func _ready() -> void:
	# Clock -100, controller -80, notes -50, saber -40, sweeps -30.
	process_physics_priority = -30
	_casts_enabled = enabled
	enabled = false
	for i in num_collision_raycasts:
		var ray := RayCast3D.new()
		ray.collision_mask = collision_mask
		ray.collide_with_areas = collide_with_areas
		ray.collide_with_bodies = collide_with_bodies
		# Manual queries only; avoid another automatic physics query per ray.
		ray.enabled = false
		add_child(ray)
		_rays.append(ray)
		_prev_ray_positions.append(Vector3.ZERO)
	reset_positions()
	$debug_ball.queue_free()

func _set_collision_mask_value(bit: int, value: bool) -> void:
	set_collision_mask_value(bit, value)
	for ray in _rays: ray.set_collision_mask_value(bit, value)

func reset_counters() -> void:
	core_ray_collision_count = 0
	aux_ray_collision_count = 0

func set_raycasts_enabled(value: bool) -> void:
	_casts_enabled = value
	enabled = false
	if value: reset_positions()
	else:
		last_query_count = 0
		last_cost_usec = 0

func _update_element_positions() -> void:
	for i in _rays.size():
		# Positions are local to this ray, not its parent; do not apply its offset twice.
		_rays[i].position = target_position * float(i) / float(_rays.size() - 1)

func _report_collision(collider: Object, core: bool) -> void:
	if not collider is Area3D: return
	var area := collider as Area3D
	var id := area.get_parent().get_instance_id()
	if _emitted_ids.has(id): return
	_emitted_ids[id] = true
	if core: core_ray_collision_count += 1
	else: aux_ray_collision_count += 1
	area_collided.emit(area)

func _physics_process(_delta: float) -> void:
	last_query_count = 0
	last_cost_usec = 0
	if not _casts_enabled: return
	var started := Time.get_ticks_usec()
	_emitted_ids.clear()
	force_raycast_update()
	last_query_count += 1
	_report_collision(get_collider(), true)
	_update_element_positions()
	for i in _rays.size():
		var ray := _rays[i]
		ray.target_position = ray.to_local(_prev_ray_positions[i])
		if ray.target_position.length_squared() > MIN_SWEPT_LENGTH_SQUARED:
			ray.force_raycast_update()
			last_query_count += 1
			_report_collision(ray.get_collider(), false)
		_prev_ray_positions[i] = ray.global_position
	last_cost_usec = Time.get_ticks_usec() - started

func reset_positions() -> void:
	_update_element_positions()
	for i in _rays.size(): _prev_ray_positions[i] = _rays[i].global_position

func _on_SwingableRayCast_tree_entered() -> void:
	pass
