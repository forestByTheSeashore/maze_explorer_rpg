# RedSlime.gd
extends CharacterBody2D

@export var attack_power: int = 10     # Red slime's attack power
@export var experience_drop: int = 15  # Experience points dropped when defeated
@export var health: int = 1            # Slime health (simplified version, usually 1)

@onready var damage_zone: Area2D = $DamageZone # Assuming you have a DamageZone Area2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Add animation sprite reference

var can_deal_damage: bool = true # Used to control damage frequency
var is_dead: bool = false       # Prevent repeated death handling

func _ready():
    add_to_group("enemies") # Add slime to "enemies" group for player detection
    
    # Check and connect DamageZone signal
    if damage_zone: 
        damage_zone.body_entered.connect(_on_DamageZone_body_entered)
    
    # Initialize animation
    if animated_sprite:
        # Check if idle animation exists
        if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")
        else:
            push_error("Warning: 'idle' animation not found for " + name)
    else:
        push_error("Error: AnimatedSprite2D node not found for " + name)

func _process(_delta):
    # Ensure slime always plays idle animation (if no other animation is playing and not dead)
    if not is_dead and animated_sprite and not animated_sprite.is_playing():
        if animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")

# New unified interface: Receive player attack
func receive_player_attack(player_attack_power: int) -> int:
    if is_dead:
        return 0
    
    # According to GDD rules: "Attack power higher than enemy means defeat"
    if player_attack_power > self.attack_power:
        print(name, " was defeated by player! Player attack power: ", player_attack_power, " > Slime attack power: ", attack_power)
        defeated()
        return player_attack_power  # Return damage dealt
    else:
        # If player attack power is not higher than enemy attack power, enemy won't be defeated per GDD rules
        print("Player attack power (", player_attack_power, ") not enough to defeat slime (", self.attack_power, ")")
        
        # Play hit effect (if hurt animation exists)
        _on_hit_by_player()
        return 0  # No effective damage dealt

# New: Response when hit (unified with enemy system)
func _on_hit_by_player():
    # Play hit effect
    play_hurt_animation()
    
    # Can add hit sound effects, flash effects, etc.
    print(name, " was hit by player but not defeated")
    
    # Improved flash effect: More noticeable hit feedback
    if animated_sprite:
        var original_modulate = animated_sprite.modulate
        
        # First red flash
        animated_sprite.modulate = Color.RED
        await get_tree().create_timer(0.1).timeout
        
        if animated_sprite:  # Ensure node still exists
            # Restore original color
            animated_sprite.modulate = original_modulate
            await get_tree().create_timer(0.05).timeout
            
        if animated_sprite:
            # Second red flash (double flash effect)
            animated_sprite.modulate = Color.RED
            await get_tree().create_timer(0.1).timeout
            
        if animated_sprite:
            # Final restore
            animated_sprite.modulate = original_modulate

# Keep original method as compatibility interface (marked as deprecated)
func receive_hit_from_player(player_total_attack_power: int):
    push_warning("receive_hit_from_player() is deprecated, use receive_player_attack() instead")
    receive_player_attack(player_total_attack_power)

# Generic damage interface (unified with other enemies)
func take_damage(amount: int, _source_attack_power: int = 0):
    if is_dead:
        return
        
    health -= amount
    print(name, " took ", amount, " damage, remaining HP: ", health)
    
    if health <= 0:
        defeated()
    else:
        _on_hit_by_player()

func defeated():
    if is_dead:
        return
        
    is_dead = true
    print(name + " was defeated!")
    
    # Update victory manager statistics
    var victory_manager = get_node_or_null("/root/VictoryManager")
    if victory_manager:
        victory_manager.increment_enemies_defeated()
        print("VictoryManager: Enemy defeat count updated")
    
    # Stop damage detection
    can_deal_damage = false
    if damage_zone:
        damage_zone.monitoring = false
    
    # Play death animation (if exists)
    await play_death_animation()
    
    # Notify player of experience gain
    var player_node = get_tree().get_first_node_in_group("player")
    if player_node and player_node.has_method("gain_experience"):
        player_node.gain_experience(experience_drop)
        print("Player gained experience: ", experience_drop)

    queue_free() # Enemy disappears

# Play hurt animation
func play_hurt_animation():
    if not animated_sprite:
        return
        
    if animated_sprite.sprite_frames.has_animation("hurt"):
        animated_sprite.play("hurt")
        # Return to idle after hurt animation
        await animated_sprite.animation_finished
        if not is_dead and animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")

# Play death animation
func play_death_animation():
    if not animated_sprite:
        return
        
    if animated_sprite.sprite_frames.has_animation("death"):
        animated_sprite.play("death")
        # Wait for death animation to complete
        await animated_sprite.animation_finished
    else:
        # If no death animation exists, wait a short time as death delay
        await get_tree().create_timer(0.2).timeout

# --- Slime deals damage to player (contact damage) ---
func _on_DamageZone_body_entered(body):
    if is_dead or not can_deal_damage:
        return
        
    if body.is_in_group("player"): # Ensure it's the player
        if body.has_method("take_damage"):
            print(name + " deals damage to player!")
            body.take_damage(attack_power)
            
            # Play attack animation (if exists)
            play_attack_animation()

            # Implement a simple damage cooldown to prevent multiple hits during continuous contact
            can_deal_damage = false
            await get_tree().create_timer(1.0).timeout # No damage for 1 second
            if not is_dead:  # Make sure slime is still alive
                can_deal_damage = true

# Play attack animation
func play_attack_animation():
    if not animated_sprite or is_dead:
        return
        
    if animated_sprite.sprite_frames.has_animation("attack"):
        animated_sprite.play("attack")
        # Return to idle after attack animation
        await animated_sprite.animation_finished
        if not is_dead and animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")