extends Node

## 输入验证管理器
## 负责验证和过滤用户输入，防止恶意输入和确保游戏稳定性

# 注意：作为autoload使用，不需要class_name

# 常量定义
const MAX_INPUT_FREQUENCY = 50  # 每秒最大输入次数
const MAX_MOVEMENT_SPEED = 300.0  # 最大移动速度
const MAX_PLAYER_NAME_LENGTH = 20  # 玩家名称最大长度
const ALLOWED_CHARACTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- "

# 输入频率跟踪
var input_timestamps: Array[float] = []
var last_input_time: float = 0.0

## 验证移动输入
## @param input_vector: 输入向量
## @return: 验证后的安全输入向量
static func validate_movement_input(input_vector: Vector2) -> Vector2:
	# 限制输入向量的大小
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	
	# 检查输入值是否在合理范围内
	input_vector.x = clamp(input_vector.x, -1.0, 1.0)
	input_vector.y = clamp(input_vector.y, -1.0, 1.0)
	
	return input_vector

## 验证攻击输入频率
## @return: 是否允许此次攻击输入
func validate_attack_input() -> bool:
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# 防止攻击输入过于频繁
	if current_timestamp - last_input_time < 0.1:  # 最小0.1秒间隔
		print("InputValidator: 攻击输入过于频繁，已拒绝")
		return false
	
	last_input_time = current_timestamp
	return true

## 验证用户名输入
## @param username: 用户输入的名称
## @return: 清理后的安全用户名
static func validate_username(username: String) -> String:
	if username.is_empty():
		return "Player"
	
	# 限制长度
	if username.length() > MAX_PLAYER_NAME_LENGTH:
		username = username.substr(0, MAX_PLAYER_NAME_LENGTH)
	
	# 过滤非法字符
	var clean_username = ""
	for char in username:
		if char in ALLOWED_CHARACTERS:
			clean_username += char
	
	# 确保不为空
	if clean_username.is_empty():
		clean_username = "Player"
	
	# 移除首尾空格
	clean_username = clean_username.strip_edges()
	
	return clean_username

## 验证文件路径
## @param file_path: 文件路径
## @return: 是否为安全的文件路径
static func validate_file_path(file_path: String) -> bool:
	# 防止路径遍历攻击
	if file_path.contains("..") or file_path.contains("//"):
		print("InputValidator: 检测到不安全的文件路径: ", file_path)
		return false
	
	# 限制只能访问用户数据目录
	if not file_path.begins_with("user://"):
		print("InputValidator: 文件路径必须在用户目录下: ", file_path)
		return false
	
	return true

## 验证存档数据
## @param save_data: 存档数据字典
## @return: 验证后的安全存档数据
static func validate_save_data(save_data: Dictionary) -> Dictionary:
	var validated_data = {}
	
	# 验证必要字段
	var required_fields = ["player_hp", "player_max_hp", "current_level", "inventory"]
	for field in required_fields:
		if field in save_data:
			validated_data[field] = save_data[field]
		else:
			print("InputValidator: 缺少必要字段: ", field)
			# 设置默认值
			match field:
				"player_hp":
					validated_data[field] = 100
				"player_max_hp":
					validated_data[field] = 100
				"current_level":
					validated_data[field] = "level_1"
				"inventory":
					validated_data[field] = {}
	
	# 验证数值范围
	if "player_hp" in validated_data:
		validated_data["player_hp"] = clamp(validated_data["player_hp"], 0, 9999)
	
	if "player_max_hp" in validated_data:
		validated_data["player_max_hp"] = clamp(validated_data["player_max_hp"], 1, 9999)
	
	return validated_data

## 记录可疑输入
## @param input_type: 输入类型
## @param details: 详细信息
static func log_suspicious_input(input_type: String, details: String):
	var timestamp = Time.get_datetime_string_from_system()
	print("[SECURITY] ", timestamp, " - 可疑输入 [", input_type, "]: ", details)
	
	# 在实际部署中，这里应该写入安全日志文件
	# 可以添加更复杂的监控和报警机制 
