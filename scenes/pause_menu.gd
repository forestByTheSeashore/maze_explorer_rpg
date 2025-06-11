extends Control

# Add GameManager reference - using a safer way to get it
var game_manager
var save_manager

# Button references
@onready var resume_button = $VBoxContainer/ResumeButton
@onready var save_button = $VBoxContainer/SaveButton
@onready var load_button = $VBoxContainer/LoadButton
@onready var tutorial_button = get_node_or_null("VBoxContainer/TutorialButton")  # Optional node
# @onready var settings_button = $VBoxContainer/SettingsButton # Removed
@onready var main_menu_button = $VBoxContainer/MainMenuButton
@onready var quit_button = $VBoxContainer/QuitButton

# Status display label
@onready var status_label = $VBoxContainer/StatusLabel

# Encryption setting controls
@onready var encryption_toggle = $VBoxContainer/EncryptionContainer/EncryptionToggle

# Scene path constants
# const SETTINGS_SCENE_PATH = "res://scenes/settings.tscn" # No longer needed, commented out or deleted
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# Load settings scene resource # No longer needed, commented out or deleted
# const SettingsScene = preload(SETTINGS_SCENE_PATH)

func _ready():
	print("Pause Menu: Starting initialization...")
	
	# Safely get manager references
	game_manager = get_node_or_null("/root/GameManager")
	save_manager = get_node_or_null("/root/SaveManager")
	
	if not game_manager:
		print("Warning: GameManager not found")
	if not save_manager:
		print("Warning: SaveManager not found")
	
	# Connect button signals
	if resume_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_button_pressed)
	if tutorial_button:
		tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Connect encryption setting signals
	if encryption_toggle:
		encryption_toggle.toggled.connect(_on_encryption_toggle_changed)
		# Initialize encryption setting state
		encryption_toggle.button_pressed = save_manager.encryption_enabled if save_manager else true
	
	# Connect SaveManager signals - deferred execution
	call_deferred("_connect_save_manager_signals")
	
	# Ensure pause menu is shown when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add to pause menu group for easy finding
	add_to_group("pause_menu")
	
	# Deferred update of save info display
	call_deferred("_update_save_info")
	
	print("Pause Menu: Initialization complete")

func _connect_save_manager_signals():
	if save_manager and save_manager.has_signal("save_completed"):
		if not save_manager.save_completed.is_connected(_on_save_completed):
			save_manager.save_completed.connect(_on_save_completed)
		if not save_manager.load_completed.is_connected(_on_load_completed):
			save_manager.load_completed.connect(_on_load_completed)
		print("Pause Menu: SaveManager signals connected")

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		if visible:
			_on_resume_button_pressed()
		else:
			show()
		# Prevent event from propagating to other nodes
		get_viewport().set_input_as_handled()

func _on_resume_button_pressed():
	# Resume game
	print("Pause Menu: Resume button clicked!")
	print("Pause Menu: Current pause state:", get_tree().paused)
	print("Pause Menu: Current visibility state:", visible)
	
	hide()
	get_tree().paused = false
	
	print("Pause Menu: Pause menu hidden, game resumed")
	print("Pause Menu: New pause state:", get_tree().paused)

func _on_save_button_pressed():
	print("Pause Menu: Save button clicked")
	_show_status("Saving game...", Color.YELLOW)
	
	# Disable save button to prevent multiple clicks
	save_button.disabled = true
	
	# Execute quick save
	var success = save_manager.quick_save()
	
	# If quick save fails, show error immediately
	if not success:
		_show_status("Save failed!", Color.RED)
		save_button.disabled = false

func _on_load_button_pressed():
	print("Pause Menu: Load button clicked")
	
	# Check if save file exists
	if not save_manager.has_save():
		_show_status("No save file found!", Color.RED)
		return
	
	_show_status("Loading game...", Color.YELLOW)
	
	# Disable load button
	load_button.disabled = true
	
	# Load save data
	var save_data = save_manager.load_progress()
	
	if save_data.is_empty():
		_show_status("Load failed!", Color.RED)
		load_button.disabled = false
		return
	
	# If valid level data exists, switch to that level
	var level_name = save_data.get("current_level", "")
	if level_name != "":
		_show_status("Load successful! Switching level...", Color.GREEN)
		
		# Delay scene switch to show success message
		await get_tree().create_timer(1.0).timeout
		
		# Resume game state and switch scene
		get_tree().paused = false
		
		# Choose scene file based on level
		if level_name == "level_1":
			print("Pause Menu: Loading level_1 scene directly")
			game_manager.change_scene("res://levels/level_1.tscn")
		else:
			# Handle other level loading through LevelManager
			var level_manager = get_node_or_null("/root/LevelManager")
			if level_manager:
				# Set LevelManager's next_level_name to correct level name
				level_manager.next_level_name = level_name
				level_manager.prepare_next_level()
				print("Pause Menu: Setting LevelManager to load level: ", level_name)
				print("Pause Menu: Loading base_level scene for level: ", level_name)
				game_manager.change_scene("res://levels/base_level.tscn")
			else:
				print("Error: LevelManager not found, using fallback method")
				# Try to switch to saved level
				var scene_path = "res://levels/" + level_name + ".tscn"
				if FileAccess.file_exists(scene_path):
					game_manager.change_scene(scene_path)
				else:
					_show_status("Level file not found: " + level_name, Color.RED)
					load_button.disabled = false
	else:
		_show_status("Invalid save data!", Color.RED)
		load_button.disabled = false

# Remove settings button signal handler and settings menu close signal handler
# func _on_settings_button_pressed():
#	...
# func _on_settings_closed():
#	...

func _on_tutorial_button_pressed():
	# Show gameplay instructions interface
	print("Pause Menu: Tutorial button clicked")
	
	# Dynamically load tutorial scene to avoid circular reference
	var tutorial_scene = load("res://scenes/tutorial.tscn")
	if not tutorial_scene:
		print("Error: Cannot load tutorial scene")
		return
	var tutorial_instance = tutorial_scene.instantiate()
	
	# Mark as opened from pause menu
	tutorial_instance.opened_from_pause_menu = true
	
	# Add to current scene
	get_parent().add_child(tutorial_instance)
	
	# Ensure it's displayed on top
	tutorial_instance.z_index = 1001  # Higher than pause menu layer
	tutorial_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Temporarily hide pause menu
	hide()

func _on_main_menu_button_pressed():
	print("Main Menu button pressed in pause menu")
	# Resume game process
	get_tree().paused = false  # Cancel pause
	# Use GameManager for scene switching
	game_manager.change_scene(MAIN_MENU_SCENE_PATH)

func _on_quit_button_pressed():
	# Exit game
	get_tree().quit() 

# SaveManager signal handler
func _on_save_completed(success: bool, message: String):
	if success:
		_show_status("Save successful!", Color.GREEN)
	else:
		_show_status("Save failed: " + message, Color.RED)
	
	# Re-enable save button
	save_button.disabled = false
	
	# Update save info
	_update_save_info()

func _on_load_completed(success: bool, message: String):
	if success:
		_show_status("Load successful!", Color.GREEN)
	else:
		_show_status("Load failed: " + message, Color.RED)
	
	# Re-enable load button
	load_button.disabled = false

# Show status message
func _show_status(text: String, color: Color = Color.WHITE):
	if status_label:
		status_label.text = text
		status_label.modulate = color
		print("Pause Menu status: ", text)
		
		# Create a fade-out effect
		if status_label.has_meta("_status_tween"):
			var old_tween = status_label.get_meta("_status_tween")
			if is_instance_valid(old_tween):
				old_tween.kill()
			var tween = create_tween()
			status_label.set_meta("_status_tween", tween)
			tween.tween_property(status_label, "modulate:a", 1.0, 0.1)
			tween.tween_delay(3.0)  # Display for 3 seconds
			tween.tween_property(status_label, "modulate:a", 0.3, 1.0)

# Update save info display
func _update_save_info():
	if not save_manager:
		return
		
	# Update load button state
	if load_button:
		load_button.disabled = not save_manager.has_save()
		
		if save_manager.has_save():
			var save_info = save_manager.get_save_info()
			if not save_info.is_empty():
				var tooltip_text = "Save info:\n"
				tooltip_text += "Level: " + save_info.get("level_name", "Unknown") + "\n"
				tooltip_text += "Time: " + save_info.get("timestamp", "Unknown") + "\n"
				tooltip_text += "Health: " + str(save_info.get("player_hp", 0)) + "/" + str(save_info.get("player_max_hp", 0))
				if save_info.has("encryption_enabled"):
					tooltip_text += "\nEncryption status: " + ("Encrypted" if save_info["encryption_enabled"] else "Not encrypted")
				load_button.tooltip_text = tooltip_text
			else:
				load_button.tooltip_text = "Click to load game"
		else:
			load_button.tooltip_text = "No available save"

# Encryption setting switch callback
func _on_encryption_toggle_changed(pressed: bool):
	if save_manager:
		print("Pause Menu: Encryption setting changed to: ", pressed)
		
		# Check if there's a save to convert
		var had_save_before = save_manager.has_save()
		
		save_manager.set_encryption_mode(pressed, false)  # Disable dynamic key
		
		# If there was a save before, check if conversion succeeded
		if had_save_before:
			var has_save_after = save_manager.has_save()
			if has_save_after:
				if pressed:
					_show_status("Encryption enabled, save converted", Color.GREEN)
				else:
					_show_status("Encryption disabled, save converted", Color.ORANGE)
			else:
				_show_status("Encryption update failed, save conversion error", Color.RED)
		else:
			# Show status message
			if pressed:
				_show_status("Encryption enabled, save converted", Color.GREEN)
			else:
				_show_status("Encryption disabled, save converted", Color.ORANGE)
		
		# Update save info
		_update_save_info()
	else:
		print("Pause Menu: Warning - SaveManager not found")
		_show_status("Cannot change encryption setting", Color.RED) 
