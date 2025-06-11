# SkelontonEnemy.gd
extends CharacterBody2D

# FSM State Enumeration
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

# --- Export Variables (adjustable in editor) ---
@export var health: int = 80
@export var attack_power: int = 20
@export var speed: float = 70.0
@export var experience_drop: int = 30

@export var detection_radius_behavior: bool = true # Whether to use detection radius Area2D
@export var detection_distance: float = 200.0    # Distance to detect player (if not using Area2D)
@export var attack_distance: float = 40.0        # Distance to enter attack state
@export var attack_cooldown: float = 1.5         # Attack interval (seconds)
@export var attack_hitbox_reach: float = 25.0    # Forward offset of attack hitbox
@export var personal_space: float = 25.0         # Enemy personal space to prevent overcrowding
@export var enemy_separation_force: float = 150.0  # Force of separation between enemies
@export var player_separation_threshold: float = 20.0  # Minimum distance threshold from player

# --- Chase Behavior Configuration ---
@export var chase_type: ChaseType = ChaseType.NORMAL  # Chase type
@export var max_chase_distance: float = 800.0        # Maximum chase distance (for endless chase type)
@export var lose_target_time: float = 5.0            # Time to stop chasing after losing target

enum ChaseType { NORMAL, ENDLESS }  # Normal chase vs Endless chase

# --- Node References ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var detection_area: Area2D = $Area2D       # For enemy detection
@onready var attack_hitbox: Area2D = $AttackHitbox  # For attack detection

# --- Internal Variables ---
var player_target: CharacterBody2D = null
var can_attack: bool = true
var facing_direction_vector: Vector2 = Vector2.RIGHT # Default facing right
var stuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var is_dead: bool = false  # Death flag to prevent multiple deaths

# --- Chase State Variables ---
var last_known_player_position: Vector2 = Vector2.ZERO  # Player's last known position
var time_since_lost_target: float = 0.0                 # Time since losing target
var is_in_endless_chase: bool = false                   # Whether in endless chase mode

func _ready():
	add_to_group("enemies")
	_enter_state(State.IDLE)
	
	# Ensure correct initialization
	is_dead = false
	print(name, " initialization complete, HP: ", health, " State: ", State.keys()[current_state])

	# Connect signals
	if detection_area and detection_radius_behavior:
		detection_area.body_entered.connect(_on_DetectionArea_body_entered)
		detection_area.body_exited.connect(_on_DetectionArea_body_exited)
	
	if attack_hitbox:
		attack_hitbox.monitoring = false

	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Deferred navigation agent setup
	call_deferred("_setup_navigation")
	last_position = global_position

func _setup_navigation():
	"""Deferred navigation agent setup - Maze optimized version"""
	if navigation_agent:
		navigation_agent.path_desired_distance = 5.0  # More precise path tracking
		navigation_agent.target_desired_distance = 20.0  # Target distance
		navigation_agent.radius = 12.0  # Radius suitable for maze
		navigation_agent.avoidance_enabled = true
		navigation_agent.max_speed = speed
		# Wait for navigation mesh to load
		await get_tree().process_frame
		print(name, " navigation agent configuration complete")

func _physics_process(delta):
	# Force death check: if HP is negative or already dead, enter death state immediately
	if health <= 0 and not is_dead:
		print(name, " detected HP <= 0 (", health, ") during physics process, forcing death state")
		is_dead = true
		health = 0
		_enter_state(State.DEAD)
		return
	
	# If already dead, stop all processing
	if is_dead and current_state != State.DEAD:
		print(name, " detected dead but wrong state, forcing death state")
		_enter_state(State.DEAD)
		return
	
	# Check for stuck condition
	if current_state == State.CHASE:
		_check_if_stuck(delta)
	
	# Global death check: if player is dead, stop all behavior immediately
	if player_target and player_target.has_method("is_dead") and player_target.is_dead():
		if current_state != State.IDLE:
			print(name, " detected player death, stopping behavior immediately")
			player_target = null
			_enter_state(State.IDLE)
			return
	
	# State machine processing
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.DEAD:
			velocity = Vector2.ZERO
	
	# Movement
	move_and_slide()
	
	# Update position record
	last_position = global_position

func _check_if_stuck(delta):
	"""Stuck detection in maze environment"""
	if current_state != State.CHASE or not navigation_agent:
		stuck_timer = 0.0
		return
	
	var movement_distance = global_position.distance_to(last_position)
	var desired_movement = speed * delta * 0.3
	
	if movement_distance < desired_movement:
		stuck_timer += delta
		# Longer detection time needed in maze for path finding
		if stuck_timer > 4.0:
			_handle_stuck_situation()
			stuck_timer = 0.0
	else:
		stuck_timer = max(0, stuck_timer - delta * 0.5)

func _handle_stuck_situation():
	"""Handle stuck situation in maze environment"""
	if player_target == null or not navigation_agent:
		return
	
	print(name, " stuck in maze, recalculating path")
	
	# Force refresh navigation path
	navigation_agent.target_position = player_target.global_position
	
	# If still stuck, try temporary target point
	await get_tree().create_timer(0.5).timeout
	
	if navigation_agent.is_navigation_finished():
		# Try moving to a random offset point in player's direction
		var to_player = global_position.direction_to(player_target.global_position)
		var perpendicular = Vector2(-to_player.y, to_player.x)
		var random_offset = perpendicular * randf_range(-80, 80)
		var intermediate_target = global_position + to_player * 50 + random_offset
		
		navigation_agent.target_position = intermediate_target
		print(name, " setting temporary target point for path finding")

# ============================================================================
# Optimized Navigation System - Remove teleportation-style overlap prevention
# ============================================================================
func _navigate_to_player():
	"""Optimized A* navigation - Rely on collision layers instead of forced separation"""
	if not player_target or not navigation_agent:
		return
	
	var current_distance = global_position.distance_to(player_target.global_position)
	
	# Set reasonable stop distance, let navigation system handle naturally
	var stop_distance = 25.0
	
	if current_distance > stop_distance:
		# Set navigation target
		navigation_agent.target_position = player_target.global_position
		
		# Use A* algorithm to get next path point
		if not navigation_agent.is_navigation_finished():
			var next_path_position = navigation_agent.get_next_path_position()
			var direction = global_position.direction_to(next_path_position)
			
			# Smooth velocity control
			var target_velocity = direction * speed
			
			# Slow down when close
			if current_distance < stop_distance * 2.0:
				var speed_factor = (current_distance - stop_distance) / stop_distance
				speed_factor = clamp(speed_factor, 0.3, 1.0)
				target_velocity *= speed_factor
			
			velocity = target_velocity
		else:
			velocity = Vector2.ZERO
	else:
		# Natural stop when close enough
		velocity = Vector2.ZERO

func _enter_state(new_state: State):
	# If already dead, force death state
	if is_dead and new_state != State.DEAD:
		print(name, " is dead, forcing death state")
		current_state = State.DEAD
		_play_death_and_cleanup_setup()
		return
	
	# Prevent repeated death state entry
	if new_state == State.DEAD and current_state == State.DEAD:
		print(name, " already in death state, skipping duplicate transition")
		return
	
	if current_state == new_state and new_state != State.ATTACK:
		return
	
	var old_state = current_state
	current_state = new_state
	print(name, " state transition: ", State.keys()[old_state], " -> ", State.keys()[new_state])

	match current_state:
		State.IDLE:
			_update_visual_animation("idle")
		State.CHASE:
			_update_visual_animation("walk")
		State.ATTACK:
			velocity = Vector2.ZERO
			if not is_attacking:
				is_attacking = true
				_perform_attack()
		State.DEAD:
			_play_death_and_cleanup_setup()

func _idle_state(_delta):
	"""Idle state logic"""
	velocity = Vector2.ZERO
	
	# Find target
	if player_target == null:
		_try_find_player()
	elif is_instance_valid(player_target):
		_enter_state(State.CHASE)
	else:
		player_target = null
	
	_update_visual_animation("idle")

func _try_find_player():
	"""Try to find player target"""
	if detection_radius_behavior:
		return # Using Area2D detection
	
	var potential_player = _find_player_in_distance(detection_distance)
	if potential_player:
		print(name, " found player: ", potential_player.name)
		player_target = potential_player
		_update_facing_direction()
		_enter_state(State.CHASE)

func _chase_state(_delta):
	"""Chase state logic - Improved continuous chase"""
	if not _validate_target():
		# If target lost, decide behavior based on chase type
		if chase_type == ChaseType.ENDLESS and is_in_endless_chase:
			time_since_lost_target += _delta
			if time_since_lost_target < lose_target_time:
				# Continue chasing to last known position
				_navigate_to_last_known_position()
				print(name, " endless chase mode: pursuing last known position")
				return
			else:
				print(name, " endless chase timeout, returning to idle")
				is_in_endless_chase = false
				time_since_lost_target = 0.0
		
		_enter_state(State.IDLE)
		return
	
	# Update player's last known position
	last_known_player_position = player_target.global_position
	time_since_lost_target = 0.0
	
	var distance_to_player = global_position.distance_to(player_target.global_position)
	_update_facing_direction()
	
	# Simplified attack distance check - using more stable detection
	var should_attack = distance_to_player <= attack_distance * 1.2 and can_attack
	
	if should_attack:
		print(name, " entering attack range: distance=", distance_to_player, " attack threshold=", attack_distance)
		_enter_state(State.ATTACK)
		return
	
	# If in attack cooldown and distance is appropriate, wait without moving
	if distance_to_player <= attack_distance * 1.5 and not can_attack:
		velocity = Vector2.ZERO
		_update_visual_animation("idle")
		return
	
	# Normal chase
	_navigate_to_player()
	_update_visual_animation("walk")

func _navigate_to_last_known_position():
	"""Chase to player's last known position"""
	if not navigation_agent:
		return
	
	var distance_to_last_known = global_position.distance_to(last_known_player_position)
	
	# If reached last known position, stop chasing
	if distance_to_last_known <= 30.0:
		print(name, " reached last known position, stopping chase")
		is_in_endless_chase = false
		time_since_lost_target = 0.0
		_enter_state(State.IDLE)
		return
	
	# Navigate to last known position
	navigation_agent.target_position = last_known_player_position
	
	if not navigation_agent.is_navigation_finished():
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	_update_visual_animation("walk")

func _attack_state(_delta):
	"""Attack state logic"""
	if not _validate_target():
		return
	
	var distance_to_player = global_position.distance_to(player_target.global_position)
	
	# Only switch to chase when player is really far
	if distance_to_player > attack_distance * 4.0:
		print(name, " player too far, switching to chase")
		is_attacking = false
		can_attack = true
		_enter_state(State.CHASE)
		return
	
	# Stay still in attack state
	velocity = Vector2.ZERO
	_update_facing_direction()

func _validate_target() -> bool:
	"""Validate target validity"""
	if player_target == null or not is_instance_valid(player_target):
		_enter_state(State.IDLE)
		return false
	
	# Check if player is dead
	if player_target.has_method("is_dead") and player_target.is_dead():
		print(name, " player is dead, stopping chase and attack")
		player_target = null
		_enter_state(State.IDLE)
		return false
	
	return true

func _update_facing_direction():
	"""Update facing direction"""
	if player_target:
		facing_direction_vector = global_position.direction_to(player_target.global_position).normalized()

# ============================================================================
# Attack System
# ============================================================================
func _perform_attack():
	"""Execute attack"""
	if not _validate_target() or is_attacking == false:
		return

	print(name, " starting attack on ", player_target.name)
	_update_visual_animation("attack")
	can_attack = false
	
	# Configure attack hitbox
	_setup_attack_hitbox()
	
	# Wait for sword swing animation to complete before executing attack check
	# attack_right animation has 10 frames, speed 5.0fps, total duration 2 seconds
	# Execute attack check at frames 6-7 (about 1.2-1.4 seconds) when swing is complete
	await get_tree().create_timer(1.2).timeout
	
	if not is_attacking:
		return
	
	# Execute attack check - only hit when sword connects with player
	_execute_attack_check()
	
	# Attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	
	_reset_attack_state()

func _setup_attack_hitbox():
	"""Setup attack hitbox - Support four-direction attacks"""
	if not attack_hitbox:
		return
	
	# Determine attack direction based on facing
	var attack_direction = Vector2.ZERO
	
	# Determine main direction (prioritize horizontal)
	if abs(facing_direction_vector.x) > abs(facing_direction_vector.y):
		# Horizontal priority
		attack_direction = Vector2.RIGHT if facing_direction_vector.x > 0 else Vector2.LEFT
	else:
		# Vertical priority
		attack_direction = Vector2.DOWN if facing_direction_vector.y > 0 else Vector2.UP
	
	# Set attack hitbox position
	attack_hitbox.position = attack_direction * attack_hitbox_reach
	attack_hitbox.monitoring = true
	
	print(name, " attack direction: ", attack_direction, " facing: ", facing_direction_vector)

func _execute_attack_check():
	"""Execute attack detection - Improved 2D attack check"""
	if not attack_hitbox:
		print("Warning: AttackHitbox node not found!")
		return
	
	# Validate target again before attack (ensure player hasn't died during this time)
	if not _validate_target():
		attack_hitbox.monitoring = false
		return
	
	var hit_targets = attack_hitbox.get_overlapping_bodies()
	var hit_player = false
	
	for body in hit_targets:
		if body == player_target and body.has_method("take_damage"):
			# Final check if player is still alive
			if body.has_method("is_dead") and body.is_dead():
				print(name, " player is dead, canceling attack")
				break
				
			var attack_distance_check = global_position.distance_to(body.global_position)
			# Relax attack distance check, especially for diagonal cases
			if attack_distance_check <= attack_distance * 1.8:
				body.take_damage(attack_power)
				hit_player = true
				print(name, " attack hit, dealing ", attack_power, " damage, distance: ", attack_distance_check)
				break
	
	# If hitbox didn't detect but player is in attack range, count as hit (backup check)
	if not hit_player and player_target:
		# Check player death again
		if player_target.has_method("is_dead") and player_target.is_dead():
			print(name, " player is dead, canceling backup attack check")
		else:
			var distance_to_player = global_position.distance_to(player_target.global_position)
			if distance_to_player <= attack_distance * 1.5:
				if player_target.has_method("take_damage"):
					player_target.take_damage(attack_power)
					hit_player = true
					print(name, " backup attack check hit, distance: ", distance_to_player)
	
	if not hit_player:
		print(name, " attack missed")
	
	attack_hitbox.monitoring = false

func _reset_attack_state():
	"""Reset attack state"""
	can_attack = true
	is_attacking = false
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	# If already dead, enter death state directly
	if is_dead:
		print(name, " detected dead during attack reset, entering death state")
		_enter_state(State.DEAD)
		return
	
	# Simple post-attack processing
	if _validate_target():
		# Brief wait before continuing chase
		await get_tree().create_timer(0.5).timeout
		if _validate_target() and not is_dead:  # Check target validity and death state again
			_enter_state(State.CHASE)

# ============================================================================
# Animation System
# ============================================================================
func _update_visual_animation(action_prefix: String):
	"""Update visual animation"""
	var anim_name = action_prefix + "_right"
	
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		print("Error: Animation '", anim_name, "' not found!")
		return
	
	var new_flip_h = facing_direction_vector.x < -0.01
	
	# Prevent attack animation from being interrupted
	if animated_sprite.animation.begins_with("attack") and animated_sprite.is_playing():
		if not anim_name.begins_with("attack"):
			return
	
	# Check if update needed
	var needs_update = (
		animated_sprite.animation != anim_name or
		animated_sprite.flip_h != new_flip_h or
		not animated_sprite.is_playing()
	)
	
	if needs_update:
		animated_sprite.flip_h = new_flip_h
		animated_sprite.play(anim_name)

# ============================================================================
# Damage System
# ============================================================================
func receive_player_attack(player_attack_power: int) -> int:
	"""Receive player attack - Enhanced debugging"""
	print(name, " received player attack request, current state: ", State.keys()[current_state], " HP: ", health, " is_dead: ", is_dead)
	
	if current_state == State.DEAD or is_dead:
		print(name, " is dead, ignoring attack")
		return 0
	
	var actual_damage = player_attack_power
	health -= actual_damage
	print(name, " took ", actual_damage, " damage from player, remaining HP: ", health)
	
	_on_hit_by_player()
	
	# Fix: Ensure immediate death when HP <= 0
	if health <= 0 and not is_dead:
		print(name, " HP <= 0 (", health, "), preparing to enter death state")
		is_dead = true
		health = 0  # Ensure HP is not negative
		_enter_state(State.DEAD)
	elif health > 0:
		print(name, " still alive, continuing fight")
	
	return actual_damage

func _on_hit_by_player():
	"""Hit reaction"""
	print(name, " hit by player")
	
	# Flash effect
	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if animated_sprite:
		animated_sprite.modulate = original_modulate

func take_damage(amount: int, _source_attack_power: int = 0):
	"""Generic damage interface"""
	if current_state == State.DEAD or is_dead:
		print(name, " is dead, ignoring damage")
		return
	
	health -= amount
	print(name, " took ", amount, " damage, remaining HP: ", health)
	
	# Fix: Enter death state immediately when HP <= 0, not just = 0
	if health <= 0 and not is_dead:
		print(name, " HP <= 0 (", health, "), entering death state")
		is_dead = true
		health = 0  # Ensure HP is not negative
		_enter_state(State.DEAD)

# ============================================================================
# Death and Cleanup
# ============================================================================
func _play_death_and_cleanup_setup():
	"""Play death animation and setup cleanup"""
	print(name, " starting death process, current HP: ", health)
	
	velocity = Vector2.ZERO
	is_attacking = false
	can_attack = false
	
	# Disable physics processing immediately
	set_physics_process(false)
	
	# Clear target reference
	player_target = null
	
	# Disable collision detection
	var collision_shape = $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = true
	
	if detection_area:
		detection_area.monitoring = false
		detection_area.monitorable = false
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
	
	# Play death animation
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		animated_sprite.flip_h = false
		print(name, " playing death animation")
	else:
		print("Error: 'death' animation not found, proceeding to cleanup")
		_handle_defeat_cleanup()

func _handle_defeat_cleanup():
	"""Handle post-death cleanup - Prevent duplicate execution"""
	if not is_inside_tree():
		print(name, " no longer in scene tree, skipping cleanup")
		return
	
	print(name, " executing death cleanup")
	
	# Give experience to player
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("gain_experience"):
		player_node.gain_experience(experience_drop)
		print("Player gained experience: ", experience_drop)
	
	# Ensure complete removal from scene
	print(name, " about to be destroyed")
	queue_free()

# ============================================================================
# Signal Callbacks
# ============================================================================
func _on_DetectionArea_body_entered(body):
	"""Detection area entry"""
	if body.is_in_group("player"):
		print(name, " found player: ", body.name)
		player_target = body
		last_known_player_position = body.global_position
		
		# If endless chase type enemy, activate endless chase mode
		if chase_type == ChaseType.ENDLESS:
			is_in_endless_chase = true
			print(name, " activating endless chase mode")
		
		if current_state == State.IDLE:
			_update_facing_direction()
			_enter_state(State.CHASE)

func _on_DetectionArea_body_exited(body):
	"""Detection area exit - Improved chase logic"""
	if body == player_target:
		print(name, " player left detection range")
		
		# For endless chase type, don't lose target immediately
		if chase_type == ChaseType.ENDLESS and is_in_endless_chase:
			print(name, " endless chase mode: continuing pursuit")
			# Don't clear player_target, let chase state handle it
			return
		
		# Normal enemies stop chase immediately
		player_target = null
		if current_state in [State.CHASE, State.ATTACK]:
			_enter_state(State.IDLE)

func _on_animation_finished():
	"""Animation completion callback - Fix resurrection issue"""
	print(name, " animation complete: ", animated_sprite.animation, " current state: ", State.keys()[current_state])
	
	if current_state == State.DEAD and animated_sprite.animation == "death":
		print(name, " death animation complete, immediate cleanup")
		_handle_defeat_cleanup()
	elif animated_sprite.animation == "attack_right":
		print(name, " attack animation complete")
		# Don't reset state after attack animation, let attack system manage it

# ============================================================================
# Helper Functions
# ============================================================================
func _find_player_in_distance(distance: float) -> CharacterBody2D:
	"""Find player within specified distance"""
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player = players[0]
		if global_position.distance_to(player.global_position) <= distance:
			return player
	return null
