extends Node

@onready var root := get_tree().root

var checks := 0
var failures: Array[String] = []
var game: BeepSaber_Game

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func _ready() -> void:
	call_deferred("run")

func info_fixture(path: String = "res://.tools/fixtures/") -> MapInfo:
	return MapInfo.new_v2({"_version": "2.0.0", "_songName": "Synthetic Test", "_songAuthorName": "Tests", "_beatsPerMinute": 120.0, "_songFilename": "song.ogg", "_difficultyBeatmapSets": [{"_beatmapCharacteristicName": "Standard", "_difficultyBeatmaps": [{"_difficulty": "Expert", "_difficultyRank": 7.0, "_beatmapFilename": "Expert.dat", "_noteJumpMovementSpeed": 10.0, "_noteJumpStartBeatOffset": 0.0}]}]}, path)

func v2_fixture() -> Dictionary:
	return {"_version": "2.0.0", "_notes": [{"_time": 4.0, "_lineIndex": 1.0, "_lineLayer": 1.0, "_type": 0.0, "_cutDirection": 8.0}], "_obstacles": [], "_events": []}

func v3_fixture() -> Dictionary:
	return {"version": "3.0.0", "colorNotes": [{"b": 4.0, "x": 1.0, "y": 1.0, "c": 0.0, "d": 8.0}], "bombNotes": [{"b": 6.0, "x": 0.0, "y": 0.0}], "obstacles": [{"b": 8.0, "x": 0.0, "y": 0.0, "d": 2.0, "w": 1.0, "h": 5.0}]}

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func test_rules() -> void:
	check(StandardScoring.cut_score(100, 60, 0) == 115, "perfect cut = 115")
	check(StandardScoring.cut_score(200, 120, 0) == 115, "angles saturate")
	check(StandardScoring.cut_score(0, 0, 0.15) == 0, "minimum cut")
	check(StandardScoring.cut_score(100, 60, -0.15) == 100, "distance is symmetric")
	check(StandardScoring.cut_score(50, 30, 0.15) == 50, "partial angles")
	var rules := StandardScoring.new()
	var expected := [1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 8]
	for value in expected:
		check(rules.hit() == value, "multiplier hit sequence")
	rules.miss()
	check(rules.multiplier == 4 and rules.combo == 0 and rules.progress == 0, "miss drops one tier")
	rules.miss(); rules.miss(); rules.miss()
	check(rules.multiplier == 1, "multiplier floor")
	check(StandardScoring.max_score(0) == 0, "empty chart")
	check(StandardScoring.max_score(2) == 345, "theoretical chart maximum")
	Scoreboard.restart()
	Scoreboard.max_points = 345
	var first := Scoreboard.reserve_hit()
	var second := Scoreboard.reserve_hit()
	Scoreboard.reset_combo(true)
	Scoreboard.add_swing_score(Vector3.ZERO, 0, 15, 100, 60, second)
	Scoreboard.add_swing_score(Vector3.ZERO, 0, 15, 100, 60, first)
	check(Scoreboard.points == 345, "delayed scores retain cut-time multiplier")
	check(is_equal_approx(Scoreboard.accuracy(), 1.0), "accuracy uses chart maximum")

func test_validation() -> void:
	var info := info_fixture()
	var difficulty := info.difficulty_beatmaps[0]
	check(MapValidator.validate(info, difficulty, v2_fixture()).errors.is_empty(), "valid v2")
	check(MapValidator.validate(info, difficulty, v3_fixture()).errors.is_empty(), "valid v3")
	var data := v3_fixture()
	data.version = "4.0.0"
	check(not MapValidator.validate(info, difficulty, data).errors.is_empty(), "v4 rejected")
	data = v3_fixture(); data.bpmEvents = [{"b": 1, "m": 150}]
	check(not MapValidator.validate(info, difficulty, data).errors.is_empty(), "variable BPM rejected")
	data = v2_fixture(); data._events = [{"_time": 1, "_type": 100}]
	check(not MapValidator.validate(info, difficulty, data).errors.is_empty(), "v2 BPM event rejected")
	data = v2_fixture(); data._notes[0]._cutDirection = 999
	check(not MapValidator.validate(info, difficulty, data).errors.is_empty(), "invalid direction rejected")
	data = v3_fixture(); data.colorNotes = "broken"
	check(not MapValidator.validate(info, difficulty, data).errors.is_empty(), "malformed notes rejected")
	difficulty.custom_data = {"_requirements": ["Noodle Extensions"]}
	check(not MapValidator.validate(info, difficulty, v2_fixture()).errors.is_empty(), "required mod rejected")
	difficulty.custom_data = {}; difficulty.characteristic = "OneSaber"
	check(not MapValidator.validate(info, difficulty, v2_fixture()).errors.is_empty(), "nonstandard rejected")
	difficulty.characteristic = "Standard"
	data = v3_fixture(); data.burstSliders = [{"b": 4, "x": 1, "y": 1, "c": 0, "d": 1, "tb": 5, "tx": 2, "ty": 1, "sc": 4, "s": 1}]
	check(MapValidator.validate(info, difficulty, data).errors.is_empty() and MapValidator.validate(info, difficulty, data).experimental, "chains marked experimental")
	for path in ["../song.ogg", "/song.ogg", "C:\\song.ogg", "safe/../../song.ogg"]:
		check(not MapValidator.safe_relative_file(path), "unsafe filename rejected")
	check(Utils.binary_to_json("[1,2]".to_utf8_buffer()).is_empty(), "non-object JSON rejected")
	check(Utils.binary_to_json("broken".to_utf8_buffer()).is_empty(), "broken JSON rejected")

func test_clock() -> void:
	SongClock.source_seconds = 0
	SongClock.bpm = 120
	SongClock.rate = 1.0
	SongClock.offset_seconds = 0.1
	SongClock.observe_audio(2, 0.02, 0.04)
	check(is_equal_approx(SongClock.song_seconds(), 1.88), "mix, output latency and offset")
	SongClock.observe_audio(1, 0, 0)
	check(is_equal_approx(SongClock.source_seconds, 1.98), "audio clock never regresses")
	SongClock.running = true; SongClock.set_paused(true)
	var frozen := SongClock.source_seconds
	SongClock._physics_process(5)
	check(SongClock.source_seconds == frozen, "paused clock frozen")
	check(is_equal_approx(NoteTiming.z_at(4, 2, 5), -10), "absolute note position")
	check(is_equal_approx(NoteTiming.half_jump_beats(120, 10, 0), 2), "half jump calculation")
	check(is_equal_approx(NoteTiming.half_jump_beats(120, 10, -3), 0.25), "half jump minimum")
	check(NoteTiming.peak_live([[0, 2], [1, 3], [2, 4]]) == 2, "pool interval capacity")
	SongClock.stop()

func test_loading() -> void:
	var info := info_fixture()
	var diff := info.difficulty_beatmaps[0]
	Settings.music_speed = 125
	check(Map.load_beatmap(info, diff, v3_fixture()), "load v3 stacks")
	check(Map.note_stack.size() == 1 and Map.bomb_stack.size() == 1 and Map.obstacle_stack.size() == 1, "v3 object counts")
	check(Map.load_beatmap(info, diff, v2_fixture()), "load v2 after v3")
	check(Map.bomb_stack.is_empty() and Map.obstacle_stack.is_empty() and Map.chain_stack.is_empty(), "no stale stacks")
	check(info.beats_per_minute == 120, "speed does not mutate source BPM")
	Map.load_beatmap(info, diff, v2_fixture())
	check(info.beats_per_minute == 120, "restart does not compound BPM")
	var unordered := v2_fixture()
	var early: Dictionary = unordered._notes[0].duplicate()
	early._time = 1.0
	unordered._notes.append(early)
	Map.load_beatmap(info, diff, unordered)
	check(Map.note_stack[-1].beat == 1.0, "unsorted notes spawn chronologically")
	Settings.music_speed = 100

func test_zip() -> void:
	var zip := ZIPPacker.new()
	zip.open("res://.tools/bad.zip")
	zip.start_file("../escape.txt"); zip.write_file("bad".to_utf8_buffer()); zip.close_file(); zip.close()
	check(Utils.unzip("res://.tools/bad.zip", "res://.tools/extraction") == ERR_INVALID_DATA, "ZIP traversal rejected")
	zip.open("res://.tools/good.zip")
	zip.start_file("nested/info.dat"); zip.write_file("{}".to_utf8_buffer()); zip.close_file(); zip.close()
	check(Utils.unzip("res://.tools/good.zip", "res://.tools/extraction") == OK, "ZIP nested folders")
	zip.open("res://.tools/audio-only.zip")
	zip.start_file("song.mp3"); zip.write_file("audio".to_utf8_buffer()); zip.close_file(); zip.close()
	check("Audio alone" in SongUploader.validate_song_zip("res://.tools/audio-only.zip"), "audio-only upload explains missing beatmap")
	zip.open("res://.tools/nested-map.zip")
	zip.start_file("Song/Info.dat"); zip.write_file("{}".to_utf8_buffer()); zip.close_file(); zip.close()
	check("ZIP root" in SongUploader.validate_song_zip("res://.tools/nested-map.zip"), "nested map upload explains required layout")

func test_session_transitions(info: MapInfo, diff: DifficultyInfo) -> void:
	game.event_driver.disabled = false
	game.event_driver.process_event(EventInfo.new(0, 8, 0, 0))
	var ring_tween: Tween = game.event_driver._ring_tween
	game.event_driver.left_laser_anim_player.speed_scale = 1.5
	game._set_xr_focus(false)
	check(game.gamestate == game.gamestate_paused and SongClock.paused, "XR focus loss pauses song")
	check(not ring_tween.is_running(), "pause freezes ring tween")
	game.set_world_paused(true)
	game._set_xr_focus(true)
	check(game.gamestate == game.gamestate_paused, "focus return does not auto-resume")
	game._unpause_button()
	game._advance_resume(1.0)
	check(game._resuming and SongClock.paused, "countdown keeps song paused")
	game._set_xr_focus(false)
	check(not game._resuming and not game.pause_countdown.visible, "focus loss cancels countdown")
	game._advance_resume(5.0)
	check(SongClock.paused, "cancelled countdown cannot resume later")
	game._set_xr_focus(true)
	game._unpause_button()
	game._advance_resume(3.01)
	check(game.gamestate == game.gamestate_playing and not SongClock.paused, "full countdown resumes song")
	check(is_equal_approx(game.event_driver.left_laser_anim_player.speed_scale, 1.5), "repeated pause preserves animation speed")
	check(ring_tween.is_running(), "resume restores ring tween")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(SongClock.paused, "application focus loss pauses song")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._unpause_button()
	game._advance_resume(3.01)
	var first := Area3D.new()
	var second := Area3D.new()
	root.add_child(first); root.add_child(second)
	first.add_to_group("wall"); second.add_to_group("wall")
	game._on_PlayerHead_area_entered(first)
	game._on_PlayerHead_area_entered(second)
	game._on_PlayerHead_area_exited(first)
	check(game._in_wall and Scoreboard.in_wall and game.song_player.volume_db == -15, "overlapping walls retain collision after first exit")
	game._on_PlayerHead_area_exited(second)
	check(not game._in_wall and not Scoreboard.in_wall, "last wall exit clears collision")
	game._transition_game_state(game.gamestate_paused)
	Scoreboard.reserve_hit()
	var combo_before := Scoreboard.combo
	game._on_PlayerHead_area_entered(first)
	check(Scoreboard.combo == combo_before, "wall entry cannot penalize paused play")
	game._on_PlayerHead_area_exited(first)
	first.queue_free(); second.queue_free()
	game._unpause_button()
	game._advance_resume(3.01)
	game._on_song_ended()
	var required_time := (Map.current_info.last_beat - SongClock.beat()) * 60.0 / SongClock.bpm / SongClock.rate
	check(game._finish_at - SongClock.active_seconds > required_time, "audio ending waits for final map objects")
	await game.start_map(info, diff)
	check(not ring_tween.is_valid() and game.event_driver.ring_rot_speed == 0, "restart cancels old ring animation")
	check(not game._audio_finished and not game._in_wall, "restart resets ending and wall state")
	game._transition_game_state(game.gamestate_paused)
	game._unpause_button()
	game._main_menu_button()
	game._advance_resume(5.0)
	check(not SongClock.running and game.gamestate == game.gamestate_mapselection, "menu exit cancels pending resume")
	await game.start_map(info, diff)

func test_library() -> void:
	var menu := game.menu
	var preview_setting := Settings.audio_music_preview
	Settings.audio_music_preview = 0
	var info := info_fixture()
	var chart_path := info.filepath + "Expert.dat"
	write_json(chart_path, v2_fixture())
	var maps: Array[MapInfo] = [info]
	menu._set_cur_playlist(maps)
	PlayCount.increment_play_count(info, 7)
	PlayCount.set_favorite(info, true)
	check(PlayCount.get_last_difficulty(info) == 7, "last difficulty is independent of favorite flag")
	menu._select_song(0)
	check(menu._map_difficulty == 0, "difficulty rank resolves to list index")
	check(not (menu.get_node("Play_Button") as Button).disabled, "valid chart playable in menu")
	var cover_revision: int = menu._cover_revision
	var list_revision: int = menu._list_revision
	var marker := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	menu._select_song(0)
	menu._on_cover_loaded(marker, true, -1, cover_revision)
	check(menu.cover.texture != marker, "old song cover callback ignored")
	var empty_maps: Array[MapInfo] = []
	menu._set_cur_playlist(empty_maps)
	menu._on_cover_loaded(marker, false, 0, list_revision)
	check(menu.current_selected == -1 and menu.songs_menu.item_count == 0, "filtered empty playlist clears selection safely")
	write_json(chart_path, {"version": "4.0.0"})
	menu._set_cur_playlist(maps); menu._select_song(0)
	check((menu.get_node("Play_Button") as Button).disabled, "unsupported chart disabled before play")
	check("Only v2/v3" in (menu.get_node("SongInfo_Label") as Label).text, "unsupported reason visible before play")
	var experimental := v3_fixture()
	experimental.burstSliders = [{"b": 4, "x": 1, "y": 1, "c": 0, "d": 1, "tb": 5, "tx": 2, "ty": 1, "sc": 4, "s": 1}]
	write_json(chart_path, experimental)
	menu._select_song(0)
	check(not (menu.get_node("Play_Button") as Button).disabled and "Experimental" in (menu.get_node("SongInfo_Label") as Label).text, "experimental chart explains record restriction")
	info.song_filename = "missing.ogg"
	menu._select_song(0)
	check((menu.get_node("Play_Button") as Button).disabled, "missing audio disables play")
	info.song_filename = "song.ogg"
	write_json(chart_path, v2_fixture()); menu._select_song(0)
	write_json(chart_path, {"version": "4.0.0"})
	menu._load_map_and_start(info)
	check(not SongClock.running and (menu.get_node("Play_Button") as Button).disabled, "play revalidates externally changed chart")
	info.difficulty_beatmaps.clear(); menu._select_song(0)
	check((menu.get_node("Play_Button") as Button).disabled and menu.diff_menu.item_count == 0, "metadata without difficulties is safe")
	var audio := Utils.read_binary_file(info.filepath, "song.ogg")
	menu.play_preview(audio, 0, 5)
	menu._on_stop_prev_timeout()
	var old_fade: Tween = menu._preview_tween
	menu.play_preview(audio, 0, 5)
	check(not old_fade.is_valid() and menu.song_preview.playing, "new preview cancels old fade-out")
	menu.stop_preview()
	check(not menu.song_preview.playing and menu._preview_tween == null, "preview stop cancels animation")
	Settings.audio_music_preview = preview_setting
	var panel := (game.get_node("MapSourceDialogs/BeatSaver_Canvas") as OQ_UI2DCanvas).ui_control as BeatSaverPanel
	panel.item_list.clear()
	panel.item_list.add_item("Download test")
	panel.item_list.set_item_metadata(0, "abc123")
	panel.downloading = [["Test", {"hash": "abc123"}]]
	panel.on_song_list_changed()
	check(panel.item_list.is_item_disabled(0), "queued download stays disabled during list refresh")
	panel._on_HTTPRequest_download_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(panel.downloading.is_empty() and not panel.item_list.is_item_disabled(0), "failed download becomes retryable")
	check("failed" in panel.label.text, "download failure remains visible")
	panel.downloading = [["Test", {"hash": ""}]]
	var sentinel := Constants.APPDATA_PATH.path_join("temp/keep.txt")
	DirAccess.make_dir_recursive_absolute(sentinel.get_base_dir())
	var file := FileAccess.open(sentinel, FileAccess.WRITE)
	file.store_string("keep"); file.close()
	panel._on_HTTPRequest_download_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray())
	check(FileAccess.file_exists(sentinel), "invalid download identifier preserves other staging files")
	menu._set_cur_playlist(empty_maps)

func test_cover_cache() -> void:
	var loader := preload("res://game/scripts/BackgroundImgLoader.gd").new()
	var img := Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png("res://.tools/cover-test.png")
	var received: Array = []
	var callback := func(texture, _main, _index): received.append(texture)
	loader.load_texture("res://.tools/", "cover-test.png", callback, false, 0)
	for i in 100:
		if not received.is_empty(): break
		await get_tree().create_timer(0.01).timeout
	check(received.size() == 1, "cover worker completes")
	if not received.is_empty():
		check(received[0].get_width() == 128 and received[0].get_height() == 32, "thumbnail dimensions bounded with aspect ratio")
	loader.load_texture("res://.tools/", "cover-test.png", callback, false, 1)
	check(received.size() == 2 and loader.physical_loads == 1, "repeated cover uses cached texture")
	loader.load_texture("res://.tools/", "cover-test.png", callback, true, -1)
	for i in 100:
		if received.size() >= 3: break
		await get_tree().create_timer(0.01).timeout
	check(received.size() == 3 and received[-1].get_width() == 512, "selected cover has independent resolution cache")
	loader.shutdown()
	check(loader._active_requests.is_empty() and loader._texture_cache.is_empty(), "loader shutdown releases workers and cache")

func test_swing_math() -> void:
	var history := SwingHistory.new()
	history.append(0, Vector3.UP)
	history.append(100, Vector3.RIGHT)
	history.append(200, Vector3.DOWN)
	check(is_equal_approx(history.angle_in_window(0, 100, Vector3.RIGHT), 90), "preswing window excludes future samples")
	check(is_equal_approx(history.angle_in_window(100, 200, Vector3.RIGHT), 90), "followthrough window measures angular travel")
	history.clear()
	check(history.angle_in_window(0, 200, Vector3.RIGHT) == 0, "tracking reset clears swing history")
	for i in 600: history.append(i, Vector3.UP)
	check(history.count == SwingHistory.CAPACITY, "swing history storage stays bounded")
	check(history.angle_in_window(0, 100, Vector3.RIGHT) == 0, "overwritten samples are not scored")
	check(is_equal_approx(history.angle_in_window(500, 599, Vector3.RIGHT), 90), "ring-buffer wrap preserves recent samples")
	var plane := LightSaber.motion_cut_plane(Vector3.ZERO, Vector3.UP, Vector3.UP, Vector3.ZERO)
	check(is_equal_approx(plane.normal.length(), 1.0) and is_zero_approx(plane.distance_to(Vector3.UP)), "stationary blade has a finite normalized cut plane")
	var moving := LightSaber.motion_cut_plane(Vector3.ZERO, Vector3.UP, Vector3(0.3, 1, 0), Vector3(0, 0, 0.2))
	check(is_zero_approx(moving.distance_to(Vector3(0.3, 1, 0.2))), "cut plane accounts for note displacement")

func test_sweep_collision() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var sweep := load("res://game/scripts/SwingableRayCast/SwingableRayCast.tscn").instantiate() as SwingableRayCast
	sweep.target_position = Vector3(0, 1.4, 0)
	sweep.collision_mask = 1 << 19
	sweep.collide_with_areas = true
	sweep.collide_with_bodies = false
	holder.add_child(sweep)
	sweep.set_physics_process(false)
	sweep.position = Vector3(100, 0, 0)
	sweep.set_raycasts_enabled(true)
	var obstacle := Node3D.new()
	holder.add_child(obstacle)
	var area := Area3D.new()
	area.collision_layer = 1 << 19
	area.collision_mask = 0
	obstacle.add_child(area)
	area.position = Vector3(100, 0.7, 0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.2, 0.4, 0.2)
	area.add_child(shape)
	var hits: Array = []
	sweep.area_collided.connect(func(hit): hits.append(hit))
	await get_tree().physics_frame
	await get_tree().process_frame
	sweep._physics_process(1.0 / 72.0)
	check(hits.size() == 1, "stationary core detects current collision")
	check(sweep.last_query_count == 1, "stationary sweep issues only one query")
	check(not sweep.enabled and not sweep._rays[0].enabled, "automatic duplicate queries disabled")
	hits.clear()
	sweep.position.x = 98.5
	sweep.reset_positions()
	sweep.position.x = 101.5
	await get_tree().physics_frame
	await get_tree().process_frame
	sweep._physics_process(1.0 / 72.0)
	check(hits.size() == 1, "fast sweep detects skipped block once across auxiliary rays")
	check(sweep.last_query_count == 9, "moving sweep uses one core plus eight segment queries")
	check(sweep._rays[-1].global_position.is_equal_approx(sweep.to_global(sweep.target_position)), "segment positions do not double-apply ray offset")
	hits.clear()
	sweep.reset_positions()
	sweep._physics_process(1.0 / 72.0)
	check(hits.is_empty() and sweep.last_query_count == 1, "tracking reset avoids phantom sweep")
	sweep.set_raycasts_enabled(false)
	sweep._physics_process(1.0 / 72.0)
	check(sweep.last_query_count == 0, "paused sweep performs no queries")
	holder.queue_free()
	await get_tree().process_frame

func test_saber_clash() -> void:
	var left := game.left_saber
	var right := game.right_saber
	var left_transform := left.global_transform
	var right_transform := right.global_transform
	var left_tip := left.saber_visual.tip.position
	var right_tip := right.saber_visual.tip.position
	var left_extended := left.is_extended()
	var right_extended := right.is_extended()
	left.global_transform = Transform3D.IDENTITY
	right.global_transform = Transform3D(Basis.IDENTITY, Vector3(-0.5, 0.5, 0))
	left.saber_visual.tip.global_position = Vector3(0, 1, 0)
	right.saber_visual.tip.global_position = Vector3(0.5, 0.5, 0)
	left.saber_visual.is_extended = true
	right.saber_visual.is_extended = true
	left.controller._update_rumble(1.0)
	right.controller._update_rumble(1.0)
	var clash := game.saber_clash
	clash.reset()
	clash.update_contact(left, right, 0.01, true)
	check(clash.touching and clash.sparks.emitting and clash.sparks.visible, "crossing blades produce sparks")
	check(absf(clash.sparks.global_position.x) < 0.02 and absf(clash.sparks.global_position.y - 0.5) < 0.03, "clash sparks originate at blade contact")
	check(left.controller.is_simple_rumbling() and right.controller.is_simple_rumbling(), "clash vibrates both controllers")
	clash.update_contact(left, right, 0.01, true)
	check(clash.cooldown < SaberClash.PULSE_INTERVAL, "held contact does not restart feedback every frame")
	right.global_position.z = 1.0
	clash.update_contact(left, right, 0.01, true)
	check(not clash.touching, "separated blades stop contact feedback")
	right.global_position.z = 0.0
	left.controller._update_rumble(1.0)
	right.controller._update_rumble(1.0)
	clash.update_contact(left, right, 0.01, true)
	check(clash.touching and left.controller.is_simple_rumbling(), "new contact immediately triggers another pulse")
	clash.update_contact(left, right, 0.01, false)
	check(not clash.touching and not clash.sparks.visible, "pause or focus loss suppresses clash sparks")
	right.saber_visual.is_extended = false
	clash.update_contact(left, right, 0.01, true)
	check(not clash.touching, "sheathed saber cannot clash")
	left.global_transform = left_transform
	right.global_transform = right_transform
	left.saber_visual.tip.position = left_tip
	right.saber_visual.tip.position = right_tip
	left.saber_visual.is_extended = left_extended
	right.saber_visual.is_extended = right_extended
	left.controller._update_rumble(1.0)
	right.controller._update_rumble(1.0)

func test_feedback_and_hud() -> void:
	test_saber_clash()
	var visual := game.left_saber.saber_visual
	visual.hit(0.15)
	check(visual.hitsound.playing, "early hit sound starts immediately")
	visual.hitsound.stop()
	check(visual.tail.get_node("Mesh").get_parent() == visual.tail, "saber owns trail mesh through visual replacement")
	var signals: Array = []
	var observer := func(): signals.append(true)
	Scoreboard.score_changed.connect(observer)
	for i in 10: game._physics_process(1.0 / 72.0)
	check(signals.is_empty(), "idle HUD refresh does not broadcast fake score changes")
	Scoreboard.score_changed.disconnect(observer)
	check(game.left_controller.process_physics_priority < game.left_saber.process_physics_priority and game.left_saber.process_physics_priority < game.left_saber._swing_cast.process_physics_priority, "controller sampling precedes saber and collision sweep")

func test_visual_resources() -> void:
	var spark_note := GlobalReferences.cube_pool.acquire() as BeepCube
	var sparks := spark_note.slice_particles
	spark_note.hide_cube()
	sparks.fire(Vector3(1, 2, 3), Vector3.RIGHT, Color.RED)
	check(sparks.c1 is CPUParticles3D and sparks.c1.amount <= 48 and sparks.c1.emitting, "Quest cut sparks emit a bounded CPU burst")
	check(sparks.can_process() and sparks.global_position.is_equal_approx(Vector3(1, 2, 3)), "sparks survive disabled note and use cut position")
	check((-sparks.global_basis.y).is_equal_approx(Vector3.RIGHT), "sparks align with world cut velocity")
	var paused_before := Scoreboard.paused
	Scoreboard.paused = true
	sparks._process(0.01)
	check(is_zero_approx(sparks.c1.speed_scale), "cut sparks freeze on pause")
	Scoreboard.paused = paused_before
	spark_note.clear_from_track()
	check(not sparks.visible and not sparks.can_process() and not sparks.c1.emitting, "track clear stops spark burst and processing")
	var materials := [game.left_saber.saber_visual.light_mesh.material_override,
		load("res://game/Wall/Wall_readable.tres"),
		(GlobalReferences.cube_pool.acquire() as BeepCube)._mat]
	for material in materials:
		check(material is ShaderMaterial and not material.shader.get_shader_uniform_list().is_empty(), "visual shader exposes valid uniforms")
	game._clear_track()
	var first := GlobalReferences.wall_pool.acquire() as Wall
	var second := GlobalReferences.wall_pool.acquire() as Wall
	var a := first.get_node("WallMeshOrientation/WallMesh") as MeshInstance3D
	var b := second.get_node("WallMeshOrientation/WallMesh") as MeshInstance3D
	a.material_override.set_shader_parameter("size", Vector3(2, 3, 4))
	check(a.material_override != b.material_override and b.material_override.get_shader_parameter("size") != Vector3(2, 3, 4), "wall dimensions use independent materials")
	first.clear_from_track(); second.clear_from_track()
	Settings.quest_quality = 2
	game.apply_quest_profile()
	check(game.get_viewport().msaa_3d == Viewport.MSAA_4X and is_equal_approx(game.get_viewport().scaling_3d_scale, 1.1), "clarity profile enables 4x MSAA and 110 percent scale")
	Settings.quest_quality = 0
	game.apply_quest_profile()
	check(game.get_viewport().msaa_3d == Viewport.MSAA_2X and is_equal_approx(game.get_viewport().scaling_3d_scale, 1.0), "standard profile restores render budget")

func test_menu_layout(info: MapInfo) -> void:
	var menu := game.main_menu.ui_control as MainMenu
	var targets: Array[Control] = []
	for path in ["SongsMenu", "DifficultyMenu", "Play_Button", "Search_Button", "PlaylistSelector",
		"Settings_Button", "Exit_Button", "LoadPlaylists_Button", "Delete_Button", "Licenses",
		"Modifiers/Health", "Modifiers/Health/Bombs", "Modifiers/Health/Bombs/Arrows",
		"Modifiers2/Claws", "Modifiers2/Claws/Size", "Modifiers2/Claws/Size/Width",
		"Modifiers3/Flip", "Modifiers3/Flip/Speed", "Modifiers3/Flip/Speed/Handedness"]:
		targets.append(menu.get_node(path) as Control)
	var inside := true
	var separate := true
	for i in targets.size():
		inside = inside and menu.get_global_rect().encloses(targets[i].get_global_rect())
		for j in range(i + 1, targets.size()):
			if targets[i].get_global_rect().intersects(targets[j].get_global_rect()):
				separate = false
				printerr("Overlapping menu targets: ", targets[i].name, " / ", targets[j].name)
	check(inside, "VR menu targets remain inside canvas")
	check(separate, "VR menu targets do not overlap after restyling")
	var songs: Array[MapInfo] = [info]
	menu._set_cur_playlist(songs)
	menu._select_song(0)
	check(not (menu.get_node("Play_Button") as Button).disabled, "restyled menu permits valid song playback")
	check((menu.get_node("SongTitle_Label") as Label).text == info.song_name, "selected song updates new detail panel")
	check(menu.diff_menu.item_count == info.difficulty_beatmaps.size(), "restyled difficulty list preserves map choices")
	menu.stop_preview()

func test_saved_highscore_rows(info: MapInfo, diff: DifficultyInfo) -> void:
	var old_table := Highscores._hs_table.duplicate(true)
	var old_path := Highscores.HIGHSCORES_FILEPATH
	Highscores.HIGHSCORES_FILEPATH = "res://.tools/menu-score-regression.json"
	var key := HighscoreTable.score_key(info, diff.difficulty_rank)
	var rank := str(HighscoreTable.get_rank_key(diff.difficulty_rank))
	Highscores._hs_table = {key: {rank: [{"player_name": "Saved player", "score": 173308, "epoch_time": 1792879993.0}]}}
	Highscores.save_hs_table()
	Highscores._hs_table.clear()
	Highscores.load_hs_table()
	# Match cold start: the scene's sample rows have already been freed.
	var panel := load("res://game/HighscorePanel.tscn").instantiate() as HighscorePanel
	root.add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	for iteration in 3:
		panel.load_highscores(info, diff.difficulty_rank)
		check(panel._highscore_list.get_child_count() == 1, "saved score replaces rows without accumulating old rows")
		var row := panel._highscore_list.get_child(0)
		check(row.get_child_count() == 3, "saved score row retains rank name and score after scene cleanup")
		if row.get_child_count() == 3:
			check(row.get_child(1).text == "Saved player" and row.get_child(2).text == "173308", "JSON-reloaded score renders player and integer score")
		await get_tree().process_frame
	game._main_menu_button()
	check(game.highscore_panel._highscore_list.get_child_count() == 1, "return to library displays existing saved score")
	panel.queue_free()
	await get_tree().process_frame
	Highscores.HIGHSCORES_FILEPATH = old_path
	Highscores._hs_table = old_table

func test_result_navigation(info: MapInfo, diff: DifficultyInfo) -> void:
	for iteration in 12:
		var result_state: GameState = game.gamestate_newhighscore if iteration % 2 == 0 else game.gamestate_mapcomplete
		game._transition_game_state(result_state)
		var repeat_button := game.endscore.get_node("Repeat") as UIRaycastButton
		var menu_button := game.endscore.get_node("MainMenu") as UIRaycastButton
		check(not (repeat_button.get_node("Collision") as CollisionShape3D).disabled,
			"result permits replay without entering a name")
		check(not (menu_button.get_node("Collision") as CollisionShape3D).disabled,
			"result permits menu exit without entering a name")
		repeat_button.ui_raycast_hit_event(Vector3.ZERO, true, false)
		repeat_button.ui_raycast_hit_event(Vector3.ZERO, false, true)
		await get_tree().process_frame
		await get_tree().process_frame
		check(game.gamestate == game.gamestate_playing and SongClock.running and not game._ending,
			"result replay starts a fresh session")
		check(Scoreboard.points == 0 and not game.name_selector_canvas.visible and not game.highscore_keyboard.visible,
			"replay resets score and hides name entry")
		game.finish_map()
		game._transition_game_state(result_state)
		menu_button.ui_raycast_hit_event(Vector3.ZERO, true, false)
		menu_button.ui_raycast_hit_event(Vector3.ZERO, false, true)
		check(game.gamestate == game.gamestate_mapselection and not SongClock.running,
			"result menu button returns to song selection")
		game.menu._on_Play_Button_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
		check(game.gamestate == game.gamestate_playing and SongClock.running,
			"song can be played again after returning from results")
		game.finish_map()
	await game.start_map(info, diff)

func test_menu_input_transition() -> void:
	game._main_menu_button()
	var area = game.main_menu.ui_area
	var blank_point: Vector3 = area.to_global(Vector3(-0.495, 0.495, 0))
	area.ui_raycast_hit_event(blank_point, false, true)
	check(not area.pointer_pressed, "menu ignores release without a matching press")
	area.ui_raycast_hit_event(blank_point, true, false)
	check(area.pointer_pressed, "menu tracks an active pointer press")
	game.left_ui_raycast.colliding_with = area
	game.right_ui_raycast.colliding_with = area
	# A detached controller keeps the desktop VR simulator from overwriting input.
	var input_controller := BeepSaberController.new()
	input_controller.trigger = true
	game.left_ui_raycast.controller = input_controller
	game.right_ui_raycast.controller = input_controller
	game._transition_game_state(game.gamestate_mapselection)
	check(not area.pointer_pressed and area.last_pos2d == Vector2(INF, INF), "screen transition cancels captured mouse press")
	for ray in [game.left_ui_raycast, game.right_ui_raycast]:
		check(ray.colliding_with == null and ray._input_is_blocked(), "both pointers discard input in transition frame")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.left_ui_raycast._input_is_blocked(), "held trigger cannot activate newly shown menu")
	input_controller.trigger = false
	check(game.left_ui_raycast._input_is_blocked(), "release from old screen is consumed")
	check(not game.left_ui_raycast._input_is_blocked(), "menu accepts a fresh click after trigger release")
	game.right_ui_raycast._input_is_blocked()
	game.left_ui_raycast.controller = game.left_controller
	game.right_ui_raycast.controller = game.right_controller
	input_controller.free()

func test_scene() -> void:
	game = load("res://game/BeepSaber_Game.tscn").instantiate()
	root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var fixture_path := "res://.tools/fixtures/"
	DirAccess.make_dir_recursive_absolute(fixture_path)
	DirAccess.copy_absolute("res://game/data/maps/Songs/TheFatRat_Timelapse/song_q1.egg", fixture_path + "song.ogg")
	write_json(fixture_path + "Expert.dat", v2_fixture())
	var info := info_fixture()
	var diff := info.difficulty_beatmaps[0]
	test_menu_layout(info)
	await test_saved_highscore_rows(info, diff)
	await game.start_map(info, diff)
	check(SongClock.running and game.gamestate == game.gamestate_playing, "scene starts valid fixture")
	check(Scoreboard.record_eligible and Scoreboard.max_points == 115, "standard chart eligible")
	await test_session_transitions(info, diff)
	var key := HighscoreTable.score_key(info, 7)
	Settings.block_size = 150
	check(key != HighscoreTable.score_key(info, 7), "modifiers isolate records")
	Settings.block_size = 100
	var note := GlobalReferences.cube_pool.acquire() as BeepCube
	note.spawn(Map.note_stack[-1], SongClock.beat())
	check(not note.resolved, "pooled note reset")
	note.on_miss(); note.on_miss()
	check(Scoreboard.wrong_notes == 1, "miss resolves a note once")
	game.left_saber.add_score(Vector3.ZERO, 0, 15, false, false, 1)
	check(game.left_saber.score_queue.size() == 1, "followthrough queued")
	var saved_points := Scoreboard.points
	game._transition_game_state(game.gamestate_paused)
	SongClock._physics_process(5)
	game.left_saber._physics_process(0.02)
	check(Scoreboard.points == saved_points and game.left_saber.score_queue.size() == 1, "pause freezes pending scores")
	await game.start_map(info, diff)
	check(game.left_saber.score_queue.is_empty() and Scoreboard.points == 0, "restart clears pending scores")
	var current := GlobalReferences.cube_pool.acquire() as BeepCube
	current.spawn(Map.note_stack[-1], SongClock.beat())
	current.is_dot = true
	current.cut(game.left_saber, Vector3.DOWN, Plane(Vector3.RIGHT, current.global_position), game.left_controller)
	current.cut(game.left_saber, Vector3.DOWN, Plane(Vector3.RIGHT, current.global_position), game.left_controller)
	check(game.left_saber.score_queue.size() == 1, "duplicate cut suppressed")
	game.finish_map()
	check(game.left_saber.score_queue.is_empty() and Scoreboard.points > 0, "ending flushes final hit")
	await test_result_navigation(info, diff)
	await test_menu_input_transition()
	game.endscore.show_score(100, 100, 0.8, "Animation test", false, false)
	var score_animation: Tween = game.endscore._score_tween
	game.endscore._hide()
	check(not score_animation.is_valid() and game.endscore._score_tween == null, "leaving result screen cancels animation")
	var experimental := v3_fixture()
	experimental.burstSliders = [{"b": 4, "x": 1, "y": 1, "c": 0, "d": 1, "tb": 5, "tx": 2, "ty": 1, "sc": 4, "s": 1}]
	write_json(fixture_path + "Expert.dat", experimental)
	await game.start_map(info, diff)
	check(not Scoreboard.record_eligible, "experimental chart excludes records")
	check(not Highscores.is_new_highscore(info, 7, 999999), "experimental highscore rejected")
	var wall := GlobalReferences.wall_pool.acquire() as Wall
	wall.spawn(Map.obstacle_stack[-1], SongClock.beat())
	wall.clear_from_track()
	wall.clear_from_track()
	check(GlobalReferences.wall_pool.free_count() == GlobalReferences.wall_pool.total_count(), "wall releases exactly once")
	var bomb := GlobalReferences.bomb_pool.acquire() as Bomb
	bomb.spawn(Map.bomb_stack[-1], SongClock.beat())
	bomb.clear_from_track()
	check(GlobalReferences.bomb_pool.free_count() == GlobalReferences.bomb_pool.total_count(), "bomb returns to pool")
	Settings.quest_quality = 1
	game.apply_quest_profile()
	check(game.event_driver.disabled and not game.event_driver.ring_holder.visible, "low profile hides decorations")
	Settings.quest_quality = 0
	info.song_filename = "missing.ogg"
	await game.start_map(info, diff)
	check(not SongClock.running and game.gamestate == game.gamestate_mapselection, "missing audio returns to menu")
	info.song_filename = "song.ogg"
	write_json(fixture_path + "Expert.dat", {"version": "4.0.0"})
	await game.start_map(info, diff)
	check(not SongClock.running and game.gamestate == game.gamestate_mapselection, "invalid map returns to menu")
	check(not (game.menu.get_node("SongInfo_Label") as Label).text.is_empty(), "visible map error")
	write_json(fixture_path + "Expert.dat", v2_fixture())
	game.start_map(info, diff)
	game._main_menu_button()
	await get_tree().process_frame
	check(not SongClock.running and game.gamestate == game.gamestate_mapselection, "menu exit cancels in-flight map start")
	game._set_xr_focus(false)
	await game.start_map(info, diff)
	check(game.gamestate == game.gamestate_paused and SongClock.paused, "map loaded without XR focus stays paused")
	game._set_xr_focus(true)
	game._main_menu_button()
	test_visual_resources()
	test_feedback_and_hud()
	await test_sweep_collision()
	await test_library()
	await preload("res://tests/BeatSaverTests.gd").run(self)
	await test_cover_cache()
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	GlobalReferences.main_game_scene = null

func run() -> void:
	test_rules()
	test_swing_math()
	test_validation()
	test_clock()
	test_loading()
	test_zip()
	await test_scene()
	print("TEST SUMMARY: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty(): print("ALL TESTS PASSED")
	get_tree().quit(0 if failures.is_empty() else 1)
