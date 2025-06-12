extends Node

## Effects Manager
## Responsible for particle effects and visual effects in the game

# Effect prefab pool
var effect_pool: Dictionary = {}
var active_effects: Array[Node] = []

# Effect configurations
var effect_configs: Dictionary = {
	"hit_effect": {
		"lifetime": 0.5,
		"color": Color.RED,
		"particle_count": 20,
		"spread": 45.0
	},
	"pickup_effect": {
		"lifetime": 1.0,
		"color": Color.YELLOW,
		"particle_count": 15,
		"spread": 360.0
	},
	"level_complete_effect": {
		"lifetime": 2.0,
		"color": Color.GOLD,
		"particle_count": 50,
		"spread": 360.0
	},
	"door_open_effect": {
		"lifetime": 1.5,
		"color": Color.CYAN,
		"particle_count": 30,
		"spread": 90.0
	},
	"enemy_death_effect": {
		"lifetime": 1.0,
		"color": Color.DARK_RED,
		"particle_count": 25,
		"spread": 180.0
	}
}

func _ready():
	add_to_group("effects_manager")
	_initialize_effect_pools()
	print("EffectsManager: Initializing effects system")

func _initialize_effect_pools():
	print("EffectsManager: Initializing effect pools")
	
	# Create object pools for each effect type
	for effect_name in effect_configs.keys():
		effect_pool[effect_name] = []
		# Pre-create some effect objects
		for i in range(5):
			var effect = _create_particle_effect(effect_name)
			effect.visible = false
			effect_pool[effect_name].append(effect)

func _create_particle_effect(effect_name: String) -> Node2D:
	"""Create particle effect node"""
	var effect_node = Node2D.new()
	effect_node.name = effect_name + "_effect"
	
	# Create CPUParticles2D
	var particles = CPUParticles2D.new()
	particles.name = "Particles"
	effect_node.add_child(particles)
	
	var config = effect_configs.get(effect_name, {})
	
	# Configure particle system
	particles.amount = config.get("particle_count", 20)
	particles.lifetime = config.get("lifetime", 1.0)
	
	# Shape and direction
	particles.direction = Vector2(0, -1)
	particles.spread = config.get("spread", 45.0)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	
	# Appearance
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = config.get("color", Color.WHITE)
	
	# Physics
	particles.gravity = Vector2(0, 98)
	particles.linear_accel_min = -20.0
	particles.linear_accel_max = 20.0
	
	# Alpha changes
	particles.color_ramp = _create_alpha_ramp()
	
	# Add to scene but keep hidden
	get_tree().current_scene.add_child(effect_node)
	
	return effect_node

func _create_alpha_ramp() -> Gradient:
	"""Create alpha gradient"""
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))  # Start fully opaque
	gradient.add_point(0.7, Color(1, 1, 1, 0.8))  # Mid slightly transparent
	gradient.add_point(1.0, Color(1, 1, 1, 0))   # End fully transparent
	return gradient

## Play effect
## @param effect_name: Effect name
## @param position: World coordinate position
## @param direction: Effect direction (optional)
func play_effect(effect_name: String, position: Vector2, direction: Vector2 = Vector2.UP):
	# Safety check: ensure current scene is valid
	if not get_tree() or not get_tree().current_scene:
		print("EffectsManager: Scene invalid, skipping effect playback - ", effect_name)
		return
		
	var effect = _get_effect_from_pool(effect_name)
	if not effect:
		print("EffectsManager: Cannot get effect - ", effect_name)
		return
	
	# Set position and direction
	effect.global_position = position
	effect.visible = true
	
	var particles = effect.get_node("Particles") as CPUParticles2D
	if particles:
		particles.direction = direction
		particles.restart()
		particles.emitting = true
	
	# Clean invalid references in active effects list
	_clean_active_effects()
	
	# Add to active effects list
	active_effects.append(effect)
	
	# Set auto cleanup
	var config = effect_configs.get(effect_name, {})
	var lifetime = config.get("lifetime", 1.0)
	
	var timer = get_tree().create_timer(lifetime + 0.5)  # Extra 0.5 seconds to ensure particles fully disappear
	timer.timeout.connect(_cleanup_effect_wrapper.bind(effect_name, effect))
	
	print("EffectsManager: Playing effect - ", effect_name, " position: ", position)

# Wrapper function to handle cleanup safely
func _cleanup_effect_wrapper(effect_name: String, effect: Node2D):
	_cleanup_effect_safe(effect_name, effect)

# Safe effect cleanup handler using lambda
func _cleanup_effect_safe(effect_name: String, effect: Node2D):
	if is_instance_valid(effect):
		_return_effect_to_pool(effect_name, effect)

# Wrapper functions for all bind() callbacks to prevent type conversion errors
func _hit_particles_cleanup_wrapper(particles: CPUParticles2D):
	_on_hit_particles_cleanup(particles)

func _pickup_particles_cleanup_wrapper(particles: CPUParticles2D):
	_on_pickup_particles_cleanup(particles)

func _explosion_cleanup_wrapper(explosion: Node2D):
	_on_explosion_cleanup(explosion)

func _heal_effect_cleanup_wrapper(heal_effect: Node2D):
	_on_heal_effect_cleanup(heal_effect)

func _trail_effect_cleanup_wrapper(trail: Node2D):
	_on_trail_effect_cleanup(trail)

func _screen_flash_cleanup_wrapper(canvas: CanvasLayer):
	_on_screen_flash_cleanup(canvas)

func _screen_flash_tween_finished_wrapper(canvas: CanvasLayer):
	_on_screen_flash_tween_finished(canvas)

func _damage_number_tween_finished_wrapper(label: Label):
	_on_damage_number_tween_finished(label)

# Hit particles cleanup handler
func _on_hit_particles_cleanup(particles: CPUParticles2D):
	if is_instance_valid(particles):
		particles.queue_free()

# Pickup particles cleanup handler  
func _on_pickup_particles_cleanup(particles: CPUParticles2D):
	if is_instance_valid(particles):
		particles.queue_free()

# Explosion cleanup handler
func _on_explosion_cleanup(explosion: Node2D):
	if is_instance_valid(explosion):
		explosion.queue_free()

# Heal effect cleanup handler
func _on_heal_effect_cleanup(heal_effect: Node2D):
	if is_instance_valid(heal_effect):
		heal_effect.queue_free()

# Trail effect cleanup handler
func _on_trail_effect_cleanup(trail: Node2D):
	if is_instance_valid(trail):
		trail.queue_free()

# Screen flash cleanup handler
func _on_screen_flash_cleanup(canvas: CanvasLayer):
	if is_instance_valid(canvas):
		print("EffectsManager: Timer cleanup of screen flash")
		canvas.queue_free()

# Screen flash tween finished handler
func _on_screen_flash_tween_finished(canvas: CanvasLayer):
	if is_instance_valid(canvas):
		print("EffectsManager: Tween cleanup of screen flash")
		canvas.queue_free()

# Damage number tween finished handler
func _on_damage_number_tween_finished(label: Label):
	if is_instance_valid(label):
		label.queue_free()

func _get_effect_from_pool(effect_name: String) -> Node2D:
	"""Get effect from object pool"""
	if effect_name not in effect_pool:
		print("EffectsManager: Unknown effect type - ", effect_name)
		return null
	
	var pool = effect_pool[effect_name]
	
	# Clean invalid object references in pool
	_clean_pool(pool)
	
	# Find idle effect object
	for effect in pool:
		if is_instance_valid(effect) and not effect.visible:
			return effect
	
	# If no idle objects, create new one
	var new_effect = _create_particle_effect(effect_name)
	if new_effect:
		pool.append(new_effect)
	return new_effect

func _return_effect_to_pool(effect_name: String, effect: Node2D):
	"""Return effect to object pool"""
	if not is_instance_valid(effect):
		return
	
	effect.visible = false
	var particles = effect.get_node("Particles") as CPUParticles2D
	if particles:
		particles.emitting = false
	
	# Remove from active list
	active_effects.erase(effect)
	
	print("EffectsManager: Effect returned to pool - ", effect_name)

func _clean_pool(pool: Array):
	"""Clean invalid references in object pool"""
	var valid_effects = []
	for effect in pool:
		if is_instance_valid(effect):
			valid_effects.append(effect)
	pool.clear()
	pool.append_array(valid_effects)

func _clean_active_effects():
	"""Clean invalid references in active effects list"""
	var valid_effects = []
	for effect in active_effects:
		if is_instance_valid(effect):
			valid_effects.append(effect)
	active_effects.clear()
	active_effects.append_array(valid_effects)

## Convenience methods - Predefined effects
func play_hit_effect(position: Vector2):
	var particles = _create_hit_particles()
	particles.global_position = position
	get_tree().current_scene.add_child(particles)
	
	# Play particles
	particles.restart()
	particles.emitting = true
	
	# Auto cleanup
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(_hit_particles_cleanup_wrapper.bind(particles))

func _create_hit_particles() -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.name = "HitEffect"
	
	# Configure particles
	particles.amount = 20
	particles.lifetime = 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.color = Color.RED
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.gravity = Vector2(0, 98)
	
	return particles

func play_pickup_effect(position: Vector2):
	var particles = _create_pickup_particles()
	particles.global_position = position
	get_tree().current_scene.add_child(particles)
	
	particles.restart()
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(_pickup_particles_cleanup_wrapper.bind(particles))

func _create_pickup_particles() -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.name = "PickupEffect"
	
	particles.amount = 15
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 360.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.color = Color.YELLOW
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.2
	particles.gravity = Vector2(0, -20)  # Float upward
	
	return particles

func play_level_complete_effect(position: Vector2):
	"""Play level complete effect"""
	print("EffectsManager: Requesting to play level complete effect at position: ", position)
	
	# Check if effect configuration exists
	if "level_complete_effect" not in effect_configs:
		print("EffectsManager: Level complete effect configuration not found, using fallback effect")
		create_explosion_effect(position, 80.0, Color.GOLD)
		return
	
	# Safely play the effect
	play_effect("level_complete_effect", position)

func play_door_open_effect(position: Vector2):
	"""Play door open effect"""
	play_effect("door_open_effect", position)

func play_enemy_death_effect(position: Vector2):
	"""Play enemy death effect"""
	play_effect("enemy_death_effect", position)

## Advanced Effects
func create_explosion_effect(position: Vector2, radius: float = 100.0, color: Color = Color.ORANGE):
	"""Create explosion effect"""
	var explosion = Node2D.new()
	explosion.name = "ExplosionEffect"
	explosion.global_position = position
	
	# Create multiple particle layers
	for i in range(3):
		var particles = CPUParticles2D.new()
		particles.name = "ExplosionLayer" + str(i)
		explosion.add_child(particles)
		
		# Configure explosion particles
		particles.amount = 30 + i * 10
		particles.lifetime = 0.5 + i * 0.2
		particles.direction = Vector2(0, -1)
		particles.spread = 360.0
		particles.initial_velocity_min = radius * 0.5
		particles.initial_velocity_max = radius * (1.0 + i * 0.3)
		
		# Color variation
		var explosion_color = color
		explosion_color.a = 1.0 - i * 0.3
		particles.color = explosion_color
		
		particles.scale_amount_min = 0.3 + i * 0.2
		particles.scale_amount_max = 1.0 + i * 0.5
		particles.gravity = Vector2(0, 50)
		particles.color_ramp = _create_alpha_ramp()
		
		particles.restart()
		particles.emitting = true
	
	# Add to scene
	get_tree().current_scene.add_child(explosion)
	
	# Auto cleanup
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(_explosion_cleanup_wrapper.bind(explosion))
	
	print("EffectsManager: Created explosion effect at position: ", position, " radius: ", radius)

func create_heal_effect(position: Vector2):
	"""Create heal effect"""
	var heal_effect = Node2D.new()
	heal_effect.name = "HealEffect"
	heal_effect.global_position = position
	
	var particles = CPUParticles2D.new()
	heal_effect.add_child(particles)
	
	# Configure healing particles (floating green particles)
	particles.amount = 20
	particles.lifetime = 1.5
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.color = Color.GREEN
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.2
	particles.gravity = Vector2(0, -20)  # Negative gravity for upward float
	particles.color_ramp = _create_alpha_ramp()
	
	particles.restart()
	particles.emitting = true
	
	get_tree().current_scene.add_child(heal_effect)
	
	# Auto cleanup
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(_heal_effect_cleanup_wrapper.bind(heal_effect))

func create_trail_effect(start_pos: Vector2, end_pos: Vector2, color: Color = Color.WHITE):
	"""Create trail effect"""
	var trail = Node2D.new()
	trail.name = "TrailEffect"
	trail.global_position = start_pos
	
	var particles = CPUParticles2D.new()
	trail.add_child(particles)
	
	# Calculate direction
	var direction = (end_pos - start_pos).normalized()
	
	# Configure trail particles
	particles.amount = 15
	particles.lifetime = 0.3
	particles.direction = direction
	particles.spread = 15.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 150.0
	particles.color = color
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.color_ramp = _create_alpha_ramp()
	
	particles.restart()
	particles.emitting = true
	
	get_tree().current_scene.add_child(trail)
	
	# Auto cleanup
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(_trail_effect_cleanup_wrapper.bind(trail))

## Screen Effects
func create_screen_flash(color: Color = Color.WHITE, duration: float = 0.2):
	print("EffectsManager: Creating screen flash effect")
	
	# Ensure current scene exists
	if not get_tree() or not get_tree().current_scene:
		print("EffectsManager: No current scene, skipping screen flash")
		return
	
	var overlay = ColorRect.new()
	overlay.name = "ScreenFlashOverlay"
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var canvas = CanvasLayer.new()
	canvas.name = "ScreenFlashCanvas"
	canvas.layer = 1000
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure it works even when paused
	canvas.add_child(overlay)
	get_tree().current_scene.add_child(canvas)
	
	# Use timer as backup cleanup mechanism
	var cleanup_timer = get_tree().create_timer(duration + 1.0)  # Extra 1 second to ensure cleanup
	cleanup_timer.timeout.connect(_screen_flash_cleanup_wrapper.bind(canvas))
	
	# Use tween for fade out animation
	var tween = create_tween()
	if tween:
		tween.tween_property(overlay, "modulate:a", 0.0, duration)
		tween.tween_callback(_screen_flash_tween_finished_wrapper.bind(canvas))
	else:
		# If tween creation fails, use timer for cleanup
		print("EffectsManager: Tween creation failed, using timer for cleanup")
	
	print("EffectsManager: Screen flash effect created with duration: ", duration)

func create_damage_number(position: Vector2, damage: int, color: Color = Color.RED):
	var label = Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.global_position = position
	label.z_index = 100
	
	get_tree().current_scene.add_child(label)
	
	# animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_damage_number_tween_finished_wrapper.bind(label))

## Clear all effects
func clear_all_effects():
	"""Clear all active effects"""
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()
	
	# Clear screen flash effects
	clear_screen_flash_effects()
	
	print("EffectsManager: All effects cleared")

func clear_screen_flash_effects():
	"""Clear all screen flash effects"""
	if not get_tree() or not get_tree().current_scene:
		return
	
	var current_scene = get_tree().current_scene
	var canvas_layers = current_scene.find_children("ScreenFlashCanvas", "", true, false)
	
	for canvas in canvas_layers:
		if is_instance_valid(canvas):
			print("EffectsManager: Removing residual screen flash canvas: ", canvas.name)
			canvas.queue_free()
	
	# Also check for any remaining ColorRect
	var flash_overlays = current_scene.find_children("ScreenFlashOverlay", "", true, false)
	for overlay in flash_overlays:
		if is_instance_valid(overlay):
			print("EffectsManager: Removing residual screen flash overlay: ", overlay.name)
			overlay.queue_free()

## Get effect statistics
func get_active_effects_count() -> int:
	return active_effects.size()

func get_pool_size(effect_name: String) -> int:
	return effect_pool.get(effect_name, []).size() 
