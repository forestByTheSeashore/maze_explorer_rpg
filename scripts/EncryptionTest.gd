extends Node
class_name EncryptionTest

## Save file encryption test class
## Used to verify the correctness of encryption and decryption functionality

## Run all encryption tests
static func run_all_tests() -> bool:
	print("=== Starting Encryption Tests ===")
	
	var all_passed = true
	
	# Basic encryption/decryption test
	if not test_basic_encryption():
		all_passed = false
		print("❌ Basic encryption/decryption test failed")
	else:
		print("✅ Basic encryption/decryption test passed")
	
	# Empty data handling test
	if not test_empty_data():
		all_passed = false
		print("❌ Empty data handling test failed")
	else:
		print("✅ Empty data handling test passed")
	
	# Complex data structure test
	if not test_complex_data():
		all_passed = false
		print("❌ Complex data structure test failed")
	else:
		print("✅ Complex data structure test passed")
	
	# Different keys test
	if not test_different_keys():
		all_passed = false
		print("❌ Different keys test failed")
	else:
		print("✅ Different keys test passed")
	
	# File integrity test
	if not test_file_integrity():
		all_passed = false
		print("❌ File integrity test failed")
	else:
		print("✅ File integrity test passed")
	
	print("=== Encryption Tests Complete ===")
	if all_passed:
		print("🎉 All tests passed!")
	else:
		print("⚠️ Some tests failed, please check encryption implementation")
		print("   Note: Some type mismatches are normal when audio files are missing")
	
	return all_passed

## Basic encryption/decryption test
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
	
	# Encrypt data
	var encrypted = EncryptionManager.encrypt_data(test_data)
	if encrypted.is_empty():
		print("Encryption failed: returned empty data")
		return false
	
	# Decrypt data
	var decrypted = EncryptionManager.decrypt_data(encrypted)
	if decrypted.is_empty():
		print("Decryption failed: returned empty data")
		return false
	
	# Verify data consistency
	for key in test_data.keys():
		if not decrypted.has(key):
			print("Decrypted data missing key: ", key)
			return false
		
		var original_value = test_data[key]
		var decrypted_value = decrypted[key]
		
		# Special handling for Vector2 type (becomes string after JSON serialization)
		if typeof(original_value) == TYPE_VECTOR2:
			# Vector2 is serialized in JSON as string format like "(120, 240)"
			var expected_string = str(original_value)
			if typeof(decrypted_value) == TYPE_STRING and decrypted_value == expected_string:
				continue  # Match successful
			else:
				print("Vector2 data mismatch - Key: ", key, " Original: ", original_value, " Decrypted: ", decrypted_value)
				return false
		elif decrypted_value != original_value:
			print("Decrypted data mismatch - Key: ", key, " Original: ", original_value, " Decrypted: ", decrypted_value)
			return false
	
	return true

## Empty data handling test
static func test_empty_data() -> bool:
	# Test empty dictionary
	var empty_dict = {}
	var encrypted_empty = EncryptionManager.encrypt_data(empty_dict)
	if not encrypted_empty.is_empty():
		print("Empty dictionary encryption should return empty data")
		return false
	
	# Test empty byte array decryption
	var empty_bytes = PackedByteArray()
	var decrypted_empty = EncryptionManager.decrypt_data(empty_bytes)
	if not decrypted_empty.is_empty():
		print("Empty byte array decryption should return empty dictionary")
		return false
	
	return true

## Complex data structure test
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
	
	# Encrypt and decrypt
	var encrypted = EncryptionManager.encrypt_data(complex_data)
	if encrypted.is_empty():
		print("Complex data encryption failed")
		return false
	
	var decrypted = EncryptionManager.decrypt_data(encrypted)
	if decrypted.is_empty():
		print("Complex data decryption failed")
		return false
	
	# Recursively verify data structure
	return _compare_dictionaries(complex_data, decrypted)

## Different keys test
static func test_different_keys() -> bool:
	var test_data = {
		"test": "Key test data",
		"number": 42
	}
	
	var key1 = "test_key_1"
	var key2 = "test_key_2"
	
	# Encrypt with key1
	var encrypted1 = EncryptionManager.encrypt_data(test_data, key1)
	if encrypted1.is_empty():
		print("Key1 encryption failed")
		return false
	
	# Decrypt with key1 - should succeed
	var decrypted1 = EncryptionManager.decrypt_data(encrypted1, key1)
	if decrypted1.is_empty() or decrypted1["test"] != test_data["test"]:
		print("Same key decryption failed")
		return false
	
	# Decrypt with key2 - should fail or get incorrect data
	var decrypted2 = EncryptionManager.decrypt_data(encrypted1, key2)
	if not decrypted2.is_empty() and decrypted2.get("test", "") == test_data["test"]:
		print("Different key decryption should not succeed")
		return false
	
	return true

## File integrity test
static func test_file_integrity() -> bool:
	# Create test file path
	var test_file_path = "user://encryption_test.dat"
	
	var test_data = {
		"integrity_test": true,
		"data": "File integrity test data",
		"checksum_test": 12345
	}
	
	# Encrypt data
	var encrypted = EncryptionManager.encrypt_data(test_data)
	if encrypted.is_empty():
		print("Integrity test: Encryption failed")
		return false
	
	# Write to file
	var file = FileAccess.open(test_file_path, FileAccess.WRITE)
	if file == null:
		print("Integrity test: Unable to create test file")
		return false
	
	file.store_buffer(encrypted)
	file.close()
	
	# Verify file existence
	if not EncryptionManager.verify_encrypted_file(test_file_path):
		print("Integrity test: File verification failed")
		return false
	
	# Read and decrypt file
	var read_file = FileAccess.open(test_file_path, FileAccess.READ)
	if read_file == null:
		print("Integrity test: Unable to read test file")
		return false
	
	var file_data = read_file.get_buffer(read_file.get_length())
	read_file.close()
	
	var decrypted = EncryptionManager.decrypt_data(file_data)
	if decrypted.is_empty():
		print("Integrity test: File decryption failed")
		return false
	
	# Verify data
	if decrypted["integrity_test"] != true or decrypted["data"] != test_data["data"]:
		print("Integrity test: Decrypted data mismatch")
		return false
	
	# Clean up test file
	DirAccess.remove_absolute(test_file_path)
	
	return true

## Recursively compare dictionaries
static func _compare_dictionaries(dict1: Dictionary, dict2: Dictionary) -> bool:
	if dict1.size() != dict2.size():
		print("Dictionary size mismatch: ", dict1.size(), " vs ", dict2.size())
		return false
	
	for key in dict1.keys():
		if not dict2.has(key):
			print("Dictionary 2 missing key: ", key)
			return false
		
		var val1 = dict1[key]
		var val2 = dict2[key]
		
		# Fault-tolerant comparison: consider type changes from JSON serialization
		if not _values_equal(val1, val2, key):
			return false
	
	return true

## Fault-tolerant value comparison function
static func _values_equal(val1, val2, context_key: String = "") -> bool:
	var type1 = typeof(val1)
	var type2 = typeof(val2)
	
	# Handle Vector2 type (becomes string after JSON serialization)
	if type1 == TYPE_VECTOR2:
		var expected_string = str(val1)
		if type2 == TYPE_STRING and val2 == expected_string:
			return true
		else:
			print("Vector2 value mismatch - Key: ", context_key, " Value1: ", val1, " Value2: ", val2)
			return false
	
	# Handle fault-tolerant number type comparison (int vs float)
	if (type1 == TYPE_INT and type2 == TYPE_FLOAT) or (type1 == TYPE_FLOAT and type2 == TYPE_INT):
		# Compare numerical values
		if abs(float(val1) - float(val2)) < 0.0001:  # Floating point precision tolerance
			return true
		else:
			print("Numerical mismatch - Key: ", context_key, " Value1: ", val1, " (", type1, ") Value2: ", val2, " (", type2, ")")
			return false
	
	# Types must match (except for special cases above)
	if type1 != type2:
		print("Type mismatch - Key: ", context_key, " Type1: ", type1, " Type2: ", type2)
		return false
	
	# Recursively handle complex types
	if type1 == TYPE_DICTIONARY:
		if not _compare_dictionaries(val1, val2):
			print("Nested dictionary mismatch - Key: ", context_key)
			return false
	elif type1 == TYPE_ARRAY:
		if not _compare_arrays(val1, val2):
			print("Array mismatch - Key: ", context_key)
			return false
	else:
		# Direct comparison for simple types
		if val1 != val2:
			print("Value mismatch - Key: ", context_key, " Value1: ", val1, " Value2: ", val2)
			return false
	
	return true

## Recursively compare arrays
static func _compare_arrays(arr1: Array, arr2: Array) -> bool:
	if arr1.size() != arr2.size():
		print("Array size mismatch: ", arr1.size(), " vs ", arr2.size())
		return false
	
	for i in range(arr1.size()):
		var val1 = arr1[i]
		var val2 = arr2[i]
		
		# Use fault-tolerant comparison
		if not _values_equal(val1, val2, "Array index[" + str(i) + "]"):
			return false
	
	return true

## Print encrypted file information (for debugging)
static func print_file_info(file_path: String):
	if not FileAccess.file_exists(file_path):
		print("File does not exist: ", file_path)
		return
	
	var info = EncryptionManager.get_encrypted_file_info(file_path)
	print("=== Encrypted File Information ===")
	print("File path: ", file_path)
	print("Magic identifier: ", info.get("magic", "Unknown"))
	print("File version: ", info.get("version", "Unknown"))
	print("Data length: ", info.get("data_length", 0), " bytes")
	print("Total file size: ", info.get("total_size", 0), " bytes")
	print("File validity: ", "Valid" if info.get("is_valid", false) else "Invalid")
	print("===================") 