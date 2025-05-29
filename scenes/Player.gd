extends CharacterBody2D

# 枚举玩家状态
enum PlayerState { IDLE, WALK, ATTACK, DEATH }
var current_state: PlayerState = PlayerState.IDLE

# --- 导出变量 ---
@export var speed: float = 150.0

# --- 节点引用 ---
@onready var animated_sprite: AnimatedSprite2D = $PlayerAnimatedSprite

@onready var attack_hitbox: Area2D = $AttackHitbox # 获取AttackHitbox节点的引用


# --- 玩家属性 ---
var current_hp: int = 100
var max_hp: int = 500 # 你之前的代码是500，如果GDD有定义初始值，以GDD为准
var facing_direction_vector: Vector2 = Vector2.DOWN # 用于记录玩家的朝向，攻击和待机时使用

# ============================================================================
# 内置函数
# ============================================================================
func _ready():
    add_to_group("player")
    # 连接动画完成信号，主要用于攻击和死亡动画后的状态切换
    animated_sprite.animation_finished.connect(_on_animation_finished)
    # 初始设置一次朝向对应的待机动画
    _update_idle_animation()

func _physics_process(_delta: float) -> void:
    if current_state == PlayerState.DEATH:
        # 如果玩家已死亡，不执行任何操作
        # 死亡动画播放完毕后，可以通过 _on_animation_finished 处理后续逻辑
        return

    # 1. 处理攻击输入
    if Input.is_action_just_pressed("attack"): # "attack" 应该映射到 'J' 键
        if current_state != PlayerState.ATTACK: # 避免在攻击时再次攻击
            _enter_state(PlayerState.ATTACK)
            return # 进入攻击状态后，本帧不处理移动

    # 2. 处理移动输入 (只有在非攻击状态下)
    var input_direction := Vector2.ZERO
    if current_state != PlayerState.ATTACK:
        input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

    if input_direction.length_squared() > 0:
        facing_direction_vector = input_direction.normalized() # 更新朝向
        if current_state != PlayerState.ATTACK: # 只有非攻击状态才能因移动进入行走状态
            _enter_state(PlayerState.WALK)
    else:
        if current_state == PlayerState.WALK: # 如果之前是行走状态，现在没有输入了，则进入待机
            _enter_state(PlayerState.IDLE)

    # 3. 根据当前状态更新速度和动画
    match current_state:
        PlayerState.WALK:
            velocity = input_direction * speed
            _update_walk_animation()
        PlayerState.IDLE:
            velocity = Vector2.ZERO
            _update_idle_animation() # 确保待机动画基于正确的facing_direction_vector
        PlayerState.ATTACK:
            velocity = Vector2.ZERO # 攻击时通常不允许移动
            # 攻击动画在 _enter_state(PlayerState.ATTACK) 中触发
        PlayerState.DEATH:
            velocity = Vector2.ZERO

    move_and_slide()

# ============================================================================
# 状态管理
# ============================================================================
func _enter_state(new_state: PlayerState):
    if current_state == new_state and new_state != PlayerState.ATTACK: # 允许重复进入攻击状态以重置攻击动画
        return

    # print("Changing state from ", PlayerState.keys()[current_state], " to ", PlayerState.keys()[new_state]) # 调试用
    current_state = new_state

    match current_state:
        PlayerState.IDLE:
            _update_idle_animation()
        PlayerState.WALK:
            _update_walk_animation() # Walk动画会在 physics_process 中根据方向持续更新
        PlayerState.ATTACK:
            _play_attack_animation()
        PlayerState.DEATH:
            _play_death_animation()

# ============================================================================
# 动画处理
# ============================================================================
func _update_walk_animation():
    var anim_name = "walk_"
    var flip_h = false

    if abs(facing_direction_vector.y) > abs(facing_direction_vector.x): # 优先上下
        if facing_direction_vector.y < 0:
            anim_name += "up"
        else:
            anim_name += "down"
    else: # 水平方向
        anim_name += "right" # 左右行走都基于 "walk_right"
        if facing_direction_vector.x < 0:
            flip_h = true

    _play_animation_if_different(anim_name, flip_h)

func _update_idle_animation():
    var anim_name = "idle_"
    var flip_h = false

    if abs(facing_direction_vector.y) > abs(facing_direction_vector.x): # 优先上下
        if facing_direction_vector.y < 0:
            anim_name += "up"
        else:
            anim_name += "down"
    else: # 水平方向
        anim_name += "right" # 左右待机都基于 "idle_right"
        if facing_direction_vector.x < 0:
            flip_h = true
            
    _play_animation_if_different(anim_name, flip_h)

func _play_attack_animation():
    var anim_name = "attack_"
    var flip_h = false

    if abs(facing_direction_vector.y) > abs(facing_direction_vector.x):
        if facing_direction_vector.y < 0:
            anim_name += "up"
        else:
            anim_name += "down"
    else:
        anim_name += "right"
        if facing_direction_vector.x < 0:
            flip_h = true
            
    _play_animation_if_different(anim_name, flip_h)
    
    # --- 改进的攻击判定逻辑 ---
    # 调整 AttackHitbox 的位置和方向以匹配攻击动画和朝向
    var hitbox_offset = Vector2(20, 0) # 基础偏移
    if anim_name == "attack_up":
        attack_hitbox.rotation = -PI / 2
        attack_hitbox.position = Vector2(0, -20)
    elif anim_name == "attack_down":
        attack_hitbox.rotation = PI / 2
        attack_hitbox.position = Vector2(0, 20)
    elif anim_name.contains("right"):
        attack_hitbox.rotation = 0
        if flip_h:
            attack_hitbox.position = Vector2(-hitbox_offset.x, hitbox_offset.y)
        else:
            attack_hitbox.position = hitbox_offset
    
    # 启用攻击判定
    attack_hitbox.monitoring = true
    print("玩家开始攻击，攻击力: ", get_total_attack())
    
    # 延迟攻击判定，与动画同步
    await get_tree().create_timer(0.2).timeout
    
    # 检测攻击命中
    var overlapping_bodies = attack_hitbox.get_overlapping_bodies()
    var hit_enemies = []
    
    for body in overlapping_bodies:
        if body.is_in_group("enemies") and body.has_method("receive_player_attack"):
            hit_enemies.append(body)
    
    # 对所有命中的敌人造成伤害
    for enemy in hit_enemies:
        var damage_dealt = enemy.receive_player_attack(get_total_attack())
        print("玩家攻击命中: ", enemy.name, " 造成伤害: ", damage_dealt)
        
        # 可以在这里添加命中特效
        _create_hit_effect(enemy.global_position)
    
    if hit_enemies.size() == 0:
        print("玩家攻击未命中任何敌人")
    
    attack_hitbox.monitoring = false

# 新增：创建命中特效（可选）
func _create_hit_effect(position: Vector2):
    # 这里可以添加粒子效果、音效等
    print("在位置 ", position, " 创建命中特效")

# 你需要添加或确保有 get_total_attack() 函数
var base_attack: int = current_hp / 5 # 示例基础攻击力
var current_weapon_attack: int = 10 # 来自武器的攻击力加成 (后续武器系统实现)
func get_total_attack() -> int:
    return base_attack + current_weapon_attack

# 你需要添加或确保有 gain_experience() 函数
var current_exp: int = 0
var exp_to_next_level: int = 50
func gain_experience(amount: int):
    current_exp += amount
    print("获得经验: ", amount, ", 当前总经验: ", current_exp)
    if current_exp >= exp_to_next_level:
        level_up()

func level_up(): # 示例升级逻辑
    print("等级提升！")
    current_exp -= exp_to_next_level
    exp_to_next_level += 25 
    max_hp += 20 
    current_hp = max_hp 
    base_attack += 2 # 示例：攻击力也提升
    print("HP上限提升至: ", max_hp, ", 攻击力提升至: ", base_attack)

func _play_death_animation():
    if animated_sprite.sprite_frames.has_animation("death"):
        _play_animation_if_different("death", false) # 死亡动画通常不翻转
    else:
        print("错误：未找到 'death' 动画！")
        _handle_game_over_logic() # 如果没有死亡动画，直接处理游戏结束

func _play_animation_if_different(anim_name: String, p_flip_h: bool):
    if animated_sprite.sprite_frames.has_animation(anim_name):
        if animated_sprite.animation != anim_name:
            animated_sprite.play(anim_name)
        animated_sprite.flip_h = p_flip_h # 确保翻转状态正确
    else:
        print("警告：动画 '", anim_name, "' 未在SpriteFrames中找到！")
        # 可以尝试播放一个默认动画，例如对应方向的idle
        var fallback_idle_anim = "idle_"
        if anim_name.contains("_up"): fallback_idle_anim += "up"
        elif anim_name.contains("_down"): fallback_idle_anim += "down"
        else: fallback_idle_anim += "right" # 水平方向的默认回退
        
        if animated_sprite.sprite_frames.has_animation(fallback_idle_anim) and animated_sprite.animation != fallback_idle_anim :
             animated_sprite.play(fallback_idle_anim)
        animated_sprite.flip_h = p_flip_h # 即使是回退动画，也应用翻转


func _on_animation_finished():
    # print("Animation finished: ", animated_sprite.animation) # 调试用
    if current_state == PlayerState.ATTACK:
        # 攻击动画播放完毕后，根据当前是否有移动输入决定回到IDLE或WALK状态
        var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
        if input_direction.length_squared() > 0:
            _enter_state(PlayerState.WALK)
        else:
            _enter_state(PlayerState.IDLE)
    elif current_state == PlayerState.DEATH and animated_sprite.animation == "death":
        # 死亡动画播放完毕
        _handle_game_over_logic()

# ============================================================================
# 玩家行为
# ============================================================================
func take_damage(amount: int):
    if current_state == PlayerState.DEATH: # 如果已死亡，不再受伤
        return

    current_hp -= amount
    current_hp = max(0, current_hp)
    print("Player HP: ", current_hp)
    # 这里可以发出信号更新UI: emit_signal("hp_updated", current_hp, max_hp)

    if current_hp == 0:
        _enter_state(PlayerState.DEATH)

func heal(amount: int):
    if current_state == PlayerState.DEATH: # 如果已死亡，无法治疗
        return
    current_hp += amount
    current_hp = min(current_hp, max_hp)
    print("Player HP: ", current_hp)
    # 这里可以发出信号更新UI: emit_signal("hp_updated", current_hp, max_hp)

func _handle_game_over_logic():
    print("玩家已死亡 - 游戏结束处理！")
    # 例如：
    # get_tree().reload_current_scene()
    # 或者显示游戏结束画面等
    # animated_sprite.stop() # 停在死亡动画的最后一帧
    # set_physics_process(false) # 彻底停止玩家活动