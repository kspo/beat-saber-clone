extends RefCounted
class_name SwingHistory

# Fixed storage: no per-tick arrays or shifting the full history on expiry.
const CAPACITY := 256
var _times := PackedInt64Array()
var _directions := PackedVector3Array()
var _next := 0
var count := 0

func _init() -> void:
	_times.resize(CAPACITY)
	_directions.resize(CAPACITY)

func clear() -> void:
	_next = 0
	count = 0

func append(time: int, direction: Vector3) -> void:
	_times[_next] = time
	_directions[_next] = direction.normalized()
	_next = (_next + 1) % CAPACITY
	count = mini(count + 1, CAPACITY)

func angle_in_window(start: int, end: int, direction: Vector3) -> float:
	if direction.is_zero_approx(): return 0.0
	var pointing := direction.normalized()
	var minimum := 1.0
	for offset in count:
		var index := posmod(_next - 1 - offset, CAPACITY)
		if _times[index] < start: break
		if _times[index] <= end and not _directions[index].is_zero_approx():
			minimum = minf(minimum, pointing.dot(_directions[index]))
	return rad_to_deg(acos(clampf(minimum, -1, 1)))
