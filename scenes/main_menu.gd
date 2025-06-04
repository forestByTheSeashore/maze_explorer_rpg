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
	# 检查存档文件是否存在
	var has_save = false
	if Engine.has_singleton("SaveManager"):
		var save_manager = Engine.get_singleton("SaveManager")
		if save_manager.has_method("has_save"):
			has_save = save_manager.has_save()
	elif "SaveManager" in get_tree().get_root():
		var save_manager = get_tree().get_root().get("SaveManager")
		if save_manager and save_manager.has_method("has_save"):
			has_save = save_manager.has_save()
	else:
		# 兼容autoload
		if typeof(SaveManager) == TYPE_OBJECT and SaveManager.has_method("has_save"):
			has_save = SaveManager.has_save()
	continue_button.disabled = !has_save

func _on_start_button_pressed():
	# 开始新游戏
	print("开始新游戏")
	# 切换到第一关
	get_tree().change_scene_to_file(LEVEL_1_PATH)

func _on_continue_button_pressed():
	# 继续游戏
	print("继续游戏")
	
	# 获取SaveManager并读取存档
	var save_manager = null
	if Engine.has_singleton("SaveManager"):
		save_manager = Engine.get_singleton("SaveManager")
	elif "SaveManager" in get_tree().get_root():
		save_manager = get_tree().get_root().get("SaveManager")
	else:
		# 兼容autoload
		if typeof(SaveManager) == TYPE_OBJECT:
			save_manager = SaveManager
	
	if not save_manager:
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
	
	# 构建场景路径并切换
	var scene_path = "res://levels/" + level_name + ".tscn"
	print("尝试切换到场景:", scene_path)
	
	# 检查场景文件是否存在
	if FileAccess.file_exists(scene_path):
		print("场景文件存在，开始切换")
		get_tree().change_scene_to_file(scene_path)
	else:
		# 尝试其他可能的路径
		var alternative_paths = [
			"res://scenes/" + level_name + ".tscn",
			"res://levels/" + level_name.to_lower() + ".tscn",
			"res://scenes/" + level_name.to_lower() + ".tscn"
		]
		
		var found_scene = false
		for path in alternative_paths:
			print("尝试备用路径:", path)
			if FileAccess.file_exists(path):
				print("找到场景文件:", path)
				get_tree().change_scene_to_file(path)
				found_scene = true
				break
		
		if not found_scene:
			print("错误: 找不到关卡文件 '", level_name, "'，默认切换到第一关")
			get_tree().change_scene_to_file(LEVEL_1_PATH)

func _on_settings_button_pressed():
	# 打开设置界面
	print("打开设置")
	get_tree().change_scene_to_file(SETTINGS_SCENE_PATH)

func _on_quit_button_pressed():
	# 退出游戏
	print("退出游戏")
	get_tree().quit() 