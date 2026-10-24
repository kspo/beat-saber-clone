extends Panel
class_name BeatSaverPanel

const API := "https://api.beatsaver.com"
const SORTS := ["Relevance", "Rating", "Latest"]
const MAX_BACK_STACK_DEPTH := 10

class BeatSaverSongInfo extends RefCounted:
	var name: String
	var description: String
	var song_name: String
	var song_author_name: String
	var level_author_name: String
	var duration: float
	var versions: Array = []
	var uploader_id: int
	var bpm: float
	var rating: float

	func _init(data: Dictionary) -> void:
		name = Utils.get_str(data, "name", "Untitled")
		description = Utils.get_str(data, "description", "")
		# A draft may precede the live version in the API response.
		for version in Utils.get_array(data, "versions", []):
			if version is Dictionary and version.get("state", "") == "Published":
				var hash_name := Utils.get_str(version, "hash", "").to_lower()
				if not hash_name.is_empty() and hash_name.is_valid_hex_number(false):
					versions.append(version.duplicate(true))
					versions[0]["hash"] = hash_name
					break
		var metadata := Utils.get_dict(data, "metadata", {})
		song_name = Utils.get_str(metadata, "songName", name)
		song_author_name = Utils.get_str(metadata, "songAuthorName", "Unknown artist")
		level_author_name = Utils.get_str(metadata, "levelAuthorName", "Unknown mapper")
		duration = maxf(0, Utils.get_float(metadata, "duration", 0))
		bpm = Utils.get_float(metadata, "bpm", 0)
		rating = Utils.get_float(Utils.get_dict(data, "stats", {}), "score", 0)
		uploader_id = int(Utils.get_float(Utils.get_dict(data, "uploader", {}), "id", -1))

class BeatSaverRequest extends RefCounted:
	var page := 0
	var type := "text_search"
	var data := ""
	var order := "Relevance"

@export var main_menu_ref: MainMenu
@export var keyboard: OQ_UI2DKeyboard
@onready var item_list := $ItemList as ItemList
@onready var mode_button := $mode as Button
@onready var label := $Label as Label
@onready var httpreq := $HTTPReq as HTTPRequest
@onready var httpdownload := $HTTPDownload as HTTPRequest
@onready var httpcoverdownload := $CoverDownload as HTTPRequest
@onready var httppreviewdownload := $PreviewDownload as HTTPRequest
@onready var placeholder_cover := preload("res://game/data/beepsaber_logo.png")
@onready var goto_maps_by := $gotoMapsBy as Button

var song_data: Array[BeatSaverSongInfo] = []
var downloading: Array = []
var back_stack: Array[BeatSaverRequest] = []
var prev_request: BeatSaverRequest
var search_word := ""
var item_selected := -1
var current_list := 0
var next_page_available := -1
var _revision := 0
var _download_revision := 0
var _selection_revision := 0
var _current_cover_to_download := 0
var _loading := false
var _browser_open := false
var _keyboard_active := false
var _progress_elapsed := 0.0
var _download_errors: Dictionary = {}

func _ready() -> void:
	for entry in [["Retry", "Retry", _retry], ["LoadMore", "More results", _load_more],
		["Preview", "Listen", _preview], ["CancelDownload", "Cancel", _cancel_downloads]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.pressed.connect(entry[2])
		add_child(button)
	for node_name in ["SearchStatus", "Title", "Artist"]:
		var text_label := Label.new()
		text_label.name = node_name
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(text_label)
	var progress := ProgressBar.new()
	progress.name = "Progress"
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	preload("res://game/ui/BeatSaverPanel/BeatSaverStyle.gd").apply(self)
	for request in [httpreq, httpdownload, httpcoverdownload, httppreviewdownload]:
		request.timeout = 25.0
		request.use_threads = OS.get_name() != "Web"
	httpdownload.timeout = 120.0
	httpreq.body_size_limit = 4 * 1024 * 1024
	httpcoverdownload.body_size_limit = 8 * 1024 * 1024
	httppreviewdownload.body_size_limit = 16 * 1024 * 1024
	httpdownload.body_size_limit = 160 * 1024 * 1024
	# Bind each response to its request generation, including cancelled requests.
	for request in [httpreq, httpcoverdownload, httppreviewdownload]:
		for connection in request.request_completed.get_connections():
			request.request_completed.disconnect(connection.callable)
	if keyboard != null:
		keyboard.text_input_enter.connect(_text_input_enter)
		keyboard.text_input_cancel.connect(_text_input_cancel)
	main_menu_ref.song_list_changed.connect(on_song_list_changed)
	UI_AudioEngine.attach_children(self)
	_reset_details()
	$SearchStatus.text = "Search for a song or artist, for example Levitating."
	$Retry.hide()
	$back.hide()
	$LoadMore.disabled = true
	$CancelDownload.hide()
	$Progress.hide()
	label.text = ""
	mode_button.text = "Sort: Relevance"
	var canvas := _canvas()
	if canvas != null:
		canvas.visibility_changed.connect(_on_BeatSaverPanel_visibility_changed)

func _canvas() -> OQ_UI2DCanvas:
	var node := get_parent()
	while node != null:
		if node is OQ_UI2DCanvas: return node
		node = node.get_parent()
	return null

func _show() -> void:
	_browser_open = true
	var canvas := _canvas()
	if canvas != null: canvas._show()
	else: show()
	if prev_request == null:
		search("")

func _hide() -> void:
	_browser_open = false
	_cancel_browsing()
	var canvas := _canvas()
	if canvas != null: canvas._hide()
	else: hide()

func _cancel_browsing() -> void:
	_revision += 1
	_selection_revision += 1
	httpreq.cancel_request()
	httpcoverdownload.cancel_request()
	httppreviewdownload.cancel_request()
	_loading = false
	_keyboard_active = false
	if keyboard != null: keyboard._hide()
	main_menu_ref.stop_preview()
	$Retry.visible = prev_request != null
	$LoadMore.disabled = next_page_available < 0

func _on_BeatSaverPanel_visibility_changed() -> void:
	var canvas := _canvas()
	if canvas != null and not canvas.is_visible_in_tree():
		_browser_open = false
		_cancel_browsing()

static func request_url(req: BeatSaverRequest) -> String:
	if req.type == "uploader":
		return API + "/maps/uploader/%s/%d" % [req.data.uri_encode(), req.page]
	return API + "/search/text/%d?q=%s&order=%s&automapper=true&pageSize=20" % [req.page, req.data.uri_encode(), req.order]

func _request(request: HTTPRequest, url: String, callback: Callable) -> Error:
	request.cancel_request()
	for connection in request.request_completed.get_connections():
		request.request_completed.disconnect(connection.callable)
	request.request_completed.connect(callback)
	return request.request(url, PackedStringArray(["User-Agent: OpenSaberPlus/0.8"]))

func search(query: String) -> void:
	_add_to_back_stack(prev_request)
	search_word = query.strip_edges().left(200)
	prev_request = BeatSaverRequest.new()
	prev_request.data = search_word
	prev_request.order = SORTS[current_list]
	update_list(prev_request)

func update_list(req: BeatSaverRequest) -> void:
	_revision += 1
	_selection_revision += 1
	httppreviewdownload.cancel_request()
	main_menu_ref.stop_preview()
	httpcoverdownload.cancel_request()
	_loading = true
	$Retry.hide()
	$LoadMore.disabled = true
	$SearchStatus.text = "Searching BeatSaver…"
	$search.text = "Search song or artist…" if req.data.is_empty() else "Search: " + req.data
	mode_button.text = "Sort: " + SORTS[current_list]
	if req.page == 0:
		item_list.clear()
		song_data.clear()
		item_selected = -1
		_current_cover_to_download = 0
		next_page_available = -1
		_reset_details()
	var error := _request(httpreq, request_url(req), _on_HTTPRequest_request_completed.bind(_revision))
	if error != OK:
		_search_error("Cannot connect. Check Wi-Fi and retry.")

func _add_to_back_stack(request: BeatSaverRequest) -> void:
	if request == null: return
	var copy := BeatSaverRequest.new()
	copy.page = 0
	copy.type = request.type
	copy.data = request.data
	copy.order = request.order
	back_stack.append(copy)
	if back_stack.size() > MAX_BACK_STACK_DEPTH: back_stack.pop_front()

func _get_selected_song() -> BeatSaverSongInfo:
	return song_data[item_selected] if item_selected >= 0 and item_selected < song_data.size() else null

func _search_error(message: String) -> void:
	_loading = false
	$SearchStatus.text = message
	$Retry.show()
	$LoadMore.disabled = true

func _on_HTTPRequest_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, revision: int = -1) -> void:
	if revision >= 0 and revision != _revision: return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_search_error("Too many requests. Wait a moment, then retry." if response_code == 429 else "Search failed. Check Wi-Fi and retry. (HTTP %d)" % response_code)
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		_search_error("BeatSaver returned an invalid response. Retry.")
		return
	var data: Variant = parser.data
	if not data is Dictionary or not data.get("docs") is Array:
		_search_error("BeatSaver returned an invalid response. Retry.")
		return
	var docs: Array = data.docs
	for raw in docs:
		if not raw is Dictionary: continue
		var song := BeatSaverSongInfo.new(raw)
		if song.versions.is_empty(): continue
		var hash_name := str(song.versions[0].hash)
		var duplicate := false
		for existing in song_data:
			if str(existing.versions[0].hash) == hash_name: duplicate = true
		if duplicate: continue
		song_data.append(song)
		var index := item_list.add_item(song.song_name + "\n" + song.song_author_name, placeholder_cover)
		item_list.set_item_metadata(index, hash_name)
		item_list.set_item_tooltip(index, "Map: " + song.level_author_name)
	var page := prev_request.page if prev_request != null else 0
	var pages := int(Utils.get_float(Utils.get_dict(data, "info", {}), "pages", -1))
	next_page_available = page + 1 if not docs.is_empty() and (pages < 0 or page + 1 < pages) else -1
	_loading = false
	$LoadMore.disabled = next_page_available < 0
	$back.visible = not back_stack.is_empty()
	$SearchStatus.text = "%d maps  •  Select a result to download" % song_data.size() if not song_data.is_empty() else "No results. Try another song or artist."
	on_song_list_changed()
	update_next_cover()

func _reset_details() -> void:
	$Title.text = "Find your next track"
	$Artist.text = "Song, artist or mapper"
	$TextureRect.texture = placeholder_cover
	$song_data.text = "Choose a result to see its difficulties and download it to your headset."
	goto_maps_by.hide()
	_update_action()

func _on_ItemList_item_selected(index: int) -> void:
	item_selected = index
	_selection_revision += 1
	httppreviewdownload.cancel_request()
	main_menu_ref.stop_preview()
	$Preview.text = "Listen"
	var song := _get_selected_song()
	if song == null: return
	$Title.text = song.song_name
	$Artist.text = song.song_author_name + "\nMap: " + song.level_author_name
	$TextureRect.texture = item_list.get_item_icon(index)
	var difficulties: Array[String] = []
	for diff in Utils.get_array(song.versions[0], "diffs", []):
		if diff is Dictionary:
			var title := "%s %s" % [diff.get("characteristic", ""), diff.get("difficulty", "")]
			if not difficulties.has(title): difficulties.append(title)
	$song_data.text = "%d:%02d  •  %.0f BPM  •  %d%% rating\n%s" % [int(song.duration) / 60, int(song.duration) % 60, song.bpm, roundi(song.rating * 100), ", ".join(difficulties)]
	$song_data.tooltip_text = song.description
	goto_maps_by.text = "More by " + song.level_author_name
	goto_maps_by.visible = song.uploader_id >= 0
	_update_action()

func _update_action() -> void:
	var button := $download as Button
	var song := _get_selected_song()
	button.disabled = song == null
	$Preview.disabled = song == null
	button.text = "SELECT A SONG"
	if song == null: return
	var version: Dictionary = song.versions[0]
	var hash_name := str(version.hash)
	$Preview.disabled = not _media_url(str(version.get("previewURL", "")))
	if main_menu_ref.all_song_hashes.has(hash_name): button.text = "OPEN IN LIBRARY"
	elif _is_queued(hash_name):
		button.text = "DOWNLOADING…" if not downloading.is_empty() and downloading[0][1].hash == hash_name else "QUEUED"
		button.disabled = true
	else:
		button.text = "RETRY DOWNLOAD" if _download_errors.has(hash_name) else "DOWNLOAD"
		button.disabled = not _media_url(str(version.get("downloadURL", "")))

func on_song_list_changed() -> void:
	for index in item_list.item_count:
		var hash_name := str(item_list.get_item_metadata(index))
		item_list.set_item_disabled(index, _is_queued(hash_name))
		if index < song_data.size():
			var suffix := "  ✓" if main_menu_ref.all_song_hashes.has(hash_name) else ""
			item_list.set_item_text(index, song_data[index].song_name + suffix + "\n" + song_data[index].song_author_name)
	_update_action()

static func _media_url(url: String) -> bool:
	if not url.begins_with("https://"): return false
	var host := url.trim_prefix("https://").get_slice("/", 0).to_lower()
	return host == "beatsaver.com" or host.ends_with(".beatsaver.com")

func _on_download_button_up() -> void:
	var song := _get_selected_song()
	if song == null: return
	var version: Dictionary = song.versions[0]
	var hash_name := str(version.hash)
	if main_menu_ref.all_song_hashes.has(hash_name):
		if main_menu_ref.select_downloaded_song(hash_name): _on_CloseButton_pressed()
		else:
			label.text = "This map format is not supported yet. Choose another map."
		return
	if _is_queued(hash_name) or not _media_url(str(version.get("downloadURL", ""))): return
	_download_errors.erase(hash_name)
	downloading.append([song.name, version.duplicate(true)])
	if downloading.size() == 1: download_next()
	on_song_list_changed()

func _is_queued(hash_name: String) -> bool:
	for entry in downloading:
		if str(entry[1].get("hash", "")) == hash_name: return true
	return false

func download_next() -> void:
	if downloading.is_empty(): return
	_download_revision += 1
	var url := str(downloading[0][1].get("downloadURL", ""))
	var error := _request(httpdownload, url, _on_HTTPRequest_download_completed.bind(_download_revision)) if _media_url(url) else ERR_INVALID_PARAMETER
	if error != OK:
		_on_HTTPRequest_download_completed.call_deferred(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), _download_revision)
	label.text = "Downloading: " + str(downloading[0][0])
	label.show()
	$CancelDownload.show()
	$Progress.show()
	$Progress.value = 0
	_update_action()

func _process(delta: float) -> void:
	_progress_elapsed += delta
	if downloading.is_empty() or _progress_elapsed < 0.2: return
	_progress_elapsed = 0
	var total := httpdownload.get_body_size()
	var received := httpdownload.get_downloaded_bytes()
	$Progress.value = 100.0 * received / total if total > 0 else 0
	label.text = "%s  •  %.1f MB%s  •  %d queued" % [downloading[0][0], received / 1048576.0, " / %.1f MB" % (total / 1048576.0) if total > 0 else "", downloading.size() - 1]
	label.tooltip_text = label.text

func _cancel_downloads() -> void:
	_download_revision += 1
	httpdownload.cancel_request()
	downloading.clear()
	$Progress.hide()
	$CancelDownload.hide()
	label.text = "Downloads cancelled. You can try again."
	on_song_list_changed()

func _preview() -> void:
	var song := _get_selected_song()
	if song == null: return
	var url := str(song.versions[0].get("previewURL", ""))
	if not _media_url(url): return
	_selection_revision += 1
	main_menu_ref.stop_preview()
	var error := _request(httppreviewdownload, url, _on_preview_download_completed.bind(_selection_revision))
	$Preview.text = "Loading…" if error == OK else "Retry preview"

func _on_preview_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, revision: int = -1) -> void:
	if revision >= 0 and (revision != _selection_revision or not _browser_open): return
	$Preview.text = "Listen"
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		main_menu_ref.play_preview(body, 0, -1, "mp3")
	else: $Preview.text = "Retry preview"

func _on_search_button_up() -> void:
	_keyboard_active = true
	keyboard._text_edit.text = search_word
	keyboard._show()
	keyboard._text_edit.grab_focus()

func _text_input_enter(text: String) -> void:
	if not _keyboard_active or not _browser_open: return
	_keyboard_active = false
	keyboard._hide()
	search(text)

func _text_input_cancel() -> void:
	if not _keyboard_active: return
	_keyboard_active = false
	keyboard._hide()

func _retry() -> void:
	if prev_request != null and not _loading: update_list(prev_request)

func _load_more() -> void:
	if _loading or next_page_available < 0 or prev_request == null: return
	prev_request.page = next_page_available
	update_list(prev_request)

func _on_mode_button_up() -> void:
	current_list = (current_list + 1) % SORTS.size()
	search(search_word)

func _on_back_pressed() -> void:
	if back_stack.is_empty(): return
	prev_request = back_stack.pop_back()
	search_word = prev_request.data
	current_list = maxi(0, SORTS.find(prev_request.order))
	update_list(prev_request)

func _on_gotoMapsBy_pressed() -> void:
	var song := _get_selected_song()
	if song == null or song.uploader_id < 0: return
	_add_to_back_stack(prev_request)
	prev_request = BeatSaverRequest.new()
	prev_request.type = "uploader"
	prev_request.data = str(song.uploader_id)
	update_list(prev_request)

func update_next_cover() -> void:
	while _current_cover_to_download < song_data.size():
		var url := str(song_data[_current_cover_to_download].versions[0].get("coverURL", ""))
		if _media_url(url):
			var error := _request(httpcoverdownload, url, _update_cover.bind(_revision, _current_cover_to_download))
			if error == OK: return
		_current_cover_to_download += 1

func _update_cover(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, revision: int = -1, index: int = -1) -> void:
	if revision >= 0 and revision != _revision: return
	if index < 0: index = _current_cover_to_download
	if index >= item_list.item_count: return
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var img := Image.new()
		var error := img.load_jpg_from_buffer(body)
		if error != OK: error = img.load_png_from_buffer(body)
		if error == OK and not img.is_empty():
			var ratio := minf(1.0, 256.0 / maxf(img.get_width(), img.get_height()))
			img.resize(maxi(1, int(img.get_width() * ratio)), maxi(1, int(img.get_height() * ratio)))
			var texture := ImageTexture.create_from_image(img)
			item_list.set_item_icon(index, texture)
			if item_selected == index: $TextureRect.texture = texture
	_current_cover_to_download = index + 1
	update_next_cover()

func _on_CloseButton_pressed() -> void:
	_hide()
	main_menu_ref.beepsaber_game._transition_game_state(main_menu_ref.beepsaber_game.gamestate_mapselection)
func _on_HTTPRequest_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, revision: int = -1) -> void:
	if revision >= 0 and revision != _download_revision: return
	var error := ""
	if downloading.is_empty(): return
	var hash_name: String = downloading[0][1].get("hash", "")
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		error = "Download failed (HTTP %d). Try again." % response_code
	elif hash_name.is_empty() or not hash_name.is_valid_hex_number(false):
		error = "Download failed: invalid map identifier."
	var temp := Constants.APPDATA_PATH.path_join("temp").path_join(hash_name)
	var zip_path := temp + ".zip"
	var destination := Constants.APPDATA_PATH.path_join("Songs").path_join(hash_name)
	var staged := error.is_empty()
	if staged:
		Utils.remove_tree(temp)
		DirAccess.make_dir_recursive_absolute(temp)
		var file := FileAccess.open(zip_path, FileAccess.WRITE)
		if file == null:
			error = "Cannot save download. Check storage space."
		else:
			file.store_buffer(body)
			file.close()
			if Utils.unzip(zip_path, temp) != OK:
				error = "Download failed: invalid ZIP or extraction error."
	if error.is_empty():
		var info := Map.load_map_info(temp + "/")
		if info == null or not MapValidator.safe_relative_file(info.song_filename) or not info.have_song or info.difficulty_beatmaps.is_empty():
			error = "Download is incomplete: song or map information missing."
		else:
			var playable := false
			for difficulty in info.difficulty_beatmaps:
				if not MapValidator.safe_relative_file(difficulty.beatmap_filename) or Utils.binary_to_json(Utils.read_binary_file(temp, difficulty.beatmap_filename)).is_empty():
					error = "Download is incomplete: missing or invalid difficulty."
				elif MapValidator.validate(info, difficulty, Utils.binary_to_json(Utils.read_binary_file(temp, difficulty.beatmap_filename))).errors.is_empty():
					playable = true
			if error.is_empty() and not playable:
				error = "This map needs unsupported features. Try another version or mapper."
	if error.is_empty():
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if DirAccess.dir_exists_absolute(destination):
			# A previously complete map is never overwritten by a staged download.
			Utils.remove_tree(temp)
		elif DirAccess.rename_absolute(temp, destination) != OK:
			error = "Cannot install download. Check storage space."
	if staged:
		Utils.remove_tree(temp)
		DirAccess.remove_absolute(zip_path)
	downloading.pop_front()
	if error.is_empty():
		main_menu_ref._load_playlists()
		if _browser_open: main_menu_ref.stop_preview()
		_download_errors.erase(hash_name)
	else:
		_download_errors[hash_name] = error
	on_song_list_changed()
	label.text = "Installed! Select Open in library." if error.is_empty() else error
	label.tooltip_text = label.text
	label.visible = true
	if not error.is_empty():
		vr.log_warning(error)
	if not downloading.is_empty():
		download_next()
	else:
		$Progress.hide()
		$CancelDownload.hide()
