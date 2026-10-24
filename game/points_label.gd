extends Node3D

# Shared font atlas, independent labels: no mesh triangulation during a hit.
static var feedback_font: FontVariation
var label: Label3D
var age := 0.0
var lifetime := 0.85
var tint := Color.WHITE
var emphasis := 1.0

func _ready() -> void:
	$mesh_instance.hide()
	$AnimationPlayer.stop()
	if feedback_font == null:
		feedback_font = FontVariation.new()
		feedback_font.base_font = preload("res://OQ_Toolkit/OQ_UI2D/theme/Roboto-Medium.ttf")
		feedback_font.variation_embolden = 0.7
		feedback_font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.24, 1), Vector2.ZERO)
	label = Label3D.new()
	label.font = feedback_font
	label.font_size = 80
	label.pixel_size = 0.0024
	label.outline_size = 12
	label.outline_modulate = Color(0.015, 0.025, 0.06)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.shaded = false
	add_child(label)
	hide()
	set_process(false)

func show_points(at: Vector3, lane_rotation: float, value: String, color: Color) -> void:
	global_position = at
	rotation.y = -lane_rotation
	label.text = value
	tint = color
	age = 0.0
	emphasis = 1.12 if value == "×" or value.contains("COMBO") else 1.0
	lifetime = 1.05 if value.contains("COMBO") else 0.85
	show()
	set_process(true)
	_animate()

func _process(delta: float) -> void:
	# Finish even during menu transitions, so pooled labels never linger.
	age += delta
	if age >= lifetime:
		hide()
		set_process(false)
		return
	_animate()

func _animate() -> void:
	var size := 1.0
	if age < 0.10:
		size = lerpf(0.55, 1.20, 1.0 - pow(1.0 - age / 0.10, 3))
	elif age < 0.22:
		size = lerpf(1.20, 1.0, smoothstep(0.10, 0.22, age))
	var fade := smoothstep(lifetime * 0.55, lifetime, age)
	label.scale = Vector3.ONE * size * emphasis * (1.0 - 0.12 * fade)
	label.position = Vector3(0, 0.05 + 0.22 * age / lifetime, 0)
	label.modulate = Color(tint, 1.0 - fade)
	label.outline_modulate = Color(0.015, 0.025, 0.06, 1.0 - fade)
