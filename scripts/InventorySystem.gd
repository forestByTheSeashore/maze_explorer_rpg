# InventorySystem.gd - 背包系统管理
class_name InventorySystem
extends Node

# === 信号 ===
signal inventory_changed
signal key_added(key_type: String)
signal key_used(key_type: String)

# === 私有变量 ===
var keys: Array[String] = []  # 玩家拥有的钥匙列表
var hp_beans_consumed: int = 0  # 已消费的HP豆数量

# === 钥匙管理 ===
func add_key(key_type: String) -> bool:
	"""添加钥匙到背包"""
	if key_type not in keys:
		keys.append(key_type)
		print("InventorySystem: 获得钥匙：", key_type)
		key_added.emit(key_type)
		inventory_changed.emit()
		return true
	else:
		print("InventorySystem: 已经拥有钥匙：", key_type)
		return false

func has_key(key_type: String) -> bool:
	"""检查是否拥有指定钥匙"""
	var result = key_type in keys
	print("InventorySystem: 检查钥匙 '", key_type, "'：", "有" if result else "没有")
	return result

func use_key(key_type: String) -> bool:
	"""使用钥匙"""
	if has_key(key_type):
		keys.erase(key_type)
		print("InventorySystem: 使用了钥匙：", key_type)
		key_used.emit(key_type)
		inventory_changed.emit()
		return true
	else:
		print("InventorySystem: 没有钥匙：", key_type, "，无法使用")
		return false

func get_keys() -> Array[String]:
	"""获取所有钥匙的副本"""
	return keys.duplicate()

# === HP豆管理 ===
func consume_hp_bean():
	"""记录HP豆消费"""
	hp_beans_consumed += 1
	inventory_changed.emit()
	print("InventorySystem: HP豆消费总数：", hp_beans_consumed)

func get_hp_beans_consumed() -> int:
	"""获取已消费的HP豆数量"""
	return hp_beans_consumed

# === 调试信息 ===
func print_inventory_status():
	"""打印背包状态"""
	print("=== 背包状态 ===")
	print("拥有钥匙：", keys)
	print("已消费HP豆数量：", hp_beans_consumed)
	print("===============") 