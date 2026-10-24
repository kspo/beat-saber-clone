extends Node3D
class_name UIRaycast

@export var active := true
@export var ui_raycast_length := 3.0
var ui_mesh_length := 1.0
@export var controller: BeepSaberController

@onready var ui_raycast := $RayCastPosition/RayCast3D as RayCast3D
@onready var ui_raycast_mesh := $RayCastPosition/RayCastMesh as MeshInstance3D
@onready var ui_raycast_hitmarker := $RayCastPosition/RayCastHitMarker as MeshInstance3D

var is_colliding := false
var colliding_with: Object = null
var _blocked_frame := -1
var _wait_for_release := false

func reset_interaction() -> void:
	if is_instance_valid(colliding_with) and colliding_with is UIRaycastTarget:
		(colliding_with as UIRaycastTarget).ui_raycast_exit()
	colliding_with = null
	is_colliding = false
	_blocked_frame = Engine.get_physics_frames()
	_wait_for_release = true
	ui_raycast_hitmarker.hide()

func _input_is_blocked() -> bool:
	if Engine.get_physics_frames() <= _blocked_frame:
		return true
	if _wait_for_release:
		if not controller.trigger_pressed():
			_wait_for_release = false
		# Discard the release belonging to the previous screen as well.
		return true
	return false


func _update_raycasts() -> void:
	ui_raycast_hitmarker.visible = false
	if _input_is_blocked(): return
	
	ui_raycast_mesh.visible = true
	
	ui_raycast.force_raycast_update() # need to update here to get the current position; else the marker laggs behind
	
	var c := ui_raycast.get_collider()
	if c != colliding_with and is_instance_valid(colliding_with) and colliding_with is UIRaycastTarget:
		(colliding_with as UIRaycastTarget).ui_raycast_exit()
	colliding_with = c
	if c:
		if not c is UIRaycastTarget: return
		
		var pos := ui_raycast.get_collision_point()
		ui_raycast_hitmarker.visible = true
		ui_raycast_hitmarker.global_transform.origin = pos
		
		(c as UIRaycastTarget).ui_raycast_hit_event(pos, controller.trigger_just_pressed(), controller.trigger_just_released())
		is_colliding = true
	else:
		is_colliding = false

func _ready() -> void:
	ui_raycast.set_target_position(Vector3(0, 0, -ui_raycast_length))
	
	Settings.changed.connect(on_settings_changed)

	#setup the mesh
	update_mesh()
	
	ui_raycast_hitmarker.visible = false
	ui_raycast_mesh.visible = false
	
func on_settings_changed(key: StringName) -> void:
	match key:
		&"claws":
			update_mesh()

func update_mesh() -> void:
	ui_mesh_length = 0.3 if Settings.claws else 1.0
	(ui_raycast_mesh.mesh as BoxMesh).size.z = ui_mesh_length
	ui_raycast_mesh.position.z = -ui_mesh_length * 0.5

# we use the physics process here be in sync with the controller position
func _physics_process(_dt: float) -> void:
	if active and visible:
		_update_raycasts()
	elif is_instance_valid(colliding_with):
		reset_interaction()
