extends Control

# Game Over Page Manager
# Displayed when player dies, provides options to save or return to main menu without saving

# Button references
@onready var save_and_return_button = $VBoxContainer/SaveAndReturnButton
@onready var return_without_save_button = $VBoxContainer/ReturnWithoutSaveButton
@onready var status_label = $VBoxContainer/StatusLabel

# Scene path constants
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# Manager references
var save_manager
var game_manager

func _ready():
	# Ensure Game Over page is initially hidden
	hide()
	
	# Set process_mode to ensure UI works even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Get manager references
	save_manager = get_node_or_null("/root/SaveManager")
	game_manager = get_node_or_null("/root/GameManager")
	
	if not save_manager:
		print("GameOver: Warning - SaveManager not found")
	if not game_manager:
		print("GameOver: Warning - GameManager not found")
	
	# Connect button signals
	if save_and_return_button:
		save_and_return_button.pressed.connect(_on_save_and_return_pressed)
	if return_without_save_button:
		return_without_save_button.pressed.connect(_on_return_without_save_pressed)
	
	# Connect SaveManager signals
	if save_manager and save_manager.has_signal("save_completed"):
		save_manager.save_completed.connect(_on_save_completed)
	
	# Initialize status
	_show_status("Choose your action", Color.WHITE)
	
	print("GameOver: Initialization complete")

func _on_save_and_return_pressed():
	print("GameOver: Player chose to save and return to main menu")
	
	# Show status
	_show_status("Saving game progress...", Color.YELLOW)
	
	# Disable buttons to prevent multiple clicks
	save_and_return_button.disabled = true
	return_without_save_button.disabled = true
	
	if not save_manager:
		_show_status("Error: Save manager not found", Color.RED)
		_enable_buttons()
		return
	
	# Get current level information
	var current_scene = get_tree().current_scene
	if not current_scene:
		_show_status("Error: Cannot get current level information", Color.RED)
		_enable_buttons()
		return
	
	var current_level_name = current_scene.scene_file_path.get_file().get_basename()
	print("GameOver: Current level name: ", current_level_name)
	
	# Get player data (if player still exists)
	var player_data = {}
	var player = get_tree().get_first_node_in_group("player")
	if player and "max_hp" in player:
		# Save player's max HP and other info, but set current HP to max (full health on respawn)
		var current_exp = 0
		var exp_to_next = 50
		
		# Safely get experience values
		if "current_exp" in player:
			current_exp = player.current_exp
		if "exp_to_next_level" in player:
			exp_to_next = player.exp_to_next_level
			
		player_data = {
			"hp": player.max_hp,  # Full health on respawn
			"max_hp": player.max_hp,
			"exp": current_exp,
			"exp_to_next": exp_to_next,
			"position": Vector2.ZERO  # Respawn at starting position
		}
		print("GameOver: Retrieved player data: ", player_data)
	else:
		print("GameOver: No player data found, using default values")
		player_data = {
			"hp": 100,
			"max_hp": 100,
			"exp": 0,
			"exp_to_next": 50,
			"position": Vector2.ZERO
		}
	
	# Execute save operation
	var save_success = save_manager.save_progress(current_level_name, player_data)
	
	if not save_success:
		_show_status("Save failed, but will still return to main menu", Color.ORANGE)
		# Even if save fails, delay a bit before returning to main menu
		await get_tree().create_timer(2.0).timeout
		_return_to_main_menu()

func _on_return_without_save_pressed():
	print("GameOver: Player chose to return to main menu without saving")
	
	_show_status("Returning to main menu...", Color.CYAN)
	
	# Disable buttons
	save_and_return_button.disabled = true
	return_without_save_button.disabled = true
	
	# Brief delay before returning to main menu
	await get_tree().create_timer(1.0).timeout
	_return_to_main_menu()

func _on_save_completed(success: bool, message: String):
	print("GameOver: Save completion callback - Success: ", success, ", Message: ", message)
	
	if success:
		_show_status("Save successful! Returning to main menu...", Color.GREEN)
	else:
		_show_status("Save failed: " + message + ", but will still return to main menu", Color.ORANGE)
	
	# Delay before returning to main menu
	await get_tree().create_timer(2.0).timeout
	_return_to_main_menu()

func _return_to_main_menu():
	print("GameOver: Executing return to main menu")
	
	# Ensure game is no longer paused
	get_tree().paused = false
	
	# Use GameManager to switch scenes if available, otherwise switch directly
	if game_manager and game_manager.has_method("change_scene"):
		game_manager.change_scene(MAIN_MENU_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _show_status(text: String, color: Color = Color.WHITE):
	if status_label:
		status_label.text = text
		status_label.modulate = color
		print("GameOver Status: ", text)

func _enable_buttons():
	"""Re-enable buttons"""
	if save_and_return_button:
		save_and_return_button.disabled = false
	if return_without_save_button:
		return_without_save_button.disabled = false

# Public method to show Game Over page
func show_game_over():
	print("GameOver: Showing Game Over screen")
	
	# Clear any remaining screen effects
	var effects_manager = get_node_or_null("/root/EffectsManager")
	if effects_manager and effects_manager.has_method("clear_screen_flash_effects"):
		effects_manager.clear_screen_flash_effects()
	
	# Pause game
	get_tree().paused = true
	
	# Show page
	show()
	
	# Reset button states
	_enable_buttons()
	
	# Reset status text
	_show_status("Choose your action", Color.WHITE) 