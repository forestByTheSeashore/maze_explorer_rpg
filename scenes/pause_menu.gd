extends Control

# 添加 GameManager 引用
@onready var game_manager = get_node("/root/GameManager")

# 按钮引用
@onready var resume_button = $VBoxContainer/ResumeButton
# @onready var settings_button = $VBoxContainer/SettingsButton # 已删除
@onready var main_menu_button = $VBoxContainer/MainMenuButton
@onready var quit_button = $VBoxContainer/QuitButton

# 场景路径常量
# const SETTINGS_SCENE_PATH = "res://scenes/settings.tscn" # 不再需要，注释掉或删除
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# 加载设置场景资源 # 不再需要，注释掉或删除
# const SettingsScene = preload(SETTINGS_SCENE_PATH)

func _ready():
	# 连接按钮信号
	resume_button.pressed.connect(_on_resume_button_pressed)
	# settings_button.pressed.connect(_on_settings_button_pressed) # 已删除
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

# 移除设置按钮的信号处理函数和设置菜单关闭信号处理函数
# func _on_settings_button_pressed():
#	...
# func _on_settings_closed():
#	...

func _on_main_menu_button_pressed():
	print("Main Menu button pressed in pause menu")
	# 恢复游戏进程
	get_tree().paused = false  # 取消暂停
	# 使用 GameManager 进行场景切换
	game_manager.change_scene(MAIN_MENU_SCENE_PATH)

func _on_quit_button_pressed():
	# 退出游戏
	get_tree().quit() 