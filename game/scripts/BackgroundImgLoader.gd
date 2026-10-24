extends RefCounted

class ImgLoadRequest:
	extends RefCounted
	
	var path: String
	var file: String
	var callback_func: Callable
	var is_main_cover: bool
	var index: int
	var thread := Thread.new()
	var cache_key: String

var _img_load_request_queue: Array[ImgLoadRequest] = []

# variable used to keep track of how many threads are currently loading images
var _running_img_load_threads := 0
var _active_requests: Array[ImgLoadRequest] = []
var _shutting_down := false

const CACHE_LIMIT := 64
var _texture_cache: Dictionary = {}
var _cache_order: Array[String] = []
var physical_loads := 0
var _max_img_load_threads: int

func _init(num_threads: int = 2) -> void:
	_max_img_load_threads = num_threads

func load_texture(path: String, file: String, callback_func: Callable, is_main_cover: bool, index: int) -> void:
	if _shutting_down or not MapValidator.safe_relative_file(file): return
	var source := path if path.to_lower().ends_with(".zip") else path.path_join(file)
	var key := "%s|%s|%d|%s" % [source, file, FileAccess.get_modified_time(source), is_main_cover]
	if _texture_cache.has(key):
		_cache_order.erase(key)
		_cache_order.append(key)
		callback_func.call(_texture_cache[key], is_main_cover, index)
		return
	var new_req := ImgLoadRequest.new()
	new_req.cache_key = key
	new_req.path = path
	new_req.file = file
	new_req.callback_func = callback_func
	new_req.is_main_cover = is_main_cover
	new_req.index = index
	_img_load_request_queue.push_back(new_req)
	
	_start_next_img_load()

func _start_next_img_load() -> void:
	while not _shutting_down and not _img_load_request_queue.is_empty() and _running_img_load_threads < _max_img_load_threads:
		var req := _img_load_request_queue.pop_front() as ImgLoadRequest
		_running_img_load_threads += 1
		_active_requests.append(req)
		physical_loads += 1
		if Utils.custom_thread_call(req.thread, _load_img_threaded, [req]) != OK:
			_running_img_load_threads -= 1
			_active_requests.erase(req)

func _load_img_threaded(req: ImgLoadRequest) -> void:
	var data := Utils.read_binary_file(req.path, req.file)
	var img := Image.new()
	if not data.is_empty():
		if req.file.to_lower().ends_with(".png"):
			img.load_png_from_buffer(data)
		elif req.file.to_lower().ends_with(".jpg") or req.file.to_lower().ends_with(".jpeg"):
			img.load_jpg_from_buffer(data)
		else:
			img.load(req.path.path_join(req.file))
	if not img.is_empty():
		var limit := 512 if req.is_main_cover else 128
		var largest := maxi(img.get_width(), img.get_height())
		if largest > limit:
			var ratio := float(limit) / largest
			img.resize(maxi(1, roundi(img.get_width() * ratio)), maxi(1, roundi(img.get_height() * ratio)), Image.INTERPOLATE_BILINEAR)
	# UI callbacks and texture creation must happen on the main thread.
	_complete_load.call_deferred(req, img)

func _complete_load(req: ImgLoadRequest, img: Image) -> void:
	if _shutting_down: return
	_active_requests.erase(req)
	Utils.custom_thread_wait_to_finish(req.thread)
	_running_img_load_threads -= 1
	if not img.is_empty() and req.callback_func.is_valid():
		var texture := ImageTexture.create_from_image(img)
		_texture_cache[req.cache_key] = texture
		_cache_order.erase(req.cache_key)
		_cache_order.append(req.cache_key)
		while _cache_order.size() > CACHE_LIMIT:
			_texture_cache.erase(_cache_order.pop_front())
		req.callback_func.call(texture, req.is_main_cover, req.index)
	_start_next_img_load()

func cancel_pending() -> void:
	_img_load_request_queue.clear()

func shutdown() -> void:
	_shutting_down = true
	_texture_cache.clear()
	_cache_order.clear()
	_img_load_request_queue.clear()
	for req in _active_requests:
		Utils.custom_thread_wait_to_finish(req.thread)
	_active_requests.clear()
	_running_img_load_threads = 0
