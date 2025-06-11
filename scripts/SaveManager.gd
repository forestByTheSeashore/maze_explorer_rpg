extends Node

const SAVE_PATH := "user://user_data/save_game.dat"
const ENCRYPTED_SAVE_PATH := "user://user_data/save_game_encrypted.dat"
const SETTINGS_PATH := "user://user_data/save_settings.cfg"

# Encryption settings
var encryption_enabled := false  # Encryption disabled by default
var use_dynamic_key := false     # Dynamic key temporarily disabled, using static key for stability

var current_level_name : String = ""

# Game save data structure
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

# Save result signals
signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)

func _ready():
	print("SaveManager: Initialization started...")
	
	# First load user's encryption preference settings
	_load_encryption_settings()
	
	print("SaveManager: Current encryption settings - Enabled:", encryption_enabled, " Dynamic Key:", use_dynamic_key)
	
	# Check save file status
	if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		print("SaveManager: Encrypted save file detected")
	if FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: Regular save file detected")
	
	# If no encryption preference is set, automatically set based on existing save type
	if not _has_saved_encryption_preference():
		if FileAccess.file_exists(ENCRYPTED_SAVE_PATH) and not FileAccess.file_exists(SAVE_PATH):
			# Only encrypted save exists, enable encryption
			encryption_enabled = true
			print("SaveManager: Automatically detected encrypted save, enabling encryption mode")
		elif FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
			# Only regular save exists, disable encryption
			encryption_enabled = false
			print("SaveManager: Automatically detected regular save, disabling encryption mode")
		# Save automatically detected settings
		_save_encryption_settings()
	
	print("SaveManager: Initialization complete")
	
	# Run encryption tests in development mode
	if OS.is_debug_build():
		print("SaveManager: Starting development mode functionality tests...")
		call_deferred("_run_encryption_tests")

func has_save() -> bool:
	# Check save file corresponding to current settings
	var current_save_exists = false
	if encryption_enabled:
		current_save_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
	else:
		current_save_exists = FileAccess.file_exists(SAVE_PATH)
	
	# If current format save doesn't exist, check if alternative format exists
	if not current_save_exists:
		var alternative_exists = false
		if encryption_enabled:
			alternative_exists = FileAccess.file_exists(SAVE_PATH)
		else:
			alternative_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
		
		# If alternative format save found, try to convert
		if alternative_exists:
			print("SaveManager: Found different format save, attempting conversion...")
			_convert_save_format()
			
			# Recheck
			if encryption_enabled:
				current_save_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
			else:
				current_save_exists = FileAccess.file_exists(SAVE_PATH)
	
	return current_save_exists

# Enhanced save progress function
func save_progress(level_name: String, player_data: Dictionary = {}) -> bool:
	print("SaveManager: Starting to save game progress...")
	
	current_level_name = level_name
	save_data["current_level"] = level_name
	save_data["save_timestamp"] = Time.get_datetime_string_from_system()
	
	# Update save data if player data is provided
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
	
	# Ensure save directory exists
	var save_dir = SAVE_PATH.get_base_dir()
	print("SaveManager: Checking save directory:", save_dir)
	
	if not DirAccess.dir_exists_absolute(save_dir):
		print("SaveManager: Creating save directory:", save_dir)
		var result = DirAccess.make_dir_recursive_absolute(save_dir)
		if result != OK:
			var error_msg = "Cannot create save directory: " + str(result)
			print("SaveManager Error: ", error_msg)
			save_completed.emit(false, error_msg)
			
			# Show error notification
			var notification_manager = get_node_or_null("/root/NotificationManager")
			if notification_manager and notification_manager.has_method("show_error"):
				notification_manager.show_error("Save failed: " + error_msg)
			
			return false
	
	# Choose save method based on encryption settings
	var save_success = false
	
	if encryption_enabled:
		# Use encrypted save
		save_success = _save_encrypted_data(save_data)
	else:
		# Use regular save
		save_success = _save_plain_data(save_data)
	
	if not save_success:
		var error_msg = "Failed to save game"
		print("SaveManager Error: ", error_msg)
		save_completed.emit(false, error_msg)
		
		# Show error notification
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("Save failed: " + error_msg)
		
		return false
	
	var success_msg = "Game successfully saved to: " + level_name
	print("SaveManager: ", success_msg)
	save_completed.emit(true, success_msg)
	
	# Show success notification
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager and notification_manager.has_method("show_success"):
		notification_manager.show_success("Game saved successfully!")
	
	return true

# Enhanced load progress function
func load_progress() -> Dictionary:
	print("SaveManager: Starting to load game progress...")
	
	if not has_save():
		var error_msg = "No save file found"
		print("SaveManager: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# Show error notification
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("No save file found")
		
		return {}
	
	# Choose load method based on encryption settings
	var data = {}
	
	if encryption_enabled:
		# Use encrypted load
		data = _load_encrypted_data()
	else:
		# Use regular load
		data = _load_plain_data()
	
	if data.is_empty():
		var error_msg = "Failed to load save data"
		print("SaveManager Error: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# Show error notification
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("Failed to load save data")
		
		return {}
	
	# Validate data
	if typeof(data) != TYPE_DICTIONARY:
		var error_msg = "Invalid save file data format"
		print("SaveManager Error: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# Show error notification
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("Invalid save file data format")
		
		return {}
	
	# Check required fields
	if not data.has("current_level"):
		var error_msg = "Save file missing critical data"
		print("SaveManager Error: ", error_msg)
		load_completed.emit(false, error_msg)
		
		# Show error notification
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_error"):
			notification_manager.show_error("Save file missing critical data")
		
		return {}
	
	# Update current data
	save_data = data
	current_level_name = data.get("current_level", "")
	
	var success_msg = "Save file loaded successfully: " + current_level_name
	print("SaveManager: ", success_msg)
	load_completed.emit(true, success_msg)
	
	# Show success notification
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager and notification_manager.has_method("show_success"):
		notification_manager.show_success("Save file loaded successfully!")
	
	return data

# Get save information
func get_save_info() -> Dictionary:
	if not has_save():
		return {}
	
	# Choose load method based on encryption settings
	var data = {}
	
	if encryption_enabled:
		data = _load_encrypted_data()
	else:
		data = _load_plain_data()
	
	if typeof(data) == TYPE_DICTIONARY and not data.is_empty():
		return {
			"level_name": data.get("current_level", "Unknown level"),
			"timestamp": data.get("save_timestamp", "Unknown time"),
			"player_hp": data.get("player_hp", 100),
			"player_max_hp": data.get("player_max_hp", 100),
			"player_exp": data.get("player_exp", 0),
			"encryption_enabled": encryption_enabled
		}
	
	return {}

# Quick save current game state
func quick_save() -> bool:
	print("SaveManager: ===== Starting quick save =====")
	# Try to get current player data
	var player_data = {}
	print("SaveManager: Step 1 - Initialization of player_data completed")
	
	var player = get_tree().get_first_node_in_group("player")
	print("SaveManager: Step 2 - Trying to get player node")
	
	if player:
		print("SaveManager: Step 3 - Found player node:", player.name)
		print("SaveManager: Step 3.1 - Player node type:", player.get_class())
		# Check attribute existence
		print("SaveManager: Step 3.2 - Checking current_hp attribute:", "current_hp" in player)
		print("SaveManager: Step 3.3 - Checking max_hp attribute:", "max_hp" in player)
		var hp_value = 100
		var max_hp_value = 100
		var position_value = Vector2.ZERO
		# Safe get HP value
		if "current_hp" in player:
			print("SaveManager: Step 3.4 - Trying to get current_hp")
			hp_value = player.current_hp
			print("SaveManager: Step 3.5 - current_hp value:", hp_value)
		else:
			print("SaveManager: Warning - current_hp attribute does not exist, using default value")
		# Safe get max HP value
		if "max_hp" in player:
			print("SaveManager: Step 3.6 - Trying to get max_hp")
			max_hp_value = player.max_hp
			print("SaveManager: Step 3.7 - max_hp value:", max_hp_value)
		else:
			print("SaveManager: Warning - max_hp attribute does not exist, using default value")
		# Safe get position
		print("SaveManager: Step 3.8 - Trying to get global_position")
		position_value = player.global_position
		print("SaveManager: Step 3.9 - position value:", position_value)
		# Build player_data
		print("SaveManager: Step 4 - Starting to build player_data dictionary")
		player_data = {
			"hp": hp_value,
			"max_hp": max_hp_value,
			"exp": 0,  # Player temporarily has no experience system
			"exp_to_next": 50,  # Use default value
			"position": position_value
		}
		print("SaveManager: Step 5 - player_data built completed:", player_data)
	else:
		print("SaveManager: Step 3 - Warning: Player node not found")
	# Try to get current level name
	print("SaveManager: Step 6 - Starting to get current level name")
	var current_scene = get_tree().current_scene
	print("SaveManager: Step 6.1 - current_scene:", current_scene)
	if current_scene == null:
		print("SaveManager: Error - current_scene is null")
		return false
	
	# Priority get level name from current_level_name attribute of scene
	var current_level_name_to_save = ""
	if "current_level_name" in current_scene and current_scene.current_level_name != "":
		current_level_name_to_save = current_scene.current_level_name
		print("SaveManager: Get from current_level_name of scene:", current_level_name_to_save)
	elif current_level_name != "":
		# If SaveManager has recorded current level name
		current_level_name_to_save = current_level_name
		print("SaveManager: Get from SaveManager record:", current_level_name_to_save)
	else:
		# Backup plan: Infer from scene file name
		var scene_file_path = current_scene.scene_file_path
		print("SaveManager: Step 6.2 - scene_file_path:", scene_file_path)
		var scene_name = scene_file_path.get_file().get_basename()
		print("SaveManager: Infer from scene file name:", scene_name)
		
		# Special handling for base_level scene
		if scene_name == "base_level":
			# Get level name from LevelManager
			var level_manager = get_node_or_null("/root/LevelManager")
			if level_manager and level_manager.next_level_name != "":
				current_level_name_to_save = level_manager.next_level_name
				print("SaveManager: Get from LevelManager:", current_level_name_to_save)
			else:
				current_level_name_to_save = "level_2"  # Default to level_2
				print("SaveManager: Use default value:", current_level_name_to_save)
		else:
			current_level_name_to_save = scene_name
	
	print("SaveManager: Step 7 - Final determined level name:", current_level_name_to_save)
	print("SaveManager: Step 8 - Preparing to call save_progress")
	var result = save_progress(current_level_name_to_save, player_data)
	print("SaveManager: Step 9 - save_progress call completed, result:", result)
	
	# Show save result notification
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		if result:
			notification_manager.notify_game_saved()
		else:
			notification_manager.show_error("Save failed! Please check disk space", 4.0)
	
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
		print("SaveManager: Save cleared")
	
	if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		DirAccess.remove_absolute(ENCRYPTED_SAVE_PATH)
		print("SaveManager: Encrypted save cleared")

# ============================================================================
# Encryption related private functions
# ============================================================================

## Save encrypted data
func _save_encrypted_data(data: Dictionary) -> bool:
	print("SaveManager: Saving encrypted data...")
	print("SaveManager: Data to save: ", data)
	
	# Get encryption key
	var encryption_key = EncryptionManager.ENCRYPTION_KEY
	if use_dynamic_key:
		encryption_key = EncryptionManager.generate_dynamic_key()
		print("SaveManager: Using dynamic key for save")
	else:
		print("SaveManager: Using static key for save: ", encryption_key)
	
	# Encrypt data
	var encrypted_bytes = EncryptionManager.encrypt_data(data, encryption_key)
	if encrypted_bytes.is_empty():
		print("SaveManager: Data encryption failed")
		return false
	
	print("SaveManager: Encryption completed, encrypted data size: ", encrypted_bytes.size(), " bytes")
	
	# Write encrypted file
	var file = FileAccess.open(ENCRYPTED_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("SaveManager: Cannot create encrypted save file: ", FileAccess.get_open_error())
		return false
	
	file.store_buffer(encrypted_bytes)
	file.close()
	
	print("SaveManager: Encrypted save saved to: ", ENCRYPTED_SAVE_PATH)
	return true

## Save regular data
func _save_plain_data(data: Dictionary) -> bool:
	print("SaveManager: Saving regular data...")
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("SaveManager: Cannot create save file: ", FileAccess.get_open_error())
		return false
	
	file.store_var(data)
	file.close()
	
	print("SaveManager: Regular save saved")
	return true

## Load encrypted data
func _load_encrypted_data() -> Dictionary:
	print("SaveManager: Loading encrypted data...")
	
	if not FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		print("SaveManager: Encrypted save file does not exist")
		return {}
	
	var file = FileAccess.open(ENCRYPTED_SAVE_PATH, FileAccess.READ)
	if file == null:
		print("SaveManager: Cannot open encrypted save file: ", FileAccess.get_open_error())
		return {}
	
	var encrypted_bytes = file.get_buffer(file.get_length())
	file.close()
	
	print("SaveManager: Read encrypted file, size: ", encrypted_bytes.size(), " bytes")
	
	# Get decryption key
	var encryption_key = EncryptionManager.ENCRYPTION_KEY
	if use_dynamic_key:
		encryption_key = EncryptionManager.generate_dynamic_key()
		print("SaveManager: Using dynamic key")
	else:
		print("SaveManager: Using static key: ", encryption_key)
	
	# Verify file integrity
	if not EncryptionManager.verify_encrypted_file(ENCRYPTED_SAVE_PATH):
		print("SaveManager: Error - Encrypted file integrity verification failed")
		return {}
	
	# Decrypt data
	var decrypted_data = EncryptionManager.decrypt_data(encrypted_bytes, encryption_key)
	if decrypted_data.is_empty():
		print("SaveManager: Data decryption failed")
		
		# Try to get file information for debugging
		var file_info = EncryptionManager.get_encrypted_file_info(ENCRYPTED_SAVE_PATH)
		print("SaveManager: File information: ", file_info)
		
		return {}
	
	print("SaveManager: Encrypted data loaded successfully, decrypted data: ", decrypted_data)
	return decrypted_data

## Load regular data
func _load_plain_data() -> Dictionary:
	print("SaveManager: Loading regular data...")
	
	if not FileAccess.file_exists(SAVE_PATH):
		print("SaveManager: Regular save file does not exist")
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("SaveManager: Cannot open save file: ", FileAccess.get_open_error())
		return {}
	
	var data = file.get_var()
	file.close()
	
	if typeof(data) != TYPE_DICTIONARY:
		print("SaveManager: Invalid save data format")
		return {}
	
	print("SaveManager: Regular data loaded successfully")
	return data

## Set encryption mode
## @param enabled: Whether to enable encryption
## @param dynamic_key: Whether to use dynamic key
func set_encryption_mode(enabled: bool, dynamic_key: bool = true):
	var old_enabled = encryption_enabled
	encryption_enabled = enabled
	use_dynamic_key = dynamic_key
	print("SaveManager: Encryption mode set - Enabled:", enabled, " Dynamic Key:", dynamic_key)
	
	# Save user's encryption preference settings
	_save_encryption_settings()
	
	# If encryption settings changed and existing save exists, try to convert format
	if old_enabled != enabled:
		print("SaveManager: Encryption settings changed, check if need to convert save format...")
		
		# Check old format save exists
		var old_format_exists = false
		if enabled:
			# Now to enable encryption, check if there is regular format save
			old_format_exists = FileAccess.file_exists(SAVE_PATH)
		else:
			# Now to disable encryption, check if there is encrypted format save
			old_format_exists = FileAccess.file_exists(ENCRYPTED_SAVE_PATH)
		
		if old_format_exists:
			print("SaveManager: Found old format save, starting conversion...")
			_convert_save_format()
		else:
			print("SaveManager: No old format save found to convert")
	
	print("SaveManager: Encryption mode set completed")

## Get save file information
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

## Run encryption tests (only in development mode)
func _run_encryption_tests():
	print("SaveManager: Starting to run encryption functionality tests...")
	
	# Delay a bit to ensure all systems are initialized
	await get_tree().create_timer(1.0).timeout
	
	# Check if EncryptionTest is available
	if not EncryptionTest:
		print("SaveManager: Warning - EncryptionTest class not available, skipping test")
		return
	
	var test_passed = EncryptionTest.run_all_tests()
	
	if test_passed:
		print("SaveManager: ✅ Encryption functionality tests passed all!")
		
		# Show success notification
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_success"):
			notification_manager.show_success("Encryption test passed!")
	else:
		print("SaveManager: ⚠️ Some encryption functionality tests failed, please check implementation")
		
		# Show more gentle notification in development mode
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager and notification_manager.has_method("show_info"):
			notification_manager.show_info("Save system ready (some tests failed)")
		elif notification_manager and notification_manager.has_method("notify_info"):
			notification_manager.notify_info("Save system ready")

## Manual run encryption tests (can be called in game)
func run_encryption_test_manual():
	print("SaveManager: Manual run encryption test...")
	if EncryptionTest:
		return EncryptionTest.run_all_tests()
	else:
		print("SaveManager: EncryptionTest not available")
		return false

## Debug: Print save system status
func debug_save_status():
	print("=== SaveManager Status Debug ===")
	print("Encryption enabled: ", encryption_enabled)
	print("Using dynamic key: ", use_dynamic_key)
	print("Current level name: ", current_level_name)
	print("Regular save path: ", SAVE_PATH)
	print("Encrypted save path: ", ENCRYPTED_SAVE_PATH)
	print("Regular save exists: ", FileAccess.file_exists(SAVE_PATH))
	print("Encrypted save exists: ", FileAccess.file_exists(ENCRYPTED_SAVE_PATH))
	print("has_save() result: ", has_save())
	
	# Get current scene information
	var current_scene = get_tree().current_scene
	if current_scene:
		print("Current scene file: ", current_scene.scene_file_path)
		print("Current scene name: ", current_scene.name)
		if "current_level_name" in current_scene:
			print("Scene level name: ", current_scene.current_level_name)
	
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			print("Regular save size: ", file.get_length(), " bytes")
			file.close()
			
		# Read and display save data
		var save_data = _load_plain_data()
		if not save_data.is_empty():
			print("Regular save level: ", save_data.get("current_level", "Not found"))
	
	if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
		var file = FileAccess.open(ENCRYPTED_SAVE_PATH, FileAccess.READ)
		if file:
			print("Encrypted save size: ", file.get_length(), " bytes")
			file.close()
		
		var file_info = EncryptionManager.get_encrypted_file_info(ENCRYPTED_SAVE_PATH)
		print("Encrypted save information: ", file_info)
		
		# Read and display save data
		var save_data = _load_encrypted_data()
		if not save_data.is_empty():
			print("Encrypted save level: ", save_data.get("current_level", "Not found"))
	
	print("=== Status Debug End ===")

## Load encryption preference settings
func _load_encryption_settings():
	if FileAccess.file_exists(SETTINGS_PATH):
		var config = ConfigFile.new()
		if config.load(SETTINGS_PATH) == OK:
			encryption_enabled = config.get_value("encryption", "enabled", false)
			use_dynamic_key = config.get_value("encryption", "use_dynamic_key", false)
			print("SaveManager: Loaded user encryption settings - Enabled:", encryption_enabled, " Dynamic Key:", use_dynamic_key)

## Save encryption preference settings
func _save_encryption_settings():
	var config = ConfigFile.new()
	config.set_value("encryption", "enabled", encryption_enabled)
	config.set_value("encryption", "use_dynamic_key", use_dynamic_key)
	config.set_value("encryption", "has_preference", true)
	
	# Ensure directory exists
	var save_dir = SETTINGS_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	
	config.save(SETTINGS_PATH)
	print("SaveManager: Encryption settings saved")

## Check if encryption preference has been saved
func _has_saved_encryption_preference() -> bool:
	if FileAccess.file_exists(SETTINGS_PATH):
		var config = ConfigFile.new()
		if config.load(SETTINGS_PATH) == OK:
			return config.get_value("encryption", "has_preference", false)
	return false

## Convert save format (called when encryption settings change)
func _convert_save_format():
	print("SaveManager: Starting to convert save format...")
	
	var source_data = {}
	var convert_success = false
	
	if encryption_enabled:
		# Need to convert from regular format to encrypted format
		if FileAccess.file_exists(SAVE_PATH):
			source_data = _load_plain_data()
			if not source_data.is_empty():
				convert_success = _save_encrypted_data(source_data)
				if convert_success:
					print("SaveManager: Successfully converted to encrypted format")
					# Delete old regular format file
					DirAccess.remove_absolute(SAVE_PATH)
	else:
		# Need to convert from encrypted format to regular format
		if FileAccess.file_exists(ENCRYPTED_SAVE_PATH):
			source_data = _load_encrypted_data()
			if not source_data.is_empty():
				convert_success = _save_plain_data(source_data)
				if convert_success:
					print("SaveManager: Successfully converted to regular format")
					# Delete old encrypted format file
					DirAccess.remove_absolute(ENCRYPTED_SAVE_PATH)
	
	if not convert_success:
		print("SaveManager: Save format conversion failed")
	
	return convert_success
