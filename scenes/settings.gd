extends Control

# 设置项引用
@onready var master_volume = $VBoxContainer/MasterVolume/HSlider
@onready var music_volume = $VBoxContainer/MusicVolume/HSlider
@onready var sfx_volume = $VBoxContainer/SFXVolume/HSlider
@onready var fullscreen = $VBoxContainer/Fullscreen
@onready var back_button = $VBoxContainer/BackButton

# 设置文件路径
const SETTINGS_FILE = "user://settings.cfg"

func _ready():
	# 连接信号
	master_volume.value_changed.connect(_on_master_volume_changed)
	music_volume.value_changed.connect(_on_music_volume_changed)
	sfx_volume.value_changed.connect(_on_sfx_volume_changed)
	fullscreen.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# 加载设置
	_load_settings()

func _load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		# 加载音量设置
		master_volume.value = config.get_value("audio", "master_volume", 1.0)
		music_volume.value = config.get_value("audio", "music_volume", 1.0)
		sfx_volume.value = config.get_value("audio", "sfx_volume", 1.0)
		
		# 加载显示设置
		fullscreen.button_pressed = config.get_value("display", "fullscreen", false)
		
		# 应用设置
		_apply_settings()

func _save_settings():
	var config = ConfigFile.new()
	
	# 保存音频设置
	config.set_value("audio", "master_volume", master_volume.value)
	config.set_value("audio", "music_volume", music_volume.value)
	config.set_value("audio", "sfx_volume", sfx_volume.value)
	
	# 保存显示设置
	config.set_value("display", "fullscreen", fullscreen.button_pressed)
	
	# 保存到文件
	config.save(SETTINGS_FILE)

func _apply_settings():
	# 应用音频设置
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 
		linear_to_db(master_volume.value))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), 
		linear_to_db(music_volume.value))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), 
		linear_to_db(sfx_volume.value))
	
	# 应用显示设置
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
	# 返回主菜单
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn") 