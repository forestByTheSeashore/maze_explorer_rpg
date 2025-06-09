# WeaponSystem.gd - 武器系统管理
class_name WeaponSystem
extends Node

# === 信号 ===
signal weapon_changed(current_weapon: WeaponData)
signal weapon_acquired(weapon: WeaponData)
signal weapon_switched(from_index: int, to_index: int)

# === 私有变量 ===
var available_weapons: Array[WeaponData] = []  # 玩家已获得的武器列表
var current_weapon_index: int = 0              # 当前装备的武器索引
var current_weapon: WeaponData                 # 当前装备的武器

# === 输入防重复变量 ===
var last_input_time: float = 0.0
var input_cooldown: float = 0.2  # 输入冷却时间（秒）

# ============================================================================
# 初始化
# ============================================================================
func _ready():
	_initialize_weapon_system()

func _initialize_weapon_system():
	"""初始化武器系统"""
	# 确保武器数组为空
	available_weapons.clear()
	
	# 创建基础武器
	var basic_weapon = WeaponData.new()
	basic_weapon.weapon_id = "basic_sword"
	basic_weapon.weapon_name = "Basic Sword"
	basic_weapon.attack_power = 5
	basic_weapon.weapon_description = "基础武器"
	
	available_weapons.append(basic_weapon)
	current_weapon_index = 0
	current_weapon = basic_weapon
	
	print("WeaponSystem: 武器系统初始化完成，初始武器：", basic_weapon.weapon_name, "，武器总数：", available_weapons.size())
	weapon_changed.emit(current_weapon)

# ============================================================================
# 武器获取系统
# ============================================================================
func try_equip_weapon(weapon_id: String, weapon_name: String, weapon_attack: int) -> bool:
	"""尝试装备新武器"""
	# 检查是否已经拥有这把武器
	for weapon in available_weapons:
		if weapon.weapon_id == weapon_id:
			print("WeaponSystem: 已经拥有武器：", weapon_name)
			return false
	
	# 创建新武器数据
	var new_weapon = WeaponData.new()
	new_weapon.weapon_id = weapon_id
	new_weapon.weapon_name = weapon_name
	new_weapon.attack_power = weapon_attack
	new_weapon.weapon_description = "从地图中获得的武器"
	
	# 将新武器添加到武器库
	available_weapons.append(new_weapon)
	weapon_acquired.emit(new_weapon)
	
	# 检查新武器是否比当前武器更强
	if weapon_attack > current_weapon.attack_power:
		# 自动切换到更强的武器
		var old_index = current_weapon_index
		current_weapon_index = available_weapons.size() - 1
		current_weapon = new_weapon
		print("WeaponSystem: 自动装备更强的武器：", weapon_name, "（攻击力：", weapon_attack, "）")
		weapon_switched.emit(old_index, current_weapon_index)
		weapon_changed.emit(current_weapon)
	else:
		print("WeaponSystem: 获得新武器：", weapon_name, "（攻击力：", weapon_attack, "），但保持当前装备")
	
	return true

# ============================================================================
# 武器切换系统
# ============================================================================
func switch_to_next_weapon():
	"""切换到下一把武器"""
	if available_weapons.size() <= 1:
		print("WeaponSystem: 只有一把武器，无法切换")
		return
	
	var old_index = current_weapon_index
	current_weapon_index = (current_weapon_index + 1) % available_weapons.size()
	current_weapon = available_weapons[current_weapon_index]
	
	print("WeaponSystem: 切换武器: 从索引", old_index, "到索引", current_weapon_index)
	print("WeaponSystem: 切换武器到：", current_weapon.weapon_name, "（攻击力：", current_weapon.attack_power, "）")
	
	weapon_switched.emit(old_index, current_weapon_index)
	weapon_changed.emit(current_weapon)

func switch_to_previous_weapon():
	"""切换到上一把武器"""
	if available_weapons.size() <= 1:
		print("WeaponSystem: 只有一把武器，无法切换")
		return
	
	var old_index = current_weapon_index
	current_weapon_index = (current_weapon_index - 1 + available_weapons.size()) % available_weapons.size()
	current_weapon = available_weapons[current_weapon_index]
	
	print("WeaponSystem: 切换武器到：", current_weapon.weapon_name, "（攻击力：", current_weapon.attack_power, "）")
	
	weapon_switched.emit(old_index, current_weapon_index)
	weapon_changed.emit(current_weapon)

func switch_to_weapon_by_index(index: int):
	"""切换到指定索引的武器"""
	if index >= 0 and index < available_weapons.size():
		if index == current_weapon_index:
			print("WeaponSystem: 已经是当前武器")
			return
			
		var old_index = current_weapon_index
		print("WeaponSystem: 切换武器到索引：", index, "当前索引：", current_weapon_index)
		current_weapon_index = index
		current_weapon = available_weapons[index]
		
		print("WeaponSystem: 切换武器到：", current_weapon.weapon_name, "（攻击力：", current_weapon.attack_power, "）")
		
		weapon_switched.emit(old_index, current_weapon_index)
		weapon_changed.emit(current_weapon)
	else:
		print("WeaponSystem: 无效的武器索引：", index, "可用武器数量：", available_weapons.size())

# ============================================================================
# 输入处理
# ============================================================================
func handle_weapon_input():
	"""处理武器相关输入"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Tab键切换武器（检测Tab和Shift+Tab）
	if Input.is_action_just_pressed("ui_focus_next") and not Input.is_key_pressed(KEY_SHIFT):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下Tab键切换到下一个武器")
			switch_to_next_weapon()
			last_input_time = current_time
	elif Input.is_action_just_pressed("ui_focus_prev") or (Input.is_action_just_pressed("ui_focus_next") and Input.is_key_pressed(KEY_SHIFT)):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下Shift+Tab键切换到上一个武器")
			switch_to_previous_weapon()
			last_input_time = current_time
	
	# E和Q键武器切换
	elif Input.is_action_just_pressed("weapon_next"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下E键切换武器")
			switch_to_next_weapon()
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_previous"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下Q键切换武器")
			switch_to_previous_weapon()
			last_input_time = current_time
	
	# 数字键快速切换武器（1-4键）
	elif Input.is_action_just_pressed("weapon_1"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下数字键1切换武器")
			switch_to_weapon_by_index(0)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_2"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下数字键2切换武器")
			switch_to_weapon_by_index(1)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_3"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下数字键3切换武器")
			switch_to_weapon_by_index(2)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_4"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: 按下数字键4切换武器")
			switch_to_weapon_by_index(3)
			last_input_time = current_time

# ============================================================================
# 获取器函数
# ============================================================================
func get_available_weapons() -> Array[WeaponData]:
	"""获取所有可用武器的副本"""
	return available_weapons.duplicate()

func get_current_weapon() -> WeaponData:
	"""获取当前武器"""
	return current_weapon

func get_current_weapon_index() -> int:
	"""获取当前武器索引"""
	return current_weapon_index

func get_weapon_count() -> int:
	"""获取武器总数"""
	return available_weapons.size()

func get_weapon_attack_power() -> int:
	"""获取当前武器攻击力"""
	return current_weapon.attack_power if current_weapon else 0

# ============================================================================
# 调试信息
# ============================================================================
func print_weapon_status():
	"""打印武器状态"""
	print("=== 武器系统状态 ===")
	print("当前武器：", current_weapon.weapon_name if current_weapon else "无", "（攻击力：", current_weapon.attack_power if current_weapon else 0, "）")
	print("拥有武器数量：", available_weapons.size())
	for i in range(available_weapons.size()):
		var weapon = available_weapons[i]
		var is_current = " [当前]" if i == current_weapon_index else ""
		print("  ", i, ": ", weapon.weapon_name, " (攻击力: ", weapon.attack_power, ")", is_current)
	print("===================") 