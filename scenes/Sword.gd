# Sword.gd - Use animations to distinguish different sword types
extends Area2D

# Weapon type enumeration
enum SwordType { BASIC, BRONZE, IRON, STEEL }

@export var sword_type: SwordType = SwordType.BRONZE  # Choose sword type in editor
@export var pickup_sound: AudioStream

@onready var animated_sprite: AnimatedSprite2D = $SwordSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var is_collected: bool = false

# Weapon configuration data (animation names correspond to sword types)
var weapon_configs = {
    SwordType.BRONZE: {
        "weapon_id": "bronze_sword",
        "weapon_name": "Bronze Sword",
        "attack_power": 12,
        "animation_name": "bronze_sword",  # Corresponds to animation name in SpriteFrames
        "glow_color": Color(0.8, 0.6, 0.4, 1.0)  # Bronze glow
    },
    SwordType.IRON: {
        "weapon_id": "iron_sword", 
        "weapon_name": "Iron Sword",
        "attack_power": 20,
        "animation_name": "iron_sword",   # Corresponds to animation name in SpriteFrames
        "glow_color": Color(0.7, 0.7, 0.8, 1.0)  # Silver glow
    },
    SwordType.STEEL: {
        "weapon_id": "steel_sword",
        "weapon_name": "Steel Sword", 
        "attack_power": 30,
        "animation_name": "steel_sword",  # Corresponds to animation name in SpriteFrames
        "glow_color": Color(1.0, 1.0, 0.8, 1.0)  # Gold glow
    },
    SwordType.BASIC: {
        "weapon_id": "basic_sword",
        "weapon_name": "Basic Sword",
        "attack_power": 5,
        "animation_name": "basic_sword",  # Corresponds to animation name in SpriteFrames
        "glow_color": Color(1.0, 1.0, 1.0, 1.0)  # White glow
    }
}

func _ready():
    body_entered.connect(_on_body_entered)
    add_to_group("weapons")
    
    # Play corresponding animation based on type
    _play_sword_animation()
    
    # Start glow effect
    _start_glow_effect()

func _play_sword_animation():
    var config = weapon_configs[sword_type]
    var animation_name = config.animation_name
    
    if animated_sprite and animated_sprite.sprite_frames:
        if animated_sprite.sprite_frames.has_animation(animation_name):
            animated_sprite.play(animation_name)
            print("Playing sword animation:", animation_name)
        else:
            print("Error: Animation '", animation_name, "' not found")
            # Fall back to default animation
            if animated_sprite.sprite_frames.has_animation("default"):
                animated_sprite.play("default")

func _start_glow_effect():
    var config = weapon_configs[sword_type]
    var glow_color = config.glow_color
    var normal_color = Color.WHITE
    
    var tween = create_tween()
    tween.set_loops()
    tween.tween_property(animated_sprite, "modulate", glow_color, 1.5)
    tween.tween_property(animated_sprite, "modulate", normal_color, 1.5)

func _on_body_entered(body):
    if is_collected or not body.is_in_group("player"):
        return
    
    is_collected = true
    
    var config = weapon_configs[sword_type]
    
    if body.has_method("try_equip_weapon"):
        var equipped = body.try_equip_weapon(
            config.weapon_id, 
            config.weapon_name, 
            config.attack_power
        )
        if equipped:
            print("Player obtained new weapon:", config.weapon_name, "(Attack Power:", config.attack_power, ")")
            
            # Show weapon obtained notification
            var notification_manager = get_node_or_null("/root/NotificationManager")
            if notification_manager:
                notification_manager.notify_weapon_obtained(config.weapon_name, config.attack_power)
            
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
            
            _play_pickup_effect()
            await get_tree().create_timer(0.5).timeout
            queue_free()
        else:
            print("Player already has this weapon")
            is_collected = false

func _play_pickup_effect():
    var tween = create_tween()
    tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)