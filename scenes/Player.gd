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
var max_hp: int = 100 # 你之前的代码是500，如果GDD有定义初始值，以GDD为准
var facing_direction_vector: Vector2 = Vector2.DOWN # 用于记录玩家的朝向，攻击和待机时使用

# --- 新增：物品系统 ---
var keys: Array[String] = []  # 玩家拥有的钥匙列表
var has_sword: bool = false   # 是否拥有剑
var hp_beans_consumed: int = 0  # 已消费的HP豆数量

# --- 武器系统变量（替换现有的武器相关变量） ---
var available_weapons: Array[WeaponData] = []  # 玩家已获得的武器列表
var current_weapon_index: int = 0              # 当前装备的武器索引
var current_weapon: WeaponData                 # 当前装备的武器

# --- 新增：UI通知系统 ---
signal inventory_changed  # 背包变化信号

# --- 新增：输入防重复变量 ---
var last_input_time: float = 0.0
var input_cooldown: float = 0.2  # 输入冷却时间（秒）


# ============================================================================
# 内置函数
# ============================================================================
func _ready():
	add_to_group("player")
	print("玩家节点已加入'player'组")
	
	# 连接动画完成信号，主要用于攻击和死亡动画后的状态切换
	animated_sprite.animation_finished.connect(_on_animation_finished)
	# 初始设置一次朝向对应的待机动画
	_update_idle_animation()

	# 初始化武器系统
	_initialize_weapon_system()
	
	# 初始设置一次朝向对应的待机动画
	_update_idle_animation()
	
	# 初始化攻击力
	_recalculate_total_attacking_power()
	
	# 通知UI系统玩家已准备就绪
	call_deferred("_notify_ui_player_ready")

func _physics_process(_delta: float) -> void:
	if current_state == PlayerState.DEATH:
		# 如果玩家已死亡，不执行任何操作
		# 死亡动画播放完毕后，可以通过 _on_animation_finished 处理后续逻辑
		return

	# 新增：处理武器切换和背包输入
	_handle_weapon_input()

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
	
	# 处理敌人分离 - 攻击状态时不干扰
	if current_state != PlayerState.ATTACK:
		_apply_enemy_separation()
	
	move_and_slide()

func _apply_enemy_separation():
	"""强化的敌人分离系统 - 解决黏附问题"""
	if current_state == PlayerState.DEATH:
		return
		
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		
		# 扩大检测范围，提前分离
		if distance < 30.0 and distance > 0.1:
			var push_direction = (global_position - enemy.global_position).normalized()
			var enemy_relative = enemy.global_position - global_position
			
			# 基础分离力
			var push_force = 600.0
			
			# 特殊情况处理
			if enemy_relative.y < -10:  # 敌人在玩家上方
				push_force = 1000.0
				# 强制向侧面逃脱
				if abs(push_direction.x) < 0.5:
					push_direction.x = 1.0 if randf() > 0.5 else -1.0
					push_direction.y = 0.3  # 稍微向下
					push_direction = push_direction.normalized()
				print("玩家被压制，强力逃脱")
			elif distance < 15.0:  # 非常接近时
				push_force = 1200.0
				print("距离过近，强力分离")
			
			# 应用分离力
			velocity += push_direction * push_force * get_physics_process_delta_time()
			
			# 额外的位置纠正 - 直接调整位置
			if distance < 12.0:
				var correction = push_direction * (12.0 - distance)
				global_position += correction
				print("执行位置纠正，距离:", distance)

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
	
	# 减少攻击判定延迟，更快响应
	await get_tree().create_timer(0.1).timeout
	
	# 检测攻击命中
	var overlapping_bodies = attack_hitbox.get_overlapping_bodies()
	var hit_enemies = []
	
	for body in overlapping_bodies:
		if body.is_in_group("enemies") and body.has_method("receive_player_attack"):
			hit_enemies.append(body)
	
	# 如果直接检测失败，尝试扩大范围检测
	if hit_enemies.size() == 0:
		var enemies_in_scene = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies_in_scene:
			if not is_instance_valid(enemy):
				continue
			var distance = global_position.distance_to(enemy.global_position)
			# 扩大攻击范围检测
			if distance <= 35.0:  # 增加攻击距离容差
				var direction_to_enemy = global_position.direction_to(enemy.global_position)
				var dot_product = facing_direction_vector.dot(direction_to_enemy)
				# 检查是否在攻击方向上（允许45度角误差）
				if dot_product > 0.5:  # 约60度范围
					hit_enemies.append(enemy)
					print("扩大范围检测命中: ", enemy.name, " 距离: ", distance)
	
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
func _create_hit_effect(hit_position: Vector2):
	# 这里可以添加粒子效果、音效等
	print("在位置 ", hit_position, " 创建命中特效")

# 你需要添加或确保有 get_total_attack() 函数
var base_attack: int = 20 # 示例基础攻击力
var current_weapon_attack: int = 5 # 来自武器的攻击力加成 (后续武器系统实现)


# ============================================================================
# 修改increase_hp_from_bean函数，确保武器系统兼容
# ============================================================================
func update_ui():
	var ui = get_tree().get_first_node_in_group("ui_manager")
	if ui:
		ui.update_player_status(current_hp, max_hp, current_exp, exp_to_next_level)

func increase_hp_from_bean(amount: int):
	current_hp += amount
	max_hp += amount
	hp_beans_consumed += 1
	_recalculate_total_attacking_power()
	update_ui()
	_update_inventory_ui()
	_notify_inventory_changed()

	

# ============================================================================
# 修改攻击力计算系统
# ============================================================================
func _recalculate_total_attacking_power():
	# 基于当前HP的攻击力
	var hp_based_attack = int(current_hp / 5.0)
	var weapon_attack = current_weapon.attack_power if current_weapon else 0
	print("重新计算攻击力：HP基础攻击力(", hp_based_attack, ") + 武器攻击力(", weapon_attack, ") = ", get_total_attack())

func get_total_attack() -> int:
	var hp_based_attack = int(current_hp / 5.0)
	var weapon_attack = current_weapon.attack_power if current_weapon else 0
	return hp_based_attack + weapon_attack


# 你需要添加或确保有 gain_experience() 函数
var current_exp: int = 0
var exp_to_next_level: int = 50
func gain_experience(amount: int):
	current_exp += amount
	if current_exp >= exp_to_next_level:
		level_up()
	update_ui()

func level_up():
	current_exp -= exp_to_next_level
	exp_to_next_level += 25
	max_hp += 20
	current_hp = max_hp
	base_attack += 2
	update_ui()
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

func _play_hit_feedback():
	"""播放受击反馈效果"""
	if not animated_sprite:
		return
	
	# 保存原始颜色
	var original_modulate = animated_sprite.modulate
	
	# 变红表示受击
	animated_sprite.modulate = Color.RED
	
	# 短暂闪烁效果
	await get_tree().create_timer(0.15).timeout
	
	# 确保节点仍然存在再恢复颜色
	if animated_sprite:
		animated_sprite.modulate = original_modulate
	
	print("玩家受击反馈效果播放完毕")

func _on_animation_finished():
	# print("Animation finished: ", animated_sprite.animation) # 调试用
	if current_state == PlayerState.ATTACK:
		# 攻击动画播放完毕后，立即执行一次强制分离，然后根据输入决定状态
		_apply_post_attack_separation()
		
		var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_direction.length_squared() > 0:
			_enter_state(PlayerState.WALK)
		else:
			_enter_state(PlayerState.IDLE)
	elif current_state == PlayerState.DEATH and animated_sprite.animation == "death":
		# 死亡动画播放完毕
		_handle_game_over_logic()

func _apply_post_attack_separation():
	"""攻击后的强制分离 - 避免攻击完成后被黏住"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		
		if distance < 20.0 and distance > 0.1:
			var push_direction = (global_position - enemy.global_position).normalized()
			
			# 攻击后强力推开，确保不被黏住
			var push_distance = 25.0
			var collision = move_and_collide(push_direction * push_distance)
			
			if collision:
				# 如果直接推开遇到障碍，尝试侧面逃脱
				var perpendicular = Vector2(-push_direction.y, push_direction.x)
				move_and_collide(perpendicular * 15.0)
			
			print("攻击后强制分离，距离:", distance)

# ============================================================================
# 玩家行为
# ============================================================================
func take_damage(amount: int):
	if current_state == PlayerState.DEATH: # 如果已死亡，不再受伤
		return

	current_hp -= amount
	current_hp = max(0, current_hp)
	update_ui()
	# 这里可以发出信号更新UI: emit_signal("hp_updated", current_hp, max_hp)

	# 播放受击反馈效果
	_play_hit_feedback()

	if current_hp == 0:
		_enter_state(PlayerState.DEATH)
	else:
		# 如果没死，可以播放受击动画或音效
		print("玩家受到攻击，剩余HP: ", current_hp)

func heal(amount: int):
	if current_state == PlayerState.DEATH: # 如果已死亡，无法治疗
		return
	current_hp += amount
	current_hp = min(current_hp, max_hp)
	update_ui()
	# 这里可以发出信号更新UI: emit_signal("hp_updated", current_hp, max_hp)

func _handle_game_over_logic():
	print("玩家已死亡 - 游戏结束处理！")
	print("关卡失败！")
	
	# 可以在这里添加更多游戏结束逻辑：
	# 1. 显示游戏结束画面
	# 2. 停止背景音乐，播放失败音效
	# 3. 显示重试按钮
	# 4. 记录失败统计等
	
	# 示例：延迟重新加载关卡
	await get_tree().create_timer(2.0).timeout
	print("准备重新开始关卡...")
	# get_tree().reload_current_scene()  # 取消注释以启用自动重启
	
	# 或者显示游戏结束画面等
	# animated_sprite.stop() # 停在死亡动画的最后一帧
	# set_physics_process(false) # 彻底停止玩家活动



# ============================================================================
# 钥匙系统
# ============================================================================
func add_key(key_type: String):
	if key_type not in keys:
		keys.append(key_type)
		print("玩家获得钥匙：", key_type)
		# 更新界面显示
		_update_inventory_ui()
		# 通知背包UI更新
		call_deferred("_notify_inventory_changed")
	else:
		print("玩家已经拥有钥匙：", key_type)

func has_key(key_type: String) -> bool:
	var result = key_type in keys
	print("检查钥匙 '", key_type, "'：", "有" if result else "没有")
	return result

func use_key(key_type: String) -> bool:
	if has_key(key_type):
		keys.erase(key_type)
		print("玩家使用了钥匙：", key_type)
		_update_inventory_ui()
		# 通知背包UI更新
		call_deferred("_notify_inventory_changed")
		return true
	else:
		print("玩家没有钥匙：", key_type, "，无法使用")
		return false

func get_keys() -> Array[String]:
	return keys.duplicate()

# ============================================================================
# 修改界面更新函数，添加武器信息显示
# ============================================================================
func _update_inventory_ui():
	print("=== 玩家状态更新 ===")
	print("当前HP：", current_hp, " 最大HP：", max_hp)
	print("当前武器：", current_weapon.weapon_name if current_weapon else "无", "（攻击力：", current_weapon.attack_power if current_weapon else 0, "）")
	print("拥有武器数量：", available_weapons.size())
	print("拥有钥匙：", keys)
	print("已消费HP豆数量：", hp_beans_consumed)
	print("总攻击力：", get_total_attack())
	print("=====================")




func _initialize_weapon_system():
	# 确保武器数组为空
	available_weapons.clear()
	
	# 创建基础武器
	var basic_weapon = WeaponData.new()
	basic_weapon.weapon_id = "basic_sword"
	basic_weapon.weapon_name = "Basic Sword"
	basic_weapon.attack_power = 5
	basic_weapon.weapon_description = "基础武器"
	
	available_weapons.append(basic_weapon)
	current_weapon_index = 0
	current_weapon = basic_weapon
	
	print("武器系统初始化完成，初始武器：", basic_weapon.weapon_name, "，武器总数：", available_weapons.size())

# ============================================================================
# 武器获取系统
# ============================================================================
func try_equip_weapon(weapon_id: String, weapon_name: String, weapon_attack: int) -> bool:
	# 检查是否已经拥有这把武器
	for weapon in available_weapons:
		if weapon.weapon_id == weapon_id:
			print("已经拥有武器：", weapon_name)
			return false
	
	# 创建新武器数据
	var new_weapon = WeaponData.new()
	new_weapon.weapon_id = weapon_id
	new_weapon.weapon_name = weapon_name
	new_weapon.attack_power = weapon_attack
	new_weapon.weapon_description = "从地图中获得的武器"
	
	# 将新武器添加到武器库
	available_weapons.append(new_weapon)
	
	# 检查新武器是否比当前武器更强
	if weapon_attack > current_weapon.attack_power:
		# 自动切换到更强的武器
		current_weapon_index = available_weapons.size() - 1
		current_weapon = new_weapon
		print("自动装备更强的武器：", weapon_name, "（攻击力：", weapon_attack, "）")
	else:
		print("获得新武器：", weapon_name, "（攻击力：", weapon_attack, "），但保持当前装备")
	
	_recalculate_total_attacking_power()
	_update_inventory_ui()
	
	# 确保立即通知UI更新
	call_deferred("_notify_inventory_changed")
	
	return true

# ============================================================================
# 武器切换系统
# ============================================================================
func switch_to_next_weapon():
	if available_weapons.size() <= 1:
		print("只有一把武器，无法切换")
		return
	
	var old_index = current_weapon_index
	current_weapon_index = (current_weapon_index + 1) % available_weapons.size()
	current_weapon = available_weapons[current_weapon_index]
	
	print("切换武器: 从索引", old_index, "到索引", current_weapon_index)
	print("切换武器到：", current_weapon.weapon_name, "（攻击力：", current_weapon.attack_power, "）")
	print("当前武器总数：", available_weapons.size())
	_recalculate_total_attacking_power()
	_update_inventory_ui()
	
	# 立即通知UI更新
	call_deferred("_notify_inventory_changed")

func switch_to_previous_weapon():
	if available_weapons.size() <= 1:
		print("只有一把武器，无法切换")
		return
	
	current_weapon_index = (current_weapon_index - 1 + available_weapons.size()) % available_weapons.size()
	current_weapon = available_weapons[current_weapon_index]
	
	print("切换武器到：", current_weapon.weapon_name, "（攻击力：", current_weapon.attack_power, "）")
	_recalculate_total_attacking_power()
	_update_inventory_ui()
	
	# 立即通知UI更新
	call_deferred("_notify_inventory_changed")

func switch_to_weapon_by_index(index: int):
	if index >= 0 and index < available_weapons.size():
		print("切换武器到索引：", index, "当前索引：", current_weapon_index)
		current_weapon_index = index
		current_weapon = available_weapons[index]
		
		print("切换武器到：", current_weapon.weapon_name, "（攻击力：", current_weapon.attack_power, "）")
		_recalculate_total_attacking_power()
		_update_inventory_ui()
		
		# 只有非UI触发的切换才发送信号，避免循环
		var ui_manager = get_tree().get_first_node_in_group("ui_manager")
		var inventory_panel = ui_manager.get_node("InventoryPanel") if ui_manager else null
		if not inventory_panel or not inventory_panel.is_updating_from_ui:
			call_deferred("_notify_inventory_changed")
	else:
		print("无效的武器索引：", index, "可用武器数量：", available_weapons.size())

# ============================================================================
# 新增：武器输入处理
# ============================================================================
func _handle_weapon_input():
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Tab键切换武器（检测Tab和Shift+Tab）
	if Input.is_action_just_pressed("ui_focus_next") and not Input.is_key_pressed(KEY_SHIFT):
		if current_time - last_input_time > input_cooldown:
			print("按下Tab键切换到下一个武器")
			switch_to_next_weapon()
			last_input_time = current_time
	elif Input.is_action_just_pressed("ui_focus_prev") or (Input.is_action_just_pressed("ui_focus_next") and Input.is_key_pressed(KEY_SHIFT)):
		if current_time - last_input_time > input_cooldown:
			print("按下Shift+Tab键切换到上一个武器")
			switch_to_previous_weapon()
			last_input_time = current_time
	
	# E和Q键武器切换
	elif Input.is_action_just_pressed("weapon_next"):
		if current_time - last_input_time > input_cooldown:
			print("按下E键切换武器")
			switch_to_next_weapon()
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_previous"):
		if current_time - last_input_time > input_cooldown:
			print("按下Q键切换武器")
			switch_to_previous_weapon()
			last_input_time = current_time
	
	# 数字键快速切换武器（1-4键）
	if Input.is_action_just_pressed("weapon_1"):
		if current_time - last_input_time > input_cooldown:
			print("按下数字键1切换武器")
			switch_to_weapon_by_index(0)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_2"):
		if current_time - last_input_time > input_cooldown:
			print("按下数字键2切换武器")
			switch_to_weapon_by_index(1)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_3"):
		if current_time - last_input_time > input_cooldown:
			print("按下数字键3切换武器")
			switch_to_weapon_by_index(2)
			last_input_time = current_time
	elif Input.is_action_just_pressed("weapon_4"):
		if current_time - last_input_time > input_cooldown:
			print("按下数字键4切换武器")
			switch_to_weapon_by_index(3)
			last_input_time = current_time
	
	# 背包切换（I键）
	if Input.is_action_just_pressed("toggle_inventory"):
		print("按下I键切换背包")
		_toggle_inventory_panel()

# ============================================================================
# 武器信息获取函数（供UI使用）
# ============================================================================
func get_available_weapons() -> Array[WeaponData]:
	return available_weapons.duplicate()

func get_current_weapon() -> WeaponData:
	return current_weapon

func get_weapon_count() -> int:
	return available_weapons.size()

# ============================================================================
# UI通知系统
# ============================================================================
func _notify_inventory_changed():
	inventory_changed.emit()

func _toggle_inventory_panel():
	# 这个函数会被UI系统调用
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("toggle_inventory"):
		ui_manager.toggle_inventory()
	else:
		print("UI Manager未找到，无法切换背包面板")

# ============================================================================
# 新增：通知UI玩家已准备就绪
func _notify_ui_player_ready():
	print("玩家准备就绪，通知UI系统")
	# 立即发送一次背包变化信号，确保UI连接
	_notify_inventory_changed()
	
	# 通知UIManager更新玩家状态
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("_try_connect_player"):
		ui_manager._try_connect_player()
		print("已通知UIManager重新连接玩家")

# ============================================================================
# 新增：玩家攻击状态检测
# ============================================================================
func is_attacking() -> bool:
	"""返回玩家是否正在攻击状态，供敌人脚本调用"""
	return current_state == PlayerState.ATTACK

func is_dead() -> bool:
	"""返回玩家是否已死亡，供敌人脚本调用"""
	return current_state == PlayerState.DEATH