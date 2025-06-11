extends Control

# Scene path constants
const LEVEL_1_PATH = "res://levels/level_1.tscn"
const SETTINGS_SCENE_PATH = "res://scenes/settings.tscn"
const TUTORIAL_SCENE_PATH = "res://scenes/tutorial.tscn"

# Button references
@onready var start_button = $VBoxContainer/StartButton
@onready var continue_button = $VBoxContainer/ContinueButton
@onready var tutorial_button = $VBoxContainer/TutorialButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	print("Main Menu: Initialization started")
	
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Delay checking save status to ensure all autoloads are initialized
	call_deferred("_update_continue_button")
	
	# Play main menu music
	call_deferred("_play_menu_music")
	
	print("Main Menu: Initialization completed")

func _play_menu_music():
	"""Play main menu background music"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_menu_music()
		print("Main Menu: Started playing background music")
	else:
		print("Main Menu: AudioManager not found")

func _play_button_sound():
	"""Play button click sound effect"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_button_click_sound()

func _update_continue_button():
	# Check if save file exists
	var has_save = false
	
	# Try to get SaveManager
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("has_save"):
		has_save = save_manager.has_save()
		print("Main Menu: Found SaveManager through node path, has_save = ", has_save)
		
		# Debug save status
		if save_manager.has_method("debug_save_status"):
			save_manager.debug_save_status()
	else:
		# Alternative method: Access autoload directly
		if SaveManager and SaveManager.has_method("has_save"):
			has_save = SaveManager.has_save()
			print("Main Menu: Accessed SaveManager through autoload, has_save = ", has_save)
			
			# Debug save status
			if SaveManager.has_method("debug_save_status"):
				SaveManager.debug_save_status()
		else:
			print("Main Menu: SaveManager not found")
	
	continue_button.disabled = !has_save
	print("Main Menu: Continue button status - disabled: ", continue_button.disabled)

func _on_start_button_pressed():
	# Start new game
	print("Starting new game")
	_play_button_sound()
	# Switch to first level
	get_tree().change_scene_to_file(LEVEL_1_PATH)

func _on_continue_button_pressed():
	# Continue game
	print("Continuing game")
	_play_button_sound()
	
	# Get SaveManager and load save
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		# Alternative method: Access autoload directly
		if SaveManager:
			save_manager = SaveManager
		else:
			print("Error: SaveManager not found")
			return
	
	if not save_manager.has_method("load_progress"):
		print("Error: SaveManager does not have load_progress method")
		return
	
	# Load save data
	var save_data = save_manager.load_progress()
	
	if save_data.is_empty():
		print("Error: Save data is empty")
		return
	
	# Get saved level name
	var level_name = save_data.get("current_level", "")
	print("Loaded level:", level_name)
	
	if level_name == "":
		print("Error: No level information in save data")
		return
	
	# Choose scene file based on level
	if level_name == "level_1":
		print("Main Menu: Loading level_1 scene directly")
		get_tree().change_scene_to_file(LEVEL_1_PATH)
	else:
		# Handle other level loading through LevelManager
		var level_manager = get_node_or_null("/root/LevelManager")
		if level_manager:
			# Set LevelManager's next_level_name to the correct level name
			level_manager.next_level_name = level_name
			level_manager.prepare_next_level()
			print("Main Menu: Set LevelManager to load level: ", level_name)
			print("Main Menu: Loading base_level scene for level: ", level_name)
			get_tree().change_scene_to_file("res://levels/base_level.tscn")
		else:
			print("Error: LevelManager not found, using fallback method")
			# Try to switch scene directly (fallback method)
			var scene_path = "res://levels/" + level_name + ".tscn"
			if FileAccess.file_exists(scene_path):
				get_tree().change_scene_to_file(scene_path)
			else:
				print("Error: Level file not found, defaulting to first level")
				get_tree().change_scene_to_file(LEVEL_1_PATH)

func _on_tutorial_button_pressed():
	# Open gameplay instructions screen
	print("Open gameplay instructions")
	_play_button_sound()
	
	# Dynamically load tutorial scene to avoid circular references
	var tutorial_scene = load("res://scenes/tutorial.tscn")
	if tutorial_scene:
		get_tree().change_scene_to_packed(tutorial_scene)
	else:
		print("Error: Cannot load tutorial scene")
		get_tree().change_scene_to_file(TUTORIAL_SCENE_PATH)

func _on_settings_button_pressed():
	# Open settings screen
	print("Opening settings")
	_play_button_sound()
	get_tree().change_scene_to_file(SETTINGS_SCENE_PATH)

func _on_quit_button_pressed():
	# Quit game
	print("Quitting game")
	_play_button_sound()
	get_tree().quit() 