extends Node3D
class_name EndScore

signal mainmenu
signal repeat

var animated_percent: float = 0.0
var _score_tween: Tween
@onready var raycast_area := $RaycastArea as Area3D
@onready var collision := $RaycastArea/CollisionShape3D as CollisionShape3D

func _ready() -> void:
	set_buttons_disabled(true)

func _show() -> void:
	raycast_area.collision_layer = CollisionLayerConstants.Ui_mask
	collision.disabled = false
	($Repeat as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	($MainMenu as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	show()

func _hide() -> void:
	_stop_score_animation()
	raycast_area.collision_layer = 0
	collision.disabled = true
	($Repeat as UIRaycastButton).collision_layer = 0
	($MainMenu as UIRaycastButton).collision_layer = 0
	hide()

func show_score(score: int, record: int, percent: float, song_string: String, is_full_combo: bool, is_new_record: bool) -> void:
	_stop_score_animation()
	var details_mesh := ($Details as MeshInstance3D).mesh as TextMesh
	var details_material := ($Details as MeshInstance3D).material_override as StandardMaterial3D
	var percent_indicator := $PercentIndicator as PercentIndicator
	var grade_label := $GradeViewport/GradeLabel as RichTextLabel
	var fc_label := $FCViewport/FCLabel as RichTextLabel
	var nr_label := $NRViewport/NRLabel as RichTextLabel
	var name_label := ($NameLabel as MeshInstance3D).mesh as TextMesh
	
	details_material.albedo_color = Color.TRANSPARENT
	grade_label.modulate = Color.TRANSPARENT
	fc_label.modulate = Color.TRANSPARENT
	nr_label.modulate = Color.TRANSPARENT
	percent_indicator.endscore()
	fc_label.visible = is_full_combo
	nr_label.visible = is_new_record
	name_label.text = song_string
	details_mesh.text = "Your Score:\n%d\n\nRecord:\n%d" % [score,record]
	
	if percent >= 0.98:
		grade_label.text = "[center][rainbow freq=0.5 sat=0.7 val=2]A+"
	elif percent >= 0.90:
		grade_label.text = "[center]A"
	elif percent >= 0.80:
		grade_label.text = "[center]B"
	elif percent >= 0.70:
		grade_label.text = "[center]C"
	elif percent >= 0.60:
		grade_label.text = "[center]D"
	elif percent >= 0.50:
		grade_label.text = "[center]E"
	elif percent >= 0.00:
		grade_label.text = "[center]F"
	else:
		grade_label.text = "[center]F-"
	
	_score_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if percent >= 0:
		_update_animated_percent(0.0)
		_score_tween.tween_method(_update_animated_percent, 0.0, percent, 3.0)
	_score_tween.set_ease(Tween.EASE_IN_OUT)
	_score_tween.tween_property(details_material, ^"albedo_color", Color.WHITE, 2).from(Color.TRANSPARENT)
	_score_tween.parallel().tween_property(grade_label, ^"modulate", Color.WHITE, 2).from(Color.TRANSPARENT)
	_score_tween.parallel().tween_property(fc_label, ^"modulate", Color.WHITE, 2).from(Color.TRANSPARENT)
	_score_tween.parallel().tween_property(nr_label, ^"modulate", Color.WHITE, 2).from(Color.TRANSPARENT)

func _update_animated_percent(value: float) -> void:
	animated_percent = value
	($PercentIndicator as PercentIndicator).update_percent(value)

func _stop_score_animation() -> void:
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = null

func _exit_tree() -> void:
	_stop_score_animation()

func set_buttons_disabled(disabled: bool) -> void:
	($Repeat/Collision as CollisionShape3D).disabled = disabled
	($MainMenu/Collision as CollisionShape3D).disabled = disabled

func _on_Repeat_button_up() -> void:
	repeat.emit()

func _on_MainMenu_button_up() -> void:
	set_buttons_disabled(true)
	mainmenu.emit()
