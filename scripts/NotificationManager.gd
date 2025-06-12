extends CanvasLayer

# Notification Manager - Used to display various messages in the game
# Examples: save successful, load failed, etc.

var notification_container: VBoxContainer
var notification_queue = []
var max_notifications = 5  # Increased maximum number of notifications
var notification_duration = 3.0

# Notification type configurations
var notification_types = {
	"success": {
		"color": Color(0.2, 0.8, 0.2, 0.95),
		"icon": "✓",
		"sound": "pickup"
	},
	"error": {
		"color": Color(0.8, 0.2, 0.2, 0.95),
		"icon": "✗",
		"sound": "door_locked"
	},
	"warning": {
		"color": Color(0.9, 0.7, 0.2, 0.95),
		"icon": "⚠",
		"sound": "button_click"
	},
	"info": {
		"color": Color(0.2, 0.5, 0.9, 0.95),
		"icon": "ℹ",
		"sound": null
	},
	"achievement": {
		"color": Color(0.8, 0.4, 0.9, 0.95),
		"icon": "🏆",
		"sound": "level_complete"
	},
	"pickup": {
		"color": Color(0.3, 0.9, 0.6, 0.95),
		"icon": "📦",
		"sound": "pickup"
	},
	"navigation": {
		"color": Color(0.4, 0.8, 0.9, 0.95),
		"icon": "🧭",
		"sound": null
	}
}

func _ready():
	print("NotificationManager: Initializing...")
	
	# Ensure notification system works even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create notification container
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notification_container.position = Vector2(-320, 20)  # Top-right position
	notification_container.custom_minimum_size = Vector2(300, 0)
	add_child(notification_container)
	
	print("NotificationManager: Initialization Complete")

# Display notification message
func show_notification(message: String, type: String = "info", duration: float = 3.0):
	print("NotificationManager: Showing notification - ", message)
	
	# Play sound effect
	_play_notification_sound(type)
	
	# Create notification node
	var notification = create_notification_node(message, type)
	
	# Add to container
	notification_container.add_child(notification)
	notification_queue.append(notification)
	
	# Remove oldest if too many
	while notification_queue.size() > max_notifications:
		var old_notification = notification_queue.pop_front()
		if is_instance_valid(old_notification):
			remove_notification(old_notification)
	
	# Set auto-removal
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(_timer_timeout_wrapper.bind(notification))
	
	# Show animation
	animate_notification_in(notification)

# Wrapper function to handle timer timeout safely
func _timer_timeout_wrapper(notification: Control):
	_on_timer_timeout(notification)

# Create notification node
func create_notification_node(message: String, type: String) -> Control:
	var notification = Panel.new()
	notification.custom_minimum_size = Vector2(300, 70)
	
	# Get type configuration
	var type_config = notification_types.get(type, notification_types["info"])
	
	# Set style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = type_config.color
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color.WHITE.lerp(type_config.color, 0.3)
	notification.add_theme_stylebox_override("panel", style_box)
	
	# Create main container
	var main_container = HBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	notification.add_child(main_container)
	
	# Add icon
	var icon_label = Label.new()
	icon_label.text = type_config.icon
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(40, 0)
	main_container.add_child(icon_label)
	
	# Add text label
	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(label)
	
	return notification

# Play notification sound
func _play_notification_sound(type: String):
	var type_config = notification_types.get(type, notification_types["info"])
	var sound_name = type_config.get("sound")
	
	if sound_name:
		var audio_manager = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("play_sfx"):
			# Simplified audio system sound mapping
			var simple_sound = ""
			match sound_name:
				"pickup":
					simple_sound = "pickup"
				"door_locked":
					simple_sound = "door_open"
				"button_click":
					simple_sound = "button"
				"level_complete":
					simple_sound = "victory"
				_:
					simple_sound = "button"  # Default to button sound
			
			audio_manager.play_sfx(simple_sound, -5.0)

# Remove notification
func remove_notification(notification: Control):
	if is_instance_valid(notification) and notification in notification_queue:
		notification_queue.erase(notification)
		animate_notification_out(notification)

# Show animation
func animate_notification_in(notification: Control):
	notification.modulate.a = 0.0
	notification.scale = Vector2(0.8, 0.8)
	notification.position.x += 50  # Slide in from right
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.4)
	tween.tween_property(notification, "scale", Vector2(1.0, 1.0), 0.4)
	tween.tween_property(notification, "position:x", notification.position.x - 50, 0.4)

# Hide animation
func animate_notification_out(notification: Control):
	if not is_instance_valid(notification):
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 0.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(0.8, 0.8), 0.3)
	tween.tween_property(notification, "position:x", notification.position.x + 50, 0.3)
	tween.tween_callback(func(): 
		if is_instance_valid(notification):
			notification.queue_free()
	).set_delay(0.3)

# Clear all notifications
func clear_all_notifications():
	for notification in notification_queue:
		if is_instance_valid(notification):
			notification.queue_free()
	notification_queue.clear()

# Convenience methods
func show_success(message: String, duration: float = 3.0):
	show_notification(message, "success", duration)

func show_error(message: String, duration: float = 4.0):
	show_notification(message, "error", duration)

func show_warning(message: String, duration: float = 3.5):
	show_notification(message, "warning", duration)

func show_info(message: String, duration: float = 3.0):
	show_notification(message, "info", duration)

func show_achievement(message: String, duration: float = 5.0):
	show_notification(message, "achievement", duration)

func show_pickup(message: String, duration: float = 2.5):
	show_notification(message, "pickup", duration)

func show_navigation(message: String, duration: float = 3.0):
	show_notification(message, "navigation", duration)

## ============================================================================
## Game-specific notification methods
## ============================================================================

# Key-related notifications
func notify_key_obtained(key_type: String = "Key"):
	show_pickup("🔑 Successfully obtained " + key_type + "! Now you can open the door", 4.0)

func notify_key_used(key_type: String = "Key"):
	show_info("🔑 Used " + key_type)

func notify_key_required(key_type: String = "Key"):
	show_warning("🚪 This door requires " + key_type + " to open")

func notify_key_already_collected():
	show_navigation("🔑 Key already collected! Navigate to the exit door")

# Navigation-related notifications
func notify_navigation_to_key():
	show_navigation("🧭 Showing path to key")

func notify_navigation_to_door():
	show_navigation("🧭 Showing path to exit door")

func notify_navigation_disabled():
	show_info("🧭 Path guidance disabled")

# Item pickup notifications
func notify_weapon_obtained(weapon_name: String, attack_power: int):
	show_pickup("⚔️ Obtained weapon: " + weapon_name + " (Attack +" + str(attack_power) + ")", 3.5)

func notify_hp_increased(amount: int):
	show_pickup("❤️ HP permanently increased +" + str(amount) + "!", 3.0)

# Combat-related notifications
func notify_enemy_defeated(enemy_name: String):
	show_success("⚔️ Defeated " + enemy_name + "!")

func notify_player_hurt(damage: int):
	show_warning("💔 Took " + str(damage) + " damage!")

# Game progress notifications
func notify_level_complete():
	show_achievement("🎉 Level complete! Congratulations!", 6.0)

func notify_door_opened():
	show_success("🚪 Door opened!")

func notify_door_locked():
	show_warning("🔒 Door is locked")

# System notifications
func notify_game_saved():
	show_success("💾 Game saved")

func notify_game_loaded():
	show_success("📁 Game loaded")

func notify_quick_save():
	show_info("💾 Quick saving...")

func notify_quick_load():
	show_info("📁 Quick loading...")

# Timer timeout handler to safely remove notifications
func _on_timer_timeout(notification: Control):
	if is_instance_valid(notification):
		remove_notification(notification)