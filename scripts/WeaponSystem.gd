# WeaponSystem.gd - Weapon System Management
class_name WeaponSystem
extends Node

# === Signals ===
signal weapon_changed(current_weapon: WeaponData)
signal weapon_acquired(weapon: WeaponData)
signal weapon_switched(from_index: int, to_index: int)

# === Private Variables ===
var available_weapons: Array[WeaponData] = []  # List of weapons player has obtained
var current_weapon_index: int = 0              # Index of currently equipped weapon
var current_weapon: WeaponData                 # Currently equipped weapon

# === Input Anti-repeat Variables ===
var last_input_time: float = 0.0
var input_cooldown: float = 0.2  # Input cooldown time (seconds)

# ============================================================================
# Initialization
# ============================================================================
func _ready():
	_initialize_weapon_system()

func _initialize_weapon_system():
	"""Initialize weapon system"""
	# Ensure weapon array is empty
	available_weapons.clear()
	
	# Create basic weapon
	var basic_weapon = WeaponData.new()
	basic_weapon.weapon_id = "basic_sword"
	basic_weapon.weapon_name = "Basic Sword"
	basic_weapon.attack_power = 5
	basic_weapon.weapon_description = "Basic weapon"
	
	available_weapons.append(basic_weapon)
	current_weapon_index = 0
	current_weapon = basic_weapon
	
	print("WeaponSystem: Weapon system initialized, initial weapon: ", basic_weapon.weapon_name, ", total weapons: ", available_weapons.size())
	weapon_changed.emit(current_weapon)

# ============================================================================
# Weapon Acquisition System
# ============================================================================
func try_equip_weapon(weapon_id: String, weapon_name: String, weapon_attack: int) -> bool:
	"""Try to equip new weapon"""
	# Check if already have this weapon
	for weapon in available_weapons:
		if weapon.weapon_id == weapon_id:
			print("WeaponSystem: Already have weapon: ", weapon_name)
			return false
	
	# Create new weapon data
	var new_weapon = WeaponData.new()
	new_weapon.weapon_id = weapon_id
	new_weapon.weapon_name = weapon_name
	new_weapon.attack_power = weapon_attack
	new_weapon.weapon_description = "Weapon obtained from map"
	
	# Add new weapon to arsenal
	available_weapons.append(new_weapon)
	weapon_acquired.emit(new_weapon)
	
	# Check if new weapon is stronger than current weapon
	if weapon_attack > current_weapon.attack_power:
		# Automatically switch to stronger weapon
		var old_index = current_weapon_index
		current_weapon_index = available_weapons.size() - 1
		current_weapon = new_weapon
		print("WeaponSystem: Automatically equipped stronger weapon: ", weapon_name, " (Attack: ", weapon_attack, ")")
		weapon_switched.emit(old_index, current_weapon_index)
		weapon_changed.emit(current_weapon)
	else:
		print("WeaponSystem: Obtained new weapon: ", weapon_name, " (Attack: ", weapon_attack, "), but keeping current equipment")
	
	return true

# ============================================================================
# Weapon Switching System
# ============================================================================
func switch_to_next_weapon():
	"""Switch to next weapon"""
	if available_weapons.size() <= 1:
		print("WeaponSystem: Only one weapon, cannot switch")
		return
	
	var old_index = current_weapon_index
	current_weapon_index = (current_weapon_index + 1) % available_weapons.size()
	current_weapon = available_weapons[current_weapon_index]
	
	print("WeaponSystem: Switching weapon: from index ", old_index, " to index ", current_weapon_index)
	print("WeaponSystem: Switched to weapon: ", current_weapon.weapon_name, " (Attack: ", current_weapon.attack_power, ")")
	
	weapon_switched.emit(old_index, current_weapon_index)
	weapon_changed.emit(current_weapon)

func switch_to_previous_weapon():
	"""Switch to previous weapon"""
	if available_weapons.size() <= 1:
		print("WeaponSystem: Only one weapon, cannot switch")
		return
	
	var old_index = current_weapon_index
	current_weapon_index = (current_weapon_index - 1 + available_weapons.size()) % available_weapons.size()
	current_weapon = available_weapons[current_weapon_index]
	
	print("WeaponSystem: Switched to weapon: ", current_weapon.weapon_name, " (Attack: ", current_weapon.attack_power, ")")
	
	weapon_switched.emit(old_index, current_weapon_index)
	weapon_changed.emit(current_weapon)

func switch_to_weapon_by_index(index: int):
	"""Switch to weapon at specified index"""
	if index >= 0 and index < available_weapons.size():
		if index == current_weapon_index:
			print("WeaponSystem: Already current weapon")
			return
			
		var old_index = current_weapon_index
		print("WeaponSystem: Switching to weapon index: ", index, " current index: ", current_weapon_index)
		current_weapon_index = index
		current_weapon = available_weapons[index]
		
		print("WeaponSystem: Switched to weapon: ", current_weapon.weapon_name, " (Attack: ", current_weapon.attack_power, ")")
		
		weapon_switched.emit(old_index, current_weapon_index)
		weapon_changed.emit(current_weapon)
	else:
		print("WeaponSystem: Invalid weapon index: ", index, " available weapons: ", available_weapons.size())

# ============================================================================
# Input Handling
# ============================================================================
func handle_weapon_input():
	"""Handle weapon-related input"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Tab key weapon switching (detect Tab and Shift+Tab)
	if Input.is_action_just_pressed("ui_focus_next") and not Input.is_key_pressed(KEY_SHIFT):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed Tab to switch to next weapon")
			switch_to_next_weapon()
			last_input_time = current_time
	elif Input.is_action_just_pressed("ui_focus_prev") or (Input.is_action_just_pressed("ui_focus_next") and Input.is_key_pressed(KEY_SHIFT)):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed Shift+Tab to switch to previous weapon")
			switch_to_previous_weapon()
			last_input_time = current_time
	
	# E and Q key weapon switching
	elif Input.is_action_just_pressed("weapon_next"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed E to switch weapon")
			switch_to_next_weapon()
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_previous"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed Q to switch weapon")
			switch_to_previous_weapon()
			last_input_time = current_time
	
	# Number keys for quick weapon switching (keys 1-4)
	elif Input.is_action_just_pressed("weapon_1"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed number key 1 to switch weapon")
			switch_to_weapon_by_index(0)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_2"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed number key 2 to switch weapon")
			switch_to_weapon_by_index(1)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_3"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed number key 3 to switch weapon")
			switch_to_weapon_by_index(2)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_4"):
		if current_time - last_input_time > input_cooldown:
			print("WeaponSystem: Pressed number key 4 to switch weapon")
			switch_to_weapon_by_index(3)
			last_input_time = current_time

# ============================================================================
# Getter Functions
# ============================================================================
func get_available_weapons() -> Array[WeaponData]:
	"""Get copy of all available weapons"""
	return available_weapons.duplicate()

func get_current_weapon() -> WeaponData:
	"""Get current weapon"""
	return current_weapon

func get_current_weapon_index() -> int:
	"""Get current weapon index"""
	return current_weapon_index

func get_weapon_count() -> int:
	"""Get total number of weapons"""
	return available_weapons.size()

func get_weapon_attack_power() -> int:
	"""Get current weapon attack power"""
	return current_weapon.attack_power if current_weapon else 0

# ============================================================================
# Debug Information
# ============================================================================
func print_weapon_status():
	"""Print weapon status"""
	print("=== Weapon System Status ===")
	print("Current weapon: ", current_weapon.weapon_name if current_weapon else "None", " (Attack: ", current_weapon.attack_power if current_weapon else 0, ")")
	print("Number of weapons owned: ", available_weapons.size())
	for i in range(available_weapons.size()):
		var weapon = available_weapons[i]
		var is_current = " [Current]" if i == current_weapon_index else ""
		print("  ", i, ": ", weapon.weapon_name, " (Attack: ", weapon.attack_power, ")", is_current)
	print("===================") 