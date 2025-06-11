# StatusBar.gd - Status Bar Script
extends Control

@onready var hp_bar = $LeftSection/BarsContainer/HPContainer/HPBar
@onready var exp_bar = $LeftSection/BarsContainer/EXPContainer/EXPBar
@onready var level_value = get_node_or_null("LeftSection/BarsContainer/LevelContainer/LevelValue")

func _ready():
	print("StatusBar initialized")
	
	# Check if required nodes exist
	if not level_value:
		print("Warning: StatusBar - LevelValue node not found, level display functionality will be disabled")
	
	# Initialize level information
	_update_level_info()

func update_hp(current_hp: int, max_hp: int):
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

func update_exp(current_exp: int, max_exp: int):
	if exp_bar:
		exp_bar.max_value = max_exp
		exp_bar.value = current_exp 

func update_level_info(level_name: String = ""):
	"""Update level information display"""
	if level_value:
		var display_text = _format_level_name(level_name)
		level_value.text = display_text
		print("StatusBar: Level information updated to: ", display_text)
	else:
		print("StatusBar: LevelValue node does not exist, cannot update level info: ", level_name)

func _format_level_name(level_name: String) -> String:
	"""Format level name for display text"""
	if level_name == "":
		level_name = _get_current_level_name()
	
	# Convert level_1 -> 1, level_2 -> 2 etc.
	if level_name.begins_with("level_"):
		var level_number = level_name.substr(6)  # Remove "level_" prefix
		return level_number
	
	# If not standard format, return as is
	return level_name if level_name != "" else "?"

func _get_current_level_name() -> String:
	"""Get current level name"""
	# First try to get current level from SaveManager (for loaded saves)
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.current_level_name != "":
		return save_manager.current_level_name
	
	# Try to get from LevelManager
	if LevelManager and LevelManager.next_level_name != "":
		return LevelManager.next_level_name
	
	# Try to get from current scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("get_current_level_name"):
		return current_scene.get_current_level_name()
	elif current_scene and "current_level_name" in current_scene:
		return current_scene.current_level_name
	
	# Try to infer from scene name
	if current_scene:
		var scene_name = current_scene.name.to_lower()
		# Special handling: if base_level scene, could be level_2 or higher
		if scene_name == "base_level":
			# Priority to infer from scene file path
			if current_scene.scene_file_path.contains("base_level"):
				return "level_2"  # base_level scene defaults to level_2
		elif scene_name.contains("level"):
			# Extract level info from scene name
			for i in range(1, 10):
				if scene_name.contains(str(i)):
					return "level_" + str(i)
	
	# Default to level_1
	return "level_1"

func _update_level_info():
	"""Initialize or update level information"""
	var level_name = _get_current_level_name()
	update_level_info(level_name) 