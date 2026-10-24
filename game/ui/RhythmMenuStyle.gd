extends RefCounted
## Presentation only: existing node paths, signals and VR hit targets are retained.
## Fixed 1408 x 640 canvas matches the headset's OQ_UI2DCanvas surface.

const CYAN := Color("27bfff")
const INK := Color("091321")
const MUTED := Color("9caec3")

static func box(fill: Color, line: Color = Color.TRANSPARENT, border: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line
	style.set_border_width_all(border)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = preload("res://OQ_Toolkit/OQ_UI2D/theme/Roboto-Medium.ttf")
	result.default_font_size = 22
	var idle := box(Color(0.035, 0.075, 0.12, 0.88))
	var hover := box(Color("16496b"), CYAN, 1)
	var selected := box(Color("e0f7ff"), Color("84e8ff"), 1)
	selected.shadow_color = Color(0.1, 0.65, 1.0, 0.18)
	selected.shadow_size = 5
	var focus := box(Color.TRANSPARENT, Color("b4e9ff"), 1)
	for kind in ["Button", "OptionButton", "CheckButton"]:
		result.set_stylebox("normal", kind, idle)
		result.set_stylebox("hover", kind, hover)
		result.set_stylebox("pressed", kind, selected)
		result.set_stylebox("hover_pressed", kind, selected)
		result.set_stylebox("focus", kind, focus)
		result.set_stylebox("disabled", kind, box(Color("0a1521")))
		result.set_color("font_color", kind, Color("edf5ff"))
		result.set_color("font_hover_color", kind, Color.WHITE)
		result.set_color("font_pressed_color", kind, INK)
		result.set_color("font_disabled_color", kind, Color("56677c"))
	result.set_color("font_color", "Label", Color("edf5ff"))
	result.set_stylebox("panel", "Panel", box(Color(0.025, 0.055, 0.09, 0.94), Color(0.22, 0.55, 0.75, 0.22), 1))
	result.set_stylebox("panel", "ItemList", box(Color(0.02, 0.04, 0.07, 0.25)))
	result.set_stylebox("selected", "ItemList", selected)
	result.set_stylebox("selected_focus", "ItemList", selected)
	result.set_stylebox("hovered", "ItemList", hover)
	result.set_stylebox("focus", "ItemList", focus)
	result.set_color("font_color", "ItemList", Color("e9f1fb"))
	result.set_color("font_selected_color", "ItemList", INK)
	result.set_constant("v_separation", "ItemList", 8)
	result.set_constant("h_separation", "ItemList", 12)
	result.set_constant("icon_margin", "ItemList", 12)
	result.set_stylebox("panel", "PopupMenu", box(INK, CYAN, 1))
	result.set_stylebox("hover", "PopupMenu", selected)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_color("font_color", "PopupMenu", Color.WHITE)
	result.set_stylebox("scroll", "VScrollBar", box(Color("122337")))
	result.set_stylebox("grabber", "VScrollBar", box(Color("467895")))
	result.set_stylebox("grabber_highlight", "VScrollBar", box(CYAN))
	result.set_stylebox("grabber_pressed", "VScrollBar", box(CYAN))
	return result

static func clear_legacy_styles(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.theme = null
		for property in control.get_property_list():
			var key := str(property.name)
			if key.begins_with("theme_override_"):
				control.set(key, null)
	for child in node.get_children():
		clear_legacy_styles(child)

static func apply_secondary(panel: Control) -> void:
	# Preserve established font sizes/layout on settings, pause and score panels.
	panel.theme = make_theme()
	_clear_panel_frames(panel)

static func _clear_panel_frames(node: Node) -> void:
	if node is Control:
		var control := node as Control
		for property in control.get_property_list():
			var key := str(property.name)
			if key.begins_with("theme_override_styles/"):
				control.set(key, null)
	for child in node.get_children():
		_clear_panel_frames(child)

static func place(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = rect.position
	node.size = rect.size

static func label(menu: Control, title: String, rect: Rect2, font_size: int, tint: Color = Color.WHITE, node_name: String = "") -> Label:
	var item := Label.new()
	if not node_name.is_empty(): item.name = node_name
	item.text = title
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", tint)
	menu.add_child(item)
	place(item, rect)
	return item

static func backdrop(menu: Control, rect: Rect2) -> void:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(panel)
	menu.move_child(panel, 0)
	place(panel, rect)

static func apply(menu: Control) -> void:
	clear_legacy_styles(menu)
	menu.theme = make_theme()
	menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var discover := Button.new()
	discover.name = "Discover_Button"
	discover.text = "DISCOVER SONGS  ›"
	discover.pressed.connect(menu._on_discover_pressed)
	menu.add_child(discover)
	place(discover, Rect2(940, 24, 306, 44))
	discover.add_theme_stylebox_override("normal", box(Color("0d4360"), CYAN, 1))
	backdrop(menu, Rect2(16, 84, 268, 468))
	backdrop(menu, Rect2(300, 84, 592, 468))
	backdrop(menu, Rect2(908, 84, 484, 468))
	var atmosphere := preload("res://game/ui/MenuAtmosphere.gd").new()
	menu.add_child(atmosphere)
	menu.move_child(atmosphere, 0)
	place(atmosphere, Rect2(0, 0, 1408, 640))
	label(menu, "OPEN", Rect2(40, 12, 90, 36), 28, Color("ff657b"))
	label(menu, "SABER", Rect2(126, 12, 130, 36), 28, CYAN)
	label(menu, "FIND YOUR RHYTHM", Rect2(40, 48, 230, 22), 14, MUTED)
	var heading := label(menu, "SOLO", Rect2(320, 10, 550, 36), 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := label(menu, "YOUR MUSIC. YOUR MOMENT.", Rect2(320, 46, 550, 22), 14, Color("8edfff"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(menu, "PLAYER SETUP", Rect2(32, 96, 186, 36), 20, MUTED)
	label(menu, "CHOOSE YOUR DIFFICULTY", Rect2(928, 358, 420, 24), 16, CYAN)
	label(menu, "Select a song", Rect2(1100, 116, 268, 82), 28, Color.WHITE, "SongTitle_Label")
	label(menu, "", Rect2(1100, 204, 268, 60), 18, MUTED, "Artist_Label")
	label(menu, "NOW SELECTED", Rect2(928, 96, 400, 20), 14, CYAN)
	label(menu, "YOUR LIBRARY", Rect2(316, 96, 310, 28), 19, Color.WHITE, "LibraryCount_Label")
	for name in ["SongTitle_Label", "Artist_Label"]:
		var title := menu.get_node(name) as Label
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.max_lines_visible = 2
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var rectangles := {
		"Search_Button": Rect2(316, 134, 120, 40),
		"Search_Button/Label": Rect2(128, 0, 180, 40),
		"PlaylistSelector": Rect2(650, 134, 224, 40),
		"SongsMenu": Rect2(316, 186, 560, 350),
		"cover": Rect2(928, 124, 152, 152),
		"SongInfo_Label": Rect2(928, 280, 440, 76),
		"DifficultyMenu": Rect2(928, 386, 440, 82),
		"Play_Button": Rect2(1012, 482, 356, 54),
		"Favorite_Button": Rect2(928, 482, 68, 54),
		"Delete_Button": Rect2(1012, 564, 148, 44),
		"LoadPlaylists_Button": Rect2(316, 564, 196, 44),
		"Settings_Button": Rect2(24, 564, 148, 44),
		"Exit_Button": Rect2(1180, 564, 196, 44),
		"Licenses": Rect2(184, 564, 112, 44),
		"Reset_Button": Rect2(224, 94, 44, 40),
		"upload_url": Rect2(532, 560, 460, 54),
		"version": Rect2(1270, 26, 108, 26),
		"Modifiers": Rect2(32, 148, 236, 114),
		"Modifiers2": Rect2(32, 276, 236, 114),
		"Modifiers3": Rect2(32, 404, 236, 132),
	}
	for path in rectangles:
		place(menu.get_node(path) as Control, rectangles[path])
	for path in ["Modifiers", "Modifiers2", "Modifiers3"]:
		(menu.get_node(path) as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for path in ["Modifiers/Health", "Modifiers2/Claws", "Modifiers3/Flip"]:
		var control := menu.get_node(path) as Control
		for row in 3:
			control.add_theme_font_size_override("font_size", 18)
			place(control, Rect2(0, 0 if row == 0 else 40, 236, 36))
			if row < 2:
				# Legacy controls are nested; preserve their paths for signals.
				for child in control.get_children():
					if child is BaseButton:
						control = child
						break
	var songs := menu.get_node("SongsMenu") as ItemList
	songs.fixed_icon_size = Vector2i(56, 56)
	songs.max_text_lines = 2
	songs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var difficulties := menu.get_node("DifficultyMenu") as ItemList
	difficulties.max_columns = 3
	difficulties.same_column_width = true
	difficulties.fixed_column_width = 128
	difficulties.add_theme_font_size_override("font_size", 18)
	var description := menu.get_node("SongInfo_Label") as Label
	description.add_theme_font_size_override("font_size", 16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 4
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(menu.get_node("Search_Button/Label") as Label).clip_text = true
	(menu.get_node("Search_Button/Label") as Label).add_theme_font_size_override("font_size", 18)
	for name in ["upload_url", "version"]:
		(menu.get_node(name) as Label).add_theme_font_size_override("font_size", 16)
		(menu.get_node(name) as Label).add_theme_color_override("font_color", MUTED)
	for name in ["Favorite_Button", "Reset_Button"]:
		(menu.get_node(name) as Button).add_theme_font_size_override("font_size", 26)
	(menu.get_node("LoadPlaylists_Button") as Button).text = "Refresh songs"
	var play := menu.get_node("Play_Button") as Button
	play.text = "PLAY  ›"
	play.add_theme_font_size_override("font_size", 28)
	var play_style := box(Color("008acb"), Color("58dfff"), 2)
	play_style.shadow_color = Color(0.0, 0.6, 1.0, 0.28)
	play_style.shadow_size = 7
	play.add_theme_stylebox_override("normal", play_style)
	play.add_theme_stylebox_override("hover", box(Color("14b8ef"), Color.WHITE, 2))
	(menu.get_node("Licenses") as Button).add_theme_font_size_override("font_size", 18)
