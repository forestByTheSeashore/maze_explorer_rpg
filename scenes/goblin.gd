# goblin_static.gd - 静态守卫型敌人 (StaticBody2D版本)
extends StaticBody2D

# --- 导出变量 ---
@export var max_hp: int = 60
@export var attack_power: int = 15
@export var detection_range: float = 80.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 2.0
@export var experience_drop: int = 20

# --- 节点引用 ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $Area2D
@onready var attack_hitbox: Area2D = $AttackHitbox

# --- 内部变量 ---
var current_hp: int
var player_target: CharacterBody2D = null
var can_attack: bool = true
var is_attacking: bool = false
var facing_direction: Vector2 = Vector2.RIGHT
var is_player_in_detection: bool = false

func _ready():
	add_to_group("enemies")
	current_hp = max_hp
	
	# 连接信号
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.play("idle_right")
	
	print(name, " StaticGoblin初始化完成，HP:", current_hp, " 攻击力:", attack_power)

# StaticBody2D使用_process而不是_physics_process
func _process(_delta: float):
	# 检查玩家状态
	if player_target and player_target.has_method("is_dead") and player_target.is_dead():
		_reset_target()
		return
	
	# 主动攻击逻辑
	if player_target and is_player_in_detection and can_attack and not is_attacking:
		var distance_to_player = global_position.distance_to(player_target.global_position)
		
		if distance_to_player <= attack_range:
			_perform_attack()
	
	# 更新朝向
	if player_target:
		_update_facing_direction()

func _update_facing_direction():
	"""更新朝向玩家的方向"""
	if not player_target or not animated_sprite:
		return
	
	var direction_to_player = global_position.direction_to(player_target.global_position)
	facing_direction = direction_to_player
	
	# 只更新动画翻转
	if not is_attacking:
		animated_sprite.flip_h = facing_direction.x < 0
		if not animated_sprite.is_playing() or animated_sprite.animation != "idle_right":
			animated_sprite.play("idle_right")

func _perform_attack():
	"""执行攻击"""
	if is_attacking or not can_attack or not player_target:
		return
	
	is_attacking = true
	can_attack = false
	
	print(name, " 开始攻击玩家")
	
	# 播放攻击动画
	if animated_sprite and animated_sprite.sprite_frames.has_animation("attack_right"):
		animated_sprite.play("attack_right")
		animated_sprite.flip_h = facing_direction.x < 0
	
	# 设置攻击判定框
	_setup_attack_hitbox()
	
	# 创建攻击时序
	_handle_attack_timing()

func _handle_attack_timing():
	"""处理攻击时序"""
	# 等待攻击判定时机
	await get_tree().create_timer(0.3).timeout
	
	if not is_attacking:
		return
	
	# 执行攻击判定
	_execute_attack()
	
	# 攻击冷却
	await get_tree().create_timer(attack_cooldown).timeout
	
	# 重置攻击状态
	_reset_attack_state()

func _setup_attack_hitbox():
	"""设置攻击判定框"""
	if not attack_hitbox:
		return
	
	var attack_offset = facing_direction.normalized() * 20.0
	attack_hitbox.position = attack_offset
	attack_hitbox.monitoring = true

func _execute_attack():
	"""执行攻击判定"""
	if not attack_hitbox or not player_target:
		return
	
	if player_target.has_method("is_dead") and player_target.is_dead():
		attack_hitbox.monitoring = false
		return
	
	var hit_targets = attack_hitbox.get_overlapping_bodies()
	var hit_player = false
	
	for body in hit_targets:
		if body == player_target and body.has_method("take_damage"):
			var distance = global_position.distance_to(body.global_position)
			if distance <= attack_range * 1.2:
				body.take_damage(attack_power)
				hit_player = true
				print(name, " 攻击命中玩家，造成", attack_power, "点伤害")
				break
	
	# 备用攻击检测
	if not hit_player and player_target:
		var distance = global_position.distance_to(player_target.global_position)
		if distance <= attack_range and player_target.has_method("take_damage"):
			if not (player_target.has_method("is_dead") and player_target.is_dead()):
				player_target.take_damage(attack_power)
				hit_player = true
				print(name, " 备用攻击检测命中")
	
	if not hit_player:
		print(name, " 攻击未命中")
	
	attack_hitbox.monitoring = false

func _reset_attack_state():
	"""重置攻击状态"""
	is_attacking = false
	can_attack = true
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	if animated_sprite:
		animated_sprite.play("idle_right")
		if player_target:
			animated_sprite.flip_h = facing_direction.x < 0

# ============================================================================
# 伤害系统
# ============================================================================
func receive_player_attack(player_attack_power: int) -> int:
	"""接收玩家攻击"""
	if current_hp <= 0:
		return 0
	
	var actual_damage = player_attack_power
	current_hp -= actual_damage
	print(name, " 受到玩家攻击", actual_damage, "点伤害，剩余HP:", current_hp)
	
	_play_hit_feedback()
	
	if current_hp <= 0:
		_handle_death()
	else:
		# 受击后反击
		if player_target and can_attack and not is_attacking:
			var distance = global_position.distance_to(player_target.global_position)
			if distance <= attack_range * 1.5:
				print(name, " 受击后反击")
				call_deferred("_perform_attack")
	
	return actual_damage

func _play_hit_feedback():
	"""播放受击反馈效果"""
	if not animated_sprite:
		return
	
	var original_modulate = animated_sprite.modulate
	animated_sprite.modulate = Color.RED
	
	await get_tree().create_timer(0.15).timeout
	
	if animated_sprite:
		animated_sprite.modulate = original_modulate

func take_damage(amount: int):
	"""通用伤害接口"""
	if current_hp <= 0:
		return
	
	current_hp -= amount
	print(name, " 受到", amount, "点伤害，剩余HP:", current_hp)
	
	_play_hit_feedback()
	
	if current_hp <= 0:
		_handle_death()

func _handle_death():
	"""处理死亡"""
	print(name, " StaticGoblin死亡")
	
	is_attacking = false
	can_attack = false
	
	# 禁用碰撞
	var collision_shape = $CollisionShape2D
	if collision_shape:
		collision_shape.disabled = true
	
	# 停用检测区域
	if detection_area:
		detection_area.monitoring = false
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
	
	# 播放死亡动画
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	else:
		_cleanup()

func _cleanup():
	"""清理并给玩家经验"""
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("gain_experience"):
		player_node.gain_experience(experience_drop)
		print("玩家获得经验:", experience_drop)
	
	queue_free()

# ============================================================================
# 检测系统
# ============================================================================
func _on_detection_area_body_entered(body):
	"""玩家进入检测范围"""
	if body.is_in_group("player"):
		print(name, " 检测到玩家进入范围:", body.name)
		player_target = body
		is_player_in_detection = true
		_update_facing_direction()

func _on_detection_area_body_exited(body):
	"""玩家离开检测范围"""
	if body == player_target:
		print(name, " 玩家离开检测范围")
		is_player_in_detection = false
		# 保持警戒状态一段时间
		await get_tree().create_timer(3.0).timeout
		if not is_player_in_detection:
			_reset_target()

func _reset_target():
	"""重置目标"""
	player_target = null
	is_player_in_detection = false
	
	facing_direction = Vector2.RIGHT
	if animated_sprite and not is_attacking:
		animated_sprite.flip_h = false
		animated_sprite.play("idle_right")

# ============================================================================
# 动画回调
# ============================================================================
func _on_animation_finished():
	"""动画完成回调"""
	if not animated_sprite:
		return
		
	if animated_sprite.animation == "death":
		_cleanup()
	elif animated_sprite.animation == "attack_right":
		# 攻击动画完成，状态由_handle_attack_timing管理
		pass