extends CharacterBody2D

# Player state enumeration
enum PlayerState { IDLE, WALK, ATTACK, DEATH }
var current_state: PlayerState = PlayerState.IDLE

# --- Export Variables ---
@export var speed: float = 150.0

# --- Node References ---
@onready var animated_sprite: AnimatedSprite2D = $PlayerAnimatedSprite

@onready var attack_hitbox: Area2D = $AttackHitbox # Reference to AttackHitbox node


# --- Player Attributes ---
var current_hp: int = 100
var max_hp: int = 100 # Previous code was 500, use GDD's initial value if defined
var facing_direction_vector: Vector2 = Vector2.DOWN # Used to record player's facing direction, used for attack and idle states

# --- Audio Variables ---
var move_sound_timer: float = 0.0
var move_sound_interval: float = 0.4  # Play move sound every 0.4 seconds while walking

# --- System Component References ---
var inventory_system: InventorySystem
var weapon_system: WeaponSystem

# --- Backward Compatible Signals ---
signal inventory_changed  # Inventory change signal (backward compatible)


# ============================================================================
# Built-in Functions
# ============================================================================
func _ready():
	add_to_group("player")
	print("Player node added to 'player' group")
	
	# Dynamically create and initialize system components
	_initialize_systems()
	
	# Connect animation finished signal, mainly for state transitions after attack and death animations
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Connect system signals (backward compatible)
	if inventory_system:
		inventory_system.inventory_changed.connect(_on_inventory_changed)
	if weapon_system:
		weapon_system.weapon_changed.connect(_on_weapon_changed)
	
	# Initially set idle animation based on facing direction
	_update_idle_animation()
	
	# Initialize attack power
	_recalculate_total_attacking_power()
	
	# Notify UI system that player is ready
	call_deferred("_notify_ui_player_ready")

# ============================================================================
# System Initialization
# ============================================================================
func _initialize_systems():
	"""Dynamically create and initialize system components"""
	# Create inventory system
	inventory_system = InventorySystem.new()
	inventory_system.name = "InventorySystem"
	add_child(inventory_system)
	print("InventorySystem creation completed")
	
	# Create weapon system  
	weapon_system = WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	add_child(weapon_system)
	print("WeaponSystem creation completed")

# ============================================================================
# System Callback Functions
# ============================================================================
func _on_inventory_changed():
	"""Inventory system change callback"""
	inventory_changed.emit()
	_update_inventory_ui()

func _on_weapon_changed(weapon: WeaponData):
	"""Weapon system change callback"""
	_recalculate_total_attacking_power()
	inventory_changed.emit()
	_update_inventory_ui()

func _handle_inventory_input():
	"""Handle inventory-related input"""
	# Toggle inventory (I key)
	if Input.is_action_just_pressed("toggle_inventory"):
		print("Pressed I key to toggle inventory")
		_toggle_inventory_panel()

func _physics_process(_delta: float) -> void:
	if current_state == PlayerState.DEATH:
		# If player is dead, don't execute any operations
		# After death animation finishes, handle subsequent logic in _on_animation_finished
		return

	# Handle weapon switching and inventory input
	if weapon_system:
		weapon_system.handle_weapon_input()
	_handle_inventory_input()

	# 1. Handle attack input (add input validation)
	if Input.is_action_just_pressed("attack"): # "attack" should be mapped to 'J' key
		# Validate attack input frequency
		if not InputValidator or InputValidator.validate_attack_input():
			if current_state != PlayerState.ATTACK: # Avoid attacking again while in attack state
				_enter_state(PlayerState.ATTACK)
				return # Don't process movement this frame after entering attack state

	# 2. Handle movement input (only in non-attack state, add input validation)
	var input_direction := Vector2.ZERO
	if current_state != PlayerState.ATTACK:
		var raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# Validate and sanitize movement input
		input_direction = InputValidator.validate_movement_input(raw_input)

	if input_direction.length_squared() > 0:
		facing_direction_vector = input_direction.normalized() # Update facing direction
		if current_state != PlayerState.ATTACK: # Only enter walk state if not attacking
			_enter_state(PlayerState.WALK)
	else:
		if current_state == PlayerState.WALK: # If previously walking and no input now, enter idle
			_enter_state(PlayerState.IDLE)

	# 3. Update velocity and animation based on current state
	match current_state:
		PlayerState.WALK:
			velocity = input_direction * speed
			_update_walk_animation()
			_handle_move_sound(_delta)
		PlayerState.IDLE:
			velocity = Vector2.ZERO
			_update_idle_animation() # Ensure idle animation based on correct facing_direction_vector
			move_sound_timer = 0.0  # Reset move sound timer when not walking
		PlayerState.ATTACK:
			velocity = Vector2.ZERO # Usually no movement allowed during attack
			# Attack animation triggered in _enter_state(PlayerState.ATTACK)
			move_sound_timer = 0.0  # Reset move sound timer when not walking
		PlayerState.DEATH:
			velocity = Vector2.ZERO
			move_sound_timer = 0.0  # Reset move sound timer when not walking
	
	# Handle enemy separation - don't interfere during attack
	if current_state != PlayerState.ATTACK:
		_apply_enemy_separation()
	
	move_and_slide()

func _apply_enemy_separation():
	"""Enhanced enemy separation system - resolve sticking issues"""
	if current_state == PlayerState.DEATH:
		return
		
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		
		# Expand detection range for early separation
		if distance < 30.0 and distance > 0.1:
			var push_direction = (global_position - enemy.global_position).normalized()
			var enemy_relative = enemy.global_position - global_position
			
			# Base separation force
			var push_force = 600.0
			
			# Special case handling
			if enemy_relative.y < -10:  # Enemy above player
				push_force = 1000.0
				# Force escape to the side
				if abs(push_direction.x) < 0.5:
					push_direction.x = 1.0 if randf() > 0.5 else -1.0
					push_direction.y = 0.3  # Slightly downward
					push_direction = push_direction.normalized()
				print("Player suppressed, strong escape")
			elif distance < 15.0:  # Very close
				push_force = 1200.0
				print("Too close, strong separation")
			
			# Apply separation force
			velocity += push_direction * push_force * get_physics_process_delta_time()
			
			# Additional position correction - direct position adjustment
			if distance < 12.0:
				var correction = push_direction * (12.0 - distance)
				global_position += correction
				print("Executing position correction, distance:", distance)

# ============================================================================
# State Management
# ============================================================================
func _enter_state(new_state: PlayerState):
	if current_state == new_state and new_state != PlayerState.ATTACK: # Allow re-entering attack state to reset attack animation
		return

	# print("Changing state from ", PlayerState.keys()[current_state], " to ", PlayerState.keys()[new_state]) # For debugging
	current_state = new_state

	match current_state:
		PlayerState.IDLE:
			_update_idle_animation()
		PlayerState.WALK:
			_update_walk_animation() # Walk animation will be continuously updated in physics_process based on direction
		PlayerState.ATTACK:
			_play_attack_animation()
		PlayerState.DEATH:
			_play_death_animation()

# ============================================================================
# Animation Handling
# ============================================================================
func _update_walk_animation():
	var anim_name = "walk_"
	var flip_h = false

	if abs(facing_direction_vector.y) > abs(facing_direction_vector.x): # Prioritize up/down
		if facing_direction_vector.y < 0:
			anim_name += "up"
		else:
			anim_name += "down"
	else: # Horizontal direction
		anim_name += "right" # Both left and right walking based on "walk_right"
		if facing_direction_vector.x < 0:
			flip_h = true

	_play_animation_if_different(anim_name, flip_h)

func _update_idle_animation():
	var anim_name = "idle_"
	var flip_h = false

	if abs(facing_direction_vector.y) > abs(facing_direction_vector.x): # Prioritize up/down
		if facing_direction_vector.y < 0:
			anim_name += "up"
		else:
			anim_name += "down"
	else: # Horizontal direction
		anim_name += "right" # Both left and right idle based on "idle_right"
		if facing_direction_vector.x < 0:
			flip_h = true
			
	_play_animation_if_different(anim_name, flip_h)

func _play_attack_animation():
	var anim_name = "attack_"
	var flip_h = false

	if abs(facing_direction_vector.y) > abs(facing_direction_vector.x):
		if facing_direction_vector.y < 0:
			anim_name += "up"
		else:
			anim_name += "down"
	else:
		anim_name += "right"
		if facing_direction_vector.x < 0:
			flip_h = true
			
	_play_animation_if_different(anim_name, flip_h)
	
	# --- Improved attack detection logic ---
	# Adjust AttackHitbox position and direction to match attack animation and facing direction
	var hitbox_offset = Vector2(20, 0) # Base offset
	if anim_name == "attack_up":
		attack_hitbox.rotation = -PI / 2
		attack_hitbox.position = Vector2(0, -20)
	elif anim_name == "attack_down":
		attack_hitbox.rotation = PI / 2
		attack_hitbox.position = Vector2(0, 20)
	elif anim_name.contains("right"):
		attack_hitbox.rotation = 0
		if flip_h:
			attack_hitbox.position = Vector2(-hitbox_offset.x, hitbox_offset.y)
		else:
			attack_hitbox.position = hitbox_offset
	
	# Enable attack detection
	attack_hitbox.monitoring = true
	print("Player starts attack, attack power: ", get_total_attack())
	
	# Reduce attack detection delay for faster response
	await get_tree().create_timer(0.1).timeout
	
	# Check attack hits
	var overlapping_bodies = attack_hitbox.get_overlapping_bodies()
	var hit_enemies = []
	
	for body in overlapping_bodies:
		if body.is_in_group("enemies") and body.has_method("receive_player_attack"):
			hit_enemies.append(body)
	
	# If direct detection fails, try expanded range detection
	if hit_enemies.size() == 0:
		var enemies_in_scene = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies_in_scene:
			if not is_instance_valid(enemy):
				continue
			var distance = global_position.distance_to(enemy.global_position)
			# Expand attack range detection
			if distance <= 35.0:  # Increase attack distance tolerance
				var direction_to_enemy = global_position.direction_to(enemy.global_position)
				var dot_product = facing_direction_vector.dot(direction_to_enemy)
				# Check if in attack direction (allow 45-degree error)
				if dot_product > 0.5:  # About 60-degree range
					hit_enemies.append(enemy)
					print("Expanded range detection hit: ", enemy.name, " distance: ", distance)
	
	# Play attack sound
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_attack_sound()
	
	# Deal damage to all hit enemies
	for enemy in hit_enemies:
		var damage_dealt = enemy.receive_player_attack(get_total_attack())
		print("Player attack hit: ", enemy.name, " damage dealt: ", damage_dealt)
		
		# Add hit effects and sounds
		_create_hit_effect(enemy.global_position)
		if audio_manager:
			audio_manager.play_enemy_hit_sound()
	
	if hit_enemies.size() == 0:
		print("Player attack missed all enemies")
	
	attack_hitbox.monitoring = false

# New: Create hit effect
func _create_hit_effect(hit_position: Vector2):
	print("Creating hit effect at position ", hit_position)
	
	# Add particle effect
	var effects_manager = get_node_or_null("/root/EffectsManager")
	if effects_manager:
		effects_manager.play_hit_effect(hit_position)

# You need to add or ensure there's a get_total_attack() function
var base_attack: int = 20 # Example base attack power
var current_weapon_attack: int = 5 # Attack power bonus from weapon (to be implemented with weapon system)


# ============================================================================
# Modify increase_hp_from_bean function to ensure weapon system compatibility
# ============================================================================
func update_ui():
	var ui = get_tree().get_first_node_in_group("ui_manager")
	if ui:
		ui.update_player_status(current_hp, max_hp, current_exp, exp_to_next_level)

func increase_hp_from_bean(amount: int):
	current_hp += amount
	max_hp += amount
	if inventory_system:
		inventory_system.consume_hp_bean()
	_recalculate_total_attacking_power()
	update_ui()
	_update_inventory_ui()
	_notify_inventory_changed()

	

# ============================================================================
# Modify Attack Power Calculation System
# ============================================================================
func _recalculate_total_attacking_power():
	# Attack power based on current HP
	var hp_based_attack = int(current_hp / 5.0)
	var weapon_attack = weapon_system.get_weapon_attack_power() if weapon_system else 0
	print("Recalculating attack power: HP-based attack(", hp_based_attack, ") + Weapon attack(", weapon_attack, ") = ", get_total_attack())

func get_total_attack() -> int:
	var hp_based_attack = int(current_hp / 5.0)
	var weapon_attack = weapon_system.get_weapon_attack_power() if weapon_system else 0
	return hp_based_attack + weapon_attack


# You need to add or ensure there's a gain_experience() function
var current_exp: int = 0
var exp_to_next_level: int = 50
func gain_experience(amount: int):
	current_exp += amount
	
	# Show experience gain notification
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		notification_manager.show_pickup("✨ Experience gained +" + str(amount), 2.5)
	
	if current_exp >= exp_to_next_level:
		level_up()
	update_ui()

func level_up():
	current_exp -= exp_to_next_level
	exp_to_next_level += 25
	max_hp += 20
	current_hp = max_hp
	base_attack += 2
	
	# Show level up notification
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		notification_manager.show_achievement("🆙 Level Up! HP and Attack Power increased", 4.0)
	
	update_ui()
	print("HP cap increased to: ", max_hp, ", Attack power increased to: ", base_attack)

func _handle_move_sound(delta: float):
	"""Handle move sound timing"""
	move_sound_timer += delta
	if move_sound_timer >= move_sound_interval:
		move_sound_timer = 0.0
		_play_move_sound()

func _play_move_sound():
	"""Play movement sound effect"""
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_move_sound()

func _play_death_animation():
	if animated_sprite.sprite_frames.has_animation("death"):
		_play_animation_if_different("death", false) # Death animation usually not flipped
	else:
		print("Error: 'death' animation not found!")
		_handle_game_over_logic() # If no death animation, directly handle game over

func _play_animation_if_different(anim_name: String, p_flip_h: bool):
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
		animated_sprite.flip_h = p_flip_h # Ensure correct flip state
	else:
		print("Warning: Animation '", anim_name, "' not found in SpriteFrames!")
		# Try to play a default animation, like corresponding direction's idle
		var fallback_idle_anim = "idle_"
		if anim_name.contains("_up"): fallback_idle_anim += "up"
		elif anim_name.contains("_down"): fallback_idle_anim += "down"
		else: fallback_idle_anim += "right" # Default fallback for horizontal direction
		
		if animated_sprite.sprite_frames.has_animation(fallback_idle_anim) and animated_sprite.animation != fallback_idle_anim :
			animated_sprite.play(fallback_idle_anim)
		animated_sprite.flip_h = p_flip_h # Apply flip even for fallback animation

func _play_hit_feedback():
	"""Play hit feedback effect"""
	if not animated_sprite:
		return
	
	# Save original color
	var original_modulate = animated_sprite.modulate
	
	# Immediately turn red to indicate hit, enhance visual feedback
	animated_sprite.modulate = Color.RED
	
	# Increase hit feedback duration for more noticeable effect
	await get_tree().create_timer(0.2).timeout
	
	# Ensure node still exists before restoring color
	if animated_sprite:
		animated_sprite.modulate = original_modulate
	
	print("Player hit feedback effect completed")

func _on_animation_finished():
	# print("Animation finished: ", animated_sprite.animation) # For debugging
	if current_state == PlayerState.ATTACK:
		# After attack animation finishes, immediately perform forced separation, then decide state based on input
		_apply_post_attack_separation()
		
		var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_direction.length_squared() > 0:
			_enter_state(PlayerState.WALK)
		else:
			_enter_state(PlayerState.IDLE)
	elif current_state == PlayerState.DEATH and animated_sprite.animation == "death":
		# Death animation finished
		_handle_game_over_logic()

func _apply_post_attack_separation():
	"""Post-attack forced separation - avoid getting stuck after attack finishes"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		
		if distance < 20.0 and distance > 0.1:
			var push_direction = (global_position - enemy.global_position).normalized()
			
			# Strong push after attack to ensure not getting stuck
			var push_distance = 25.0
			var collision = move_and_collide(push_direction * push_distance)
			
			if collision:
				# If direct push meets obstacle, try escaping sideways
				var perpendicular = Vector2(-push_direction.y, push_direction.x)
				move_and_collide(perpendicular * 15.0)
			
			print("Post-attack forced separation, distance:", distance)

# ============================================================================
# Player Actions
# ============================================================================
func take_damage(amount: int):
	if current_state == PlayerState.DEATH: # If already dead, don't take damage
		return

	current_hp -= amount
	current_hp = max(0, current_hp)
	update_ui()
	# Can emit signal here to update UI: emit_signal("hp_updated", current_hp, max_hp)

	# Play hit feedback effect
	_play_hit_feedback()

	if current_hp == 0:
		_enter_state(PlayerState.DEATH)
	else:
		# If not dead, can play hit animation or sound
		print("Player took damage, remaining HP: ", current_hp)

func heal(amount: int):
	if current_state == PlayerState.DEATH: # If dead, can't heal
		return
	current_hp += amount
	current_hp = min(current_hp, max_hp)
	update_ui()
	# Can emit signal here to update UI: emit_signal("hp_updated", current_hp, max_hp)

func _handle_game_over_logic():
	print("Player died - Showing Game Over screen!")
	
	# Update victory manager statistics
	var victory_manager = get_node_or_null("/root/VictoryManager")
	if victory_manager:
		victory_manager.increment_deaths()
	
	# Play death sound
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_player_hurt_sound()
	
	# Play death effect
	var effects_manager = get_node_or_null("/root/EffectsManager")
	if effects_manager:
		effects_manager.create_screen_flash(Color.RED, 0.5)
	
	# Stop all player physics processing
	set_physics_process(false)
	
	# Stop animation at last frame
	if animated_sprite:
		animated_sprite.stop()
	
	# Find and show Game Over screen
	var game_over_screen = _find_or_create_game_over_screen()
	if game_over_screen:
		game_over_screen.show_game_over()
	else:
		print("Error: Cannot find or create Game Over screen")
		# Fallback: Reload scene after delay
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()

func _find_or_create_game_over_screen():
	"""Find or create Game Over screen"""
	# First try to find Game Over screen in current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		var game_over_node = current_scene.find_child("GameOverScreen", true, false)
		if game_over_node:
			print("Found existing Game Over screen")
			return game_over_node
		
		# Try to find in CanvasLayer
		var canvas_layers = current_scene.find_children("CanvasLayer", "", true, false)
		for canvas_layer in canvas_layers:
			var game_over_in_canvas = canvas_layer.find_child("GameOverScreen", true, false)
			if game_over_in_canvas:
				print("Found Game Over screen in CanvasLayer")
				return game_over_in_canvas
	
	# If not found, try to create dynamically
	print("Game Over screen not found, attempting dynamic load")
	var game_over_scene_path = "res://scenes/game_over.tscn"
	
	if FileAccess.file_exists(game_over_scene_path):
		var game_over_scene = load(game_over_scene_path)
		if game_over_scene:
			var game_over_instance = game_over_scene.instantiate()
			
			# Add to most appropriate parent node
			var target_parent = _find_best_ui_parent()
			if target_parent:
				target_parent.add_child(game_over_instance)
				print("Successfully created and added Game Over screen to:", target_parent.name)
				return game_over_instance
			else:
				print("Error: Cannot find suitable parent node for Game Over screen")
				game_over_instance.queue_free()
	
	print("Cannot load Game Over scene file:", game_over_scene_path)
	return null

func _find_best_ui_parent():
	"""Find the most suitable parent node for UI"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	
	# Prefer existing CanvasLayer
	var canvas_layers = current_scene.find_children("CanvasLayer", "", true, false)
	for canvas_layer in canvas_layers:
		# Avoid adding to minimap CanvasLayer
		if canvas_layer.name != "MiniMapCanvas" and not canvas_layer.name.to_lower().contains("minimap"):
			print("Using existing CanvasLayer:", canvas_layer.name)
			return canvas_layer
	
	# If no suitable CanvasLayer found, create a new one
	var new_canvas_layer = CanvasLayer.new()
	new_canvas_layer.name = "GameOverCanvasLayer"
	new_canvas_layer.layer = 100  # Ensure it's on top
	current_scene.add_child(new_canvas_layer)
	print("Created new CanvasLayer for Game Over screen")
	return new_canvas_layer



# ============================================================================
# Key System
# ============================================================================
func add_key(key_type: String):
	if inventory_system:
		inventory_system.add_key(key_type)
		# Update interface display
		_update_inventory_ui()
		# Notify inventory UI update
		call_deferred("_notify_inventory_changed")

func has_key(key_type: String) -> bool:
	if inventory_system:
		return inventory_system.has_key(key_type)
	return false

func use_key(key_type: String) -> bool:
	if inventory_system:
		var success = inventory_system.use_key(key_type)
		if success:
			_update_inventory_ui()
			# Notify inventory UI update
			call_deferred("_notify_inventory_changed")
		return success
	else:
		print("Inventory system not found, cannot use key")
		return false

func get_keys() -> Array[String]:
	if inventory_system:
		return inventory_system.get_keys()
	return []

# ============================================================================
# Modify Interface Update Function, Add Weapon Information Display
# ============================================================================
func _update_inventory_ui():
	print("=== Player Status Update ===")
	print("Current HP: ", current_hp, " Max HP: ", max_hp)
	var current_weapon = weapon_system.get_current_weapon() if weapon_system else null
	print("Current Weapon: ", current_weapon.weapon_name if current_weapon else "None", " (Attack Power: ", current_weapon.attack_power if current_weapon else 0, ")")
	print("Weapons Owned: ", weapon_system.get_weapon_count() if weapon_system else 0)
	print("Keys Owned: ", inventory_system.get_keys() if inventory_system else [])
	print("HP Beans Consumed: ", inventory_system.get_hp_beans_consumed() if inventory_system else 0)
	print("Total Attack Power: ", get_total_attack())
	print("=====================")




# ============================================================================
# Backward Compatible Weapon Interface Functions (Delegate to Weapon System)
# ============================================================================
func try_equip_weapon(weapon_id: String, weapon_name: String, weapon_attack: int) -> bool:
	"""Try to equip new weapon (backward compatible interface)"""
	if weapon_system:
		return weapon_system.try_equip_weapon(weapon_id, weapon_name, weapon_attack)
	else:
		return false
	
func switch_to_next_weapon():
	"""Switch to next weapon (backward compatible interface)"""
	if weapon_system:
		weapon_system.switch_to_next_weapon()

func switch_to_previous_weapon():
	"""Switch to previous weapon (backward compatible interface)"""
	if weapon_system:
		weapon_system.switch_to_previous_weapon()

func switch_to_weapon_by_index(index: int):
	"""Switch to weapon at specified index (backward compatible interface)"""
	if weapon_system:
		weapon_system.switch_to_weapon_by_index(index)

func get_available_weapons() -> Array[WeaponData]:
	"""Get all available weapons (backward compatible interface)"""
	if weapon_system:
		return weapon_system.get_available_weapons()
	return []

func get_current_weapon() -> WeaponData:
	"""Get current weapon (backward compatible interface)"""
	if weapon_system:
		return weapon_system.get_current_weapon()
	return null

func get_weapon_count() -> int:
	"""Get weapon count (backward compatible interface)"""
	if weapon_system:
		return weapon_system.get_weapon_count()
	return 0

# ============================================================================
# UI Notification System
# ============================================================================
func _notify_inventory_changed():
	"""Backward compatible notification function"""
	inventory_changed.emit()

func _toggle_inventory_panel():
	# This function will be called by UI system
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("toggle_inventory"):
		ui_manager.toggle_inventory()
	else:
		print("UI Manager not found, cannot toggle inventory panel")

# ============================================================================
# New: Notify UI that player is ready
func _notify_ui_player_ready():
	print("Player ready, notifying UI system")
	# Immediately emit inventory change signal to ensure UI connection
	_notify_inventory_changed()
	
	# Notify UIManager to update player status
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("_try_connect_player"):
		ui_manager._try_connect_player()
		print("Notified UIManager to reconnect player")

# ============================================================================
# New: Player Attack State Detection
# ============================================================================
func is_attacking() -> bool:
	"""Return whether player is in attack state, for enemy scripts to call"""
	return current_state == PlayerState.ATTACK

func is_dead() -> bool:
	"""Return whether player is dead, for enemy scripts to call"""
	return current_state == PlayerState.DEATH
