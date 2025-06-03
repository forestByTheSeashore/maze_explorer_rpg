extends Control

# 场景路径常量
const LEVEL_1_PATH = "res://levels/level_1.tscn"
const SETTINGS_SCENE_PATH = "res://scenes/settings.tscn"

# 按钮引用
@onready var start_button = $VBoxContainer/StartButton
@onready var continue_button = $VBoxContainer/ContinueButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# 检查是否有存档来决定是否启用继续按钮
	_update_continue_button()

func _update_continue_button():
	# TODO: 检查存档文件是否存在
	var has_save = false  # 这里需要实现实际的存档检查逻辑
	continue_button.disabled = !has_save

func _on_start_button_pressed():
	# 开始新游戏
	print("开始新游戏")
	# 切换到第一关
	get_tree().change_scene_to_file(LEVEL_1_PATH)

func _on_continue_button_pressed():
	# 继续游戏
	print("继续游戏")
	# TODO: 实现读档逻辑
	# 这里需要实现实际的读档逻辑
	pass

func _on_settings_button_pressed():
	# 打开设置界面
	print("打开设置")
	get_tree().change_scene_to_file(SETTINGS_SCENE_PATH)

func _on_quit_button_pressed():
	# 退出游戏
	print("退出游戏")
	get_tree().quit() 