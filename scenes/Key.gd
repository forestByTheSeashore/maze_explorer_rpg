# Key.gd
extends Area2D

# Export Variables
@export var key_type: String = "master_key"  # Key type, can be extended to multiple key types
@export var pickup_sound: AudioStream  # Pickup sound effect

# Node References
@onready var animated_sprite: AnimatedSprite2D = $KeySprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

# State Variables
var is_collected: bool = false

func _ready():
    # Connect signals
    body_entered.connect(_on_body_entered)
    
    # Set up animation
    if animated_sprite and animated_sprite.sprite_frames:
        if animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")
    
    # Optional: Add floating effect
    # _start_floating_animation()

func _start_floating_animation():
    # Create simple up and down floating effect
    var tween = create_tween()
    tween.set_loops()
    tween.tween_property(self, "position:y", position.y - 5, 1.0)
    tween.tween_property(self, "position:y", position.y + 5, 1.0)

func _on_body_entered(body):
    if is_collected:
        return
    
    if body.is_in_group("player"):
        collect_key(body)

func collect_key(player_node):
    if is_collected:
        return
    
    is_collected = true
    
    # Add key to player
    if player_node.has_method("add_key"):
        player_node.add_key(key_type)
        print("Player obtained", key_type)
        
        # Show key pickup notification
        var notification_manager = get_node_or_null("/root/NotificationManager")
        if notification_manager:
            notification_manager.notify_key_obtained(key_type)
    
    # Update statistics
    var victory_manager = get_node_or_null("/root/VictoryManager")
    if victory_manager:
        victory_manager.increment_items_collected()
    
    # Play pickup sound
    var audio_manager = get_node_or_null("/root/AudioManager")
    if audio_manager:
        audio_manager.play_pickup_sound()
    elif audio_player and pickup_sound:
        audio_player.stream = pickup_sound
        audio_player.play()
    
    # Play pickup effects
    var effects_manager = get_node_or_null("/root/EffectsManager")
    if effects_manager:
        effects_manager.play_pickup_effect(global_position)
    
    # Play pickup animation or effect
    _play_pickup_effect()
    
    # Delay deletion to wait for sound effect completion
    await get_tree().create_timer(0.5).timeout
    queue_free()

func _play_pickup_effect():
    # Visual effect on pickup
    var tween = create_tween()
    tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)