# SkelontonEnemy.gd
extends CharacterBody2D

# FSM 状态枚举
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

# --- 导出变量 (可在编辑器中调整) ---
@export var health: int = 100
@export var attack_power: int = 25
@export var speed: float = 75.0
@export var experience_drop: int = 50

@export var detection_radius_behavior: bool = true # 是否使用索敌范围 Area2D
@export var detection_distance: float = 200.0    # 发现玩家的距离 (如果不用Area2D)
@export var attack_distance: float = 50.0     # 进入攻击状态的距离
@export var attack_cooldown: float = 1.5      # 攻击间隔 (秒)
@export var attack_hitbox_reach: float = 25.0 # 攻击判定框的向前（左右）偏移量
@export var personal_space: float = 15.0 # 敌人个人空间，防止过近
@export var retreat_speed_factor: float = 0.5 # 后退时的速度系数

# --- 节点引用 ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var detection_area: Area2D = $Area2D       # 用于索敌
@onready var attack_hitbox: Area2D = $AttackHitbox  # 用于攻击判定

# --- 内部变量 ---
var player_target: CharacterBody2D = null
var can_attack: bool = true
var facing_direction_vector: Vector2 = Vector2.RIGHT # 默认朝右
var stuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var is_attacking: bool = false  # 新增：标记是否正在攻击过程中

func _ready():
    add_to_group("enemies")
    _enter_state(State.IDLE)

    # 连接信号
    if detection_area and detection_radius_behavior:
        print("连接 Area2D 信号")
        detection_area.body_entered.connect(_on_DetectionArea_body_entered)
        detection_area.body_exited.connect(_on_DetectionArea_body_exited)
    
    if attack_hitbox:
        attack_hitbox.monitoring = false

    animated_sprite.animation_finished.connect(_on_animation_finished)
    
    # 延迟配置导航代理，确保导航系统已准备好
    call_deferred("_setup_navigation")
    last_position = global_position

func _setup_navigation():
    """延迟配置导航代理"""
    if navigation_agent:
        navigation_agent.path_desired_distance = 8.0
        navigation_agent.target_desired_distance = 15.0
        navigation_agent.radius = 16.0
        navigation_agent.avoidance_enabled = true
        # 等待一帧确保导航网格加载
        await get_tree().process_frame

func _physics_process(delta):
    _check_if_stuck(delta)
    
    # 根据状态处理逻辑，但统一在最后调用 move_and_slide()
    match current_state:
        State.IDLE:
            _idle_state(delta)
        State.CHASE:
            _chase_state(delta)
        State.ATTACK:
            _attack_state(delta)
        State.DEAD:
            velocity = Vector2.ZERO
    
    # 应用分离力（在速度设置之后）
    _apply_separation_force(delta)
    
    # 统一移动处理
    move_and_slide()
    
    # 更新位置记录
    last_position = global_position

func _apply_separation_force(delta):
    """防止与玩家重叠的分离力"""
    if player_target == null or current_state == State.DEAD:
        return
        
    var distance_to_player = global_position.distance_to(player_target.global_position)
    
    # 如果太近，施加推力
    if distance_to_player < personal_space and distance_to_player > 1.0: # 避免除零
        var push_direction = global_position.direction_to(player_target.global_position) * -1
        var push_strength = (personal_space - distance_to_player) / personal_space
        var push_force = push_direction * push_strength * 100.0 # 调整推力强度
        
        velocity += push_force * delta
        velocity = velocity.limit_length(speed * 1.5)

func _check_if_stuck(delta):
    """检测是否卡住"""
    if current_state != State.CHASE:
        stuck_timer = 0.0
        return
    
    var movement_threshold = 10.0 # 稍微提高阈值
    if global_position.distance_to(last_position) < movement_threshold * delta:
        stuck_timer += delta
        if stuck_timer > 1.5: # 减少等待时间
            print(name, " 检测到卡住，尝试绕路")
            _handle_stuck_situation()
            stuck_timer = 0.0
    else:
        stuck_timer = 0.0

func _handle_stuck_situation():
    """处理卡住情况"""
    if player_target == null:
        return
    
    # 尝试随机偏移方向
    var to_player = global_position.direction_to(player_target.global_position)
    var perpendicular = Vector2(-to_player.y, to_player.x) # 垂直方向
    var random_offset = perpendicular * randf_range(-50, 50)
    var new_target = player_target.global_position + random_offset
    
    if navigation_agent:
        navigation_agent.target_position = new_target

# ============================================================================
# 状态管理与逻辑
# ============================================================================
func _enter_state(new_state: State):
    if current_state == new_state and new_state != State.ATTACK:
        return
    
    var old_state = current_state
    current_state = new_state
    print(name, " 状态切换: ", State.keys()[old_state], " -> ", State.keys()[new_state])

    match current_state:
        State.IDLE:
            velocity = Vector2.ZERO
            is_attacking = false
            _update_visual_animation("idle")
        State.CHASE:
            is_attacking = false
            _update_visual_animation("walk")
        State.ATTACK:
            velocity = Vector2.ZERO
            if not is_attacking: # 防止重复攻击
                is_attacking = true
                _perform_attack()
        State.DEAD:
            is_attacking = false
            _play_death_and_cleanup_setup()

func _idle_state(_delta):
    """待机状态逻辑"""
    velocity = Vector2.ZERO
    
    # 寻找目标
    if player_target == null:
        _try_find_player()
    elif is_instance_valid(player_target):
        _enter_state(State.CHASE)
    else:
        player_target = null
    
    _update_visual_animation("idle")

func _try_find_player():
    """尝试寻找玩家目标"""
    if detection_radius_behavior:
        return # 使用 Area2D 检测
    
    var potential_player = _find_player_in_distance(detection_distance)
    if potential_player:
        print(name, " 发现玩家: ", potential_player.name)
        player_target = potential_player
        _update_facing_direction()
        _enter_state(State.CHASE)

func _chase_state(_delta):
    """追逐状态逻辑"""
    if not _validate_target():
        return
    
    var distance_to_player = global_position.distance_to(player_target.global_position)
    _update_facing_direction()
    
    # 检查是否进入攻击状态
    if distance_to_player <= attack_distance and can_attack:
        print(name, " 进入攻击距离: ", distance_to_player)
        _enter_state(State.ATTACK)
        return
    
    # 如果在冷却中且距离很近，等待
    if distance_to_player <= attack_distance * 1.2 and not can_attack:
        velocity = Vector2.ZERO
        _update_visual_animation("idle")
        return
    
    # 导航到玩家位置
    _navigate_to_player(distance_to_player)
    _update_visual_animation("walk")

func _attack_state(_delta):
    """攻击状态逻辑"""
    if not _validate_target():
        return
    
    var distance_to_player = global_position.distance_to(player_target.global_position)
    
    # 如果玩家跑太远，切换到追逐
    if distance_to_player > attack_distance * 2.0:
        print(name, " 玩家跑远，切换到追逐")
        is_attacking = false
        can_attack = true
        _enter_state(State.CHASE)
        return
    
    # 面向玩家并停止移动
    _update_facing_direction()
    velocity = Vector2.ZERO
    
    # 攻击动画处理在 _perform_attack 中

func _validate_target() -> bool:
    """验证目标有效性"""
    if player_target == null or not is_instance_valid(player_target):
        _enter_state(State.IDLE)
        return false
    return true

func _update_facing_direction():
    """更新朝向"""
    if player_target:
        facing_direction_vector = global_position.direction_to(player_target.global_position).normalized()

func _navigate_to_player(distance_to_player: float):
    """导航到玩家位置"""
    if not navigation_agent:
        # 如果没有导航代理，直接移动
        velocity = facing_direction_vector * speed
        return
    
    navigation_agent.target_position = player_target.global_position
    
    if not navigation_agent.is_navigation_finished():
        var next_path_position = navigation_agent.get_next_path_position()
        var move_direction = global_position.direction_to(next_path_position)
        
        # 如果导航路径不理想，使用直接路径
        if next_path_position.distance_to(player_target.global_position) > attack_distance * 2:
            move_direction = facing_direction_vector
        
        velocity = move_direction * speed
    else:
        # 导航完成，直接向玩家移动
        velocity = facing_direction_vector * speed

# ============================================================================
# 攻击系统
# ============================================================================
func _perform_attack():
    """执行攻击"""
    if not _validate_target() or is_attacking == false:
        return

    print(name, " 开始攻击 ", player_target.name)
    _update_visual_animation("attack")
    can_attack = false
    
    # 检查距离
    var distance_to_player = global_position.distance_to(player_target.global_position)
    if distance_to_player > attack_distance * 1.5:
        print(name, " 攻击时玩家太远，取消攻击")
        _reset_attack_state()
        return
    
    # 配置攻击判定框
    _setup_attack_hitbox()
    
    # 等待攻击判定
    await get_tree().create_timer(0.2).timeout
    
    if not is_attacking: # 检查是否被打断
        return
    
    # 执行攻击判定
    _execute_attack_check()
    
    # 攻击冷却
    await get_tree().create_timer(attack_cooldown).timeout
    
    _reset_attack_state()

func _setup_attack_hitbox():
    """设置攻击判定框"""
    if not attack_hitbox:
        return
    
    var attack_direction = Vector2.RIGHT if not animated_sprite.flip_h else Vector2.LEFT
    attack_hitbox.position = attack_direction * attack_hitbox_reach
    attack_hitbox.monitoring = true

func _execute_attack_check():
    """执行攻击检测"""
    if not attack_hitbox:
        print("警告: 未找到 AttackHitbox 节点!")
        return
    
    var hit_targets = attack_hitbox.get_overlapping_bodies()
    var hit_player = false
    
    for body in hit_targets:
        if body == player_target and body.has_method("take_damage"):
            var current_distance = global_position.distance_to(body.global_position)
            if current_distance <= attack_distance * 1.5:
                body.take_damage(attack_power)
                hit_player = true
                print(name, " 攻击命中，造成 ", attack_power, " 点伤害")
                break
    
    if not hit_player:
        print(name, " 攻击未命中")
    
    attack_hitbox.monitoring = false

func _reset_attack_state():
    """重置攻击状态"""
    can_attack = true
    is_attacking = false
    
    if attack_hitbox:
        attack_hitbox.monitoring = false
    
    # 重新评估状态
    if current_state == State.ATTACK and _validate_target():
        var distance = global_position.distance_to(player_target.global_position)
        if distance <= attack_distance:
            # 可以继续攻击，但不立即重新攻击
            pass
        else:
            _enter_state(State.CHASE)

# ============================================================================
# 动画系统
# ============================================================================
func _update_visual_animation(action_prefix: String):
    """更新视觉动画"""
    var anim_name = action_prefix + "_right"
    
    if not animated_sprite.sprite_frames.has_animation(anim_name):
        print("错误: 动画 '", anim_name, "' 未找到!")
        return
    
    var new_flip_h = facing_direction_vector.x < -0.01
    
    # 防止攻击动画被打断
    if animated_sprite.animation.begins_with("attack") and animated_sprite.is_playing():
        if not anim_name.begins_with("attack"):
            return
    
    # 检查是否需要更新
    var needs_update = (
        animated_sprite.animation != anim_name or
        animated_sprite.flip_h != new_flip_h or
        not animated_sprite.is_playing()
    )
    
    if needs_update:
        animated_sprite.flip_h = new_flip_h
        animated_sprite.play(anim_name)

# ============================================================================
# 伤害系统
# ============================================================================
func receive_player_attack(player_attack_power: int) -> int:
    """接收玩家攻击"""
    if current_state == State.DEAD:
        return 0
    
    var actual_damage = player_attack_power
    health -= actual_damage
    print(name, " 受到玩家攻击 ", actual_damage, " 点伤害, 剩余HP: ", health)
    
    _on_hit_by_player()
    
    if health <= 0:
        _enter_state(State.DEAD)
    
    return actual_damage

func _on_hit_by_player():
    """受击反应"""
    print(name, " 被玩家击中")
    
    # 闪烁效果
    var original_modulate = animated_sprite.modulate
    animated_sprite.modulate = Color.RED
    await get_tree().create_timer(0.1).timeout
    if animated_sprite: # 确保节点存在
        animated_sprite.modulate = original_modulate

func take_damage(amount: int, _source_attack_power: int = 0):
    """通用伤害接口"""
    if current_state == State.DEAD:
        return
    
    health -= amount
    print(name, " 受到 ", amount, " 点伤害, 剩余HP: ", health)
    
    if health <= 0:
        _enter_state(State.DEAD)

# ============================================================================
# 死亡和清理
# ============================================================================
func _play_death_and_cleanup_setup():
    """播放死亡动画并设置清理"""
    velocity = Vector2.ZERO
    set_physics_process(false)
    
    # 禁用碰撞
    var collision_shape = $CollisionShape2D
    if collision_shape:
        collision_shape.disabled = true
    
    # 播放死亡动画
    if animated_sprite.sprite_frames.has_animation("death"):
        animated_sprite.play("death")
        animated_sprite.flip_h = false
    else:
        print("错误: 'death' 动画未找到!")
        _handle_defeat_cleanup()

func _handle_defeat_cleanup():
    """处理死亡后的清理"""
    var player_node = get_tree().get_first_node_in_group("player")
    if player_node and player_node.has_method("gain_experience"):
        player_node.gain_experience(experience_drop)
        print("玩家获得经验: ", experience_drop)
    
    queue_free()

# ============================================================================
# 信号回调
# ============================================================================
func _on_DetectionArea_body_entered(body):
    """检测区域进入"""
    if body.is_in_group("player"):
        print(name, " 发现玩家: ", body.name)
        player_target = body
        if current_state == State.IDLE:
            _update_facing_direction()
            _enter_state(State.CHASE)

func _on_DetectionArea_body_exited(body):
    """检测区域离开"""
    if body == player_target:
        print(name, " 玩家离开检测范围")
        player_target = null
        if current_state in [State.CHASE, State.ATTACK]:
            _enter_state(State.IDLE)

func _on_animation_finished():
    """动画完成回调"""
    if current_state == State.DEAD and animated_sprite.animation == "death":
        _handle_defeat_cleanup()

# ============================================================================
# 辅助函数
# ============================================================================
func _find_player_in_distance(distance: float) -> CharacterBody2D:
    """在指定距离内寻找玩家"""
    var players = get_tree().get_nodes_in_group("player")
    if not players.is_empty():
        var player = players[0]
        if global_position.distance_to(player.global_position) <= distance:
            return player
    return null