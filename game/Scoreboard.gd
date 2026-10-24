extends Node

signal score_changed()
signal points_awarded(position: Vector3, rotation: float, amount: String)

var points := 0
var combo := 0
var multiplier := 1
var in_wall := false
var right_notes := 0.0
var wrong_notes := 0.0
var full_combo := true
var paused := true
var last_in_wall_time := -1000.0
var max_points := 0
var record_eligible := false
var rules := StandardScoring.new()

func restart() -> void:
	rules = StandardScoring.new()
	points = 0
	combo = 0
	multiplier = 1
	right_notes = 0
	wrong_notes = 0
	full_combo = true
	in_wall = false
	last_in_wall_time = -1000
	record_eligible = false
	max_points = 0
	score_changed.emit()

func accuracy() -> float:
	return clampf(float(points) / max_points, 0, 1) if max_points > 0 else 0.0

func reserve_hit() -> int:
	var value := rules.hit()
	combo = rules.combo
	multiplier = rules.multiplier
	right_notes += 1
	score_changed.emit()
	return value

func reset_combo(wrong_note: bool) -> void:
	rules.miss()
	combo = rules.combo
	multiplier = rules.multiplier
	if wrong_note:
		wrong_notes += 1
	full_combo = false
	score_changed.emit()

func health(amount: float) -> void:
	if is_instance_valid(GlobalReferences.main_game_scene):
		GlobalReferences.main_game_scene.update_health(amount)

func enter_wall() -> void:
	if paused: return
	var time := SongClock.active_seconds
	if not in_wall:
		reset_combo(false)
		last_in_wall_time = time
		in_wall = true
	elif time - last_in_wall_time >= 0.1:
		health(Constants.HEALTH_OBSTACLE_PER_SECOND * (time - last_in_wall_time))
		last_in_wall_time = time

func exit_wall() -> void:
	in_wall = false
	last_in_wall_time = -1000

func add_points(position: Vector3, lane_rotation: float, amount: int, comment: String = "", hit_multiplier: int = -1) -> void:
	if hit_multiplier < 0:
		hit_multiplier = reserve_hit()
	points += amount * hit_multiplier
	health(Constants.HEALTH_HIT)
	points_awarded.emit(position, lane_rotation, str(amount) + (comment if Settings.explain else ""))
	score_changed.emit()

func add_swing_score(position: Vector3, lane_rotation: float, accuracy_points: float, before: float, after: float, hit_multiplier: int = -1) -> void:
	var distance := (1.0 - clampf(accuracy_points / 15.0, 0, 1)) * 0.15
	add_points(position, lane_rotation, StandardScoring.cut_score(before, after, distance), "", hit_multiplier)

func chain_link_cut(position: Vector3, lane_rotation: float) -> void:
	add_points(position, lane_rotation, Constants.SWING_CHAIN_LINK_SCORE)

func note_cut(saber: LightSaber, position: Vector3, lane_rotation: float, beat_accuracy: float, angle_accuracy: float, distance_accuracy: float, travel_factor: float, arc_head: bool, arc_tail: bool, chain_head: bool) -> void:
	if angle_accuracy <= 1e-10:
		bad_cut(position, lane_rotation, "bad angle")
		return
	var hit_multiplier := reserve_hit()
	if Settings.swing_scoring:
		if chain_head:
			saber.add_chain_head_score(position, lane_rotation, distance_accuracy * 15, hit_multiplier)
		else:
			saber.add_score(position, lane_rotation, distance_accuracy * 15, arc_head, arc_tail, hit_multiplier)
	else:
		var score := (beat_accuracy * 50 + angle_accuracy * 50 + distance_accuracy * 50) * (1 + travel_factor)
		add_points(position, lane_rotation, roundi(score), "", hit_multiplier)

func bad_cut(position: Vector3, lane_rotation: float, description: String) -> void:
	reset_combo(description != "bomb")
	var damage := Constants.HEALTH_BAD_CUT
	if description == "bomb":
		damage = Constants.HEALTH_BOMB
	elif description in ["wrong saber", "miss"]:
		damage = Constants.HEALTH_MISS
	health(damage)
	points_awarded.emit(position, lane_rotation, description if Settings.explain else "x")
