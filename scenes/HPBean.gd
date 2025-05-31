# HPBean.gd - 修正版
extends Area2D

@export var hp_increase: int = 20  # HP增加量
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
    
    _start_floating_animation()

func _start_floating_animation():
    var tween = create_tween()
    tween.set_loops()
    tween.tween_property(self, "position:y", position.y - 3, 1.0)
    tween.tween_property(self, "position:y", position.y + 3, 1.0)

func _on_body_entered(body):
    if is_collected or not body.is_in_group("player"):
        return
    
    is_collected = true
    
    # 提升玩家的当前HP（不是恢复，是永久增加）
    if body.has_method("increase_hp_from_bean"):
        body.increase_hp_from_bean(hp_increase)
        print("玩家的HP永久增加了 ", hp_increase, " 点！")
    
    # 播放拾取效果
    _play_pickup_effect()
    
    await get_tree().create_timer(0.5).timeout
    queue_free()

func _play_pickup_effect():
    var tween = create_tween()
    tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)