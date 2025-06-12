# goblin_static.gd - Static Guard Enemy (StaticBody2D version)
extends StaticBody2D

# --- Export Variables ---
@export var max_hp: int = 60
@export var attack_power: int = 15
@export var detection_range: float = 80.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 2.0
@export var experience_drop: int = 20

# --- Node References ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D
@onready var attack_hitbox: Area2D = $AttackHitbox

# --- Internal Variables ---
var current_hp: int
var player_target: CharacterBody2D = null
var can_attack: bool = true
var is_attacking: bool = false
var facing_direction: Vector2 = Vector2.RIGHT
var is_player_in_detection: bool = false

func _ready():
	add_to_group("enemies")
	current_hp = max_hp
	
	# Connect signals
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.play("idle_right")
	
	print(name, " StaticGoblin initialized, HP:", current_hp, " Attack Power:", attack_power)

# StaticBody2D uses _process instead of _physics_process
func _process(_delta: float):
	# Check player state
	if player_target and player_target.has_method("is_dead") and player_target.is_dead():
		_reset_target()
		return
	
	# Active attack logic
	if player_target and is_player_in_detection and can_attack and not is_attacking:
		var distance_to_player = global_position.distance_to(player_target.global_position)
		
		if distance_to_player <= attack_range:
			_perform_attack()
	
	# Update facing direction
	if player_target:
		_update_facing_direction()

func _update_facing_direction():
	"""Update direction facing the player"""
	if not player_target or not animated_sprite:
		return
	
	var direction_to_player = global_position.direction_to(player_target.global_position)
	facing_direction = direction_to_player
	
	# Only update animation flip
	if not is_attacking:
		animated_sprite.flip_h = facing_direction.x < 0
		if not animated_sprite.is_playing() or animated_sprite.animation != "idle_right":
			animated_sprite.play("idle_right")

func _perform_attack():
	"""Execute attack"""
	if is_attacking or not can_attack or not player_target:
		return
	
	is_attacking = true
	can_attack = false
	
	print(name, " starting attack on player")
	
	# Play attack animation
	if animated_sprite and animated_sprite.sprite_frames.has_animation("attack_right"):
		animated_sprite.play("attack_right")
		animated_sprite.flip_h = facing_direction.x < 0
		
		# Connect animation frame change signal to monitor jump attack key frame
		if not animated_sprite.frame_changed.is_connected(_on_attack_frame_changed):
			animated_sprite.frame_changed.connect(_on_attack_frame_changed)
	
	# Set up attack hitbox
	_setup_attack_hitbox()
	
	# Create attack timing (backup plan)
	_handle_attack_timing()

func _handle_attack_timing():
	"""Handle attack timing"""
	# Backup attack timing: If frame monitoring fails, execute attack at appropriate time
	# Wait for goblin to jump down (frame 5 at about 1.0 seconds)
	await get_tree().create_timer(1.0).timeout
	
	if not is_attacking:
		return
	
	# Check if attack detection has already been executed through frame monitoring
	# If not executed yet, execute as backup plan
	if attack_hitbox and attack_hitbox.monitoring:
		print(name, " backup attack timing: executing attack detection when goblin jumps down")
		_execute_attack()
	
	# Attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	
	# Reset attack state
	_reset_attack_state()

func _setup_attack_hitbox():
	"""Set up attack hitbox"""
	if not attack_hitbox:
		return
	
	var attack_offset = facing_direction.normalized() * 20.0
	attack_hitbox.position = attack_offset
	attack_hitbox.monitoring = true

func _execute_attack():
	"""Execute attack detection"""
	if not attack_hitbox or not player_target:
		return
	
	if player_target.has_method("is_dead") and player_target.is_dead():
		attack_hitbox.monitoring = false
		return
	
	var hit_targets = attack_hitbox.get_overlapping_bodies()
	var hit_player = false
	
	for body in hit_targets:
		if body == player_target and body.has_method("take_damage"):
			var distance = global_position.distance_to(body.global_position)
			if distance <= attack_range * 1.2:
				body.take_damage(attack_power)
				hit_player = true
				print(name, " hit player, dealing ", attack_power, " damage")
				break
	
	# Backup attack detection
	if not hit_player and player_target:
		var distance = global_position.distance_to(player_target.global_position)
		if distance <= attack_range and player_target.has_method("take_damage"):
			if not (player_target.has_method("is_dead") and player_target.is_dead()):
				player_target.take_damage(attack_power)
				hit_player = true
				print(name, " backup attack detection hit")
	
	if not hit_player:
		print(name, " attack missed")
	
	attack_hitbox.monitoring = false

func _reset_attack_state():
	"""Reset attack state"""
	is_attacking = false
	can_attack = true
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	if animated_sprite:
		animated_sprite.play("idle_right")
		if player_target:
			animated_sprite.flip_h = facing_direction.x < 0

# ============================================================================
# Damage System
# ============================================================================
func receive_player_attack(player_attack_power: int) -> int:
	"""Receive player attack"""
	if current_hp <= 0:
		return 0
	
	var actual_damage = player_attack_power
	current_hp -= actual_damage
	print(name, " received ", actual_damage, " damage from player, remaining HP:", current_hp)
	
	_play_hit_feedback()
	
	if current_hp <= 0:
		_handle_death()
	else:
		# Counter-attack after being hit
		if player_target and can_attack and not is_attacking:
			var distance = global_position.distance_to(player_target.global_position)
			if distance <= attack_range * 1.5:
				print(name, " counter-attacking after being hit")
				call_deferred("_perform_attack")
	
	return actual_damage

func _play_hit_feedback():
	"""Play hit feedback effect"""
	if not animated_sprite:
		return
	
	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color.RED
	
	await get_tree().create_timer(0.15).timeout
	
	if animated_sprite:
		animated_sprite.modulate = original_modulate

func take_damage(amount: int):
	"""Generic damage interface"""
	if current_hp <= 0:
		return
	
	current_hp -= amount
	print(name, " took ", amount, " damage, remaining HP:", current_hp)
	
	_play_hit_feedback()
	
	if current_hp <= 0:
		_handle_death()

func _handle_death():
	"""Handle death"""
	print(name, " StaticGoblin died")
	
	is_attacking = false
	can_attack = false
	
	# Disable collision
	var collision_shape = $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = true
	
	# Disable detection area
	if detection_area:
		detection_area.monitoring = false
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	# Play death animation
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		_cleanup()

func _cleanup():
	"""Clean up and give player experience"""
	# Update victory manager statistics
	var victory_manager = get_node_or_null("/root/VictoryManager")
	if victory_manager:
		victory_manager.increment_enemies_defeated()
		print("VictoryManager: Enemy defeat count updated (", name, ")")
	
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("gain_experience"):
		player_node.gain_experience(experience_drop)
		print("Player gained experience:", experience_drop)
	
	queue_free()

# ============================================================================
# Detection System
# ============================================================================
func _on_detection_area_body_entered(body):
	"""Player enters detection range"""
	if body.is_in_group("player"):
		print(name, " detected player entering range:", body.name)
		player_target = body
		is_player_in_detection = true
		_update_facing_direction()

func _on_detection_area_body_exited(body):
	"""Player leaves detection range"""
	if body == player_target:
		print(name, " player left detection range")
		is_player_in_detection = false
		# Maintain alert state for a while
		await get_tree().create_timer(3.0).timeout
		if not is_player_in_detection:
			_reset_target()

func _reset_target():
	"""Reset target"""
	player_target = null
	is_player_in_detection = false
	
	facing_direction = Vector2.RIGHT
	if animated_sprite and not is_attacking:
		animated_sprite.flip_h = false
		animated_sprite.play("idle_right")

# ============================================================================
# Animation Callbacks
# ============================================================================
func _on_animation_finished():
	"""Animation completion callback"""
	if not animated_sprite:
		return
		
	if animated_sprite.animation == "death":
		_cleanup()
	elif animated_sprite.animation == "attack_right":
		# Attack animation complete, state managed by _handle_attack_timing
		pass

func _on_attack_frame_changed():
	"""Monitor attack animation frame changes, execute attack detection at key frame"""
	if not is_attacking or not animated_sprite:
		return
		
	# Only monitor during attack animation
	if not animated_sprite.animation == "attack_right":
		return
	
	# Execute attack detection at frame 5 (when goblin jumps down)
	# Note: frame counting starts at 0, so frame 5 is frame=4
	if animated_sprite.frame == 4:
		print(name, " detected goblin jump-down key frame, executing attack detection")
		_execute_attack()
		
		# Disconnect signal to avoid repeated execution
		if animated_sprite.frame_changed.is_connected(_on_attack_frame_changed):
			animated_sprite.frame_changed.disconnect(_on_attack_frame_changed)