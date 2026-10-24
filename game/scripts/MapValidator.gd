extends RefCounted
class_name MapValidator

static func validate(info: MapInfo, difficulty: DifficultyInfo, data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var version := str(data.get("version", data.get("_version", "")))
	var v2 := version.begins_with("2.")
	if not v2 and not version.begins_with("3."):
		errors.append("Only v2/v3 maps are supported in this build.")
	if info.version.begins_with("4."):
		errors.append("v4 song metadata is not supported yet.")
	if difficulty.characteristic != "Standard":
		errors.append("Only Standard maps are supported in this build.")
	if not is_finite(info.beats_per_minute) or info.beats_per_minute <= 0:
		errors.append("Invalid BPM.")
	if not is_finite(info.song_time_offset):
		errors.append("Invalid song offset.")
	if not is_finite(difficulty.note_jump_movement_speed) or difficulty.note_jump_movement_speed <= 0 or not is_finite(difficulty.note_jump_start_beat_offset):
		errors.append("Invalid note jump settings.")
	if not safe_relative_file(info.song_filename) or not safe_relative_file(difficulty.beatmap_filename):
		errors.append("Invalid song or map filename.")
	for custom in [info.custom_data, difficulty.custom_data, data.get("_customData", {}), data.get("customData", {})]:
		if custom is Dictionary:
			for key in ["_requirements", "requirements"]:
				if custom.has(key) and custom[key] != []:
					errors.append("This map requires unsupported mods.")
			for key in ["_BPMChanges", "BPMChanges", "bpmChanges"]:
				if custom.has(key) and custom[key] != []:
					errors.append("Variable BPM maps are not supported yet.")
	if data.get("bpmEvents", []) != []:
		errors.append("Variable BPM maps are not supported yet.")
	if data.get("rotationEvents", []) != []:
		errors.append("Rotation maps are not supported yet.")
	var arrays := ["_notes", "_obstacles", "_events", "_sliders"] if v2 else ["colorNotes", "bombNotes", "obstacles", "basicBeatmapEvents", "sliders", "burstSliders"]
	var required: String = "_notes" if v2 else "colorNotes"
	if not data.has(required):
		errors.append("Missing notes array.")
	for key in arrays:
		var entries: Variant = data.get(key, [])
		if not entries is Array:
			errors.append("Invalid array: " + key)
			continue
		for entry in entries:
			if not entry is Dictionary:
				errors.append("Invalid entry in " + key)
				break
			var time_key := ("_headTime" if key == "_sliders" else "_time") if v2 else "b"
			if not number(entry, time_key) or float(entry[time_key]) < 0:
				errors.append("Invalid beat in " + key)
				break
			if key in ["_events", "basicBeatmapEvents"]:
				var event_type: Variant = entry.get("_type" if v2 else "et", -1)
				if event_type in [100, 14, 15]:
					errors.append("BPM/rotation events are not supported yet.")
				continue
			var x := ("_headLineIndex" if key == "_sliders" else "_lineIndex") if v2 else "x"
			var y := ("_headLineLayer" if key == "_sliders" else "_lineLayer") if v2 else "y"
			if not integer_in(entry, x, 0, 3):
				errors.append("Invalid lane in " + key)
			if key != "_obstacles" and not integer_in(entry, y, 0, 2):
				errors.append("Invalid layer in " + key)
			if key in ["_notes", "colorNotes"]:
				var color_key := "_type" if v2 else "c"
				var color: Variant = entry.get(color_key, -1)
				if not integer_in(entry, color_key, 0, 3 if v2 else 1) or color == 2:
					errors.append("Invalid note color.")
				if color != 3 and not integer_in(entry, "_cutDirection" if v2 else "d", 0, 8):
					errors.append("Invalid cut direction.")
			if key in ["_obstacles", "obstacles"]:
				if not number(entry, "_duration" if v2 else "d") or float(entry.get("_duration" if v2 else "d", -1)) <= 0:
					errors.append("Invalid wall duration.")
				if not integer_in(entry, "_width" if v2 else "w", 1, 4):
					errors.append("Invalid wall width.")
				if v2 and not integer_in(entry, "_type", 0, 1):
					errors.append("Invalid wall type.")
				if not v2 and not integer_in(entry, "h", 1, 5):
					errors.append("Invalid wall height.")
			if key in ["_sliders", "sliders", "burstSliders"]:
				var tail := "_tailTime" if v2 else "tb"
				if not number(entry, tail) or float(entry.get(tail, -1)) < float(entry[time_key]):
					errors.append("Invalid arc/chain tail.")
				if not integer_in(entry, "_colorType" if v2 else "c", 0, 1) or not integer_in(entry, "_tailLineIndex" if v2 else "tx", 0, 3) or not integer_in(entry, "_tailLineLayer" if v2 else "ty", 0, 2):
					errors.append("Invalid arc/chain position or color.")
				if not integer_in(entry, "_headCutDirection" if v2 else "d", 0, 8):
					errors.append("Invalid arc/chain direction.")
				if key == "burstSliders" and (not integer_in(entry, "sc", 2, 128) or not number(entry, "s") or float(entry.get("s", 0)) <= 0):
					errors.append("Invalid chain slices.")
		if errors.size() > 16:
			break
	var experimental: bool = data.get("_sliders", []) != [] or data.get("sliders", []) != [] or data.get("burstSliders", []) != []
	return {"errors": errors, "experimental": experimental}

static func number(data: Dictionary, key: String) -> bool:
	var value: Variant = data.get(key)
	return (value is float or value is int) and is_finite(float(value))

static func integer_in(data: Dictionary, key: String, low: int, high: int) -> bool:
	if not number(data, key):
		return false
	var value := float(data[key])
	return value == floor(value) and value >= low and value <= high

static func safe_relative_file(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not path.contains(":") and not path.contains("\\") and not ".." in path.split("/")
