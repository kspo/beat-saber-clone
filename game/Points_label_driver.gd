extends Node3D
class_name PointsLabelDriver

const POOL_SIZE := 24
var points_label: Array[Node3D] = []
var current_point_label := 0
var last_combo := 0
var combo_mesh: MeshInstance3D
var combo_scale := Vector3.ONE
var pulse: Tween

func _ready() -> void:
	var scene := preload("res://game/points_label.tscn")
	for i in range(POOL_SIZE):
		var instance := scene.instantiate() as Node3D
		points_label.append(instance)
		add_child(instance)
	combo_mesh = get_parent().get_node_or_null("Multiplier_Label") as MeshInstance3D
	if combo_mesh:
		combo_scale = combo_mesh.scale
		combo_mesh.mesh = combo_mesh.mesh.duplicate()
		var font := FontVariation.new()
		font.base_font = preload("res://OQ_Toolkit/OQ_UI2D/theme/Roboto-Medium.ttf")
		font.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.24, 1), Vector2.ZERO)
		(combo_mesh.mesh as TextMesh).font = font
	Scoreboard.score_changed.connect(_combo_changed)

func _combo_changed() -> void:
	var combo := Scoreboard.combo
	if combo == last_combo:
		return
	if combo_mesh:
		if pulse and pulse.is_valid():
			pulse.kill()
		combo_mesh.scale = combo_scale
		pulse = create_tween()
		pulse.tween_property(combo_mesh, "scale", combo_scale * 1.12, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse.tween_property(combo_mesh, "scale", combo_scale, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if combo > last_combo and combo >= 25 and combo % 25 == 0:
		# Separate from hit numbers and below the central note lanes.
		_emit(Vector3(0, 0.72, -3.2), 0.0, "%d COMBO" % combo, Color(1.0, 0.78, 0.30))
	last_combo = combo

func show_points(at: Vector3, lane_rotation: float, value: String) -> void:
	var failed := not value.is_valid_int()
	var text := "×" if value == "x" else value
	var color := Color(1.0, 0.26, 0.38) if failed else Color(0.86, 0.97, 1.0)
	if value.is_valid_int() and int(value) >= 110:
		color = Color(0.30, 1.0, 0.88)
	# Misses originate behind the player. Bring their feedback into view.
	var local := at.rotated(Vector3.UP, lane_rotation)
	local.z = minf(local.z, -1.8)
	_emit(local.rotated(Vector3.UP, -lane_rotation), lane_rotation, text, color)

func _emit(at: Vector3, lane_rotation: float, value: String, color: Color) -> void:
	points_label[current_point_label].show_points(at, lane_rotation, value, color)
	current_point_label = (current_point_label + 1) % POOL_SIZE
