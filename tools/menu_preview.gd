extends Control

# Flat render of a 2D menu panel (default: main menu) over a stage-like
# backdrop, for reviewing UI styling without a headset.
# Usage: Godot --path . tools/menu_preview.tscn -- out.png [res://scene.tscn]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[1] if args.size() > 1 else "res://game/BeepSaberMainMenu.tscn"
	var backdrop := ColorRect.new()
	backdrop.color = Color("070a14")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := (load(scene_path) as PackedScene).instantiate() as Control
	if "main_song_player_ref" in panel:
		var player := AudioStreamPlayer.new()
		add_child(player)
		panel.set(&"main_song_player_ref", player)
	add_child(panel)
	await get_tree().process_frame
	get_window().size = Vector2i(maxi(int(panel.size.x), 400), maxi(int(panel.size.y), 300))
	for frame in 10: await get_tree().process_frame
	# Show the selected-song state when the library has entries.
	var songs := panel.get_node_or_null("SongsMenu") as ItemList
	if songs != null and songs.item_count > 0 and panel.has_method(&"_select_song"):
		songs.select(0)
		panel.call(&"_select_song", 0)
	for frame in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not args.is_empty():
		get_viewport().get_texture().get_image().save_png(args[0])
		get_tree().quit()
