extends Node

## Victory Manager
## Handles game completion conditions and victory screen

signal game_completed()
signal level_completed(level_name: String)

# Level configuration
const TOTAL_LEVELS = 3  # Total number of levels
const FINAL_LEVEL_NAME = "level_3"  # Name of the final level

var completed_levels: Array[String] = []
var victory_screen: Control = null
var game_statistics: Dictionary = {}

func _ready():
	add_to_group("victory_manager")
	_initialize_statistics()

func _initialize_statistics():
	game_statistics = {
		"start_time": Time.get_unix_time_from_system(),
		"levels_completed": 0,
		"enemies_defeated": 0,
		"items_collected": 0,
		"deaths": 0,
		"total_play_time": 0.0
	}

func mark_level_completed(level_name: String):
	print("VictoryManager: Level completed - ", level_name)
	
	if level_name not in completed_levels:
		completed_levels.append(level_name)
		game_statistics["levels_completed"] += 1
		level_completed.emit(level_name)
	
	# Check if all levels are completed
	if _is_game_completed():
		_trigger_game_victory()

func _is_game_completed() -> bool:
	return game_statistics["levels_completed"] >= TOTAL_LEVELS

func _trigger_game_victory():
	print("VictoryManager: Game completed!")
	game_statistics["total_play_time"] = Time.get_unix_time_from_system() - game_statistics["start_time"]
	game_completed.emit()
	_show_victory_screen()

func _show_victory_screen():
	print("VictoryManager: Showing victory screen")
	
	# Pause the game
	get_tree().paused = true
	
	# Create victory screen
	_create_victory_screen()

func _create_victory_screen():
	if victory_screen:
		return
	
	victory_screen = Control.new()
	victory_screen.name = "VictoryScreen"
	victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Background
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.9)
	victory_screen.add_child(background)
	
	# Main container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(600, 500)
	main_container.position = Vector2(-300, -250)
	
	# Title
	var title = Label.new()
	title.text = "🎉 Congratulations! 🎉"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	main_container.add_child(title)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(spacer1)
	
	# Statistics
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 10)
	
	var stats_title = Label.new()
	stats_title.text = "Game Statistics"
	stats_title.add_theme_font_size_override("font_size", 24)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(stats_title)
	
	# Create statistics labels
	var stats_labels = [
		"Levels Completed: %d / %d" % [game_statistics["levels_completed"], TOTAL_LEVELS],
		"Enemies Defeated: %d" % game_statistics["enemies_defeated"],
		"Items Collected: %d" % game_statistics["items_collected"],
		"Deaths: %d" % game_statistics["deaths"],
		"Play Time: %s" % _format_time(game_statistics["total_play_time"])
	]
	
	for stat_text in stats_labels:
		var stat_label = Label.new()
		stat_label.text = stat_text
		stat_label.add_theme_font_size_override("font_size", 16)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(stat_label)
	
	main_container.add_child(stats_container)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(spacer2)
	
	# Button container
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	
	# Play Again button
	var play_again_btn = Button.new()
	play_again_btn.text = "Play Again"
	play_again_btn.custom_minimum_size = Vector2(120, 50)
	play_again_btn.pressed.connect(_play_again)
	button_container.add_child(play_again_btn)
	
	# Main Menu button
	var main_menu_btn = Button.new()
	main_menu_btn.text = "Main Menu"
	main_menu_btn.custom_minimum_size = Vector2(120, 50)
	main_menu_btn.pressed.connect(_return_to_main_menu)
	button_container.add_child(main_menu_btn)
	
	# Quit Game button
	var quit_btn = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(120, 50)
	quit_btn.pressed.connect(_quit_game)
	button_container.add_child(quit_btn)
	
	main_container.add_child(button_container)
	victory_screen.add_child(main_container)
	
	# Add to scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(victory_screen)
		victory_screen.z_index = 1000

func _format_time(seconds: float) -> String:
	var hours = int(seconds) / 3600
	var minutes = (int(seconds) % 3600) / 60
	var secs = int(seconds) % 60
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	else:
		return "%02d:%02d" % [minutes, secs]

func _play_again():
	print("VictoryManager: Player chose to play again")
	_reset_game_state()
	get_tree().paused = false
	
	# Clear victory screen
	if victory_screen:
		victory_screen.queue_free()
		victory_screen = null
	
	# Restart first level
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.change_scene("res://levels/level_1.tscn")
	else:
		get_tree().change_scene_to_file("res://levels/level_1.tscn")

func _return_to_main_menu():
	print("VictoryManager: Returning to main menu")
	get_tree().paused = false
	
	# Clear victory screen
	if victory_screen:
		victory_screen.queue_free()
		victory_screen = null
	
	# Return to main menu
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.change_scene("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _quit_game():
	print("VictoryManager: Quitting game")
	get_tree().quit()

func _reset_game_state():
	"""Reset game state for a new game"""
	completed_levels.clear()
	_initialize_statistics()
	
	# Optionally clear save data
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("clear_progress"):
		save_manager.clear_progress()

# Statistics update functions
func increment_enemies_defeated():
	game_statistics["enemies_defeated"] += 1

func increment_items_collected():
	game_statistics["items_collected"] += 1

func increment_deaths():
	game_statistics["deaths"] += 1

func get_completion_percentage() -> float:
	return float(game_statistics["levels_completed"]) / float(TOTAL_LEVELS) * 100.0

func get_game_statistics() -> Dictionary:
	return game_statistics.duplicate()

# Debug functions
func force_victory():
	"""Debug: Force trigger victory"""
	print("VictoryManager: Force triggering victory (debug)")
	_trigger_game_victory() 