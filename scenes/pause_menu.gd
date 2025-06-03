extends Control

# 按钮引用
@onready var resume_button = $VBoxContainer/ResumeButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var main_menu_button = $VBoxContainer/MainMenuButton
@onready var quit_button = $VBoxContainer/QuitButton

# 场景路径常量
const SETTINGS_SCENE_PATH = "res://scenes/settings.tscn"
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

func _ready():
	# 连接按钮信号
	resume_button.pressed.connect(_on_resume_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# 确保暂停菜单在游戏暂停时显示
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC键
		if visible:
			_on_resume_button_pressed()
		else:
			show()

func _on_resume_button_pressed():
	# 继续游戏
	hide()
	get_tree().paused = false

func _on_settings_button_pressed():
	# 打开设置界面
	get_tree().change_scene_to_file(SETTINGS_SCENE_PATH)

func _on_main_menu_button_pressed():
	# 返回主菜单
	get_tree().paused = false  # 取消暂停
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_quit_button_pressed():
	# 退出游戏
	get_tree().quit() 