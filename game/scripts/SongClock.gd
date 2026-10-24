extends Node

# Audio position is in source seconds. Swing windows use unscaled active time.
var player: AudioStreamPlayer
var source_seconds := 0.0
var active_seconds := 0.0
var bpm := 120.0
var rate := 1.0
var offset_seconds := 0.0
var running := false
var paused := false
var preroll := false
var output_latency := 0.0
var revision := 0

func _ready() -> void:
	process_physics_priority = -100

func start(audio: AudioStreamPlayer, source_bpm: float, speed: float, offset: float, lead_seconds: float) -> void:
	stop()
	player = audio
	bpm = source_bpm
	rate = speed
	offset_seconds = offset
	active_seconds = 0.0
	output_latency = AudioServer.get_output_latency()
	source_seconds = -maxf(lead_seconds, output_latency * rate)
	preroll = true
	running = true
	paused = false
	player.pitch_scale = rate
	player.stream_paused = false

func stop() -> void:
	revision += 1
	running = false
	paused = false
	if is_instance_valid(player):
		player.stop()

func set_paused(value: bool) -> void:
	paused = value
	if is_instance_valid(player):
		player.stream_paused = value

func _physics_process(delta: float) -> void:
	if not running or paused:
		return
	active_seconds += delta
	if preroll:
		source_seconds += delta * rate
		# Start the device early enough that its first audible sample is at t=0.
		if source_seconds >= -output_latency * rate:
			player.play(0.0)
			preroll = false
	elif player.playing:
		observe_audio(player.get_playback_position(), AudioServer.get_time_since_last_mix(), output_latency)
	else:
		# Let final notes and follow-through finish after the audio ends.
		source_seconds += delta * rate

func observe_audio(position_seconds: float, since_mix: float, latency: float) -> void:
	source_seconds = maxf(source_seconds, position_seconds + (since_mix - latency) * rate)

func song_seconds() -> float:
	return source_seconds - offset_seconds

func beat() -> float:
	return song_seconds() * bpm / 60.0

func active_msec() -> int:
	return roundi(active_seconds * 1000.0)

func seconds_at_beat(value: float) -> float:
	return value * 60.0 / bpm
