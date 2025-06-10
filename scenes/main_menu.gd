extends Control

# 场景路径常量
const LEVEL_1_PATH = "res://levels/level_1.tscn"
const SETTINGS_SCENE_PATH = "res://scenes/settings.tscn"
const TUTORIAL_SCENE_PATH = "res://scenes/tutorial.tscn"

# 按钮引用
@onready var start_button = $VBoxContainer/StartButton
@onready var continue_button = $VBoxContainer/ContinueButton
@onready var tutorial_button = $VBoxContainer/TutorialButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	print("主菜单: 初始化开始")
	
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# 延迟检查存档状态，确保所有autoload都已初始化
	call_deferred("_update_continue_button")
	
	# 播放主菜单音乐
	call_deferred("_play_menu_music")
	
	print("主菜单: 初始化完成")

func _play_menu_music():
	"""播放主菜单背景音乐"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_menu_music()
		print("主菜单: 开始播放背景音乐")
	else:
		print("主菜单: 找不到AudioManager")

func _play_button_sound():
	"""播放按钮点击音效"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_button_click_sound()

func _update_continue_button():
	# 检查存档文件是否存在
	var has_save = false
	
	# 尝试获取SaveManager
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("has_save"):
		has_save = save_manager.has_save()
		print("主菜单: 通过节点路径找到SaveManager, has_save = ", has_save)
		
		# 调试存档状态
		if save_manager.has_method("debug_save_status"):
			save_manager.debug_save_status()
	else:
		# 备选方法：直接访问autoload
		if SaveManager and SaveManager.has_method("has_save"):
			has_save = SaveManager.has_save()
			print("主菜单: 通过autoload访问SaveManager, has_save = ", has_save)
			
			# 调试存档状态
			if SaveManager.has_method("debug_save_status"):
				SaveManager.debug_save_status()
		else:
			print("主菜单: 无法找到SaveManager")
	
	continue_button.disabled = !has_save
	print("主菜单: 继续游戏按钮状态 - disabled: ", continue_button.disabled)

func _on_start_button_pressed():
	# 开始新游戏
	print("开始新游戏")
	_play_button_sound()
	# 切换到第一关
	get_tree().change_scene_to_file(LEVEL_1_PATH)

func _on_continue_button_pressed():
	# 继续游戏
	print("继续游戏")
	_play_button_sound()
	
	# 获取SaveManager并读取存档
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		# 备选方法：直接访问autoload
		if SaveManager:
			save_manager = SaveManager
		else:
			print("错误: 找不到SaveManager")
			return
	
	if not save_manager.has_method("load_progress"):
		print("错误: SaveManager没有load_progress方法")
		return
	
	# 读取存档数据
	var save_data = save_manager.load_progress()
	
	if save_data.is_empty():
		print("错误: 存档数据为空")
		return
	
	# 获取保存的关卡名称
	var level_name = save_data.get("current_level", "")
	print("读取到关卡:", level_name)
	
	if level_name == "":
		print("错误: 存档中没有关卡信息")
		return
	
	# 根据关卡选择场景文件
	if level_name == "level_1":
		print("主菜单: 直接加载level_1场景")
		get_tree().change_scene_to_file(LEVEL_1_PATH)
	else:
		# 通过LevelManager处理其他关卡加载
		var level_manager = get_node_or_null("/root/LevelManager")
		if level_manager:
			# 设置LevelManager的next_level_name为正确的关卡名称
			level_manager.next_level_name = level_name
			level_manager.prepare_next_level()
			print("主菜单: 设置LevelManager加载关卡: ", level_name)
			print("主菜单: 加载base_level场景用于关卡: ", level_name)
			get_tree().change_scene_to_file("res://levels/base_level.tscn")
		else:
			print("错误: 找不到LevelManager，使用备用方法")
			# 尝试直接切换场景（备用方法）
			var scene_path = "res://levels/" + level_name + ".tscn"
			if FileAccess.file_exists(scene_path):
				get_tree().change_scene_to_file(scene_path)
			else:
				print("错误: 找不到关卡文件，默认切换到第一关")
				get_tree().change_scene_to_file(LEVEL_1_PATH)

func _on_tutorial_button_pressed():
	# 打开玩法说明界面
	print("打开玩法说明")
	_play_button_sound()
	get_tree().change_scene_to_file(TUTORIAL_SCENE_PATH)

func _on_settings_button_pressed():
	# 打开设置界面
	print("打开设置")
	_play_button_sound()
	get_tree().change_scene_to_file(SETTINGS_SCENE_PATH)

func _on_quit_button_pressed():
	# 退出游戏
	print("退出游戏")
	_play_button_sound()
	get_tree().quit() 