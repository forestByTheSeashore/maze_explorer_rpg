extends Node

## Input Validation Manager
## Responsible for validating and filtering user input, preventing malicious input and ensuring game stability

# Note: Used as autoload, no class_name needed

# Constants
const MAX_INPUT_FREQUENCY = 50  # Maximum input frequency per second
const MAX_MOVEMENT_SPEED = 300.0  # Maximum movement speed
const MAX_PLAYER_NAME_LENGTH = 20  # Maximum player name length
const ALLOWED_CHARACTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- "

# Input frequency tracking
var input_timestamps: Array[float] = []
var last_input_time: float = 0.0

## Validate movement input
## @param input_vector: Input vector
## @return: Validated safe input vector
static func validate_movement_input(input_vector: Vector2) -> Vector2:
	# Limit input vector magnitude
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	
	# Check if input values are within reasonable range
	input_vector.x = clamp(input_vector.x, -1.0, 1.0)
	input_vector.y = clamp(input_vector.y, -1.0, 1.0)
	
	return input_vector

## Validate attack input frequency
## @return: Whether this attack input is allowed
func validate_attack_input() -> bool:
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# Prevent too frequent attack inputs
	if current_timestamp - last_input_time < 0.1:  # Minimum 0.1 second interval
		print("InputValidator: Attack input too frequent, rejected")
		return false
	
	last_input_time = current_timestamp
	return true

## Validate username input
## @param username: User input name
## @return: Sanitized safe username
static func validate_username(username: String) -> String:
	if username.is_empty():
		return "Player"
	
	# Limit length
	if username.length() > MAX_PLAYER_NAME_LENGTH:
		username = username.substr(0, MAX_PLAYER_NAME_LENGTH)
	
	# Filter illegal characters
	var clean_username = ""
	for char in username:
		if char in ALLOWED_CHARACTERS:
			clean_username += char
	
	# Ensure not empty
	if clean_username.is_empty():
		clean_username = "Player"
	
	# Remove leading and trailing spaces
	clean_username = clean_username.strip_edges()
	
	return clean_username

## Validate file path
## @param file_path: File path
## @return: Whether it's a safe file path
static func validate_file_path(file_path: String) -> bool:
	# Prevent path traversal attacks
	if file_path.contains("..") or file_path.contains("//"):
		print("InputValidator: Detected unsafe file path: ", file_path)
		return false
	
	# Restrict access to user data directory only
	if not file_path.begins_with("user://"):
		print("InputValidator: File path must be in user directory: ", file_path)
		return false
	
	return true

## Validate save data
## @param save_data: Save data dictionary
## @return: Validated safe save data
static func validate_save_data(save_data: Dictionary) -> Dictionary:
	var validated_data = {}
	
	# Validate required fields
	var required_fields = ["player_hp", "player_max_hp", "current_level", "inventory"]
	for field in required_fields:
		if field in save_data:
			validated_data[field] = save_data[field]
		else:
			print("InputValidator: Missing required field: ", field)
			# Set default values
			match field:
				"player_hp":
					validated_data[field] = 100
				"player_max_hp":
					validated_data[field] = 100
				"current_level":
					validated_data[field] = "level_1"
				"inventory":
					validated_data[field] = {}
	
	# Validate value ranges
	if "player_hp" in validated_data:
		validated_data["player_hp"] = clamp(validated_data["player_hp"], 0, 9999)
	
	if "player_max_hp" in validated_data:
		validated_data["player_max_hp"] = clamp(validated_data["player_max_hp"], 1, 9999)
	
	return validated_data

## Log suspicious input
## @param input_type: Input type
## @param details: Detailed information
static func log_suspicious_input(input_type: String, details: String):
	var timestamp = Time.get_datetime_string_from_system()
	print("[SECURITY] ", timestamp, " - Suspicious input [", input_type, "]: ", details)
	
	# In actual deployment, this should write to a security log file
	# Can add more complex monitoring and alerting mechanisms 
