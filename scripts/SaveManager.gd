extends Node

const SAVE_PATH := "user://user_data/save_game.dat"

var current_level_name : String = ""

# 游戏保存数据结构
var save_data = {
	"current_level": "",
	"player_hp": 100,
	"player_max_hp": 100,
	"player_exp": 0,
	"player_exp_to_next": 50,
	"player_position": Vector2.ZERO,
	"save_timestamp": "",
	"game_version": "1.0"
}

# 保存结果信号
signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)

func _ready():
	print("SaveManager: 初始化完成")

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# 增强的保存进度函数
func save_progress(level_name: String, player_data: Dictionary = {}) -> bool:
	print("SaveManager: 开始保存游戏进度...")
	
	current_level_name = level_name
	save_data["current_level"] = level_name
	save_data["save_timestamp"] = Time.get_datetime_string_from_system()
	
	# 如果提供了玩家数据，则更新保存数据
	if not player_data.is_empty():
		if player_data.has("hp"):
			save_data["player_hp"] = player_data["hp"]
		if player_data.has("max_hp"):
			save_data["player_max_hp"] = player_data["max_hp"]
		if player_data.has("exp"):
			save_data["player_exp"] = player_data["exp"]
		if player_data.has("exp_to_next"):
			save_data["player_exp_to_next"] = player_data["exp_to_next"]
		if player_data.has("position"):
			save_data["player_position"] = player_data["position"]
	
	# 确保保存目录存在
	var save_dir = SAVE_PATH.get_base_dir()
	print("SaveManager: 检查保存目录:", save_dir)
	
	if not DirAccess.dir_exists_absolute(save_dir):
		print("SaveManager: 创建保存目录:", save_dir)
		var result = DirAccess.make_dir_recursive_absolute(save_dir)
		if result != OK:
			var error_msg = "无法创建保存目录: " + str(result)
			print("SaveManager 错误: ", error_msg)
			save_completed.emit(false, error_msg)
			
			# 显示错误通知
			var notification_manager = get_node_or_null("/root/NotificationManager")
			if notification_manager and notification_manager.has_method("show_error"):
				notification_manager.show_error("保存失败: " + error_msg)
			
			return false
	
	# 尝试保存到文件
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var error_msg = "无法创建存档文件: " + str(FileAccess.get_open_error())
		print("SaveManager 错误: ", error_msg)
		save_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("保存失败: " + error_msg)
		
		return false
	
	# 写入数据
	file.store_var(save_data)
	file.close()
	
	var success_msg = "游戏已成功保存到: " + level_name
	print("SaveManager: ", success_msg)
	save_completed.emit(true, success_msg)
	
	# 显示成功通知
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager and notification_manager.has_method("show_success"):
		notification_manager.show_success("游戏保存成功!")
	
	return true

# 增强的读取进度函数
func load_progress() -> Dictionary:
	print("SaveManager: 开始读取游戏进度...")
	
	if not FileAccess.file_exists(SAVE_PATH):
		var error_msg = "未找到存档文件"
		print("SaveManager: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("没有找到存档文件")
		
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		var error_msg = "无法打开存档文件: " + str(FileAccess.get_open_error())
		print("SaveManager 错误: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("无法打开存档文件")
		
		return {}
	
	var data = file.get_var()
	file.close()
	
	# 验证数据有效性
	if typeof(data) != TYPE_DICTIONARY:
		var error_msg = "存档文件数据格式无效"
		print("SaveManager 错误: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("存档文件数据格式无效")
		
		return {}
	
	# 检查必要字段
	if not data.has("current_level"):
		var error_msg = "存档文件缺少关键数据"
		print("SaveManager 错误: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("存档文件缺少关键数据")
		
		return {}
	
	# 更新当前数据
	save_data = data
	current_level_name = data.get("current_level", "")
	
	var success_msg = "存档读取成功: " + current_level_name
	print("SaveManager: ", success_msg)
	load_completed.emit(true, success_msg)
	
	# 显示成功通知
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager and notification_manager.has_method("show_success"):
		notification_manager.show_success("存档加载成功!")
	
	return data

# 获取存档信息
func get_save_info() -> Dictionary:
	if not has_save():
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	
	var data = file.get_var()
	file.close()
	
	if typeof(data) == TYPE_DICTIONARY:
		return {
			"level_name": data.get("current_level", "未知关卡"),
			"timestamp": data.get("save_timestamp", "未知时间"),
			"player_hp": data.get("player_hp", 100),
			"player_max_hp": data.get("player_max_hp", 100),
			"player_exp": data.get("player_exp", 0)
		}
	
	return {}

# 快速保存当前游戏状态
func quick_save() -> bool:
	print("SaveManager: ===== 开始执行快速保存 =====")
	# 尝试获取当前玩家数据
	var player_data = {}
	print("SaveManager: 步骤1 - 初始化player_data完成")
	
	var player = get_tree().get_first_node_in_group("player")
	print("SaveManager: 步骤2 - 尝试获取player节点")
	
	if player:
		print("SaveManager: 步骤3 - 找到玩家节点:", player.name)
		print("SaveManager: 步骤3.1 - 玩家节点类型:", player.get_class())
		# 检查属性是否存在
		print("SaveManager: 步骤3.2 - 检查current_hp属性:", "current_hp" in player)
		print("SaveManager: 步骤3.3 - 检查max_hp属性:", "max_hp" in player)
		var hp_value = 100
		var max_hp_value = 100
		var position_value = Vector2.ZERO
		# 安全获取HP值
		if "current_hp" in player:
			print("SaveManager: 步骤3.4 - 尝试获取current_hp")
			hp_value = player.current_hp
			print("SaveManager: 步骤3.5 - current_hp值:", hp_value)
		else:
			print("SaveManager: 警告 - current_hp属性不存在，使用默认值")
		# 安全获取最大HP值
		if "max_hp" in player:
			print("SaveManager: 步骤3.6 - 尝试获取max_hp")
			max_hp_value = player.max_hp
			print("SaveManager: 步骤3.7 - max_hp值:", max_hp_value)
		else:
			print("SaveManager: 警告 - max_hp属性不存在，使用默认值")
		# 安全获取位置
		print("SaveManager: 步骤3.8 - 尝试获取global_position")
		position_value = player.global_position
		print("SaveManager: 步骤3.9 - position值:", position_value)
		# 构建player_data
		print("SaveManager: 步骤4 - 开始构建player_data字典")
		player_data = {
			"hp": hp_value,
			"max_hp": max_hp_value,
			"exp": 0,  # 玩家暂时没有经验系统
			"exp_to_next": 50,  # 使用默认值
			"position": position_value
		}
		print("SaveManager: 步骤5 - player_data构建完成:", player_data)
	else:
		print("SaveManager: 步骤3 - 警告：未找到玩家节点")
	# 尝试获取当前关卡名称
	print("SaveManager: 步骤6 - 开始获取当前场景名称")
	var current_scene = get_tree().current_scene
	print("SaveManager: 步骤6.1 - current_scene:", current_scene)
	if current_scene == null:
		print("SaveManager: 错误 - current_scene为null")
		return false
	var scene_file_path = current_scene.scene_file_path
	print("SaveManager: 步骤6.2 - scene_file_path:", scene_file_path)
	var current_scene_name = scene_file_path.get_file().get_basename()
	print("SaveManager: 步骤7 - 当前场景名称:", current_scene_name)
	print("SaveManager: 步骤8 - 准备调用save_progress")
	var result = save_progress(current_scene_name, player_data)
	print("SaveManager: 步骤9 - save_progress调用完成，结果:", result)
	return result

func clear_progress() -> void:
	current_level_name = ""
	save_data = {
		"current_level": "",
		"player_hp": 100,
		"player_max_hp": 100,
		"player_exp": 0,
		"player_exp_to_next": 50,
		"player_position": Vector2.ZERO,
		"save_timestamp": "",
		"game_version": "1.0"
	}
	
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("SaveManager: 存档已清除")
