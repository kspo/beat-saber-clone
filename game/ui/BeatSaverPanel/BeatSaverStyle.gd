extends RefCounted

static func apply(panel: Control) -> void:
	var style := preload("res://game/ui/RhythmMenuStyle.gd")
	style.clear_legacy_styles(panel)
	panel.theme = style.make_theme()
	panel.size = Vector2(1408, 640)
	panel.add_theme_stylebox_override("panel", style.box(Color("081321"), Color("184b68"), 1))
	style.label(panel, "DISCOVER MUSIC", Rect2(28, 14, 630, 40), 30, style.CYAN)
	style.label(panel, "Search BeatSaver. Download here. Play anytime.", Rect2(28, 54, 800, 28), 18, style.MUTED)
	var rects := {
		"CloseButton": Rect2(1136, 24, 244, 48),
		"search": Rect2(28, 100, 650, 52),
		"mode": Rect2(694, 100, 210, 52),
		"back": Rect2(920, 100, 210, 52),
		"Retry": Rect2(1146, 100, 234, 52),
		"SearchStatus": Rect2(28, 162, 850, 30),
		"ItemList": Rect2(28, 202, 740, 328),
		"TextureRect": Rect2(792, 202, 160, 160),
		"Title": Rect2(976, 202, 404, 72),
		"Artist": Rect2(976, 282, 404, 76),
		"song_data": Rect2(792, 374, 588, 94),
		"download": Rect2(792, 482, 330, 48),
		"Preview": Rect2(1138, 482, 242, 48),
		"gotoMapsBy": Rect2(28, 542, 360, 42),
		"LoadMore": Rect2(404, 542, 364, 42),
		"Label": Rect2(792, 542, 400, 36),
		"CancelDownload": Rect2(1208, 542, 172, 42),
		"Progress": Rect2(792, 586, 588, 10),
		"source": Rect2(28, 598, 1352, 26),
	}
	for path in rects:
		style.place(panel.get_node(path), rects[path])
	(panel.get_node("CloseButton") as Button).text = "‹  MY LIBRARY"
	(panel.get_node("search") as Button).text = "Search song or artist…"
	(panel.get_node("back") as Button).text = "Previous search"
	(panel.get_node("source") as Label).text = "BEATSAVER  /  COMMUNITY MAPS     •     Compatibility is checked before play."
	(panel.get_node("source") as Label).add_theme_font_size_override("font_size", 16)
	(panel.get_node("source") as Label).add_theme_color_override("font_color", style.MUTED)
	var songs := panel.get_node("ItemList") as ItemList
	songs.clear()
	songs.fixed_icon_size = Vector2i(64, 64)
	songs.max_text_lines = 2
	songs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for path in ["Title", "Artist"]:
		var title := panel.get_node(path) as Label
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.max_lines_visible = 2
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(panel.get_node("Title") as Label).add_theme_font_size_override("font_size", 26)
	(panel.get_node("Artist") as Label).add_theme_color_override("font_color", style.MUTED)
	(panel.get_node("Label") as Label).add_theme_font_size_override("font_size", 16)
	(panel.get_node("Label") as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(panel.get_node("Label") as Label).max_lines_visible = 2
	(panel.get_node("Label") as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(panel.get_node("SearchStatus") as Label).clip_text = true
	(panel.get_node("song_data") as RichTextLabel).bbcode_enabled = false
	(panel.get_node("song_data") as RichTextLabel).add_theme_font_size_override("normal_font_size", 18)
	var action := panel.get_node("download") as Button
	action.add_theme_stylebox_override("normal", style.box(Color("008acb"), style.CYAN, 2))
	action.add_theme_font_size_override("font_size", 22)
	for path in ["search", "mode", "gotoMapsBy"]:
		(panel.get_node(path) as Button).clip_text = true
	var progress := panel.get_node("Progress") as ProgressBar
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", style.box(Color("14293b")))
	progress.add_theme_stylebox_override("fill", style.box(style.CYAN))
