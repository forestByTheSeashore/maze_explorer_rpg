# Sword.gd - 使用动画区分不同剑类型
extends Area2D

# 武器类型枚举
enum SwordType { BASIC, BRONZE, IRON, STEEL }

@export var sword_type: SwordType = SwordType.BRONZE  # 在编辑器中选择剑类型
@export var pickup_sound: AudioStream

@onready var animated_sprite: AnimatedSprite2D = $SwordSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var is_collected: bool = false

# 武器配置数据（动画名称对应剑的类型）
var weapon_configs = {
    SwordType.BRONZE: {
        "weapon_id": "bronze_sword",
        "weapon_name": "Bronze Sword",
        "attack_power": 12,
        "animation_name": "bronze_sword",  # 对应SpriteFrames中的动画名称
        "glow_color": Color(0.8, 0.6, 0.4, 1.0)  # 青铜色光芒
    },
    SwordType.IRON: {
        "weapon_id": "iron_sword", 
        "weapon_name": "Iron Sword",
        "attack_power": 20,
        "animation_name": "iron_sword",   # 对应SpriteFrames中的动画名称
        "glow_color": Color(0.7, 0.7, 0.8, 1.0)  # 银色光芒
    },
    SwordType.STEEL: {
        "weapon_id": "steel_sword",
        "weapon_name": "Steel Sword", 
        "attack_power": 30,
        "animation_name": "steel_sword",  # 对应SpriteFrames中的动画名称
        "glow_color": Color(1.0, 1.0, 0.8, 1.0)  # 金色光芒
    },
	SwordType.BASIC: {
		"weapon_id": "basic_sword",
		"weapon_name": "Basic Sword",
		"attack_power": 5,
		"animation_name": "basic_sword",  # 对应SpriteFrames中的动画名称
		"glow_color": Color(1.0, 1.0, 1.0, 1.0)  # 白色光芒
	}
}

func _ready():
    body_entered.connect(_on_body_entered)
    add_to_group("weapons")
    
    # 根据类型播放对应的动画
    _play_sword_animation()
    
    # 开始发光效果
    _start_glow_effect()

func _play_sword_animation():
    var config = weapon_configs[sword_type]
    var animation_name = config.animation_name
    
    if animated_sprite and animated_sprite.sprite_frames:
        if animated_sprite.sprite_frames.has_animation(animation_name):
            animated_sprite.play(animation_name)
            print("播放剑动画：", animation_name)
        else:
            print("错误：找不到动画 '", animation_name, "'")
            # 回退到默认动画
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
            print("玩家获得了新武器：", config.weapon_name, "（攻击力：", config.attack_power, "）")
            _play_pickup_effect()
            await get_tree().create_timer(0.5).timeout
            queue_free()
        else:
            print("玩家已经拥有这把武器")
            is_collected = false

func _play_pickup_effect():
    var tween = create_tween()
    tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)