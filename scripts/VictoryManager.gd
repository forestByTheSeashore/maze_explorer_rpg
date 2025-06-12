extends Node

## Victory Manager
## Handles game completion conditions and victory screen

signal game_completed()
signal level_completed(level_name: String)

# Level configuration
const TOTAL_LEVELS = 4  # Total number of levels
const FINAL_LEVEL_NAME = "level_4"  # Name of the final level

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
	print("VictoryManager: Before marking - completed levels: ", completed_levels)
	print("VictoryManager: Before marking - levels completed count: ", game_statistics["levels_completed"])
	print("VictoryManager: TOTAL_LEVELS = ", TOTAL_LEVELS)
	print("VictoryManager: FINAL_LEVEL_NAME = ", FINAL_LEVEL_NAME)
	
	if level_name not in completed_levels:
		completed_levels.append(level_name)
		game_statistics["levels_completed"] += 1
		level_completed.emit(level_name)
		print("VictoryManager: After marking - completed levels: ", completed_levels)
		print("VictoryManager: After marking - levels completed count: ", game_statistics["levels_completed"])
	
	# First check if this is the final level (by name)
	if level_name == FINAL_LEVEL_NAME:
		print("VictoryManager: Final level (", FINAL_LEVEL_NAME, ") completed! Triggering immediate victory!")
		_trigger_game_victory()
		return
	
	# Then check if all levels are completed (by count)
	var is_completed = _is_game_completed()
	print("VictoryManager: Is game completed by count? ", is_completed, " (", game_statistics["levels_completed"], "/", TOTAL_LEVELS, ")")
	
	if is_completed:
		print("VictoryManager: Triggering game victory by level count!")
		_trigger_game_victory()

func _is_game_completed() -> bool:
	var completed = game_statistics["levels_completed"] >= TOTAL_LEVELS
	print("VictoryManager: _is_game_completed check - ", game_statistics["levels_completed"], " >= ", TOTAL_LEVELS, " = ", completed)
	return completed

func _trigger_game_victory():
	print("VictoryManager: Game completed!")
	game_statistics["total_play_time"] = Time.get_unix_time_from_system() - game_statistics["start_time"]
	game_completed.emit()
	_show_victory_screen()

func _show_victory_screen():
	print("VictoryManager: Showing victory screen")
	
	# Pause the game
	get_tree().paused = true
	print("VictoryManager: Game paused: ", get_tree().paused)
	
	# Create victory screen
	_create_victory_screen()

func _create_victory_screen():
	print("VictoryManager: _create_victory_screen called")
	
	if victory_screen:
		print("VictoryManager: Victory screen already exists, returning")
		return
	
	print("VictoryManager: Creating new victory screen")
	
	# Create a CanvasLayer to ensure the victory screen is on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "VictoryCanvasLayer"
	canvas_layer.layer = 1000
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	
	victory_screen = Control.new()
	victory_screen.name = "VictoryScreen"
	victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add victory screen to canvas layer
	canvas_layer.add_child(victory_screen)
	
	print("VictoryManager: Victory screen Control created")
	
	# Background
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.9)
	victory_screen.add_child(background)
	
	print("VictoryManager: Background added")
	
	# Main container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	main_container.custom_minimum_size = Vector2(600, 500)
	main_container.anchor_left = 0.5
	main_container.anchor_right = 0.5
	main_container.anchor_top = 0.5
	main_container.anchor_bottom = 0.5
	main_container.offset_left = -300
	main_container.offset_right = 300
	main_container.offset_top = -250
	main_container.offset_bottom = 250
	
	# Title
	var title = Label.new()
	title.text = "🎉 Victory! 🎉"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	main_container.add_child(title)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(spacer1)
	
	# Simplified information container
	var info_container = VBoxContainer.new()
	info_container.add_theme_constant_override("separation", 15)
	
	# Create information labels - simplified version
	var info_labels = [
		"Congratulations on completing the game!",
		"All levels completed",
		"",
		"Thank you for playing!"
	]
	
	for info_text in info_labels:
		var info_label = Label.new()
		info_label.text = info_text
		info_label.add_theme_font_size_override("font_size", 20)
		info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_label.add_theme_color_override("font_color", Color.WHITE)
		info_container.add_child(info_label)
	
	main_container.add_child(info_container)
	
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
	print("VictoryManager: Current scene: ", current_scene.name if current_scene else "null")
	
	if current_scene:
		current_scene.add_child(canvas_layer)
		print("VictoryManager: Victory screen added to scene with z_index 1000")
		print("VictoryManager: Victory screen visible: ", victory_screen.visible)
		print("VictoryManager: Victory screen modulate: ", victory_screen.modulate)
	else:
		print("VictoryManager: ERROR - No current scene to add victory screen to!")

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
	
	# Clear victory screen and its canvas layer
	if victory_screen:
		var canvas_layer = victory_screen.get_parent()
		if canvas_layer and canvas_layer.name == "VictoryCanvasLayer":
			canvas_layer.queue_free()
		else:
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
	
	# Clear victory screen and its canvas layer
	if victory_screen:
		var canvas_layer = victory_screen.get_parent()
		if canvas_layer and canvas_layer.name == "VictoryCanvasLayer":
			canvas_layer.queue_free()
		else:
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

# Public victory trigger function
func trigger_victory():
	"""Public function: Trigger game victory"""
	print("VictoryManager: Public victory trigger called")
	_trigger_game_victory() 