extends Control

# Setting references
@onready var master_volume = $VBoxContainer/MasterVolume/HSlider
@onready var music_volume = $VBoxContainer/MusicVolume/HSlider
@onready var sfx_volume = $VBoxContainer/SFXVolume/HSlider
@onready var fullscreen = $VBoxContainer/Fullscreen
@onready var back_button = $VBoxContainer/BackButton

# Settings file path
const SETTINGS_FILE = "user://settings.cfg"

# Add GameManager reference
@onready var game_manager = get_node("/root/GameManager")

# Define a signal that is emitted when the settings menu is closed
# signal settings_closed

func _ready():
	# Connect signals
	master_volume.value_changed.connect(_on_master_volume_changed)
	music_volume.value_changed.connect(_on_music_volume_changed)
	sfx_volume.value_changed.connect(_on_sfx_volume_changed)
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Load settings
	_load_settings()

func _load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		# Load volume settings
		master_volume.value = config.get_value("audio", "master_volume", 1.0)
		music_volume.value = config.get_value("audio", "music_volume", 1.0)
		sfx_volume.value = config.get_value("audio", "sfx_volume", 1.0)
		
		# Load display settings
		fullscreen.button_pressed = config.get_value("display", "fullscreen", false)
		
		# Apply settings
		_apply_settings()

func _save_settings():
	var config = ConfigFile.new()
	
	# Save audio settings
	config.set_value("audio", "master_volume", master_volume.value)
	config.set_value("audio", "music_volume", music_volume.value)
	config.set_value("audio", "sfx_volume", sfx_volume.value)
	
	# Save display settings
	config.set_value("display", "fullscreen", fullscreen.button_pressed)
	
	# Save to file
	config.save(SETTINGS_FILE)

func _apply_settings():
	# Apply audio settings
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 
		linear_to_db(master_volume.value))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 
		linear_to_db(music_volume.value))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 
		linear_to_db(sfx_volume.value))
	
	# Apply display settings
	if fullscreen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_master_volume_changed(value: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()

func _on_music_volume_changed(value: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	_save_settings()

func _on_sfx_volume_changed(value: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
	_save_settings()

func _on_fullscreen_toggled(button_pressed: bool):
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _on_back_button_pressed():
	print("Settings: Back button pressed")
	# Return to main menu scene
	game_manager.change_scene("res://scenes/main_menu.tscn") 