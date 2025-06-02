# SkelontonEnemy.gd
extends CharacterBody2D

# FSM 状态枚举
enum State { IDLE, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

# --- 导出变量 (可在编辑器中调整) ---
@export var health: int = 80
@export var attack_power: int = 20
@export var speed: float = 70.0
@export var experience_drop: int = 30

@export var detection_radius_behavior: bool = true # 是否使用索敌范围 Area2D
@export var detection_distance: float = 200.0    # 发现玩家的距离 (如果不用Area2D)
@export var attack_distance: float = 40.0        # 进入攻击状态的距离
@export var attack_cooldown: float = 1.5         # 攻击间隔 (秒)
@export var attack_hitbox_reach: float = 25.0    # 攻击判定框的向前偏移量
@export var personal_space: float = 25.0         # 敌人个人空间，防止过近
@export var enemy_separation_force: float = 150.0  # 敌人间分离力度
@export var player_separation_threshold: float = 20.0  # 与玩家的最小距离阈值

# --- 追逐行为配置 ---
@export var chase_type: ChaseType = ChaseType.NORMAL  # 追逐类型
@export var max_chase_distance: float = 800.0        # 最大追逐距离（用于无限追逐型）
@export var lose_target_time: float = 5.0            # 失去目标后多久停止追逐

enum ChaseType { NORMAL, ENDLESS }  # 普通追逐 vs 无限追逐

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
var is_attacking: bool = false
var is_dead: bool = false  # 添加死亡标志，防止重复死亡

# --- 追逐状态变量 ---
var last_known_player_position: Vector2 = Vector2.ZERO  # 玩家最后已知位置
var time_since_lost_target: float = 0.0                 # 失去目标后的时间
var is_in_endless_chase: bool = false                   # 是否进入无限追逐模式

func _ready():
	add_to_group("enemies")
	_enter_state(State.IDLE)
	
	# 确保正确初始化
	is_dead = false
	print(name, " 初始化完成，HP: ", health, " 状态: ", State.keys()[current_state])

	# 连接信号
	if detection_area and detection_radius_behavior:
		detection_area.body_entered.connect(_on_DetectionArea_body_entered)
		detection_area.body_exited.connect(_on_DetectionArea_body_exited)
	
	if attack_hitbox:
		attack_hitbox.monitoring = false

	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# 延迟配置导航代理
	call_deferred("_setup_navigation")
	last_position = global_position

func _setup_navigation():
	"""延迟配置导航代理 - 迷宫优化版"""
	if navigation_agent:
		navigation_agent.path_desired_distance = 5.0  # 更精确的路径跟踪
		navigation_agent.target_desired_distance = 20.0  # 目标距离
		navigation_agent.radius = 12.0  # 适合迷宫的半径
		navigation_agent.avoidance_enabled = true
		navigation_agent.max_speed = speed
		# 等待导航网格加载
		await get_tree().process_frame
		print(name, " 导航代理配置完成")

func _physics_process(delta):
	# 强制死亡检查：如果HP为负数或已死亡，立即进入死亡状态
	if health <= 0 and not is_dead:
		print(name, " 物理处理中检测到HP小于等于0(", health, ")，强制进入死亡状态")
		is_dead = true
		health = 0
		_enter_state(State.DEAD)
		return
	
	# 如果已死亡，停止所有处理
	if is_dead and current_state != State.DEAD:
		print(name, " 检测到已死亡但状态不对，强制进入死亡状态")
		_enter_state(State.DEAD)
		return
	
	# 检测卡住情况
	if current_state == State.CHASE:
		_check_if_stuck(delta)
	
	# 全局死亡检查：如果玩家死亡，立即停止所有行为
	if player_target and player_target.has_method("is_dead") and player_target.is_dead():
		if current_state != State.IDLE:
			print(name, " 检测到玩家死亡，立即停止行为")
			player_target = null
			_enter_state(State.IDLE)
			return
	
	# 状态机处理
	match current_state:
		State.IDLE:
			_idle_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.DEAD:
			velocity = Vector2.ZERO
	
	# 移动
	move_and_slide()
	
	# 更新位置记录
	last_position = global_position

func _check_if_stuck(delta):
	"""迷宫环境下的卡住检测"""
	if current_state != State.CHASE or not navigation_agent:
		stuck_timer = 0.0
		return
	
	var movement_distance = global_position.distance_to(last_position)
	var desired_movement = speed * delta * 0.3
	
	if movement_distance < desired_movement:
		stuck_timer += delta
		# 迷宫中可能经常需要绕路，延长检测时间
		if stuck_timer > 4.0:
			_handle_stuck_situation()
			stuck_timer = 0.0
	else:
		stuck_timer = max(0, stuck_timer - delta * 0.5)

func _handle_stuck_situation():
	"""迷宫环境下的卡住处理"""
	if player_target == null or not navigation_agent:
		return
	
	print(name, " 在迷宫中卡住，重新计算路径")
	
	# 强制刷新导航路径
	navigation_agent.target_position = player_target.global_position
	
	# 如果还是卡住，尝试临时目标点
	await get_tree().create_timer(0.5).timeout
	
	if navigation_agent.is_navigation_finished():
		# 尝试朝玩家方向的一个随机偏移点移动
		var to_player = global_position.direction_to(player_target.global_position)
		var perpendicular = Vector2(-to_player.y, to_player.x)
		var random_offset = perpendicular * randf_range(-80, 80)
		var intermediate_target = global_position + to_player * 50 + random_offset
		
		navigation_agent.target_position = intermediate_target
		print(name, " 设置临时目标点进行绕路")

# ============================================================================
# 优化的导航系统 - 移除瞬移式的防重叠
# ============================================================================
func _navigate_to_player():
	"""优化的A*导航 - 依靠碰撞层而非强制分离"""
	if not player_target or not navigation_agent:
		return
	
	var current_distance = global_position.distance_to(player_target.global_position)
	
	# 设置合理的停止距离，让导航系统自然处理
	var stop_distance = 25.0
	
	if current_distance > stop_distance:
		# 设置导航目标
		navigation_agent.target_position = player_target.global_position
		
		# 使用A*算法获取下一个路径点
		if not navigation_agent.is_navigation_finished():
			var next_path_position = navigation_agent.get_next_path_position()
			var direction = global_position.direction_to(next_path_position)
			
			# 平滑的速度控制
			var target_velocity = direction * speed
			
			# 距离很近时减速
			if current_distance < stop_distance * 2.0:
				var speed_factor = (current_distance - stop_distance) / stop_distance
				speed_factor = clamp(speed_factor, 0.3, 1.0)
				target_velocity *= speed_factor
			
			velocity = target_velocity
		else:
			velocity = Vector2.ZERO
	else:
		# 距离够近时自然停止
		velocity = Vector2.ZERO

func _enter_state(new_state: State):
	# 如果已经死了，强制进入死亡状态
	if is_dead and new_state != State.DEAD:
		print(name, " 已死亡，强制切换到死亡状态")
		current_state = State.DEAD
		_play_death_and_cleanup_setup()
		return
	
	# 防止重复进入死亡状态
	if new_state == State.DEAD and current_state == State.DEAD:
		print(name, " 已在死亡状态，跳过重复切换")
		return
	
	if current_state == new_state and new_state != State.ATTACK:
		return
	
	var old_state = current_state
	current_state = new_state
	print(name, " 状态切换: ", State.keys()[old_state], " -> ", State.keys()[new_state])

	match current_state:
		State.IDLE:
			_update_visual_animation("idle")
		State.CHASE:
			_update_visual_animation("walk")
		State.ATTACK:
			velocity = Vector2.ZERO
			if not is_attacking:
				is_attacking = true
				_perform_attack()
		State.DEAD:
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
	"""追逐状态逻辑 - 改进的持续追逐"""
	if not _validate_target():
		# 如果失去目标，根据追逐类型决定行为
		if chase_type == ChaseType.ENDLESS and is_in_endless_chase:
			time_since_lost_target += _delta
			if time_since_lost_target < lose_target_time:
				# 继续追逐到最后已知位置
				_navigate_to_last_known_position()
				print(name, " 无限追逐模式：追逐最后已知位置")
				return
			else:
				print(name, " 无限追逐超时，返回待机")
				is_in_endless_chase = false
				time_since_lost_target = 0.0
		
		_enter_state(State.IDLE)
		return
	
	# 更新玩家最后已知位置
	last_known_player_position = player_target.global_position
	time_since_lost_target = 0.0
	
	var distance_to_player = global_position.distance_to(player_target.global_position)
	_update_facing_direction()
	
	# 简化攻击距离判断 - 使用更稳定的检测
	var should_attack = distance_to_player <= attack_distance * 1.2 and can_attack
	
	if should_attack:
		print(name, " 进入攻击距离: 距离=", distance_to_player, " 攻击阈值=", attack_distance)
		_enter_state(State.ATTACK)
		return
	
	# 如果在攻击冷却中且距离合适，等待而不移动
	if distance_to_player <= attack_distance * 1.5 and not can_attack:
		velocity = Vector2.ZERO
		_update_visual_animation("idle")
		return
	
	# 正常追逐
	_navigate_to_player()
	_update_visual_animation("walk")

func _navigate_to_last_known_position():
	"""追逐到玩家最后已知位置"""
	if not navigation_agent:
		return
	
	var distance_to_last_known = global_position.distance_to(last_known_player_position)
	
	# 如果已经到达最后已知位置，停止追逐
	if distance_to_last_known <= 30.0:
		print(name, " 到达最后已知位置，停止追逐")
		is_in_endless_chase = false
		time_since_lost_target = 0.0
		_enter_state(State.IDLE)
		return
	
	# 导航到最后已知位置
	navigation_agent.target_position = last_known_player_position
	
	if not navigation_agent.is_navigation_finished():
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	_update_visual_animation("walk")

func _attack_state(_delta):
	"""攻击状态逻辑"""
	if not _validate_target():
		return
	
	var distance_to_player = global_position.distance_to(player_target.global_position)
	
	# 只有在玩家真的跑很远时才切换到追逐
	if distance_to_player > attack_distance * 4.0:
		print(name, " 玩家跑太远，切换到追逐")
		is_attacking = false
		can_attack = true
		_enter_state(State.CHASE)
		return
	
	# 攻击状态下保持静止
	velocity = Vector2.ZERO
	_update_facing_direction()

func _validate_target() -> bool:
	"""验证目标有效性"""
	if player_target == null or not is_instance_valid(player_target):
		_enter_state(State.IDLE)
		return false
	
	# 检查玩家是否已死亡
	if player_target.has_method("is_dead") and player_target.is_dead():
		print(name, " 玩家已死亡，停止追逐和攻击")
		player_target = null
		_enter_state(State.IDLE)
		return false
	
	return true

func _update_facing_direction():
	"""更新朝向"""
	if player_target:
		facing_direction_vector = global_position.direction_to(player_target.global_position).normalized()

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
	
	# 不检查距离限制，直接执行攻击
	print(name, " 跳过距离检查，直接攻击")
	
	# 配置攻击判定框
	_setup_attack_hitbox()
	
	# 等待攻击判定
	await get_tree().create_timer(0.3).timeout
	
	if not is_attacking:
		return
	
	# 执行攻击判定
	_execute_attack_check()
	
	# 攻击冷却
	await get_tree().create_timer(attack_cooldown).timeout
	
	_reset_attack_state()

func _setup_attack_hitbox():
	"""设置攻击判定框 - 支持四方向攻击"""
	if not attack_hitbox:
		return
	
	# 根据朝向确定攻击方向
	var attack_direction = Vector2.ZERO
	
	# 判断主要朝向（优先考虑水平方向）
	if abs(facing_direction_vector.x) > abs(facing_direction_vector.y):
		# 水平方向为主
		attack_direction = Vector2.RIGHT if facing_direction_vector.x > 0 else Vector2.LEFT
	else:
		# 垂直方向为主
		attack_direction = Vector2.DOWN if facing_direction_vector.y > 0 else Vector2.UP
	
	# 设置攻击判定框位置
	attack_hitbox.position = attack_direction * attack_hitbox_reach
	attack_hitbox.monitoring = true
	
	print(name, " 攻击方向: ", attack_direction, " 朝向: ", facing_direction_vector)

func _execute_attack_check():
	"""执行攻击检测 - 改进的2D攻击判定"""
	if not attack_hitbox:
		print("警告: 未找到 AttackHitbox 节点!")
		return
	
	# 攻击前再次验证目标（确保玩家没有在这段时间内死亡）
	if not _validate_target():
		attack_hitbox.monitoring = false
		return
	
	var hit_targets = attack_hitbox.get_overlapping_bodies()
	var hit_player = false
	
	for body in hit_targets:
		if body == player_target and body.has_method("take_damage"):
			# 最后一次检查玩家是否还活着
			if body.has_method("is_dead") and body.is_dead():
				print(name, " 玩家已死亡，取消攻击")
				break
				
			var attack_distance_check = global_position.distance_to(body.global_position)
			# 放宽攻击距离检测，特别是对角线情况
			if attack_distance_check <= attack_distance * 1.8:
				body.take_damage(attack_power)
				hit_player = true
				print(name, " 攻击命中，造成 ", attack_power, " 点伤害，距离: ", attack_distance_check)
				break
	
	# 如果hitbox没有检测到，但玩家在攻击范围内，也算命中（备用检测）
	if not hit_player and player_target:
		# 再次检查玩家是否死亡
		if player_target.has_method("is_dead") and player_target.is_dead():
			print(name, " 玩家已死亡，取消备用攻击检测")
		else:
			var distance_to_player = global_position.distance_to(player_target.global_position)
			if distance_to_player <= attack_distance * 1.5:
				if player_target.has_method("take_damage"):
					player_target.take_damage(attack_power)
					hit_player = true
					print(name, " 备用攻击检测命中，距离: ", distance_to_player)
	
	if not hit_player:
		print(name, " 攻击未命中")
	
	attack_hitbox.monitoring = false

func _reset_attack_state():
	"""重置攻击状态"""
	can_attack = true
	is_attacking = false
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	# 如果已经死了，直接进入死亡状态
	if is_dead:
		print(name, " 攻击结束时检测到已死亡，进入死亡状态")
		_enter_state(State.DEAD)
		return
	
	# 简单的攻击后处理
	if _validate_target():
		# 短暂等待后继续追逐
		await get_tree().create_timer(0.5).timeout
		if _validate_target() and not is_dead:  # 再次检查目标有效性和死亡状态
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
	"""接收玩家攻击 - 增强调试"""
	print(name, " 收到玩家攻击请求，当前状态: ", State.keys()[current_state], " HP: ", health, " is_dead: ", is_dead)
	
	if current_state == State.DEAD or is_dead:
		print(name, " 已死亡，忽略攻击")
		return 0
	
	var actual_damage = player_attack_power
	health -= actual_damage
	print(name, " 受到玩家攻击 ", actual_damage, " 点伤害, 剩余HP: ", health)
	
	_on_hit_by_player()
	
	# 修复：确保HP小于等于0时立即死亡
	if health <= 0 and not is_dead:
		print(name, " HP小于等于0(", health, ")，准备进入死亡状态")
		is_dead = true
		health = 0  # 确保HP不为负数
		_enter_state(State.DEAD)
	elif health > 0:
		print(name, " 还活着，继续战斗")
	
	return actual_damage

func _on_hit_by_player():
	"""受击反应"""
	print(name, " 被玩家击中")
	
	# 闪烁效果
	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if animated_sprite:
		animated_sprite.modulate = original_modulate

func take_damage(amount: int, _source_attack_power: int = 0):
	"""通用伤害接口"""
	if current_state == State.DEAD or is_dead:
		print(name, " 已死亡，忽略伤害")
		return
	
	health -= amount
	print(name, " 受到 ", amount, " 点伤害, 剩余HP: ", health)
	
	# 修复：HP小于等于0时立即死亡，不仅仅是等于0
	if health <= 0 and not is_dead:
		print(name, " HP小于等于0(", health, ")，进入死亡状态")
		is_dead = true
		health = 0  # 确保HP不会是负数
		_enter_state(State.DEAD)

# ============================================================================
# 死亡和清理
# ============================================================================
func _play_death_and_cleanup_setup():
	"""播放死亡动画并设置清理"""
	print(name, " 开始死亡流程，当前HP: ", health)
	
	velocity = Vector2.ZERO
	is_attacking = false
	can_attack = false
	
	# 立即禁用物理处理
	set_physics_process(false)
	
	# 清除目标引用
	player_target = null
	
	# 禁用碰撞检测
	var collision_shape = $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = true
	
	if detection_area:
		detection_area.monitoring = false
		detection_area.monitorable = false
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
	
	# 播放死亡动画
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		animated_sprite.flip_h = false
		print(name, " 播放死亡动画")
	else:
		print("错误: 'death' 动画未找到，直接清理")
		_handle_defeat_cleanup()

func _handle_defeat_cleanup():
	"""处理死亡后的清理 - 防止重复执行"""
	if not is_inside_tree():
		print(name, " 已经不在场景树中，跳过清理")
		return
	
	print(name, " 执行死亡清理")
	
	# 给玩家经验
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("gain_experience"):
		player_node.gain_experience(experience_drop)
		print("玩家获得经验: ", experience_drop)
	
	# 确保完全从场景中移除
	print(name, " 即将被销毁")
	queue_free()

# ============================================================================
# 信号回调
# ============================================================================
func _on_DetectionArea_body_entered(body):
	"""检测区域进入"""
	if body.is_in_group("player"):
		print(name, " 发现玩家: ", body.name)
		player_target = body
		last_known_player_position = body.global_position
		
		# 如果是无限追逐型敌人，激活无限追逐模式
		if chase_type == ChaseType.ENDLESS:
			is_in_endless_chase = true
			print(name, " 激活无限追逐模式")
		
		if current_state == State.IDLE:
			_update_facing_direction()
			_enter_state(State.CHASE)

func _on_DetectionArea_body_exited(body):
	"""检测区域离开 - 改进的追逐逻辑"""
	if body == player_target:
		print(name, " 玩家离开检测范围")
		
		# 如果是无限追逐型，不立即失去目标
		if chase_type == ChaseType.ENDLESS and is_in_endless_chase:
			print(name, " 无限追逐模式：继续追逐")
			# 不清除player_target，让追逐状态处理
			return
		
		# 普通敌人立即停止追逐
		player_target = null
		if current_state in [State.CHASE, State.ATTACK]:
			_enter_state(State.IDLE)

func _on_animation_finished():
	"""动画完成回调 - 修复复活问题"""
	print(name, " 动画完成: ", animated_sprite.animation, " 当前状态: ", State.keys()[current_state])
	
	if current_state == State.DEAD and animated_sprite.animation == "death":
		print(name, " 死亡动画完成，立即清理")
		_handle_defeat_cleanup()
	elif animated_sprite.animation == "attack_right":
		print(name, " 攻击动画完成")
		# 攻击动画完成后不重置状态，由攻击系统管理

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
