extends Node3D
class_name DefaultSaber

var is_extended := false

@onready var _anim := $AnimationPlayer as AnimationPlayer
@onready var light_mesh := $LightSaber_Mesh as MeshInstance3D
@onready var _mat := light_mesh.material_override as ShaderMaterial
@onready var tip := $tip as Marker3D
@onready var tail := $tail as SaberTail
@onready var hitsound := $hitsound as AudioStreamPlayer3D

func _ready() -> void:
	quickhide()

func set_color(color: Color) -> void:
	_mat.set_shader_parameter(&"color", color)
	tail.set_color(color)

func set_thickness(value: float) -> void:
	light_mesh.scale.x = value
	light_mesh.scale.z = value

func set_trail(enabled: bool = true) -> void:
	tail.visible = enabled

func _show() -> void:
	#if Settings.claws:
		#$Hilt_Mesh.rotation_degrees.x = 90
		#$Hilt_Mesh.position.y = .02
		#$Hilt_Mesh.position.z = -.02
		#rotation_degrees.x = -90
	#else:
		#$Hilt_Mesh.rotation_degrees.x = 0
		#$Hilt_Mesh.position.y = -.03
		#$Hilt_Mesh.position.z = 0
		#tip.rotation_degrees.x = 0
		#rotation_degrees.x = 0
	_anim.play(&"ShowShort" if Settings.claws else &"Show")
	is_extended = true
	
func _hide() -> void:
	#$Hilt_Mesh.show()
	_anim.play(&"HideShort" if Settings.claws else &"Hide")
	is_extended = false
	
func quickhide() -> void:
	#$Hilt_Mesh.show()
	_anim.play(&"QuickHide")
	is_extended = false

func hit(_time_offset: float) -> void:
	# Contact feedback must not wait for the chart beat or skip the sound's attack.
	hitsound.play(0.0)
