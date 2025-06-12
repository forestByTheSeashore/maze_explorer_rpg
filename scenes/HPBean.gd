# HPBean.gd - Revised Version
extends Area2D

@export var hp_increase: int = 20  # Amount of HP increase
@export var pickup_sound: AudioStream

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var is_collected: bool = false

func _ready():
    body_entered.connect(_on_body_entered)
    
    if animated_sprite and animated_sprite.sprite_frames:
        if animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")
    
    # _start_floating_animation()

func _start_floating_animation():
    var tween = create_tween()
    tween.set_loops()
    tween.tween_property(self, "position:y", position.y, 1.0)
    tween.tween_property(self, "position:y", position.y, 1.0)

func _on_body_entered(body):
    if is_collected or not body.is_in_group("player"):
        return
    
    is_collected = true
    
    # Update victory manager statistics
    var victory_manager = get_node_or_null("/root/VictoryManager")
    if victory_manager:
        victory_manager.increment_items_collected()
        print("VictoryManager: Item collected count updated (HPBean)")
    
    # Increase player's current HP (not healing, permanent increase)
    if body.has_method("increase_hp_from_bean"):
        body.increase_hp_from_bean(hp_increase)
        print("Player's HP permanently increased by ", hp_increase, " points!")
        
        # Show HP increase notification
        var notification_manager = get_node_or_null("/root/NotificationManager")
        if notification_manager:
            notification_manager.notify_hp_increased(hp_increase)
    
    # Play pickup sound effect
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
    
    # Play pickup effect
    _play_pickup_effect()
    
    await get_tree().create_timer(0.5).timeout
    queue_free()

func _play_pickup_effect():
    var tween = create_tween()
    tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)