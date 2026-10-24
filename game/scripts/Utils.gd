extends Node

static func get_str(dict: Dictionary, key: String, default: String, platform_defaults: Dictionary = {}) -> String:
	if dict.has(key) and dict[key] is String:
		@warning_ignore("unsafe_cast")
		return dict[key] as String
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_bool(dict: Dictionary, key: String, default: bool, platform_defaults: Dictionary = {}) -> bool:
	if dict.has(key) and dict[key] is bool:
		@warning_ignore("unsafe_cast")
		return dict[key] as bool
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_float(dict: Dictionary, key: String, default: float, platform_defaults: Dictionary = {}) -> float:
	if dict.has(key) and (dict[key] is float or dict[key] is int):
		@warning_ignore("unsafe_cast")
		return dict[key] as float
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_array(dict: Dictionary, key: String, default: Array, platform_defaults: Dictionary = {}) -> Array:
	if dict.has(key) and dict[key] is Array:
		@warning_ignore("unsafe_cast")
		return dict[key] as Array
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default

static func get_dict(dict: Dictionary, key: String, default: Dictionary, platform_defaults: Dictionary = {}) -> Dictionary:
	if dict.has(key) and dict[key] is Dictionary:
		@warning_ignore("unsafe_cast")
		return dict[key] as Dictionary
	if OS.get_name() in platform_defaults.keys():
		return platform_defaults[OS.get_name()]
	return default
	
static func ends_in(name: String, exts: Array) -> bool:
	for ext in exts:
		if name.to_lower().ends_with(ext.to_lower()):
			return true
	return false

static func unzip(zip_file: String, destination: String) -> Error:
	var reader := ZIPReader.new()
	var result := reader.open(zip_file)
	if result != OK:
		return result
	var names := reader.get_files()
	for name in names:
		if not MapValidator.safe_relative_file(name):
			reader.close()
			return ERR_INVALID_DATA
	for name in names:
		var path := destination.path_join(name)
		if name.ends_with("/"):
			result = DirAccess.make_dir_recursive_absolute(path)
		else:
			result = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			if result == OK:
				var file := FileAccess.open(path, FileAccess.WRITE)
				if file == null:
					result = FileAccess.get_open_error()
				else:
					file.store_buffer(reader.read_file(name))
					result = file.get_error()
					file.close()
		if result != OK:
			reader.close()
			return result
	reader.close()
	return OK

static func remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for file in dir.get_files():
		dir.remove(file)
	for child in dir.get_directories():
		remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)

static func file_exists(base: String, file: String) -> bool:
	if DirAccess.dir_exists_absolute(base):
		var path : String
		if base.ends_with("/"):
			path = base + file
		else:
			path = base + "/" + file
		return FileAccess.file_exists(path)
	elif base.to_lower().ends_with(".zip") and FileAccess.file_exists(base):
		var zreader := ZIPReader.new()
		if zreader.open(base) == OK:
			var exists := zreader.file_exists(file)
			zreader.close()
			return exists
	return false
			
static func read_binary_file(base: String, file: String) -> PackedByteArray:
	if DirAccess.dir_exists_absolute(base):
		var path : String
		if base.ends_with("/"):
			path = base + file
		else:
			path = base + "/" + file
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_bytes(path)
	else:
			var zreader := ZIPReader.new()
			if zreader.open(base) == OK:
				var data := zreader.read_file(file)
				zreader.close()
				return data
	return PackedByteArray()
	
static func binary_to_json(data: PackedByteArray) -> Dictionary:
	if len(data) == 0:
		return {}
	else:
		var parser := JSON.new()
		if parser.parse(data.get_string_from_utf8()) != OK: return {}
		return parser.data if parser.data is Dictionary else {}
	
# Each parser owns its Thread; avoid a shared mutable registry across worker threads.
static var fake_thread_finished = {}

static func custom_thread_wait_to_finish(thread: Thread):
	if OS.get_name() == &"Web":
		var result = fake_thread_finished.get(thread)
		fake_thread_finished.erase(thread)
		return result
	return thread.wait_to_finish() if thread.is_started() else null

static func custom_thread_call(thread: Thread, function: Callable, params := []):
	if OS.get_name() == &"Web":
		fake_thread_finished[thread] = function.callv(params)
		return OK
	return thread.start(function.bindv(params))

static func precise_measurement(x : int) -> float:
	if x < 1000:
		return x
	else:
		return (x-1000.)/1000.

static func precise_angle_rad(direction: float, offset: float) -> float:
	var angle : float
	if direction < 1000:
		angle = Constants.CUBE_ROTATIONS[direction]
	else:
		angle = direction - 1000
	angle += offset * (PI/180.)
	if angle < 0:
		angle += TAU
	elif angle >= TAU:
		angle -= TAU
	if Settings.flip & Constants.FLIP_VERTICAL:
		angle = PI - angle
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		angle = -angle
		if angle < 0:
			angle += TAU
	if direction == 8:
		angle += Constants.DIRECTION8_OFFSET
	return angle

static func rotation_unit_vector(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))

static func close_angle(angle1: float, angle2: float) -> bool:
	return abs(angle1-angle2)<1e-5
	
static func update_bus_speed(bus_name: String) -> void:
	var speed := Settings.music_speed / 100.
	if (Settings.audio_master == 0. or 
			(bus_name == &"Music" and Settings.audio_music == 0.) or 
			(bus_name == &"MusicPreview" and Settings.audio_music == 0.)):
		# ignore when silent
		speed = 1.
	
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		vr.log_error("Unknown bus "+bus_name)
		return
	for i in range(AudioServer.get_bus_effect_count(bus)):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectPitchShift:
			if speed == 1.:
				AudioServer.remove_bus_effect(bus, i)
			else:
				(effect as AudioEffectPitchShift).pitch_scale = 1./Settings.music_speed
			return
	if speed == 1.:
		return
	var effect := AudioEffectPitchShift.new()
	effect.pitch_scale = 1./speed
	AudioServer.add_bus_effect(bus, effect)

static func adjust_vertical(y: int) -> int:
	if Settings.flip & Constants.FLIP_VERTICAL:
		return 2-y
	else:
		return y

static func adjust_horizontal(x: int) -> int:
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		return 3-x
	else:
		return x
		
static func adjust_color(c: int) -> int:
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		return 1-c
	else:
		return c
		
static func adjust_lane_rotation(theta: float) -> float:
	if Settings.flip & Constants.FLIP_HORIZONTAL:
		return -theta
	else:
		return theta
