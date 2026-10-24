extends RefCounted

static func map_response(hash_name: String) -> Dictionary:
	return {"name": "Levitating fixture", "metadata": {"songName": "Levitating", "songAuthorName": "Test Artist", "levelAuthorName": "Test Mapper", "duration": 200, "bpm": 120},
		"versions": [{"state": "Uploaded", "hash": "bad"}, {"state": "Published", "hash": hash_name, "diffs": [{"characteristic": "Standard", "difficulty": "Expert"}]}]}

static func archive(chart: Dictionary) -> PackedByteArray:
	var info := {"_version": "2.0.0", "_songName": "Browser install test", "_songAuthorName": "Tests", "_beatsPerMinute": 120.0, "_songFilename": "song.ogg", "_difficultyBeatmapSets": [{"_beatmapCharacteristicName": "Standard", "_difficultyBeatmaps": [{"_difficulty": "Expert", "_difficultyRank": 7, "_beatmapFilename": "Expert.dat", "_noteJumpMovementSpeed": 10, "_noteJumpStartBeatOffset": 0}]}]}
	var zip := ZIPPacker.new()
	zip.open("res://.tools/browser-test.zip")
	for entry in [["Info.dat", JSON.stringify(info).to_utf8_buffer()], ["Expert.dat", JSON.stringify(chart).to_utf8_buffer()],
		["song.ogg", FileAccess.get_file_as_bytes("res://game/data/maps/Songs/TheFatRat_Timelapse/song_q1.egg")]]:
		zip.start_file(entry[0])
		zip.write_file(entry[1])
		zip.close_file()
	zip.close()
	return FileAccess.get_file_as_bytes("res://.tools/browser-test.zip")

static func run(test: Node) -> void:
	var game: BeepSaber_Game = test.game
	var canvas := game.get_node("MapSourceDialogs/BeatSaver_Canvas") as OQ_UI2DCanvas
	var panel := canvas.ui_control as BeatSaverPanel
	var hash_name := "a12345678901234567890123456789012345678901"
	Utils.remove_tree(Constants.APPDATA_PATH.path_join("Songs").path_join(hash_name))
	var req := BeatSaverPanel.BeatSaverRequest.new()
	req.data = "levitating & Dua/Lipa"
	test.check(BeatSaverPanel.request_url(req).contains("q=levitating%20%26%20Dua%2FLipa&order=Relevance"), "BeatSaver search safely encodes artist query and documented sort parameter")
	panel.prev_request = req
	panel.song_data.clear()
	panel.item_list.clear()
	panel.item_selected = -1
	panel._on_HTTPRequest_request_completed(0, 200, [], JSON.stringify({"docs": [map_response(hash_name), {"versions": []}, 1], "info": {"pages": 2}}).to_utf8_buffer())
	test.check(panel.song_data.size() == 1 and panel.song_data[0].versions[0].hash == hash_name, "browser skips malformed maps and selects published version after draft")
	test.check(panel.next_page_available == 1, "browser exposes next results page")
	panel._on_ItemList_item_selected(0)
	test.check(panel.get_node("Title").text == "Levitating" and "Standard Expert" in panel.get_node("song_data").text, "browser shows selected song and difficulty details")
	test.check(panel.get_node("download").disabled, "missing download URL cannot start an invalid request")
	panel._revision += 1
	panel._on_HTTPRequest_request_completed(0, 200, [], '{"docs":[]}'.to_utf8_buffer(), panel._revision - 1)
	test.check(panel.song_data.size() == 1, "cancelled search response cannot replace current results")
	panel._on_HTTPRequest_request_completed(0, 429, [], PackedByteArray())
	test.check(panel.get_node("Retry").visible and "Wait" in panel.get_node("SearchStatus").text, "rate limit offers visible retry guidance")
	panel._on_HTTPRequest_request_completed(0, 200, [], '<html>error</html>'.to_utf8_buffer())
	test.check("invalid response" in panel.get_node("SearchStatus").text, "invalid search JSON is handled without crashing")
	panel._on_HTTPRequest_request_completed(0, 200, [], '{"docs":[],"info":{"pages":1}}'.to_utf8_buffer())
	test.check(panel.next_page_available == -1, "empty last page stops pagination")
	panel.song_data[0].versions[0].downloadURL = "https://r2cdn.beatsaver.com/" + hash_name + ".zip"
	panel.downloading = [["Fixture", panel.song_data[0].versions[0]]]
	panel._on_download_button_up()
	test.check(panel.downloading.size() == 1, "download button cannot enqueue the same map twice")
	panel._cancel_downloads()
	panel._on_HTTPRequest_download_completed(0, 200, [], PackedByteArray(), panel._download_revision - 1)
	test.check(panel.downloading.is_empty(), "late cancelled download does not install or change queue")
	game.open_song_browser()
	test.check(not game.main_menu.visible and canvas.is_visible_in_tree(), "discover button opens browser in place of library")
	test.check(canvas.global_transform.is_equal_approx(game.main_menu.global_transform), "browser uses front-facing menu position")
	panel._on_search_button_up()
	test.check(game.online_search_keyboard.visible, "search opens headset keyboard")
	panel._text_input_cancel()
	test.check(not game.online_search_keyboard.visible, "keyboard cancel keeps browser available")
	var image_before: Texture2D = panel.get_node("TextureRect").texture
	panel._update_cover(0, 200, [], PackedByteArray(), panel._revision - 1, 0)
	test.check(panel.get_node("TextureRect").texture == image_before, "late cover response cannot overwrite selected artwork")
	panel._on_preview_download_completed(0, 200, [], PackedByteArray(), panel._selection_revision - 1)
	test.check(not game.menu.song_preview.playing, "late preview response cannot play another selection")
	var targets: Array[Control] = []
	for path in ["ItemList", "search", "mode", "back", "Retry", "download", "Preview", "CloseButton", "gotoMapsBy", "LoadMore", "CancelDownload"]:
		targets.append(panel.get_node(path))
	var valid_layout := true
	for i in targets.size():
		valid_layout = valid_layout and panel.get_global_rect().encloses(targets[i].get_global_rect())
		for j in range(i + 1, targets.size()):
			valid_layout = valid_layout and not targets[i].get_global_rect().intersects(targets[j].get_global_rect())
	test.check(valid_layout, "browser VR targets fit canvas without overlapping")
	panel.downloading = [["Fixture", {"hash": hash_name}]]
	panel._on_HTTPRequest_download_completed(0, 200, [], archive({"version": "4.0.0"}))
	test.check(not DirAccess.dir_exists_absolute(Constants.APPDATA_PATH.path_join("Songs").path_join(hash_name)), "unsupported downloaded map is rejected before installation")
	test.check("unsupported" in panel.label.text, "incompatible map explains why another version is needed")
	panel.downloading = [["Fixture", {"hash": hash_name}]]
	panel._on_HTTPRequest_download_completed(0, 200, [], archive(test.v2_fixture()))
	test.check(game.menu.all_song_hashes.has(hash_name), "download installs archive and refreshes local library")
	test.check(panel.get_node("download").text == "OPEN IN LIBRARY", "download action becomes open-in-library after installation")
	test.check(not game.highscore_canvas.visible, "background library refresh does not reveal score panels over browser")
	panel._on_download_button_up()
	test.check(game.main_menu.visible and not canvas.visible, "open installed song returns to library")
	test.check(not game.online_search_keyboard.visible and not panel._browser_open, "leaving discovery closes keyboard and preview session")
	test.check(game.menu.current_selected >= 0 and game.menu._currently_selected_songlist_ref[game.menu.current_selected].filepath.contains(hash_name), "installed song is selected despite previous filters")
	game.menu._on_Play_Button_pressed()
	await test.get_tree().process_frame
	await test.get_tree().process_frame
	test.check(SongClock.running and game.gamestate == game.gamestate_playing, "downloaded song starts from the library without desktop file operations")
	game._main_menu_button()
	Utils.remove_tree(Constants.APPDATA_PATH.path_join("Songs").path_join(hash_name))
	game.menu._load_playlists()
	game.menu.stop_preview()
	panel.song_data.clear()
	panel.item_list.clear()
	panel.item_selected = -1
	panel._reset_details()
