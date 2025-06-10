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

# --- 系统组件引用 ---
var inventory_system: InventorySystem
var weapon_system: WeaponSystem

# --- 向后兼容的信号 ---
signal inventory_changed  # 背包变化信号（向后兼容）


# ============================================================================
# 内置函数
# ============================================================================
func _ready():
	add_to_group("player")
	print("玩家节点已加入'player'组")
	
	# 动态创建和初始化系统组件
	_initialize_systems()
	
	# 连接动画完成信号，主要用于攻击和死亡动画后的状态切换
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# 连接系统信号（向后兼容）
	if inventory_system:
		inventory_system.inventory_changed.connect(_on_inventory_changed)
	if weapon_system:
		weapon_system.weapon_changed.connect(_on_weapon_changed)
	
	# 初始设置一次朝向对应的待机动画
	_update_idle_animation()
	
	# 初始化攻击力
	_recalculate_total_attacking_power()
	
	# 通知UI系统玩家已准备就绪
	call_deferred("_notify_ui_player_ready")

# ============================================================================
# 系统初始化
# ============================================================================
func _initialize_systems():
	"""动态创建和初始化系统组件"""
	# 创建背包系统
	inventory_system = InventorySystem.new()
	inventory_system.name = "InventorySystem"
	add_child(inventory_system)
	print("InventorySystem 创建完成")
	
	# 创建武器系统  
	weapon_system = WeaponSystem.new()
	weapon_system.name = "WeaponSystem"
	add_child(weapon_system)
	print("WeaponSystem 创建完成")

# ============================================================================
# 系统回调函数
# ============================================================================
func _on_inventory_changed():
	"""背包系统变化回调"""
	inventory_changed.emit()
	_update_inventory_ui()

func _on_weapon_changed(weapon: WeaponData):
	"""武器系统变化回调"""
	_recalculate_total_attacking_power()
	inventory_changed.emit()
	_update_inventory_ui()

func _handle_inventory_input():
	"""处理背包相关输入"""
	# 背包切换（I键）
	if Input.is_action_just_pressed("toggle_inventory"):
		print("按下I键切换背包")
		_toggle_inventory_panel()

func _physics_process(_delta: float) -> void:
	if current_state == PlayerState.DEATH:
		# 如果玩家已死亡，不执行任何操作
		# 死亡动画播放完毕后，可以通过 _on_animation_finished 处理后续逻辑
		return

	# 处理武器切换和背包输入
	if weapon_system:
		weapon_system.handle_weapon_input()
	_handle_inventory_input()

	# 1. 处理攻击输入 (添加输入验证)
	if Input.is_action_just_pressed("attack"): # "attack" 应该映射到 'J' 键
		# 验证攻击输入频率
		if not InputValidator or InputValidator.validate_attack_input():
			if current_state != PlayerState.ATTACK: # 避免在攻击时再次攻击
				_enter_state(PlayerState.ATTACK)
				return # 进入攻击状态后，本帧不处理移动

	# 2. 处理移动输入 (只有在非攻击状态下，添加输入验证)
	var input_direction := Vector2.ZERO
	if current_state != PlayerState.ATTACK:
		var raw_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# 验证和净化移动输入
		input_direction = InputValidator.validate_movement_input(raw_input)

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
	
	# 播放攻击音效
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_attack_sound()
	
	# 对所有命中的敌人造成伤害
	for enemy in hit_enemies:
		var damage_dealt = enemy.receive_player_attack(get_total_attack())
		print("玩家攻击命中: ", enemy.name, " 造成伤害: ", damage_dealt)
		
		# 添加命中特效和音效
		_create_hit_effect(enemy.global_position)
		if audio_manager:
			audio_manager.play_enemy_hit_sound()
	
	if hit_enemies.size() == 0:
		print("玩家攻击未命中任何敌人")
	
	attack_hitbox.monitoring = false

		# 新增：创建命中特效
func _create_hit_effect(hit_position: Vector2):
	print("在位置 ", hit_position, " 创建命中特效")
	
	# 添加粒子特效
	var effects_manager = get_node_or_null("/root/EffectsManager")
	if effects_manager:
		effects_manager.play_hit_effect(hit_position)

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
	if inventory_system:
		inventory_system.consume_hp_bean()
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
	var weapon_attack = weapon_system.get_weapon_attack_power() if weapon_system else 0
	print("重新计算攻击力：HP基础攻击力(", hp_based_attack, ") + 武器攻击力(", weapon_attack, ") = ", get_total_attack())

func get_total_attack() -> int:
	var hp_based_attack = int(current_hp / 5.0)
	var weapon_attack = weapon_system.get_weapon_attack_power() if weapon_system else 0
	return hp_based_attack + weapon_attack


# 你需要添加或确保有 gain_experience() 函数
var current_exp: int = 0
var exp_to_next_level: int = 50
func gain_experience(amount: int):
	current_exp += amount
	
	# 显示经验值获得通知
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		notification_manager.show_pickup("✨ 获得经验值 +" + str(amount), 2.5)
	
	if current_exp >= exp_to_next_level:
		level_up()
	update_ui()

func level_up():
	current_exp -= exp_to_next_level
	exp_to_next_level += 25
	max_hp += 20
	current_hp = max_hp
	base_attack += 2
	
	# 显示升级通知
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		notification_manager.show_achievement("🆙 升级了！HP和攻击力提升", 4.0)
	
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
	
	# 立即变红表示受击，增强视觉反馈
	animated_sprite.modulate = Color.RED
	
	# 增加受击反馈持续时间，让效果更明显
	await get_tree().create_timer(0.2).timeout
	
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
	print("玩家已死亡 - 显示Game Over页面！")
	
	# 更新胜利管理器统计
	var victory_manager = get_node_or_null("/root/VictoryManager")
	if victory_manager:
		victory_manager.increment_deaths()
	
	# 播放死亡音效
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_player_hurt_sound()
	
	# 播放死亡特效
	var effects_manager = get_node_or_null("/root/EffectsManager")
	if effects_manager:
		effects_manager.create_screen_flash(Color.RED, 0.5)
	
	# 停止玩家的所有物理处理
	set_physics_process(false)
	
	# 停止动画在最后一帧
	if animated_sprite:
		animated_sprite.stop()
	
	# 寻找并显示Game Over页面
	var game_over_screen = _find_or_create_game_over_screen()
	if game_over_screen:
		game_over_screen.show_game_over()
	else:
		print("错误：无法找到或创建Game Over页面")
		# 备用方案：延迟后重新加载场景
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()

func _find_or_create_game_over_screen():
	"""查找或创建Game Over页面"""
	# 首先尝试在当前场景中查找Game Over页面
	var current_scene = get_tree().current_scene
	if current_scene:
		var game_over_node = current_scene.find_child("GameOverScreen", true, false)
		if game_over_node:
			print("找到现有的Game Over页面")
			return game_over_node
		
		# 尝试在CanvasLayer中查找
		var canvas_layers = current_scene.find_children("CanvasLayer", "", true, false)
		for canvas_layer in canvas_layers:
			var game_over_in_canvas = canvas_layer.find_child("GameOverScreen", true, false)
			if game_over_in_canvas:
				print("在CanvasLayer中找到Game Over页面")
				return game_over_in_canvas
	
	# 如果没有找到，尝试动态创建
	print("未找到Game Over页面，尝试动态加载")
	var game_over_scene_path = "res://scenes/game_over.tscn"
	
	if FileAccess.file_exists(game_over_scene_path):
		var game_over_scene = load(game_over_scene_path)
		if game_over_scene:
			var game_over_instance = game_over_scene.instantiate()
			
			# 添加到最适合的父节点
			var target_parent = _find_best_ui_parent()
			if target_parent:
				target_parent.add_child(game_over_instance)
				print("成功创建并添加Game Over页面到:", target_parent.name)
				return game_over_instance
			else:
				print("错误：找不到合适的父节点来添加Game Over页面")
				game_over_instance.queue_free()
	
	print("无法加载Game Over场景文件:", game_over_scene_path)
	return null

func _find_best_ui_parent():
	"""找到最适合添加UI的父节点"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	
	# 优先使用现有的CanvasLayer
	var canvas_layers = current_scene.find_children("CanvasLayer", "", true, false)
	for canvas_layer in canvas_layers:
		# 避免添加到小地图的CanvasLayer
		if canvas_layer.name != "MiniMapCanvas" and not canvas_layer.name.to_lower().contains("minimap"):
			print("使用现有的CanvasLayer:", canvas_layer.name)
			return canvas_layer
	
	# 如果没有合适的CanvasLayer，创建一个新的
	var new_canvas_layer = CanvasLayer.new()
	new_canvas_layer.name = "GameOverCanvasLayer"
	new_canvas_layer.layer = 100  # 确保在最上层
	current_scene.add_child(new_canvas_layer)
	print("创建新的CanvasLayer用于Game Over页面")
	return new_canvas_layer



# ============================================================================
# 钥匙系统
# ============================================================================
func add_key(key_type: String):
	if inventory_system:
		inventory_system.add_key(key_type)
		# 更新界面显示
		_update_inventory_ui()
		# 通知背包UI更新
		call_deferred("_notify_inventory_changed")

func has_key(key_type: String) -> bool:
	if inventory_system:
		return inventory_system.has_key(key_type)
	return false

func use_key(key_type: String) -> bool:
	if inventory_system:
		var success = inventory_system.use_key(key_type)
		if success:
			_update_inventory_ui()
			# 通知背包UI更新
			call_deferred("_notify_inventory_changed")
		return success
	else:
		print("背包系统未找到，无法使用钥匙")
		return false

func get_keys() -> Array[String]:
	if inventory_system:
		return inventory_system.get_keys()
	return []

# ============================================================================
# 修改界面更新函数，添加武器信息显示
# ============================================================================
func _update_inventory_ui():
	print("=== 玩家状态更新 ===")
	print("当前HP：", current_hp, " 最大HP：", max_hp)
	var current_weapon = weapon_system.get_current_weapon() if weapon_system else null
	print("当前武器：", current_weapon.weapon_name if current_weapon else "无", "（攻击力：", current_weapon.attack_power if current_weapon else 0, "）")
	print("拥有武器数量：", weapon_system.get_weapon_count() if weapon_system else 0)
	print("拥有钥匙：", inventory_system.get_keys() if inventory_system else [])
	print("已消费HP豆数量：", inventory_system.get_hp_beans_consumed() if inventory_system else 0)
	print("总攻击力：", get_total_attack())
	print("=====================")




# ============================================================================
# 向后兼容的武器接口函数（委托给武器系统）
# ============================================================================
func try_equip_weapon(weapon_id: String, weapon_name: String, weapon_attack: int) -> bool:
	"""尝试装备新武器（向后兼容接口）"""
	if weapon_system:
		return weapon_system.try_equip_weapon(weapon_id, weapon_name, weapon_attack)
	else:
		return false
	
func switch_to_next_weapon():
	"""切换到下一把武器（向后兼容接口）"""
	if weapon_system:
		weapon_system.switch_to_next_weapon()

func switch_to_previous_weapon():
	"""切换到上一把武器（向后兼容接口）"""
	if weapon_system:
		weapon_system.switch_to_previous_weapon()

func switch_to_weapon_by_index(index: int):
	"""切换到指定索引的武器（向后兼容接口）"""
	if weapon_system:
		weapon_system.switch_to_weapon_by_index(index)

func get_available_weapons() -> Array[WeaponData]:
	"""获取所有可用武器（向后兼容接口）"""
	if weapon_system:
		return weapon_system.get_available_weapons()
	return []

func get_current_weapon() -> WeaponData:
	"""获取当前武器（向后兼容接口）"""
	if weapon_system:
		return weapon_system.get_current_weapon()
	return null

func get_weapon_count() -> int:
	"""获取武器数量（向后兼容接口）"""
	if weapon_system:
		return weapon_system.get_weapon_count()
	return 0

# ============================================================================
# UI通知系统
# ============================================================================
func _notify_inventory_changed():
	"""向后兼容的通知函数"""
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
