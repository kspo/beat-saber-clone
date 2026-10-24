extends Node
class_name FrameMetrics

var active := false
var file: FileAccess
var cpu_samples: Array[float] = []
var gpu_samples: Array[float] = []
var frame_samples: Array[float] = []
var sweep_samples: Array[float] = []
var physics_samples: Array[float] = []
var pending := ""
var frames := 0
var report_path := ""

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

func begin() -> void:
	finish()
	if DisplayServer.get_name() == "headless": return
	var directory := Constants.APPDATA_PATH.path_join("metrics")
	DirAccess.make_dir_recursive_absolute(directory)
	report_path = directory.path_join("session-%d" % Time.get_unix_time_from_system())
	file = FileAccess.open(report_path + ".csv", FileAccess.WRITE)
	if file == null: return
	file.store_line("frame,frame_ms,render_cpu_ms,render_gpu_ms,static_bytes,active_objects,pool_growth,physics_process_ms,saber_sweep_ms,saber_queries")
	cpu_samples.clear()
	gpu_samples.clear()
	frame_samples.clear()
	frames = 0
	sweep_samples.clear()
	physics_samples.clear()
	active = true

func _process(delta: float) -> void:
	if not active or Scoreboard.paused or SongClock.preroll: return
	var rid := get_viewport().get_viewport_rid()
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	frame_samples.append(delta * 1000)
	cpu_samples.append(cpu)
	gpu_samples.append(gpu)
	frames += 1
	var live := 0
	var growth := 0
	for pool in [GlobalReferences.cube_pool, GlobalReferences.link_pool, GlobalReferences.bomb_pool, GlobalReferences.wall_pool, GlobalReferences.arc_pool]:
		live += pool.total_count() - pool.free_count()
		growth += pool.runtime_growth
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var sweep_ms := 0.0
	var queries := 0
	var game := GlobalReferences.main_game_scene
	for saber in [game.left_saber, game.right_saber]:
		sweep_ms += saber._swing_cast.last_cost_usec / 1000.0
		queries += saber._swing_cast.last_query_count
	physics_samples.append(physics_ms)
	sweep_samples.append(sweep_ms)
	pending += "%d,%.4f,%.4f,%.4f,%d,%d,%d,%.4f,%.4f,%d\n" % [frames, delta * 1000, cpu, gpu, Performance.get_monitor(Performance.MEMORY_STATIC), live, growth, physics_ms, sweep_ms, queries]
	if frames % 120 == 0:
		file.store_string(pending)
		pending = ""

static func percentile99(values: Array[float]) -> float:
	if values.is_empty(): return 0
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * 0.99) - 1, 0, ordered.size() - 1)]

func finish() -> void:
	active = false
	if file == null: return
	file.store_string(pending)
	pending = ""
	file.close()
	file = null
	var summary := {
		"frames": frames, "target_hz": 72, "quality": Settings.quest_quality,
		"frame_p99_ms": percentile99(frame_samples),
		"render_cpu_p99_ms": percentile99(cpu_samples),
		"render_gpu_p99_ms": percentile99(gpu_samples),
		"physics_process_p99_ms": percentile99(physics_samples),
		"saber_sweep_p99_ms": percentile99(sweep_samples),
		"map": Map.current_info.song_name if Map.current_info else "",
		"device": OS.get_model_name(), "engine": Engine.get_version_info().string,
		"acceptance": "UNVERIFIED: render CPU excludes gameplay; runtime dropped-frame counters require device profiler. Zero GPU timing means unavailable."
	}
	var output := FileAccess.open(report_path + ".json", FileAccess.WRITE)
	if output:
		output.store_string(JSON.stringify(summary, "  "))
		output.close()

func _exit_tree() -> void:
	finish()
