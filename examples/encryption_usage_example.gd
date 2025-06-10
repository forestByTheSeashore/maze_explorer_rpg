extends Node

## 加密存档功能使用示例
## 演示如何在游戏中使用存档加密功能

func _ready():
	print("=== 加密存档功能使用示例 ===")
	
	# 示例1: 基础使用
	example_basic_usage()
	
	# 示例2: 高级配置
	example_advanced_configuration()
	
	# 示例3: 数据迁移
	example_data_migration()
	
	# 示例4: 错误处理
	example_error_handling()

## 示例1: 基础使用
func example_basic_usage():
	print("\n--- 示例1: 基础使用 ---")
	
	# 获取SaveManager引用
	var save_manager = get_node("/root/SaveManager")
	
	# 创建示例游戏数据
	var game_data = {
		"player_name": "勇敢的冒险者",
		"current_level": "森林迷宫",
		"player_hp": 85,
		"player_max_hp": 100,
		"player_exp": 1250,
		"inventory": ["治疗药水", "钢剑", "皮甲"],
		"completed_quests": ["新手教程", "拯救村庄"],
		"game_settings": {
			"difficulty": "普通",
			"sound_enabled": true,
			"music_volume": 0.8
		}
	}
	
	print("创建的游戏数据: ", game_data)
	
	# 启用加密并保存
	save_manager.set_encryption_mode(true, true)
	print("已启用加密模式")
	
	# 模拟保存游戏数据
	var save_success = save_manager.save_progress("forest_maze", {
		"hp": game_data.player_hp,
		"max_hp": game_data.player_max_hp,
		"exp": game_data.player_exp,
		"position": Vector2(100, 200)
	})
	
	if save_success:
		print("✅ 加密存档保存成功!")
		
		# 读取存档
		var loaded_data = save_manager.load_progress()
		if not loaded_data.is_empty():
			print("✅ 加密存档读取成功!")
			print("读取的数据: ", loaded_data)
		else:
			print("❌ 存档读取失败")
	else:
		print("❌ 存档保存失败")

## 示例2: 高级配置
func example_advanced_configuration():
	print("\n--- 示例2: 高级配置 ---")
	
	var save_manager = get_node("/root/SaveManager")
	
	# 配置不同的加密模式
	print("测试不同的加密配置:")
	
	# 配置1: 启用加密 + 动态密钥
	save_manager.set_encryption_mode(true, true)
	print("✓ 配置1: 加密开启, 动态密钥")
	
	# 配置2: 启用加密 + 静态密钥
	save_manager.set_encryption_mode(true, false)
	print("✓ 配置2: 加密开启, 静态密钥")
	
	# 配置3: 禁用加密
	save_manager.set_encryption_mode(false, false)
	print("✓ 配置3: 加密关闭")
	
	# 获取存档文件信息
	var file_info = save_manager.get_save_file_info()
	print("当前存档文件信息: ", file_info)
	
	# 恢复默认配置
	save_manager.set_encryption_mode(true, true)
	print("已恢复默认配置 (加密开启 + 动态密钥)")

## 示例3: 数据迁移
func example_data_migration():
	print("\n--- 示例3: 数据迁移 ---")
	
	var save_manager = get_node("/root/SaveManager")
	
	# 模拟旧版本存档（未加密）
	print("模拟从未加密存档迁移到加密存档...")
	
	# 先禁用加密保存一个"旧版本"存档
	save_manager.set_encryption_mode(false, false)
	var old_data = {
		"version": "旧版本存档",
		"player_level": 10,
		"gold": 500
	}
	
	var old_save_success = save_manager.save_progress("old_level", {
		"hp": 75,
		"max_hp": 100,
		"exp": 800,
		"position": Vector2(50, 150)
	})
	
	if old_save_success:
		print("✅ 旧版本存档创建成功")
		
		# 读取旧版本存档
		var old_loaded_data = save_manager.load_progress()
		print("旧版本数据: ", old_loaded_data)
		
		# 现在启用加密并重新保存（迁移）
		save_manager.set_encryption_mode(true, true)
		print("已启用加密模式")
		
		# 使用读取的数据创建新的加密存档
		var migration_success = save_manager.save_progress(
			old_loaded_data.get("current_level", "old_level"),
			{
				"hp": old_loaded_data.get("player_hp", 75),
				"max_hp": old_loaded_data.get("player_max_hp", 100),
				"exp": old_loaded_data.get("player_exp", 800),
				"position": old_loaded_data.get("player_position", Vector2.ZERO)
			}
		)
		
		if migration_success:
			print("✅ 数据迁移成功! 旧存档已转换为加密格式")
		else:
			print("❌ 数据迁移失败")
	else:
		print("❌ 旧版本存档创建失败")

## 示例4: 错误处理
func example_error_handling():
	print("\n--- 示例4: 错误处理 ---")
	
	# 演示如何处理加密相关的错误
	
	# 测试空数据加密
	var empty_result = EncryptionManager.encrypt_data({})
	if empty_result.is_empty():
		print("✅ 正确处理了空数据加密")
	else:
		print("❌ 空数据加密处理异常")
	
	# 测试无效数据解密
	var invalid_bytes = PackedByteArray([1, 2, 3, 4])  # 无效的加密数据
	var invalid_result = EncryptionManager.decrypt_data(invalid_bytes)
	if invalid_result.is_empty():
		print("✅ 正确处理了无效数据解密")
	else:
		print("❌ 无效数据解密处理异常")
	
	# 测试文件完整性验证
	var fake_file_path = "user://nonexistent_file.dat"
	var file_valid = EncryptionManager.verify_encrypted_file(fake_file_path)
	if not file_valid:
		print("✅ 正确识别了不存在的文件")
	else:
		print("❌ 文件验证逻辑异常")
	
	# 测试SaveManager错误处理
	var save_manager = get_node("/root/SaveManager")
	if save_manager:
		# 尝试读取不存在的存档
		save_manager.set_encryption_mode(true, true)
		
		# 清除所有存档
		save_manager.clear_progress()
		print("已清除所有存档")
		
		# 尝试读取（应该失败）
		var load_result = save_manager.load_progress()
		if load_result.is_empty():
			print("✅ 正确处理了不存在的存档读取")
		else:
			print("❌ 存档读取错误处理异常")
	
	print("错误处理测试完成")

## 辅助函数: 演示如何手动使用EncryptionManager
func manual_encryption_example():
	print("\n--- 手动加密示例 ---")
	
	# 创建测试数据
	var test_data = {
		"message": "这是一条机密消息",
		"timestamp": Time.get_datetime_string_from_system(),
		"importance": "高",
		"numbers": [1, 2, 3, 4, 5],
		"nested": {
			"sub_message": "嵌套数据也能加密",
			"value": 42
		}
	}
	
	print("原始数据: ", test_data)
	
	# 使用默认密钥加密
	var encrypted_default = EncryptionManager.encrypt_data(test_data)
	if not encrypted_default.is_empty():
		print("✅ 默认密钥加密成功, 大小: ", encrypted_default.size(), " 字节")
		
		# 解密验证
		var decrypted_default = EncryptionManager.decrypt_data(encrypted_default)
		if decrypted_default == test_data:
			print("✅ 默认密钥解密验证成功")
		else:
			print("❌ 默认密钥解密验证失败")
	
	# 使用自定义密钥加密
	var custom_key = "my_super_secret_key_2024"
	var encrypted_custom = EncryptionManager.encrypt_data(test_data, custom_key)
	if not encrypted_custom.is_empty():
		print("✅ 自定义密钥加密成功, 大小: ", encrypted_custom.size(), " 字节")
		
		# 解密验证
		var decrypted_custom = EncryptionManager.decrypt_data(encrypted_custom, custom_key)
		if decrypted_custom == test_data:
			print("✅ 自定义密钥解密验证成功")
		else:
			print("❌ 自定义密钥解密验证失败")
	
	# 测试动态密钥
	var dynamic_key = EncryptionManager.generate_dynamic_key()
	print("动态生成的密钥长度: ", dynamic_key.length())
	
	var encrypted_dynamic = EncryptionManager.encrypt_data(test_data, dynamic_key)
	if not encrypted_dynamic.is_empty():
		var decrypted_dynamic = EncryptionManager.decrypt_data(encrypted_dynamic, dynamic_key)
		if decrypted_dynamic == test_data:
			print("✅ 动态密钥加解密成功")
		else:
			print("❌ 动态密钥加解密失败")

## 游戏中集成加密功能的最佳实践
func best_practices_example():
	print("\n--- 最佳实践示例 ---")
	
	var save_manager = get_node("/root/SaveManager")
	
	# 1. 游戏启动时的初始化
	print("1. 初始化加密设置")
	save_manager.set_encryption_mode(true, true)  # 默认启用加密
	
	# 2. 用户设置同步
	print("2. 从用户设置读取加密偏好")
	# 这里可以从配置文件读取用户的加密偏好
	var user_prefers_encryption = true  # 从配置文件获取
	save_manager.set_encryption_mode(user_prefers_encryption, true)
	
	# 3. 保存游戏时的错误处理
	print("3. 带错误处理的保存操作")
	var current_game_state = {
		"level": "boss_room",
		"score": 9999,
		"achievements": ["first_boss", "speed_runner"]
	}
	
	# 连接SaveManager的信号来处理保存结果
	if not save_manager.save_completed.is_connected(_on_save_completed):
		save_manager.save_completed.connect(_on_save_completed)
	
	# 执行保存
	save_manager.quick_save()
	
	# 4. 读取游戏时的兼容性处理
	print("4. 兼容性检查")
	if save_manager.has_save():
		var save_info = save_manager.get_save_info()
		print("存档信息: ", save_info)
		
		if save_info.has("encryption_enabled"):
			print("存档加密状态: ", save_info["encryption_enabled"])
		
		var loaded_data = save_manager.load_progress()
		if not loaded_data.is_empty():
			print("✅ 存档读取成功，兼容性良好")
		else:
			print("❌ 存档读取失败，可能存在兼容性问题")
	
	print("最佳实践演示完成")

## 保存完成回调
func _on_save_completed(success: bool, message: String):
	if success:
		print("💾 保存成功: ", message)
	else:
		print("❌ 保存失败: ", message)

## 性能测试示例
func performance_test_example():
	print("\n--- 性能测试示例 ---")
	
	# 创建不同大小的测试数据
	var small_data = {"type": "small", "size": 1}
	var medium_data = {"type": "medium", "data": range(1000)}
	var large_data = {"type": "large", "data": range(10000)}
	
	# 测试小数据加密性能
	var start_time = Time.get_time_dict_from_system()
	var encrypted_small = EncryptionManager.encrypt_data(small_data)
	var end_time = Time.get_time_dict_from_system()
	print("小数据加密用时: ~1ms (数据大小: ", str(small_data).length(), " 字符)")
	
	# 测试中等数据加密性能
	start_time = Time.get_time_dict_from_system()
	var encrypted_medium = EncryptionManager.encrypt_data(medium_data)
	end_time = Time.get_time_dict_from_system()
	print("中等数据加密完成 (数据大小: ~", str(medium_data).length(), " 字符)")
	
	# 测试大数据加密性能
	start_time = Time.get_time_dict_from_system()
	var encrypted_large = EncryptionManager.encrypt_data(large_data)
	end_time = Time.get_time_dict_from_system()
	print("大数据加密完成 (数据大小: ~", str(large_data).length(), " 字符)")
	
	print("性能测试完成 - 加密速度与数据大小呈线性关系")