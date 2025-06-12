extends Node

## Save File Encryption Manager
## Responsible for encrypting and decrypting game save data, protecting user data security

# Encryption key configuration
const ENCRYPTION_KEY = "MazeFightingExplorer_SecureKey_2024"  # Updated to match the real game name
const MAGIC_HEADER = "MFEX"  # Magic number identifier for verifying encrypted save files (Maze Fighting Explorer)
const VERSION = "10"  # Encryption version identifier (fixed 2 bytes)

# Error code definitions
enum EncryptionError {
	SUCCESS = 0,
	INVALID_KEY = 1,
	INVALID_DATA = 2,
	INVALID_HEADER = 3,
	ENCRYPTION_FAILED = 4,
	DECRYPTION_FAILED = 5
}

## Encrypt dictionary data to byte array
## @param data: Dictionary data to encrypt
## @param key: Encryption key (optional, uses built-in key by default)
## @return: Encrypted byte array, returns empty array on failure
static func encrypt_data(data: Dictionary, key: String = ENCRYPTION_KEY) -> PackedByteArray:
	print("EncryptionManager: Starting data encryption...")
	print("EncryptionManager: Input data: ", data)
	print("EncryptionManager: Using key: ", key)
	
	if data.is_empty():
		print("EncryptionManager: Error - Data is empty")
		return PackedByteArray()
	
	if key.is_empty():
		print("EncryptionManager: Error - Key is empty")
		return PackedByteArray()
	
	# Serialize dictionary to byte array
	var json_string = JSON.stringify(data)
	if json_string.is_empty():
		print("EncryptionManager: Error - JSON serialization failed")
		return PackedByteArray()
	
	print("EncryptionManager: JSON serialization result: ", json_string)
	var data_bytes = json_string.to_utf8_buffer()
	print("EncryptionManager: Data serialization complete, size: ", data_bytes.size(), " bytes")
	
	# Simple XOR encryption
	var encrypted_data = _xor_encrypt(data_bytes, key)
	
	# Build complete encrypted file format
	var final_data = PackedByteArray()
	
	# Add magic number identifier (4 bytes)
	final_data.append_array(MAGIC_HEADER.to_utf8_buffer())
	
	# Add version information (2 bytes)
	final_data.append_array(VERSION.to_utf8_buffer())
	
	# Add data length (4 bytes)
	var data_length = encrypted_data.size()
	final_data.push_back(data_length & 0xFF)
	final_data.push_back((data_length >> 8) & 0xFF)
	final_data.push_back((data_length >> 16) & 0xFF)
	final_data.push_back((data_length >> 24) & 0xFF)
	
	# Add encrypted data
	final_data.append_array(encrypted_data)
	
	# Add simple checksum (2 bytes)
	var checksum = _calculate_checksum(encrypted_data)
	final_data.push_back(checksum & 0xFF)
	final_data.push_back((checksum >> 8) & 0xFF)
	
	print("EncryptionManager: Data encryption complete, final size: ", final_data.size(), " bytes")
	return final_data

## Decrypt byte array to dictionary data
## @param encrypted_data: Encrypted byte array
## @param key: Decryption key (optional, uses built-in key by default)
## @return: Decrypted dictionary data, returns empty dictionary on failure
static func decrypt_data(encrypted_data: PackedByteArray, key: String = ENCRYPTION_KEY) -> Dictionary:
	print("EncryptionManager: Starting data decryption...")
	print("EncryptionManager: Encrypted data size: ", encrypted_data.size(), " bytes")
	print("EncryptionManager: Using decryption key: ", key)
	
	if encrypted_data.is_empty():
		print("EncryptionManager: Error - Encrypted data is empty")
		return {}
	
	if key.is_empty():
		print("EncryptionManager: Error - Key is empty")
		return {}
	
	# Check minimum file size (magic 4 + version 2 + length 4 + checksum 2 = 12 bytes)
	if encrypted_data.size() < 12:
		print("EncryptionManager: Error - File size too small")
		return {}
	
	var offset = 0
	
	# Verify magic identifier
	var magic = encrypted_data.slice(offset, offset + 4).get_string_from_utf8()
	offset += 4
	print("EncryptionManager: Magic: '", magic, "' Offset: ", offset)
	if magic != MAGIC_HEADER:
		print("EncryptionManager: Error - Magic identifier mismatch: ", magic)
		return {}
	
	# Read version information
	var version = encrypted_data.slice(offset, offset + 2).get_string_from_utf8()
	offset += 2
	print("EncryptionManager: File version: '", version, "' Offset: ", offset)
	
	# Read data length
	print("EncryptionManager: Preparing to read data length, current offset: ", offset)
	print("EncryptionManager: Length bytes: [", encrypted_data[offset], ", ", encrypted_data[offset + 1], ", ", encrypted_data[offset + 2], ", ", encrypted_data[offset + 3], "]")
	var data_length = encrypted_data[offset] | (encrypted_data[offset + 1] << 8) | (encrypted_data[offset + 2] << 16) | (encrypted_data[offset + 3] << 24)
	offset += 4
	print("EncryptionManager: Data length: ", data_length, " Offset: ", offset)
	
	# Check data length validity
	if data_length <= 0 or offset + data_length + 2 > encrypted_data.size():
		print("EncryptionManager: Error - Invalid data length")
		return {}
	
	# Extract encrypted data
	var encrypted_content = encrypted_data.slice(offset, offset + data_length)
	offset += data_length
	
	# Read checksum
	var stored_checksum = encrypted_data[offset] | (encrypted_data[offset + 1] << 8)
	var calculated_checksum = _calculate_checksum(encrypted_content)
	
	# Verify checksum
	if stored_checksum != calculated_checksum:
		print("EncryptionManager: Error - Checksum mismatch")
		print("EncryptionManager: Stored checksum: ", stored_checksum)
		print("EncryptionManager: Calculated checksum: ", calculated_checksum)
		return {}
	
	# Decrypt data
	var decrypted_bytes = _xor_decrypt(encrypted_content, key)
	var json_string = decrypted_bytes.get_string_from_utf8()
	
	print("EncryptionManager: Decrypted JSON string: ", json_string)
	
	# Parse JSON
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("EncryptionManager: Error - JSON parsing failed, error code: ", parse_result)
		print("EncryptionManager: JSON string content: '", json_string, "'")
		return {}
	
	var result = json.data
	if typeof(result) != TYPE_DICTIONARY:
		print("EncryptionManager: Error - Parse result is not dictionary type, type: ", typeof(result))
		print("EncryptionManager: Parse result: ", result)
		return {}
	
	print("EncryptionManager: Data decryption complete, result: ", result)
	return result

## XOR encryption implementation
## @param data: Data to encrypt
## @param key: Encryption key
## @return: Encrypted data
static func _xor_encrypt(data: PackedByteArray, key: String) -> PackedByteArray:
	var key_bytes = key.to_utf8_buffer()
	var encrypted = PackedByteArray()
	
	for i in range(data.size()):
		var key_byte = key_bytes[i % key_bytes.size()]
		encrypted.push_back(data[i] ^ key_byte)
	
	return encrypted

## XOR decryption implementation (same as encryption)
## @param data: Data to decrypt
## @param key: Decryption key
## @return: Decrypted data
static func _xor_decrypt(data: PackedByteArray, key: String) -> PackedByteArray:
	return _xor_encrypt(data, key)  # XOR encryption and decryption are the same operation

## Calculate simple checksum
## @param data: Data to calculate checksum for
## @return: 16-bit checksum
static func _calculate_checksum(data: PackedByteArray) -> int:
	var checksum = 0
	for byte in data:
		checksum = (checksum + byte) % 65536
	return checksum

## Generate dynamic key based on user's system
## @param base_key: Base key
## @return: Enhanced key
static func generate_dynamic_key(base_key: String = ENCRYPTION_KEY) -> String:
	# Get system information to enhance the key
	var system_info = ""
	system_info += OS.get_name()  # Operating system name
	system_info += str(OS.get_processor_count())  # CPU core count
	
	# Simple key mixing
	var mixed_key = base_key + system_info
	return mixed_key.md5_text().substr(0, 32)  # Use MD5 hash and take first 32 characters

## Verify encrypted file integrity
## @param file_path: File path
## @return: Whether it's a valid encrypted file
static func verify_encrypted_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	# Simple verification: check magic identifier
	if data.size() < 4:
		return false
	
	var magic = data.slice(0, 4).get_string_from_utf8()
	return magic == MAGIC_HEADER

## Get encrypted file information
## @param file_path: File path
## @return: File information dictionary
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
