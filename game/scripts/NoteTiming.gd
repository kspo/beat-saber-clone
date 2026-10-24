extends RefCounted
class_name NoteTiming

static func half_jump_beats(bpm: float, njs: float, offset: float) -> float:
	var beats := 4.0
	while njs * 60.0 / bpm * beats > 18.0:
		beats *= 0.5
	return maxf(0.25, beats + offset)

static func distance_per_beat(bpm: float, njs: float) -> float:
	return njs * 60.0 / bpm

static func z_at(note_beat: float, current_beat: float, distance: float) -> float:
	return (current_beat - note_beat) * distance

# Half-open lifetime intervals; exits precede entrances at the same instant.
static func peak_live(intervals: Array) -> int:
	var events: Array = []
	for interval in intervals:
		events.append([interval[0], 1])
		events.append([interval[1], -1])
	events.sort_custom(func(a, b): return a[1] < b[1] if a[0] == b[0] else a[0] < b[0])
	var active := 0
	var peak := 0
	for event in events:
		active += event[1]
		peak = maxi(peak, active)
	return peak
