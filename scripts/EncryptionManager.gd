extends Node

## 存档加密管理器
## 负责游戏存档数据的加密和解密，保护用户数据安全

# 加密密钥配置
const ENCRYPTION_KEY = "GameExplorer_SecureKey_2024"  # 可以根据需要修改
const MAGIC_HEADER = "GEXP"  # 魔数标识，用于验证文件是否为加密存档
const VERSION = "10"  # 加密版本标识（固定2字节）

# 错误码定义
enum EncryptionError {
	SUCCESS = 0,
	INVALID_KEY = 1,
	INVALID_DATA = 2,
	INVALID_HEADER = 3,
	ENCRYPTION_FAILED = 4,
	DECRYPTION_FAILED = 5
}

## 将字典数据加密为字节数组
## @param data: 要加密的字典数据
## @param key: 加密密钥（可选，默认使用内置密钥）
## @return: 加密后的字节数组，失败时返回空数组
static func encrypt_data(data: Dictionary, key: String = ENCRYPTION_KEY) -> PackedByteArray:
	print("EncryptionManager: 开始加密数据...")
	print("EncryptionManager: 输入数据: ", data)
	print("EncryptionManager: 使用密钥: ", key)
	
	if data.is_empty():
		print("EncryptionManager: 错误 - 数据为空")
		return PackedByteArray()
	
	if key.is_empty():
		print("EncryptionManager: 错误 - 密钥为空")
		return PackedByteArray()
	
	# 将字典序列化为字节数组
	var json_string = JSON.stringify(data)
	if json_string.is_empty():
		print("EncryptionManager: 错误 - JSON序列化失败")
		return PackedByteArray()
	
	print("EncryptionManager: JSON序列化结果: ", json_string)
	var data_bytes = json_string.to_utf8_buffer()
	print("EncryptionManager: 数据序列化完成，大小: ", data_bytes.size(), " 字节")
	
	# 简单的XOR加密
	var encrypted_data = _xor_encrypt(data_bytes, key)
	
	# 构建完整的加密文件格式
	var final_data = PackedByteArray()
	
	# 添加魔数标识（4字节）
	final_data.append_array(MAGIC_HEADER.to_utf8_buffer())
	
	# 添加版本信息（2字节）
	final_data.append_array(VERSION.to_utf8_buffer())
	
	# 添加数据长度（4字节）
	var data_length = encrypted_data.size()
	final_data.push_back(data_length & 0xFF)
	final_data.push_back((data_length >> 8) & 0xFF)
	final_data.push_back((data_length >> 16) & 0xFF)
	final_data.push_back((data_length >> 24) & 0xFF)
	
	# 添加加密数据
	final_data.append_array(encrypted_data)
	
	# 添加简单的校验和（2字节）
	var checksum = _calculate_checksum(encrypted_data)
	final_data.push_back(checksum & 0xFF)
	final_data.push_back((checksum >> 8) & 0xFF)
	
	print("EncryptionManager: 数据加密完成，最终大小: ", final_data.size(), " 字节")
	return final_data

## 将加密的字节数组解密为字典数据
## @param encrypted_data: 加密的字节数组
## @param key: 解密密钥（可选，默认使用内置密钥）
## @return: 解密后的字典数据，失败时返回空字典
static func decrypt_data(encrypted_data: PackedByteArray, key: String = ENCRYPTION_KEY) -> Dictionary:
	print("EncryptionManager: 开始解密数据...")
	print("EncryptionManager: 加密数据大小: ", encrypted_data.size(), " 字节")
	print("EncryptionManager: 使用解密密钥: ", key)
	
	if encrypted_data.is_empty():
		print("EncryptionManager: 错误 - 加密数据为空")
		return {}
	
	if key.is_empty():
		print("EncryptionManager: 错误 - 密钥为空")
		return {}
	
	# 检查最小文件大小（魔数4 + 版本2 + 长度4 + 校验和2 = 12字节）
	if encrypted_data.size() < 12:
		print("EncryptionManager: 错误 - 文件大小不足")
		return {}
	
	var offset = 0
	
	# 验证魔数标识
	var magic = encrypted_data.slice(offset, offset + 4).get_string_from_utf8()
	offset += 4
	print("EncryptionManager: 魔数: '", magic, "' 偏移量: ", offset)
	if magic != MAGIC_HEADER:
		print("EncryptionManager: 错误 - 魔数标识不匹配: ", magic)
		return {}
	
	# 读取版本信息
	var version = encrypted_data.slice(offset, offset + 2).get_string_from_utf8()
	offset += 2
	print("EncryptionManager: 文件版本: '", version, "' 偏移量: ", offset)
	
	# 读取数据长度
	print("EncryptionManager: 准备读取数据长度，当前偏移量: ", offset)
	print("EncryptionManager: 长度字节: [", encrypted_data[offset], ", ", encrypted_data[offset + 1], ", ", encrypted_data[offset + 2], ", ", encrypted_data[offset + 3], "]")
	var data_length = encrypted_data[offset] | (encrypted_data[offset + 1] << 8) | (encrypted_data[offset + 2] << 16) | (encrypted_data[offset + 3] << 24)
	offset += 4
	print("EncryptionManager: 数据长度: ", data_length, " 偏移量: ", offset)
	
	# 检查数据长度有效性
	if data_length <= 0 or offset + data_length + 2 > encrypted_data.size():
		print("EncryptionManager: 错误 - 数据长度无效")
		return {}
	
	# 提取加密数据
	var encrypted_content = encrypted_data.slice(offset, offset + data_length)
	offset += data_length
	
	# 读取校验和
	var stored_checksum = encrypted_data[offset] | (encrypted_data[offset + 1] << 8)
	var calculated_checksum = _calculate_checksum(encrypted_content)
	
	# 验证校验和
	if stored_checksum != calculated_checksum:
		print("EncryptionManager: 错误 - 校验和不匹配")
		print("EncryptionManager: 存储的校验和: ", stored_checksum)
		print("EncryptionManager: 计算的校验和: ", calculated_checksum)
		return {}
	
	# 解密数据
	var decrypted_bytes = _xor_decrypt(encrypted_content, key)
	var json_string = decrypted_bytes.get_string_from_utf8()
	
	print("EncryptionManager: 解密后的JSON字符串: ", json_string)
	
	# 解析JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("EncryptionManager: 错误 - JSON解析失败，错误码: ", parse_result)
		print("EncryptionManager: JSON字符串内容: '", json_string, "'")
		return {}
	
	var result = json.data
	if typeof(result) != TYPE_DICTIONARY:
		print("EncryptionManager: 错误 - 解析结果不是字典类型，类型: ", typeof(result))
		print("EncryptionManager: 解析结果: ", result)
		return {}
	
	print("EncryptionManager: 数据解密完成，结果: ", result)
	return result

## XOR加密实现
## @param data: 要加密的数据
## @param key: 加密密钥
## @return: 加密后的数据
static func _xor_encrypt(data: PackedByteArray, key: String) -> PackedByteArray:
	var key_bytes = key.to_utf8_buffer()
	var encrypted = PackedByteArray()
	
	for i in range(data.size()):
		var key_byte = key_bytes[i % key_bytes.size()]
		encrypted.push_back(data[i] ^ key_byte)
	
	return encrypted

## XOR解密实现（与加密过程相同）
## @param data: 要解密的数据
## @param key: 解密密钥
## @return: 解密后的数据
static func _xor_decrypt(data: PackedByteArray, key: String) -> PackedByteArray:
	return _xor_encrypt(data, key)  # XOR加密和解密是相同的操作

## 计算简单校验和
## @param data: 要计算校验和的数据
## @return: 16位校验和
static func _calculate_checksum(data: PackedByteArray) -> int:
	var checksum = 0
	for byte in data:
		checksum = (checksum + byte) % 65536
	return checksum

## 生成基于用户系统的动态密钥
## @param base_key: 基础密钥
## @return: 增强的密钥
static func generate_dynamic_key(base_key: String = ENCRYPTION_KEY) -> String:
	# 获取系统信息来增强密钥
	var system_info = ""
	system_info += OS.get_name()  # 操作系统名称
	system_info += str(OS.get_processor_count())  # CPU核心数
	
	# 简单的密钥混合
	var mixed_key = base_key + system_info
	return mixed_key.md5_text().substr(0, 32)  # 使用MD5哈希并截取前32字符

## 验证加密文件的完整性
## @param file_path: 文件路径
## @return: 是否为有效的加密文件
static func verify_encrypted_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	# 简单验证：检查魔数标识
	if data.size() < 4:
		return false
	
	var magic = data.slice(0, 4).get_string_from_utf8()
	return magic == MAGIC_HEADER

## 获取加密文件信息
## @param file_path: 文件路径
## @return: 文件信息字典
static func get_encrypted_file_info(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	if data.size() < 12:
		return {}
	
	var magic = data.slice(0, 4).get_string_from_utf8()
	var version = data.slice(4, 6).get_string_from_utf8()
	var data_length = data[6] | (data[7] << 8) | (data[8] << 16) | (data[9] << 24)
	
	return {
		"magic": magic,
		"version": version,
		"data_length": data_length,
		"total_size": data.size(),
		"is_valid": magic == MAGIC_HEADER
	} 
