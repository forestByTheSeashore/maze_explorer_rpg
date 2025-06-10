extends Node
class_name EncryptionTest

## 存档加密功能测试类
## 用于验证加密和解密功能的正确性

## 运行所有加密测试
static func run_all_tests() -> bool:
	print("=== 开始加密功能测试 ===")
	
	var all_passed = true
	
	# 基础加密解密测试
	if not test_basic_encryption():
		all_passed = false
		print("❌ 基础加密解密测试失败")
	else:
		print("✅ 基础加密解密测试通过")
	
	# 空数据处理测试
	if not test_empty_data():
		all_passed = false
		print("❌ 空数据处理测试失败")
	else:
		print("✅ 空数据处理测试通过")
	
	# 复杂数据结构测试
	if not test_complex_data():
		all_passed = false
		print("❌ 复杂数据结构测试失败")
	else:
		print("✅ 复杂数据结构测试通过")
	
	# 密钥测试
	if not test_different_keys():
		all_passed = false
		print("❌ 不同密钥测试失败")
	else:
		print("✅ 不同密钥测试通过")
	
	# 文件完整性测试
	if not test_file_integrity():
		all_passed = false
		print("❌ 文件完整性测试失败")
	else:
		print("✅ 文件完整性测试通过")
	
	print("=== 加密功能测试完成 ===")
	if all_passed:
		print("🎉 所有测试都通过了！")
	else:
		print("⚠️ 部分测试失败，请检查加密实现")
	
	return all_passed

## 基础加密解密测试
static func test_basic_encryption() -> bool:
	var test_data = {
		"current_level": "level_1",
		"player_hp": 85,
		"player_max_hp": 100,
		"player_exp": 150,
		"player_exp_to_next": 200,
		"player_position": Vector2(120, 240),
		"save_timestamp": "2024-01-15 14:30:25",
		"game_version": "1.0"
	}
	
	# 加密数据
	var encrypted = EncryptionManager.encrypt_data(test_data)
	if encrypted.is_empty():
		print("加密失败：返回空数据")
		return false
	
	# 解密数据
	var decrypted = EncryptionManager.decrypt_data(encrypted)
	if decrypted.is_empty():
		print("解密失败：返回空数据")
		return false
	
	# 验证数据一致性
	for key in test_data.keys():
		if not decrypted.has(key):
			print("解密数据缺少键: ", key)
			return false
		
		var original_value = test_data[key]
		var decrypted_value = decrypted[key]
		
		# 特殊处理Vector2类型（JSON序列化后会变成字符串）
		if typeof(original_value) == TYPE_VECTOR2:
			# Vector2在JSON中被序列化为字符串格式如"(120, 240)"
			var expected_string = str(original_value)
			if typeof(decrypted_value) == TYPE_STRING and decrypted_value == expected_string:
				continue  # 匹配成功
			else:
				print("Vector2数据不匹配 - 键: ", key, " 原值: ", original_value, " 解密值: ", decrypted_value)
				return false
		elif decrypted_value != original_value:
			print("解密数据不匹配 - 键: ", key, " 原值: ", original_value, " 解密值: ", decrypted_value)
			return false
	
	return true

## 空数据处理测试
static func test_empty_data() -> bool:
	# 测试空字典
	var empty_dict = {}
	var encrypted_empty = EncryptionManager.encrypt_data(empty_dict)
	if not encrypted_empty.is_empty():
		print("空字典加密应该返回空数据")
		return false
	
	# 测试空字节数组解密
	var empty_bytes = PackedByteArray()
	var decrypted_empty = EncryptionManager.decrypt_data(empty_bytes)
	if not decrypted_empty.is_empty():
		print("空字节数组解密应该返回空字典")
		return false
	
	return true

## 复杂数据结构测试
static func test_complex_data() -> bool:
	var complex_data = {
		"level_data": {
			"current_level": "forest_dungeon",
			"visited_levels": ["level_1", "level_2", "forest_entrance"],
			"level_scores": {
				"level_1": 1250,
				"level_2": 980,
				"forest_entrance": 1500
			}
		},
		"player_stats": {
			"attributes": {
				"strength": 15,
				"agility": 12,
				"intelligence": 8
			},
			"skills": ["sword_mastery", "dodge", "fireball"],
			"equipment": {
				"weapon": "steel_sword",
				"armor": "leather_vest",
				"accessory": "health_ring"
			}
		},
		"inventory": [
			{"id": "health_potion", "count": 5},
			{"id": "mana_potion", "count": 3},
			{"id": "steel_sword", "count": 1, "enhanced": true}
		],
		"flags": {
			"tutorial_completed": true,
			"first_boss_defeated": false,
			"secret_area_found": true
		}
	}
	
	# 加密和解密
	var encrypted = EncryptionManager.encrypt_data(complex_data)
	if encrypted.is_empty():
		print("复杂数据加密失败")
		return false
	
	var decrypted = EncryptionManager.decrypt_data(encrypted)
	if decrypted.is_empty():
		print("复杂数据解密失败")
		return false
	
	# 递归验证数据结构
	return _compare_dictionaries(complex_data, decrypted)

## 不同密钥测试
static func test_different_keys() -> bool:
	var test_data = {
		"test": "密钥测试数据",
		"number": 42
	}
	
	var key1 = "test_key_1"
	var key2 = "test_key_2"
	
	# 使用密钥1加密
	var encrypted1 = EncryptionManager.encrypt_data(test_data, key1)
	if encrypted1.is_empty():
		print("密钥1加密失败")
		return false
	
	# 使用密钥1解密 - 应该成功
	var decrypted1 = EncryptionManager.decrypt_data(encrypted1, key1)
	if decrypted1.is_empty() or decrypted1["test"] != test_data["test"]:
		print("相同密钥解密失败")
		return false
	
	# 使用密钥2解密 - 应该失败或得到错误数据
	var decrypted2 = EncryptionManager.decrypt_data(encrypted1, key2)
	if not decrypted2.is_empty() and decrypted2.get("test", "") == test_data["test"]:
		print("不同密钥解密不应该成功")
		return false
	
	return true

## 文件完整性测试
static func test_file_integrity() -> bool:
	# 创建测试文件路径
	var test_file_path = "user://encryption_test.dat"
	
	var test_data = {
		"integrity_test": true,
		"data": "文件完整性测试数据",
		"checksum_test": 12345
	}
	
	# 加密数据
	var encrypted = EncryptionManager.encrypt_data(test_data)
	if encrypted.is_empty():
		print("完整性测试：加密失败")
		return false
	
	# 写入文件
	var file = FileAccess.open(test_file_path, FileAccess.WRITE)
	if file == null:
		print("完整性测试：无法创建测试文件")
		return false
	
	file.store_buffer(encrypted)
	file.close()
	
	# 验证文件存在
	if not EncryptionManager.verify_encrypted_file(test_file_path):
		print("完整性测试：文件验证失败")
		return false
	
	# 读取并解密文件
	var read_file = FileAccess.open(test_file_path, FileAccess.READ)
	if read_file == null:
		print("完整性测试：无法读取测试文件")
		return false
	
	var file_data = read_file.get_buffer(read_file.get_length())
	read_file.close()
	
	var decrypted = EncryptionManager.decrypt_data(file_data)
	if decrypted.is_empty():
		print("完整性测试：文件解密失败")
		return false
	
	# 验证数据
	if decrypted["integrity_test"] != true or decrypted["data"] != test_data["data"]:
		print("完整性测试：解密数据不匹配")
		return false
	
	# 清理测试文件
	DirAccess.remove_absolute(test_file_path)
	
	return true

## 递归比较字典
static func _compare_dictionaries(dict1: Dictionary, dict2: Dictionary) -> bool:
	if dict1.size() != dict2.size():
		print("字典大小不匹配: ", dict1.size(), " vs ", dict2.size())
		return false
	
	for key in dict1.keys():
		if not dict2.has(key):
			print("字典2缺少键: ", key)
			return false
		
		var val1 = dict1[key]
		var val2 = dict2[key]
		
		if typeof(val1) != typeof(val2):
			print("类型不匹配 - 键: ", key, " 类型1: ", typeof(val1), " 类型2: ", typeof(val2))
			return false
		
		if typeof(val1) == TYPE_DICTIONARY:
			if not _compare_dictionaries(val1, val2):
				print("嵌套字典不匹配 - 键: ", key)
				return false
		elif typeof(val1) == TYPE_ARRAY:
			if not _compare_arrays(val1, val2):
				print("数组不匹配 - 键: ", key)
				return false
		elif typeof(val1) == TYPE_VECTOR2:
			# 特殊处理Vector2类型
			var expected_string = str(val1)
			if typeof(val2) == TYPE_STRING and val2 == expected_string:
				continue  # 匹配成功
			else:
				print("Vector2值不匹配 - 键: ", key, " 值1: ", val1, " 值2: ", val2)
				return false
		else:
			if val1 != val2:
				print("值不匹配 - 键: ", key, " 值1: ", val1, " 值2: ", val2)
				return false
	
	return true

## 递归比较数组
static func _compare_arrays(arr1: Array, arr2: Array) -> bool:
	if arr1.size() != arr2.size():
		print("数组大小不匹配: ", arr1.size(), " vs ", arr2.size())
		return false
	
	for i in range(arr1.size()):
		var val1 = arr1[i]
		var val2 = arr2[i]
		
		if typeof(val1) != typeof(val2):
			print("数组元素类型不匹配 - 索引: ", i, " 类型1: ", typeof(val1), " 类型2: ", typeof(val2))
			return false
		
		if typeof(val1) == TYPE_DICTIONARY:
			if not _compare_dictionaries(val1, val2):
				print("数组中的字典不匹配 - 索引: ", i)
				return false
		elif typeof(val1) == TYPE_ARRAY:
			if not _compare_arrays(val1, val2):
				print("嵌套数组不匹配 - 索引: ", i)
				return false
		else:
			if val1 != val2:
				print("数组元素值不匹配 - 索引: ", i, " 值1: ", val1, " 值2: ", val2)
				return false
	
	return true

## 打印加密文件信息（用于调试）
static func print_file_info(file_path: String):
	if not FileAccess.file_exists(file_path):
		print("文件不存在: ", file_path)
		return
	
	var info = EncryptionManager.get_encrypted_file_info(file_path)
	print("=== 加密文件信息 ===")
	print("文件路径: ", file_path)
	print("魔数标识: ", info.get("magic", "未知"))
	print("文件版本: ", info.get("version", "未知"))
	print("数据长度: ", info.get("data_length", 0), " 字节")
	print("总文件大小: ", info.get("total_size", 0), " 字节")
	print("文件有效性: ", "有效" if info.get("is_valid", false) else "无效")
	print("===================") 