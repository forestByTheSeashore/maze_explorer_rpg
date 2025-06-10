# Key.gd
extends Area2D

# 导出变量
@export var key_type: String = "master_key"  # 钥匙类型，可扩展多种钥匙
@export var pickup_sound: AudioStream  # 拾取音效

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $KeySprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

# 状态变量
var is_collected: bool = false

func _ready():
    # 连接信号
    body_entered.connect(_on_body_entered)
    
    # 设置动画
    if animated_sprite and animated_sprite.sprite_frames:
        if animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")
    
    # 可选：添加浮动效果
    # _start_floating_animation()

func _start_floating_animation():
    # 创建简单的上下浮动效果
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
    
    # 给玩家添加钥匙
    if player_node.has_method("add_key"):
        player_node.add_key(key_type)
        print("玩家获得了", key_type)
        
        # 显示钥匙拾取通知
        var notification_manager = get_node_or_null("/root/NotificationManager")
        if notification_manager:
            notification_manager.notify_key_obtained(key_type)
    
    # 更新统计
    var victory_manager = get_node_or_null("/root/VictoryManager")
    if victory_manager:
        victory_manager.increment_items_collected()
    
    # 播放拾取音效
    var audio_manager = get_node_or_null("/root/AudioManager")
    if audio_manager:
        audio_manager.play_pickup_sound()
    elif audio_player and pickup_sound:
        audio_player.stream = pickup_sound
        audio_player.play()
    
    # 播放拾取特效
    var effects_manager = get_node_or_null("/root/EffectsManager")
    if effects_manager:
        effects_manager.play_pickup_effect(global_position)
    
    # 播放拾取动画或效果
    _play_pickup_effect()
    
    # 延迟删除，等待音效播放完成
    await get_tree().create_timer(0.5).timeout
    queue_free()

func _play_pickup_effect():
    # 拾取时的视觉效果
    var tween = create_tween()
    tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)