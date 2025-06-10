extends Node

const SAVE_PATH := "user://user_data/save_game.dat"
const ENCRYPTED_SAVE_PATH := "user://user_data/save_game_encrypted.dat"
const SETTINGS_PATH := "user://user_data/save_settings.cfg"

# 加密设置
var encryption_enabled := false  # 默认关闭加密功能
var use_dynamic_key := false     # 暂时禁用动态密钥，使用静态密钥保证稳定性

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
	print("SaveManager: 初始化开始...")
	
	# 首先加载用户的加密设置偏好
	_load_encryption_settings()
	
	print("SaveManager: 当前加密设置 - 启用:", encryption_enabled, " 动态密钥:", use_dynamic_key)
	
	# 检查存档文件状态
	if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		print("SaveManager: 检测到加密存档文件")
	if FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: 检测到普通存档文件")
	
	# 如果没有设置过加密偏好，根据现有存档类型自动设置
	if not _has_saved_encryption_preference():
		if FileAccess.file_exists(ENCRYPTED_SAVE_PATH) and not FileAccess.file_exists(SAVE_PATH):
			# 只有加密存档，启用加密
			encryption_enabled = true
			print("SaveManager: 自动检测到加密存档，启用加密模式")
		elif FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
			# 只有普通存档，禁用加密
			encryption_enabled = false
			print("SaveManager: 自动检测到普通存档，禁用加密模式")
		# 保存自动检测的设置
		_save_encryption_settings()
	
	print("SaveManager: 初始化完成")
	
	# 在开发模式下运行加密测试
	if OS.is_debug_build():
		print("SaveManager: 启动开发模式功能测试...")
		call_deferred("_run_encryption_tests")

func has_save() -> bool:
	# 检查当前设置对应的存档文件
	var current_save_exists = false
	if encryption_enabled:
		current_save_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
	else:
		current_save_exists = FileAccess.file_exists(SAVE_PATH)
	
	# 如果当前设置的存档不存在，检查另一种格式的存档是否存在
	if not current_save_exists:
		var alternative_exists = false
		if encryption_enabled:
			alternative_exists = FileAccess.file_exists(SAVE_PATH)
		else:
			alternative_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
		
		# 如果找到了另一种格式的存档，尝试转换
		if alternative_exists:
			print("SaveManager: 发现不同格式的存档，尝试转换...")
			_convert_save_format()
			
			# 重新检查
			if encryption_enabled:
				current_save_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
			else:
				current_save_exists = FileAccess.file_exists(SAVE_PATH)
	
	return current_save_exists

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
	
	# 根据加密设置选择保存方式
	var save_success = false
	
	if encryption_enabled:
		# 使用加密保存
		save_success = _save_encrypted_data(save_data)
	else:
		# 使用普通保存
		save_success = _save_plain_data(save_data)
	
	if not save_success:
		var error_msg = "存档保存失败"
		print("SaveManager 错误: ", error_msg)
		save_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("保存失败: " + error_msg)
		
		return false
	
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
	
	if not has_save():
		var error_msg = "未找到存档文件"
		print("SaveManager: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("没有找到存档文件")
		
		return {}
	
	# 根据加密设置选择加载方式
	var data = {}
	
	if encryption_enabled:
		# 使用加密加载
		data = _load_encrypted_data()
	else:
		# 使用普通加载
		data = _load_plain_data()
	
	if data.is_empty():
		var error_msg = "存档数据加载失败"
		print("SaveManager 错误: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# 显示错误通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("存档数据加载失败")
		
		return {}
	
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
	
	# 根据加密设置选择加载方式
	var data = {}
	
	if encryption_enabled:
		data = _load_encrypted_data()
	else:
		data = _load_plain_data()
	
	if typeof(data) == TYPE_DICTIONARY and not data.is_empty():
		return {
			"level_name": data.get("current_level", "未知关卡"),
			"timestamp": data.get("save_timestamp", "未知时间"),
			"player_hp": data.get("player_hp", 100),
			"player_max_hp": data.get("player_max_hp", 100),
			"player_exp": data.get("player_exp", 0),
			"encryption_enabled": encryption_enabled
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
	print("SaveManager: 步骤6 - 开始获取当前关卡名称")
	var current_scene = get_tree().current_scene
	print("SaveManager: 步骤6.1 - current_scene:", current_scene)
	if current_scene == null:
		print("SaveManager: 错误 - current_scene为null")
		return false
	
	# 优先从场景的current_level_name属性获取关卡名称
	var current_level_name_to_save = ""
	if "current_level_name" in current_scene and current_scene.current_level_name != "":
		current_level_name_to_save = current_scene.current_level_name
		print("SaveManager: 从场景的current_level_name获取: ", current_level_name_to_save)
	elif current_level_name != "":
		# 如果SaveManager自己有记录的当前关卡名
		current_level_name_to_save = current_level_name
		print("SaveManager: 从SaveManager记录获取: ", current_level_name_to_save)
	else:
		# 备选方案：从场景文件名推断
		var scene_file_path = current_scene.scene_file_path
		print("SaveManager: 步骤6.2 - scene_file_path:", scene_file_path)
		var scene_name = scene_file_path.get_file().get_basename()
		print("SaveManager: 从场景文件名推断: ", scene_name)
		
		# 特殊处理base_level场景
		if scene_name == "base_level":
			# 从LevelManager获取关卡名称
			var level_manager = get_node_or_null("/root/LevelManager")
			if level_manager and level_manager.next_level_name != "":
				current_level_name_to_save = level_manager.next_level_name
				print("SaveManager: 从LevelManager获取: ", current_level_name_to_save)
			else:
				current_level_name_to_save = "level_2"  # 默认为level_2
				print("SaveManager: 使用默认值: ", current_level_name_to_save)
		else:
			current_level_name_to_save = scene_name
	
	print("SaveManager: 步骤7 - 最终确定的关卡名称:", current_level_name_to_save)
	print("SaveManager: 步骤8 - 准备调用save_progress")
	var result = save_progress(current_level_name_to_save, player_data)
	print("SaveManager: 步骤9 - save_progress调用完成，结果:", result)
	
	# 显示保存结果通知
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		if result:
			notification_manager.notify_game_saved()
		else:
			notification_manager.show_error("保存失败！请检查磁盘空间", 4.0)
	
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
	
	if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		DirAccess.remove_absolute(ENCRYPTED_SAVE_PATH)
		print("SaveManager: 加密存档已清除")

# ============================================================================
# 加密相关私有函数
# ============================================================================

## 保存加密数据
func _save_encrypted_data(data: Dictionary) -> bool:
	print("SaveManager: 保存加密数据...")
	print("SaveManager: 要保存的数据: ", data)
	
	# 获取加密密钥
	var encryption_key = EncryptionManager.ENCRYPTION_KEY
	if use_dynamic_key:
		encryption_key = EncryptionManager.generate_dynamic_key()
		print("SaveManager: 使用动态密钥保存")
	else:
		print("SaveManager: 使用静态密钥保存: ", encryption_key)
	
	# 加密数据
	var encrypted_bytes = EncryptionManager.encrypt_data(data, encryption_key)
	if encrypted_bytes.is_empty():
		print("SaveManager: 数据加密失败")
		return false
	
	print("SaveManager: 加密完成，加密数据大小: ", encrypted_bytes.size(), " 字节")
	
	# 写入加密文件
	var file = FileAccess.open(ENCRYPTED_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("SaveManager: 无法创建加密存档文件: ", FileAccess.get_open_error())
		return false
	
	file.store_buffer(encrypted_bytes)
	file.close()
	
	print("SaveManager: 加密存档保存完成到: ", ENCRYPTED_SAVE_PATH)
	return true

## 保存普通数据
func _save_plain_data(data: Dictionary) -> bool:
	print("SaveManager: 保存普通数据...")
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("SaveManager: 无法创建存档文件: ", FileAccess.get_open_error())
		return false
	
	file.store_var(data)
	file.close()
	
	print("SaveManager: 普通存档保存完成")
	return true

## 加载加密数据
func _load_encrypted_data() -> Dictionary:
	print("SaveManager: 加载加密数据...")
	
	if not FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		print("SaveManager: 加密存档文件不存在")
		return {}
	
	var file = FileAccess.open(ENCRYPTED_SAVE_PATH, FileAccess.READ)
	if file == null:
		print("SaveManager: 无法打开加密存档文件: ", FileAccess.get_open_error())
		return {}
	
	var encrypted_bytes = file.get_buffer(file.get_length())
	file.close()
	
	print("SaveManager: 读取到加密文件，大小: ", encrypted_bytes.size(), " 字节")
	
	# 获取解密密钥
	var encryption_key = EncryptionManager.ENCRYPTION_KEY
	if use_dynamic_key:
		encryption_key = EncryptionManager.generate_dynamic_key()
		print("SaveManager: 使用动态密钥")
	else:
		print("SaveManager: 使用静态密钥: ", encryption_key)
	
	# 验证文件完整性
	if not EncryptionManager.verify_encrypted_file(ENCRYPTED_SAVE_PATH):
		print("SaveManager: 错误 - 加密文件完整性验证失败")
		return {}
	
	# 解密数据
	var decrypted_data = EncryptionManager.decrypt_data(encrypted_bytes, encryption_key)
	if decrypted_data.is_empty():
		print("SaveManager: 数据解密失败")
		
		# 尝试获取文件信息进行调试
		var file_info = EncryptionManager.get_encrypted_file_info(ENCRYPTED_SAVE_PATH)
		print("SaveManager: 文件信息: ", file_info)
		
		return {}
	
	print("SaveManager: 加密数据加载完成，解密数据: ", decrypted_data)
	return decrypted_data

## 加载普通数据
func _load_plain_data() -> Dictionary:
	print("SaveManager: 加载普通数据...")
	
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: 普通存档文件不存在")
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("SaveManager: 无法打开存档文件: ", FileAccess.get_open_error())
		return {}
	
	var data = file.get_var()
	file.close()
	
	if typeof(data) != TYPE_DICTIONARY:
		print("SaveManager: 存档数据格式无效")
		return {}
	
	print("SaveManager: 普通数据加载完成")
	return data

## 设置加密模式
## @param enabled: 是否启用加密
## @param dynamic_key: 是否使用动态密钥
func set_encryption_mode(enabled: bool, dynamic_key: bool = true):
	var old_enabled = encryption_enabled
	encryption_enabled = enabled
	use_dynamic_key = dynamic_key
	print("SaveManager: 加密模式设置 - 启用:", enabled, " 动态密钥:", dynamic_key)
	
	# 保存用户的加密设置偏好
	_save_encryption_settings()
	
	# 如果加密设置发生了变化，并且存在存档，尝试转换格式
	if old_enabled != enabled:
		print("SaveManager: 加密设置发生变化，检查是否需要转换存档格式...")
		
		# 检查旧格式的存档是否存在
		var old_format_exists = false
		if enabled:
			# 现在要启用加密，检查是否有普通格式的存档
			old_format_exists = FileAccess.file_exists(SAVE_PATH)
		else:
			# 现在要禁用加密，检查是否有加密格式的存档
			old_format_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
		
		if old_format_exists:
			print("SaveManager: 发现旧格式存档，开始转换...")
			_convert_save_format()
		else:
			print("SaveManager: 没有找到需要转换的旧格式存档")
	
	print("SaveManager: 加密模式设置完成")

## 获取存档文件信息
func get_save_file_info() -> Dictionary:
	var info = {}
	
	if encryption_enabled and FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		info["encrypted"] = EncryptionManager.get_encrypted_file_info(ENCRYPTED_SAVE_PATH)
		info["type"] = "encrypted"
	elif not encryption_enabled and FileAccess.file_exists(SAVE_PATH):
		var file_access = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file_access:
			info["plain"] = {
				"size": file_access.get_length(),
				"modified_time": FileAccess.get_modified_time(SAVE_PATH)
			}
			file_access.close()
		info["type"] = "plain"
	else:
		info["type"] = "none"
	
	return info

## 运行加密测试（仅在开发模式下）
func _run_encryption_tests():
	print("SaveManager: 开始运行加密功能测试...")
	
	# 延迟一下以确保所有系统都已初始化
	await get_tree().create_timer(1.0).timeout
	
	# 检查EncryptionTest是否可用
	if not EncryptionTest:
		print("SaveManager: 警告 - EncryptionTest类不可用，跳过测试")
		return
	
	var test_passed = EncryptionTest.run_all_tests()
	
	if test_passed:
		print("SaveManager: ✅ 加密功能测试全部通过！")
		
		# 显示成功通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_success"):
			notification_manager.show_success("加密功能测试通过!")
	else:
		print("SaveManager: ⚠️ 部分加密功能测试失败，请检查实现")
		
		# 在开发模式显示更温和的通知
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_info"):
			notification_manager.show_info("存档系统就绪 (部分测试未通过)")
		elif notification_manager and notification_manager.has_method("notify_info"):
			notification_manager.notify_info("存档系统就绪")

## 手动运行加密测试（可在游戏中调用）
func run_encryption_test_manual():
	print("SaveManager: 手动运行加密测试...")
	if EncryptionTest:
		return EncryptionTest.run_all_tests()
	else:
		print("SaveManager: EncryptionTest不可用")
		return false

## 调试：打印存档系统状态
func debug_save_status():
	print("=== SaveManager 状态调试 ===")
	print("加密启用: ", encryption_enabled)
	print("使用动态密钥: ", use_dynamic_key)
	print("当前关卡名: ", current_level_name)
	print("普通存档路径: ", SAVE_PATH)
	print("加密存档路径: ", ENCRYPTED_SAVE_PATH)
	print("普通存档存在: ", FileAccess.file_exists(SAVE_PATH))
	print("加密存档存在: ", FileAccess.file_exists(ENCRYPTED_SAVE_PATH))
	print("has_save()结果: ", has_save())
	
	# 获取当前场景信息
	var current_scene = get_tree().current_scene
	if current_scene:
		print("当前场景文件: ", current_scene.scene_file_path)
		print("当前场景名称: ", current_scene.name)
		if "current_level_name" in current_scene:
			print("场景的关卡名: ", current_scene.current_level_name)
	
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			print("普通存档大小: ", file.get_length(), " 字节")
			file.close()
			
		# 读取并显示存档内容
		var save_data = _load_plain_data()
		if not save_data.is_empty():
			print("普通存档中的关卡: ", save_data.get("current_level", "未找到"))
	
	if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		var file = FileAccess.open(ENCRYPTED_SAVE_PATH, FileAccess.READ)
		if file:
			print("加密存档大小: ", file.get_length(), " 字节")
			file.close()
		
		var file_info = EncryptionManager.get_encrypted_file_info(ENCRYPTED_SAVE_PATH)
		print("加密存档信息: ", file_info)
		
		# 读取并显示存档内容
		var save_data = _load_encrypted_data()
		if not save_data.is_empty():
			print("加密存档中的关卡: ", save_data.get("current_level", "未找到"))
	
	print("=== 状态调试结束 ===")

## 加载加密设置偏好
func _load_encryption_settings():
	if FileAccess.file_exists(SETTINGS_PATH):
		var config = ConfigFile.new()
		if config.load(SETTINGS_PATH) == OK:
			encryption_enabled = config.get_value("encryption", "enabled", false)
			use_dynamic_key = config.get_value("encryption", "use_dynamic_key", false)
			print("SaveManager: 加载了用户加密设置 - 启用:", encryption_enabled, " 动态密钥:", use_dynamic_key)

## 保存加密设置偏好
func _save_encryption_settings():
	var config = ConfigFile.new()
	config.set_value("encryption", "enabled", encryption_enabled)
	config.set_value("encryption", "use_dynamic_key", use_dynamic_key)
	config.set_value("encryption", "has_preference", true)
	
	# 确保目录存在
	var save_dir = SETTINGS_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	
	config.save(SETTINGS_PATH)
	print("SaveManager: 已保存加密设置偏好")

## 检查是否已保存过加密偏好
func _has_saved_encryption_preference() -> bool:
	if FileAccess.file_exists(SETTINGS_PATH):
		var config = ConfigFile.new()
		if config.load(SETTINGS_PATH) == OK:
			return config.get_value("encryption", "has_preference", false)
	return false

## 转换存档格式（在加密设置改变时调用）
func _convert_save_format():
	print("SaveManager: 开始转换存档格式...")
	
	var source_data = {}
	var convert_success = false
	
	if encryption_enabled:
		# 需要从普通格式转换为加密格式
		if FileAccess.file_exists(SAVE_PATH):
			source_data = _load_plain_data()
			if not source_data.is_empty():
				convert_success = _save_encrypted_data(source_data)
				if convert_success:
					print("SaveManager: 成功转换为加密格式")
					# 删除旧的普通格式文件
					DirAccess.remove_absolute(SAVE_PATH)
	else:
		# 需要从加密格式转换为普通格式
		if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
			source_data = _load_encrypted_data()
			if not source_data.is_empty():
				convert_success = _save_plain_data(source_data)
				if convert_success:
					print("SaveManager: 成功转换为普通格式")
					# 删除旧的加密格式文件
					DirAccess.remove_absolute(ENCRYPTED_SAVE_PATH)
	
	if not convert_success:
		print("SaveManager: 存档格式转换失败")
	
	return convert_success
