extends Node3D
class_name DefaultSaber

var is_extended := false

@onready var _anim := $AnimationPlayer as AnimationPlayer
@onready var light_mesh := $LightSaber_Mesh as MeshInstance3D
@onready var _mat := light_mesh.material_override as ShaderMaterial
@onready var tip := $tip as Marker3D
@onready var tail := $tail as SaberTail
@onready var hitsound := $hitsound as AudioStreamPlayer3D

# Soft coloured halo around the blade; stands in for bloom, which is off on Quest.
var _glow := ShaderMaterial.new()
var _hilt := ShaderMaterial.new()

func _ready() -> void:
	_glow.shader = preload("res://game/NeonGlow.gdshader")
	_glow.set_shader_parameter(&"axis", Vector3(0, 1, 0))
	_glow.set_shader_parameter(&"glow_radius", 0.075)
	_glow.set_shader_parameter(&"expand", 8.0)
	_glow.set_shader_parameter(&"intensity", 1.1)
	_glow.set_shader_parameter(&"tightness", 3.2)
	_glow.set_shader_parameter(&"core_radius", 0.014)
	_glow.set_shader_parameter(&"core_intensity", 0.8)
	_glow.set_shader_parameter(&"color", _mat.get_shader_parameter(&"color"))
	light_mesh.material_overlay = _glow
	var hilt_mesh := $Hilt_Mesh as MeshInstance3D
	_hilt.shader = preload("res://game/sabers/default/SaberHilt.gdshader")
	_hilt.set_shader_parameter(&"half_height", (hilt_mesh.mesh as CylinderMesh).height * 0.5)
	_hilt.set_shader_parameter(&"color", _mat.get_shader_parameter(&"color"))
	hilt_mesh.material_override = _hilt
	quickhide()

func _process(_delta: float) -> void:
	# The blade length is animated on the mesh; keep the halo segment matched.
	var half := (light_mesh.mesh as CapsuleMesh).height * 0.5
	if not is_equal_approx(half, _glow_half_length):
		_glow_half_length = half
		_glow.set_shader_parameter(&"half_length", maxf(half, 0.001))
		_glow.set_shader_parameter(&"color", _mat.get_shader_parameter(&"color") if half > 0.01 else Color.BLACK)

var _glow_half_length := -1.0

func set_color(color: Color) -> void:
	_mat.set_shader_parameter(&"color", color)
	_glow.set_shader_parameter(&"color", color)
	_hilt.set_shader_parameter(&"color", color)
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
