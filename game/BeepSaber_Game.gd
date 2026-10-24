# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently
# This file contains the main game logic for the BeepSaber demo implementation
extends Node3D
class_name BeepSaber_Game

var version : String = ProjectSettings.get_setting("application/config/version", "0.0.0")
var gamestate_bootup := GameState.new()
var gamestate_mapcomplete := GameStateMapComplete.new()
var gamestate_mapselection := GameStateMapSelection.new()
var gamestate_newhighscore := GameStateNewHighScore.new()
var gamestate_paused := GameStatePaused.new()
var gamestate_playing := GameStatePlaying.new()
var gamestate_settings := GameStateSettings.new()
var gamestate: GameState = gamestate_bootup
var current_health := Constants.HEALTH_START

@onready var xr_origin := $XROrigin3D as XROrigin3D
@onready var left_controller := $XROrigin3D/LeftController as BeepSaberController
@onready var right_controller := $XROrigin3D/RightController as BeepSaberController
@onready var left_saber := $XROrigin3D/LeftController/LeftLightSaber as LightSaber
@onready var right_saber := $XROrigin3D/RightController/RightLightSaber as LightSaber
@onready var left_ui_raycast := $XROrigin3D/LeftController/LeftLightSaber/UIRaycast as UIRaycast
@onready var right_ui_raycast := $XROrigin3D/RightController/RightLightSaber/UIRaycast as UIRaycast
@onready var goggles_shader := ($XROrigin3D/XRCamera3D/VRGoggles as MeshInstance3D).material_override as ShaderMaterial
@onready var debug_info_label := $XROrigin3D/XRCamera3D/PlayerHead/DebugInfoLabel as MeshInstance3D

@onready var main_menu := $MainMenu_OQ_UI2DCanvas as OQ_UI2DCanvas
@onready var pause_menu := $PauseMenu_canvas as OQ_UI2DCanvas
@onready var pause_countdown := $Pause_countdown as OQ_UI2DLabel
@onready var settings_canvas := $Settings_canvas as OQ_UI2DCanvas
@onready var settings_panel := settings_canvas.ui_control as SettingsPanel
@onready var highscore_canvas := $Highscores_Canvas as OQ_UI2DCanvas
@onready var highscore_panel := highscore_canvas.ui_control as HighscorePanel
@onready var name_selector_canvas := $NameSelector_Canvas as OQ_UI2DCanvas
@onready var highscore_keyboard := $Keyboard_highscore as OQ_UI2DKeyboard
@onready var endscore := $EndScore as EndScore

@onready var points_label_driver := $Points_label_driver as PointsLabelDriver
@onready var event_driver := $event_driver as EventDriver

@onready var multiplier_label := $Multiplier_Label as MeshInstance3D
@onready var point_label := $Point_Label as MeshInstance3D
@onready var percent_indicator := $Percent_Indicator as PercentIndicator

@onready var map_source_dialogs := $MapSourceDialogs as Node3D
@onready var online_search_keyboard := $Keyboard_online_search as OQ_UI2DKeyboard


@onready var track := $Track as Node3D
@onready var standing_ground := $StandingGround as Floor

@onready var song_player := $SongPlayer as AudioStreamPlayer

@onready var menu := main_menu.ui_control as MainMenu


# There's an interesting issue where the AudioStreamPlayer's playback_position
# doesn't immediately return to 0.0 after restarting the song_player. This
# causes issues with restarting a map because the process_physics routine will
# execute for a times and attempt to process the map up to the playback_position
# prior to the AudioStreamPlayer restart. This bug can presents itself as notes
# persisting between map restarts.
# To remidy this issue, this flag is set to true when the map is restarted. The
# process_physics routine won't begin processing the map until after the
# AudioStreamPlayer has reset it's playback_position to zero. This flag is set
# to false once the AudioStreamPlayer reset is detected.
var _audio_synced_after_restart := false

var _in_wall := false

#prevents the song for starting from the start when pausing and unpausing
var pause_position := 0.0

var metrics := FrameMetrics.new()
var saber_clash := SaberClash.new()
var _ending := false
var _starting := false
var _resuming := false
var _audio_finished := false
var _finish_at := 0.0
var _hud_dirty := true
var _hud_elapsed := 0.0
var _debug_elapsed := 0.0
var _resume_remaining := 0.0
var _resume_revision := 0
var _application_focused := true
var _xr_focused := true
var _wall_contacts: Dictionary = {}

func show_map_error(message: String) -> void:
	_starting = false
	metrics.finish()
	SongClock.stop()
	Scoreboard.paused = true
	_clear_track()
	Map.reset_stacks()
	_transition_game_state(gamestate_mapselection)
	(menu.get_node("SongInfo_Label") as Label).text = message
	vr.log_warning(message)

func start_map(info: MapInfo, map_difficulty: DifficultyInfo) -> void:
	if _starting:
		return
	_cancel_resume()
	set_world_paused(false)
	event_driver.reset_session()
	_starting = true
	metrics.finish()
	SongClock.stop()
	var load_revision := SongClock.revision
	Scoreboard.paused = true
	_clear_track()
	left_saber.reset_session()
	right_saber.reset_session()
	if not MapValidator.safe_relative_file(map_difficulty.beatmap_filename):
		show_map_error("Cannot read map: invalid filename.")
		return
	var map_data := Utils.binary_to_json(Utils.read_binary_file(info.filepath, map_difficulty.beatmap_filename))
	if map_data.is_empty():
		show_map_error("Cannot read map: invalid or missing JSON.")
		return
	var validation := MapValidator.validate(info, map_difficulty, map_data)
	if not validation.errors.is_empty():
		show_map_error("Cannot play this map:\n" + "\n".join(validation.errors))
		return
	var audio_data := Utils.read_binary_file(info.filepath, info.song_filename)
	if audio_data.is_empty():
		show_map_error("Cannot play this map: audio file is missing.")
		return
	var stream := AudioStreamOggVorbis.load_from_buffer(audio_data)
	if stream == null:
		show_map_error("Cannot play this map: invalid Ogg audio.")
		return
	if not Map.load_beatmap(info, map_difficulty, map_data):
		show_map_error("Cannot play this map: unsupported format.")
		return
	Map.experimental = validation.experimental
	Map.source_note_count = Map.note_stack.size()
	prepare_map_pools()
	# Allow the scene tree/physics server to register preallocated objects before play.
	await get_tree().process_frame
	if SongClock.revision != load_revision:
		_starting = false
		return
	song_player.stream = stream
	_audio_finished = false
	_ending = false
	_resuming = false
	_in_wall = false
	_wall_contacts.clear()
	Scoreboard.restart()
	Scoreboard.record_eligible = not Map.experimental and Settings.swing_scoring
	Scoreboard.max_points = StandardScoring.max_score(Map.source_note_count)
	event_driver.set_background_texture()
	update_left_color(Map.color_left)
	update_right_color(Map.color_right)
	event_driver.set_background()
	apply_quest_profile()
	if Map.event_stack.is_empty():
		event_driver.set_all_on(Map.color_left, Map.color_right)
	else:
		event_driver.set_all_off()
	percent_indicator.set_health_mode(Settings.health_mode)
	current_health = Constants.HEALTH_START
	song_player.volume_db = 0.0
	var offset := info.song_time_offset + Settings.audio_offset_ms / 1000.0
	var lead := Map.look_ahead_beats * 60.0 / info.beats_per_minute + maxf(0, -offset)
	SongClock.start(song_player, info.beats_per_minute, Settings.music_speed / 100.0, offset, lead)
	metrics.begin()
	_starting = false
	_transition_game_state(gamestate_playing)
	_handle_focus_change()
	_display_points()

func apply_quest_profile() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X if Settings.quest_quality == 2 else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = [1.0, 0.85, 1.1][Settings.quest_quality]
	($WorldEnvironment as WorldEnvironment).environment.glow_enabled = false
	event_driver.set_background()

func prepare_map_pools() -> void:
	var padding := Map.look_ahead_beats
	var release_beats := Constants.MISS_Z / Map.distance_per_beat + 0.3 * Map.current_info.beats_per_minute / 60.0
	var intervals: Array = []
	for note in Map.note_stack:
		intervals.append([note.beat - padding, note.beat + release_beats])
	GlobalReferences.cube_pool.ensure_capacity(NoteTiming.peak_live(intervals) + 8)
	intervals.clear()
	for bomb in Map.bomb_stack:
		intervals.append([bomb.beat - padding, bomb.beat + release_beats])
	GlobalReferences.bomb_pool.ensure_capacity(NoteTiming.peak_live(intervals) + 4)
	intervals.clear()
	for wall in Map.obstacle_stack:
		intervals.append([wall.beat - padding, wall.beat + wall.duration + release_beats])
	GlobalReferences.wall_pool.ensure_capacity(NoteTiming.peak_live(intervals) + 4)
	intervals.clear()
	for arc in Map.arc_stack:
		intervals.append([arc.head_beat - padding, arc.tail_beat + release_beats])
	GlobalReferences.arc_pool.ensure_capacity(NoteTiming.peak_live(intervals) + 4)
	intervals.clear()
	for chain in Map.chain_stack:
		for i in maxi(0, chain.slice_count - 1):
			intervals.append([chain.head_beat - padding, chain.tail_beat + release_beats])
	GlobalReferences.link_pool.ensure_capacity(NoteTiming.peak_live(intervals) + 8)

func create_pool(scene_path: String) -> ScenePool:
	var pool := ScenePool.new()
	pool.scene = load(scene_path)
	pool.new_scene_instanced.connect(_on_ScenePool_new_scene_instanced)
	add_child(pool)
	return pool

func update_health(delta: float) -> void:
	if Settings.health_mode:
		current_health += delta
		if current_health > Constants.HEALTH_MAX:
			current_health = Constants.HEALTH_MAX
		percent_indicator.update_percent(current_health / Constants.HEALTH_MAX)
		if current_health <= 0:
			Scoreboard.record_eligible = false
			finish_map()
			
# This function will transitioning the game from it's current state into
# the provided 'next_state'.
func _transition_game_state(next_state: GameState) -> void:
	_reset_menu_input()
	gamestate = next_state
	gamestate._ready(self)
	print("SESSION_STATE: ", gamestate.get_script().resource_path)

func _reset_menu_input() -> void:
	for ray in [left_ui_raycast, right_ui_raycast]:
		if is_instance_valid(ray): ray.reset_interaction()

func open_song_browser() -> void:
	_reset_menu_input()
	main_menu._hide()
	menu.stop_preview()
	highscore_canvas._hide()
	highscore_keyboard._hide()
	show_MapSourceDialogs(false)
	map_source_dialogs.show()
	var canvas := $MapSourceDialogs/BeatSaver_Canvas as OQ_UI2DCanvas
	canvas.global_transform = main_menu.global_transform
	online_search_keyboard.global_transform = highscore_keyboard.global_transform
	(canvas.ui_control as BeatSaverPanel)._show()

func show_MapSourceDialogs(showing: bool = true) -> void:
	map_source_dialogs.visible = showing
	for c in map_source_dialogs.get_children():
		if c is OQ_UI2DCanvas:
			(c as OQ_UI2DCanvas)._hide()
	if showing:
		var first_dialog := map_source_dialogs.get_child(0)
		if first_dialog is OQ_UI2DCanvas:
			(first_dialog as OQ_UI2DCanvas)._show()

# call this method to submit a new highscore to the database
func _submit_highscore(player_name: String) -> void:
	if gamestate == gamestate_newhighscore:
		Highscores.add_highscore(
			Map.current_info,
			Map.current_difficulty.difficulty_rank,
			player_name,
			Scoreboard.points)
			
		_transition_game_state(gamestate_mapcomplete)

func _check_and_update_saber(controller: BeepSaberController, saber: LightSaber) -> void:
	# to allow extending/sheething the saber while not playing a song
	if ((not song_player.playing)
		and (controller.ax_just_pressed() or controller.by_just_pressed())
		and (not saber._anim.is_playing())):
		if (saber.is_extended()): saber._hide()
		else: saber._show()
		
	if _in_wall:
		Scoreboard.enter_wall()
	
	# check for saber rumble (only when extended and not already rumbling)
	# this check is necessary to not overwrite a rumble set from somewhere else
	# (in this case it can come from cutting cubes)
	if not controller.is_simple_rumbling(): 
		if _in_wall:
			# weak rumble on both controllers when player is inside wall
			controller.simple_rumble(0.3, 0.3)
		elif saber.has_overlapping_areas() or saber.has_overlapping_bodies():
			# strong rumble when saber is cutting into wall or other saber
			controller.simple_rumble(0.5, 0.1)



func _queue_hud_update() -> void:
	_hud_dirty = true

func _physics_process(_dt: float) -> void:
	if _audio_finished and not _ending and gamestate == gamestate_playing and SongClock.active_seconds >= _finish_at:
		finish_map()
	_hud_elapsed += _dt
	_debug_elapsed += _dt
	if _hud_dirty or _hud_elapsed >= 0.1:
		_display_points()
		_hud_dirty = false
		_hud_elapsed = 0.0
	if debug_info_label.visible and _debug_elapsed >= 0.25:
		_debug_elapsed = 0.0
		var dbg_text := "FPS: %d\nCube Pool: %d free of %d\nLink Pool: %d free of %d" % [
			Engine.get_frames_per_second(),
			GlobalReferences.cube_pool.free_count(), GlobalReferences.cube_pool.total_count(),
			GlobalReferences.link_pool.free_count(), GlobalReferences.link_pool.total_count()]
		(debug_info_label.mesh as TextMesh).text = dbg_text
	
	gamestate._physics_process(self)
	
	_check_and_update_saber(left_controller, left_saber)
	_check_and_update_saber(right_controller, right_saber)
	saber_clash.update_contact(left_saber, right_saber, _dt,
		_application_focused and _xr_focused and gamestate != gamestate_paused and not _starting)

func _enter_tree() -> void:
	GlobalReferences.main_game_scene = self
	
	@warning_ignore("return_value_discarded")
	Settings.changed.connect(on_settings_changed)

func _ready() -> void:
	add_child(metrics)
	add_child(saber_clash)
	# pre-allocate scenes in our scene pools
	GlobalReferences.cube_pool = $BeepCubePool
	GlobalReferences.link_pool = $ChainLinkPool
	GlobalReferences.bomb_pool = create_pool("res://game/Bomb/Bomb.tscn")
	GlobalReferences.wall_pool = create_pool("res://game/Wall/Wall.tscn")
	GlobalReferences.arc_pool = create_pool("res://game/Arc/Arc.tscn")
	GlobalReferences.cube_pool.presize(100)
	GlobalReferences.link_pool.presize(100)
	
	var xr_camera := $XROrigin3D/XRCamera3D as XRCamera3D
	vr.initialize(
		xr_origin,
		xr_camera,
		left_controller,
		right_controller
	)
	
	vr.pose_recentered.connect(recenter)
	if vr.inVR and vr.xr_interface:
		vr.xr_interface.connect("session_focussed", _set_xr_focus.bind(true))
		for signal_name in ["session_visible", "session_synchronized", "session_stopping", "session_loss_pending", "instance_exiting"]:
			vr.xr_interface.connect(signal_name, _set_xr_focus.bind(false))

	debug_info_label.visible = Settings.show_debug_info
	set_colors_from_settings()
	($WorldEnvironment as WorldEnvironment).environment.glow_enabled = false
	var note_environment := ($WorldEnvironment as WorldEnvironment).environment
	note_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	note_environment.ambient_light_color = Color(0.62, 0.70, 0.85)
	note_environment.ambient_light_energy = 0.22
	
	if not vr.inVR:
		xr_origin.add_child(preload("res://OQ_Toolkit/OQ_ARVROrigin/Feature_VRSimulator.tscn").instantiate())
	
	UI_AudioEngine.attach_children(highscore_keyboard)
	UI_AudioEngine.attach_children(online_search_keyboard)
	
	_transition_game_state(gamestate_mapselection)
	
	@warning_ignore("return_value_discarded")
	Scoreboard.score_changed.connect(_queue_hud_update)
	@warning_ignore("return_value_discarded")
	Scoreboard.points_awarded.connect(points_label_driver.show_points)
	
	#render common assets for a couple of frames to prevent performance issues when loading them mid game
	($pre_renderer as Node3D).visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	($pre_renderer as Node3D).queue_free()
	
	set_background_texture()
	
	recenter()

func set_background_texture() -> void:
	var environment : Environment = $WorldEnvironment.environment
	var panorama : PanoramaSkyMaterial = environment.sky.sky_material 
	panorama.panorama = load(Settings.background_texture)	
	
func on_settings_changed(key: StringName) -> void:
	# ensures proper initialization of tree for proper first frame setting loading
	await get_tree().process_frame
	match key:
		&"quest_quality":
			apply_quest_profile()
		&"left_handed":
			if Settings.left_handed:
				left_ui_raycast.active = true
				right_ui_raycast.active = false
			else:
				left_ui_raycast.active = false
				right_ui_raycast.active = true
		&"color_left":
			update_left_color(Settings.color_left)
		&"color_right":
			update_right_color(Settings.color_right)
		&"width":
			event_driver.set_background()
		&"background":
			event_driver.set_background()
		&"background_texture":
			set_background_texture()
			event_driver.set_background_texture()
		&"show_debug_info":
			debug_info_label.visible = Settings.show_debug_info
		&"glare":
			($WorldEnvironment as WorldEnvironment).environment.glow_enabled = false
		&"player_height_offset":
			xr_origin.transform.origin.y = Settings.player_height_offset

func set_colors_from_settings() -> void:
	update_left_color(Settings.color_left)
	update_right_color(Settings.color_right)
	event_driver.set_background()

func update_left_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	left_saber.set_color(color)
	Arc.left_material.set_shader_parameter(&"color", color)
	Arc.left_material_magnet.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"left_color", color)
	event_driver.update_left_color(color)
	standing_ground.update_left_color(color)

func update_right_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	right_saber.set_color(color)
	Arc.right_material.set_shader_parameter(&"color", color)
	Arc.right_material_magnet.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"right_color", color)
	event_driver.update_right_color(color)
	standing_ground.update_right_color(color)

func _clear_track() -> void:
	_wall_contacts.clear()
	_in_wall = false
	Scoreboard.exit_wall()
	song_player.volume_db = 0.0
	for c in track.get_children():
		if c.has_method("clear_from_track"):
			c.clear_from_track()
		else:
			track.remove_child(c)
			c.queue_free()

func _display_points() -> void:
	var hit_rate := Scoreboard.accuracy()

	var minutes = 0
	var seconds = 0
	if Map.current_info != null:
		var time_left = Map.current_info.get_length_seconds() - get_current_time()
		if time_left < 0:
			time_left = 0
		minutes = int(time_left) / 60
		seconds = int(time_left) % 60
	var display = "Score %6d\n%02d:%02d" % [Scoreboard.points,minutes,seconds]
	if (point_label.mesh as TextMesh).text != display:
		(point_label.mesh as TextMesh).text = display
	display = "x %d\nCombo %d" % [Scoreboard.multiplier, Scoreboard.combo]
	if (multiplier_label.mesh as TextMesh).text != display:
		(multiplier_label.mesh as TextMesh).text = display
	if not Settings.health_mode:
		percent_indicator.update_percent(hit_rate)

# accessor method for the player name selector UI element
func _name_selector() -> NameSelector:
	return name_selector_canvas.ui_control

func _on_PlayerHead_area_entered(area: Area3D) -> void:
	if area.is_in_group(&"wall") and SongClock.running:
		_wall_contacts[area.get_instance_id()] = true
		_in_wall = true
		song_player.volume_db = -15.0
		Scoreboard.enter_wall()

func _on_PlayerHead_area_exited(area: Area3D) -> void:
	if area.is_in_group(&"wall"):
		_wall_contacts.erase(area.get_instance_id())
		_in_wall = not _wall_contacts.is_empty()
		if not _in_wall:
			song_player.volume_db = 0.0
			Scoreboard.exit_wall()

func get_current_time() -> float:
	return SongClock.song_seconds()

# when the song ended we want to display the current score and
# the high score
func _on_song_ended() -> void:
	if _ending or not SongClock.running:
		return
	_audio_finished = true
	_finish_at = SongClock.active_seconds + maxf(0.25, (Map.current_info.last_beat + Constants.MISS_Z / Map.distance_per_beat - SongClock.beat()) * 60.0 / SongClock.bpm / SongClock.rate + 0.25)

func finish_map() -> void:
	if _ending:
		return
	_ending = true
	_cancel_resume()
	metrics.finish()
	left_saber.flush_scores()
	right_saber.flush_scores()
	Scoreboard.paused = true
	SongClock.stop()
	_clear_track()

	PlayCount.increment_play_count(Map.current_info,Map.current_difficulty.difficulty_rank)
	
	var new_record := false
	var highscore := Highscores.get_highscore(Map.current_info,Map.current_difficulty.difficulty_rank)
	if highscore == -1:
		# no highscores exist yet
		highscore = Scoreboard.points
	elif Scoreboard.points > highscore:
		# player's score is the new highscore!
		highscore = Scoreboard.points
		new_record = Scoreboard.record_eligible

	var current_percent : float
	if Settings.health_mode and current_health <= 0:
		current_percent = -1
	else:
		current_percent = Scoreboard.accuracy()
	endscore.show_score(
		Scoreboard.points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			Map.current_info.song_name + (" [Experimental - no records]" if Map.experimental else ""),
			Map.current_info.song_author_name,
			Map.current_difficulty.get_display_name(),
			Map.current_info.level_author_name],
		Scoreboard.full_combo,
		new_record
	)
	
	if Scoreboard.record_eligible and Highscores.is_new_highscore(Map.current_info,Map.current_difficulty.difficulty_rank,Scoreboard.points):
		_transition_game_state(gamestate_newhighscore)
	else:
		_transition_game_state(gamestate_mapcomplete)

func _restart_button() -> void:
	start_map(Map.current_info, Map.current_difficulty)
	endscore.visible = false
	pause_menu.visible = false

func _main_menu_button() -> void:
	_cancel_resume()
	set_world_paused(false)
	event_driver.reset_session()
	metrics.finish()
	SongClock.stop()
	Scoreboard.paused = true
	left_saber.reset_session()
	right_saber.reset_session()
	_resuming = false
	_clear_track()
	_transition_game_state(gamestate_mapselection)

func _cancel_resume() -> void:
	_resuming = false
	_resume_remaining = 0.0
	if is_instance_valid(pause_countdown): pause_countdown.hide()

func _unpause_button() -> void:
	if _resuming or gamestate != gamestate_paused or not _application_focused or not _xr_focused:
		return
	_resuming = true
	_resume_remaining = 3.0
	_resume_revision = SongClock.revision
	pause_menu.visible = false
	pause_countdown.visible = true
	pause_countdown.set_label_text("3")
	track.visible = true

func _process(delta: float) -> void:
	_advance_resume(delta)

func _advance_resume(delta: float) -> void:
	if not _resuming: return
	if SongClock.revision != _resume_revision or gamestate != gamestate_paused:
		_cancel_resume()
		return
	_resume_remaining -= delta
	if _resume_remaining > 0:
		pause_countdown.set_label_text(str(ceili(_resume_remaining)))
		return
	_cancel_resume()
	left_saber.reset_tracking()
	right_saber.reset_tracking()
	set_world_paused(false)
	SongClock.set_paused(false)
	_transition_game_state(gamestate_playing)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_application_focused = false
		_handle_focus_change()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		_application_focused = true

func _set_xr_focus(focused: bool) -> void:
	_xr_focused = focused
	_handle_focus_change()

func _handle_focus_change() -> void:
	if not is_node_ready() or (_application_focused and _xr_focused): return
	_cancel_resume()
	if gamestate == gamestate_playing:
		_transition_game_state(gamestate_paused)
	elif gamestate == gamestate_paused:
		pause_menu._show()
		track.hide()

func _on_BeepSaberMainMenu_difficulty_changed(map_info: MapInfo, diff_rank: int) -> void:
	if diff_rank < 0:
		if highscore_canvas:
			highscore_canvas.hide()
		return
		
	# menu loads playlist in _ready(), must yield until scene is loaded
	if not highscore_canvas:
		await self.ready
	
	if gamestate != gamestate_mapselection or not main_menu.visible:
		return
	highscore_canvas._show()
	highscore_panel.load_highscores(map_info,diff_rank)

func _settings_button() -> void:
	settings_panel._update_backgrounds()
	_transition_game_state(gamestate_settings)

func _on_settings_Panel_apply() -> void:
	set_colors_from_settings()
	_transition_game_state(gamestate_mapselection)

func _on_ScenePool_new_scene_instanced(obj: Node3D, during_presizing: bool) -> void:
	track.add_child(obj)
	if during_presizing:
		if obj.has_method("hide_cube"):
			obj.hide_cube()
		elif obj.has_method("clear_from_track"):
			obj.clear_from_track()
		else:
			obj.hide()
			obj.process_mode = Node.PROCESS_MODE_DISABLED


func recenter():
	var xr_camera := $XROrigin3D/XRCamera3D as XRCamera3D
	xr_origin.rotation.y -= xr_camera.global_rotation.y
	xr_origin.position -= (xr_camera.global_position * Vector3(1,0,1)) - Vector3(0,0,1)

func _set_hand(right: bool, hand: bool) -> void:
	var angle_offset := -45. if hand else 0.
	if right:
		right_saber.second_extra_offset_rot.x=angle_offset
		right_saber._update_size_and_angle()
	else:
		left_saber.second_extra_offset_rot.x=angle_offset
		left_saber._update_size_and_angle()

func _on_right_controller_profile_changed(role: String) -> void:
	if role.ends_with("/simple_controller"):
		_set_hand(true, true)
	else:
		_set_hand(true, false)

func _on_left_controller_profile_changed(role: String) -> void:
	if role.ends_with("/simple_controller"):
		_set_hand(false, true)
	else:
		_set_hand(false, false)

var _world_paused := false
var _paused_animations: Array[AnimationPlayer] = []
var _paused_speeds: Array[float] = []
var _paused_tweens: Array[Tween] = []

func set_world_paused(value: bool) -> void:
	if value == _world_paused: return
	_world_paused = value
	if value:
		_paused_animations.clear()
		_paused_speeds.clear()
		for node in track.find_children("*", "AnimationPlayer", true, false) + event_driver.find_children("*", "AnimationPlayer", true, false):
			_paused_animations.append(node)
			_paused_speeds.append(node.speed_scale)
			node.speed_scale = 0
		for tween in event_driver.active_tweens():
			if tween != null and tween.is_valid() and tween.is_running():
				tween.pause()
				_paused_tweens.append(tween)
	else:
		for i in _paused_animations.size():
			if is_instance_valid(_paused_animations[i]):
				_paused_animations[i].speed_scale = _paused_speeds[i]
		for tween in _paused_tweens:
			if tween != null and tween.is_valid(): tween.play()
		_paused_animations.clear()
		_paused_speeds.clear()
		_paused_tweens.clear()
