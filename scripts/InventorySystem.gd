# InventorySystem.gd - Inventory System Management
class_name InventorySystem
extends Node

# === Signals ===
signal inventory_changed
signal key_added(key_type: String)
signal key_used(key_type: String)

# === Private Variables ===
var keys: Array[String] = []  # List of keys player owns
var hp_beans_consumed: int = 0  # Number of HP beans consumed

# === Key Management ===
func add_key(key_type: String) -> bool:
	"""Add key to inventory"""
	if key_type not in keys:
		keys.append(key_type)
		print("InventorySystem: Obtained key: ", key_type)
		key_added.emit(key_type)
		inventory_changed.emit()
		return true
	else:
		print("InventorySystem: Already have key: ", key_type)
		return false

func has_key(key_type: String) -> bool:
	"""Check if has specified key"""
	var result = key_type in keys
	print("InventorySystem: Check key '", key_type, "': ", "Yes" if result else "No")
	return result

func use_key(key_type: String) -> bool:
	"""Use key"""
	if has_key(key_type):
		keys.erase(key_type)
		print("InventorySystem: Used key: ", key_type)
		key_used.emit(key_type)
		inventory_changed.emit()
		return true
	else:
		print("InventorySystem: No key: ", key_type, ", cannot use")
		return false

func get_keys() -> Array[String]:
	"""Get copy of all keys"""
	return keys.duplicate()

# === HP Bean Management ===
func consume_hp_bean():
	"""Record HP bean consumption"""
	hp_beans_consumed += 1
	inventory_changed.emit()
	print("InventorySystem: Total HP beans consumed: ", hp_beans_consumed)

func get_hp_beans_consumed() -> int:
	"""Get number of HP beans consumed"""
	return hp_beans_consumed

# === Debug Information ===
func print_inventory_status():
	"""Print inventory status"""
	print("=== Inventory Status ===")
	print("Owned keys: ", keys)
	print("HP beans consumed: ", hp_beans_consumed)
	print("===============") 