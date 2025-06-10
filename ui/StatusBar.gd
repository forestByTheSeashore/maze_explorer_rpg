# StatusBar.gd - 状态栏脚本
extends Control

@onready var hp_bar = $LeftSection/BarsContainer/HPContainer/HPBar
@onready var exp_bar = $LeftSection/BarsContainer/EXPContainer/EXPBar
@onready var level_value = get_node_or_null("LeftSection/BarsContainer/LevelContainer/LevelValue")

func _ready():
	print("StatusBar initialized")
	
	# 检查必要的节点是否存在
	if not level_value:
		print("警告：StatusBar - LevelValue节点未找到，关卡信息显示功能将被禁用")
	
	# 初始化关卡信息
	_update_level_info()

func update_hp(current_hp: int, max_hp: int):
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

func update_exp(current_exp: int, max_exp: int):
	if exp_bar:
		exp_bar.max_value = max_exp
		exp_bar.value = current_exp 

func update_level_info(level_name: String = ""):
	"""更新关卡信息显示"""
	if level_value:
		var display_text = _format_level_name(level_name)
		level_value.text = display_text
		print("StatusBar: 关卡信息更新为: ", display_text)
	else:
		print("StatusBar: LevelValue节点不存在，无法更新关卡信息: ", level_name)

func _format_level_name(level_name: String) -> String:
	"""格式化关卡名称为显示文本"""
	if level_name == "":
		level_name = _get_current_level_name()
	
	# 转换 level_1 -> 1, level_2 -> 2 等
	if level_name.begins_with("level_"):
		var level_number = level_name.substr(6)  # 去掉 "level_" 前缀
		return level_number
	
	# 如果不是标准格式，直接返回
	return level_name if level_name != "" else "?"

func _get_current_level_name() -> String:
	"""获取当前关卡名称"""
	# 首先尝试从LevelManager获取
	if LevelManager and LevelManager.next_level_name != "":
		return LevelManager.next_level_name
	
	# 尝试从当前场景获取
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("get_current_level_name"):
		return current_scene.get_current_level_name()
	elif current_scene and "current_level_name" in current_scene:
		return current_scene.current_level_name
	
	# 尝试从场景名称推断
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		if scene_name.contains("level"):
			# 从场景名中提取关卡信息
			for i in range(1, 10):
				if scene_name.contains(str(i)):
					return "level_" + str(i)
	
	# 默认返回level_1
	return "level_1"

func _update_level_info():
	"""初始化或更新关卡信息"""
	var level_name = _get_current_level_name()
	update_level_info(level_name) 