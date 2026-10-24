extends RefCounted
class_name StandardScoring

const RULESET := "standard115-v1"
var multiplier := 1
var progress := 0
var combo := 0

func hit() -> int:
	combo += 1
	if multiplier < 8:
		progress += 1
		if progress >= multiplier * 2:
			multiplier *= 2
			progress = 0
	return multiplier

func miss() -> void:
	multiplier = maxi(1, multiplier / 2)
	progress = 0
	combo = 0

static func cut_score(before: float, after: float, distance: float) -> int:
	return roundi(clampf(before / 100.0, 0, 1) * 70) + roundi(clampf(after / 60.0, 0, 1) * 30) + roundi(clampf(1 - absf(distance) / 0.15, 0, 1) * 15)

static func max_score(count: int) -> int:
	var rules := StandardScoring.new()
	var total := 0
	for i in count:
		total += 115 * rules.hit()
	return total
