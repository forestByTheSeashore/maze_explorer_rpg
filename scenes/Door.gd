# Door.gd
extends StaticBody2D

# -----------------------------------------------------------------------------
# 节点引用
# -----------------------------------------------------------------------------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# -----------------------------------------------------------------------------
# 导出变量：在编辑器中定义门的类型 (重要！)
# -----------------------------------------------------------------------------
enum DoorType { ENTRANCE, EXIT } # 定义门的类型枚举
@export var type: DoorType = DoorType.ENTRANCE # 默认是入口门，可在检查器中更改
@export var requires_key: bool = false  # 是否需要钥匙
@export var required_key_type: String = "master_key"  # 需要的钥匙类型
@export var consume_key_on_open: bool = true  # 开门时是否消耗钥匙

# -----------------------------------------------------------------------------
# 门的状态变量
# -----------------------------------------------------------------------------
var is_open: bool = false
var is_transitioning: bool = false # 防止重复触发或打断动画

# -----------------------------------------------------------------------------
# 信号
# -----------------------------------------------------------------------------
signal door_opened
signal door_closed

# -----------------------------------------------------------------------------
# _ready() 函数
# -----------------------------------------------------------------------------
func _ready():
    # 调试：检查节点是否被正确引用
    if animated_sprite == null:
        push_error("Error: AnimatedSprite2D node not found for Door.gd!")
        return
    if collision_shape == null:
        push_error("Error: CollisionShape2D node not found for Door.gd!")
        return

    # 确保 AnimatedSprite2D 的动画完成信号只连接一次
    if not animated_sprite.animation_finished.is_connected(on_animation_finished):
        animated_sprite.animation_finished.connect(on_animation_finished)

    # 根据门类型设置初始状态 (重要调整！)
    if type == DoorType.ENTRANCE:
        # 入口门：初始是开着的（播放开门动画的最后一帧），没有碰撞
        if animated_sprite.sprite_frames.has_animation("door_open"):
            animated_sprite.play("door_open")
            animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_open") - 1
            animated_sprite.stop() # 停止在打开的最后一帧
            #print("Entrance Door initialized to OPEN state.")
        else:
            push_error("Error: 'door_open' animation not found for Entrance Door!")
        
        is_open = true # 初始状态为打开
        collision_shape.disabled = true # 打开时无碰撞

    elif type == DoorType.EXIT:
        # 出口门：初始是关着的（播放关门动画的最后一帧），有碰撞
        if animated_sprite.sprite_frames.has_animation("door_close"):
            animated_sprite.play("door_close")
            animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_close") - 1
            animated_sprite.stop() # 停止在关闭的最后一帧
            #print("Exit Door initialized to CLOSED state.")
        else:
            push_error("Error: 'door_close' animation not found for Exit Door!")

        is_open = false # 初始状态为关闭
        collision_shape.disabled = false # 关闭时有碰撞

    is_transitioning = false # 初始没有动画正在播放

    # -----------------------------------------------------------------------------
    # 调整 Sprite 和 碰撞体的对齐 (基于 18x32 像素图块，此部分保持不变)
    # -----------------------------------------------------------------------------
    animated_sprite.offset = Vector2(-1, -16) 
    if collision_shape.shape == null or not (collision_shape.shape is RectangleShape2D):
        collision_shape.shape = RectangleShape2D.new()
    (collision_shape.shape as RectangleShape2D).extents = Vector2(9, 16)
    collision_shape.position = Vector2(8, 0)


# -----------------------------------------------------------------------------
# 公开函数：打开门 (行为根据门类型调整)
# -----------------------------------------------------------------------------
func open_door():
    if type == DoorType.ENTRANCE:
        # 入口门不应该执行打开动作，只执行关闭动作
        # print("Entrance Door: open_door() called, but it only closes.")
        return 

    # 以下为出口门的打开逻辑
    if is_open or is_transitioning:
        # print("Exit Door: open_door() ignored (already open or transitioning).")
        return 
    
    is_transitioning = true
    if animated_sprite.sprite_frames.has_animation("door_open"):
        animated_sprite.play("door_open")
        # print("Exit Door: Playing 'door_open' animation.")
    else:
        push_error("Error: 'door_open' animation not found for Exit Door!")
        is_transitioning = false 

    collision_shape.disabled = true # 门打开时立即禁用碰撞

# -----------------------------------------------------------------------------
# 公开函数：关闭门 (行为根据门类型调整)
# -----------------------------------------------------------------------------
func close_door():
    if type == DoorType.EXIT:
        # 出口门不应该执行关闭动作，只执行打开动作
        # print("Exit Door: close_door() called, but it only opens.")
        return 

    # 以下为入口门的关闭逻辑
    if not is_open or is_transitioning:
        # print("Entrance Door: close_door() ignored (already closed or transitioning).")
        return 
    
    is_transitioning = true
    if animated_sprite.sprite_frames.has_animation("door_close"):
        animated_sprite.play("door_close")
        # print("Entrance Door: Playing 'door_close' animation.")
    else:
        push_error("Error: 'door_close' animation not found for Entrance Door!")
        is_transitioning = false 

# -----------------------------------------------------------------------------
# 私有回调函数：动画播放完成时触发
# -----------------------------------------------------------------------------
func on_animation_finished():
    is_transitioning = false 
    
    if animated_sprite.animation == "door_open":
        is_open = true
        animated_sprite.stop() 
        animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_open") - 1
        # print("Door (open animation finished).")
        door_opened.emit() 

    elif animated_sprite.animation == "door_close":
        is_open = false
        animated_sprite.stop()
        animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_close") - 1
        collision_shape.disabled = false # 关门动画完成后，重新启用碰撞体
        # print("Door (close animation finished).")
        door_closed.emit() 


# -----------------------------------------------------------------------------
# 公开函数：交互 (根据门类型只执行允许的动作)
# -----------------------------------------------------------------------------
# 修改 interact() 函数
func interact():
    match type:
        DoorType.ENTRANCE:
            # 入口门逻辑保持不变
            close_door()
        
        DoorType.EXIT:
            # 出口门需要检查钥匙
            if requires_key:
                _try_open_locked_door()
            else:
                open_door()


# 新增：尝试打开锁定的门
func _try_open_locked_door():
    # 查找玩家
    var player = get_tree().get_first_node_in_group("player")
    if not player:
        print("错误：找不到玩家节点")
        return
    
    # 检查玩家是否有所需钥匙
    if player.has_method("has_key") and player.has_key(required_key_type):
        print("玩家有钥匙，正在开门...")
        
        # 显示钥匙使用通知
        var notification_manager = get_node_or_null("/root/NotificationManager")
        if notification_manager:
            notification_manager.notify_key_used(required_key_type)
        
        # 使用钥匙（如果设置为消耗）
        if consume_key_on_open:
            if player.has_method("use_key"):
                player.use_key(required_key_type)
                print("钥匙已被使用")
        
        # 打开门
        open_door()
        
        # 显示门打开通知
        if notification_manager:
            notification_manager.notify_door_opened()
        
    else:
        # 玩家没有钥匙
        print("这扇门被锁着，需要", required_key_type, "才能打开")
        
        # 显示门被锁住的通知
        var notification_manager = get_node_or_null("/root/NotificationManager")
        if notification_manager:
            notification_manager.notify_key_required(required_key_type)
        
        _play_locked_door_feedback()

# 新增：锁门反馈效果
func _play_locked_door_feedback():
    # 播放锁门音效
    var audio_manager = get_node_or_null("/root/AudioManager")
    if audio_manager:
        audio_manager.play_door_locked_sound()
    
    # 播放锁门音效或动画
    if animated_sprite:
        # 简单的晃动效果表示门被锁住
        var original_position = animated_sprite.position
        var tween = create_tween()
        tween.tween_property(animated_sprite, "position:x", original_position.x + 2, 0.1)
        tween.tween_property(animated_sprite, "position:x", original_position.x - 2, 0.1)
        tween.tween_property(animated_sprite, "position:x", original_position.x, 0.1)