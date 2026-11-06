extends Panel
class_name HighscorePanel

signal close()

@export var show_close_button := true
@export var show_song_info := true

@onready var _highscore_list = $Margin/VBox/LeftRight/ScrollContainer/Margin/HighscoresList
@onready var _title = $Margin/VBox/Title
@onready var _song_info = $Margin/VBox/LeftRight/VBox/SongInfo_Label
@onready var _exit_button = $Margin/VBox/Exit_Button
@onready var _song_info_panel = $Margin/VBox/LeftRight/VBox
@onready var _song_heading: Label = $Margin/VBox/SongHeading
@onready var _empty_message: Label = $Margin/VBox/EmptyMessage

func _ready() -> void:
	preload("res://game/ui/RhythmMenuStyle.gd").apply_secondary(self)
	_clear_list()
	_exit_button.visible = show_close_button
	_song_info_panel.visible = show_song_info
	
func load_highscores(map_info: MapInfo, diff_rank: int) -> void:
	
	# clear the high score list
	_clear_list()
	
	diff_rank = HighscoreTable.get_rank_key(diff_rank)
	
	# populate title text
	set_title("LOCAL LEADERBOARD · TOP 10")
	_song_heading.text = "%s — %s\n%s" % [map_info.song_name, map_info.song_author_name, _get_difficulty_name(map_info, diff_rank)]
	
	# populate song info
	_song_info.text = """Artist: %s
		Song: %s
		Map Author: %s""" % [map_info.song_author_name, map_info.song_name, map_info.level_author_name]
		
	# TODO populate song artwork
	
	var records := Highscores.get_records(map_info,diff_rank)
	_empty_message.visible = records.is_empty()
	_empty_message.text = "No saved scores for this song and settings yet."
	($Margin/VBox/LeftRight/ScrollContainer as ScrollContainer).scroll_vertical = 0
	var idx = 1
	for record in records:
		# Construct owned children explicitly. Duplicating a detached scene row
		# can lose its children after the original scene-owned row is freed.
		var new_row := HBoxContainer.new()
		new_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rank_label := Label.new()
		rank_label.custom_minimum_size.x = 50
		rank_label.text = "%d." % idx
		new_row.add_child(rank_label)
		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text = str(record.player_name)
		new_row.add_child(name_label)
		var score_label := Label.new()
		score_label.custom_minimum_size.x = 120
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.text = str(int(record.score))
		new_row.add_child(score_label)
		var date_label := Label.new()
		date_label.custom_minimum_size.x = 150
		date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		date_label.add_theme_font_size_override("font_size", 18)
		date_label.text = Time.get_date_string_from_unix_time(int(record.epoch_time)) if record.has("epoch_time") else "—"
		new_row.add_child(date_label)
		
		_highscore_list.add_child(new_row)
		idx += 1
		
func set_title(title_text):
	_title.text = title_text
	
# clears all rows from the highscore table
func _clear_list():
	for c in _highscore_list.get_children():
		_highscore_list.remove_child(c)
		c.queue_free()
	
func _get_difficulty_name(map_info: MapInfo, diff_rank: int) -> String:
	var difficulty := diff_rank & Constants.DIFFICULTY_MASK
	var width := HighscoreTable.get_width_from_rank(diff_rank)
	var speed := HighscoreTable.get_speed_from_rank(diff_rank)
	var game_type := ( ("Health" if (diff_rank & Constants.DIFFICULTY_HEALTH) != 0 else "No Health") +
					 ("" if (diff_rank & Constants.DIFFICULTY_BOMBS) != 0 else ", No Bombs") + 
					 ("" if (diff_rank & Constants.DIFFICULTY_ARROWS) != 0 else ", No Arrows") +
					 (", Small" if ((diff_rank & Constants.DIFFICULTY_BLOCK_SIZE_MASK) == Constants.DIFFICULTY_BLOCK_SIZE_SMALL) else "") + 
					 (", Big" if ((diff_rank & Constants.DIFFICULTY_BLOCK_SIZE_MASK) == Constants.DIFFICULTY_BLOCK_SIZE_BIG) else "") + 
					 (", Giant" if ((diff_rank & Constants.DIFFICULTY_BLOCK_SIZE_MASK) == Constants.DIFFICULTY_BLOCK_SIZE_GIANT) else "") + 
					 (", Short Sword" if (diff_rank & Constants.DIFFICULTY_CLAWS) != 0 else "") +
					 ((", Stretch %d%% " % width) if (width != 100) else "") +
					 ((", Speed %d%% " % speed) if (speed != 100) else "") +
					 ((", %s " % Constants.FLIPS[Settings.flip][1] if Settings.flip != 0 else "")) +
					 ((", %s " % Constants.FLIPS[Settings.handedness][1] if Settings.handedness != 0 else ""))
					 )
	for beat_map in map_info.difficulty_beatmaps:
		if beat_map.difficulty_rank == (diff_rank & Constants.DIFFICULTY_MASK):
			return beat_map.difficulty + ", " + game_type
	return ('Rank %d' % (diff_rank & Constants.DIFFICULTY_MASK)) + " " + game_type

func _on_Exit_Button_pressed() -> void:
	close.emit()
