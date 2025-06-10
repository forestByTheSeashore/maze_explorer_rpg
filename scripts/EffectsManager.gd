extends Node

## 特效管理器
## 负责游戏中的粒子效果和视觉特效

# 特效预制体池
var effect_pool: Dictionary = {}
var active_effects: Array[Node] = []

# 特效配置
var effect_configs: Dictionary = {
	"hit_effect": {
		"lifetime": 0.5,
		"color": Color.RED,
		"particle_count": 20,
		"spread": 45.0
	},
	"pickup_effect": {
		"lifetime": 1.0,
		"color": Color.YELLOW,
		"particle_count": 15,
		"spread": 360.0
	},
	"level_complete_effect": {
		"lifetime": 2.0,
		"color": Color.GOLD,
		"particle_count": 50,
		"spread": 360.0
	},
	"door_open_effect": {
		"lifetime": 1.5,
		"color": Color.CYAN,
		"particle_count": 30,
		"spread": 90.0
	},
	"enemy_death_effect": {
		"lifetime": 1.0,
		"color": Color.DARK_RED,
		"particle_count": 25,
		"spread": 180.0
	}
}

func _ready():
	add_to_group("effects_manager")
	_initialize_effect_pools()
	print("EffectsManager: 初始化特效系统")

func _initialize_effect_pools():
	print("EffectsManager: 初始化特效池")
	
	# 为每种特效类型创建对象池
	for effect_name in effect_configs.keys():
		effect_pool[effect_name] = []
		# 预创建一些特效对象
		for i in range(5):
			var effect = _create_particle_effect(effect_name)
			effect.visible = false
			effect_pool[effect_name].append(effect)

func _create_particle_effect(effect_name: String) -> Node2D:
	"""创建粒子特效节点"""
	var effect_node = Node2D.new()
	effect_node.name = effect_name + "_effect"
	
	# 创建CPUParticles2D
	var particles = CPUParticles2D.new()
	particles.name = "Particles"
	effect_node.add_child(particles)
	
	var config = effect_configs.get(effect_name, {})
	
	# 配置粒子系统
	particles.amount = config.get("particle_count", 20)
	particles.lifetime = config.get("lifetime", 1.0)
	
	# 形状和方向
	particles.direction = Vector2(0, -1)
	particles.spread = config.get("spread", 45.0)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	
	# 外观
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = config.get("color", Color.WHITE)
	
	# 物理
	particles.gravity = Vector2(0, 98)
	particles.linear_accel_min = -20.0
	particles.linear_accel_max = 20.0
	
	# 透明度变化
	particles.color_ramp = _create_alpha_ramp()
	
	# 添加到场景但保持隐藏
	get_tree().current_scene.add_child(effect_node)
	
	return effect_node

func _create_alpha_ramp() -> Gradient:
	"""创建透明度渐变"""
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))  # 开始完全不透明
	gradient.add_point(0.7, Color(1, 1, 1, 0.8))  # 中期稍微透明
	gradient.add_point(1.0, Color(1, 1, 1, 0))   # 结束完全透明
	return gradient

## 播放特效
## @param effect_name: 特效名称
## @param position: 世界坐标位置
## @param direction: 特效方向（可选）
func play_effect(effect_name: String, position: Vector2, direction: Vector2 = Vector2.UP):
	# 安全检查：确保当前场景有效
	if not get_tree() or not get_tree().current_scene:
		print("EffectsManager: 场景无效，跳过特效播放 - ", effect_name)
		return
		
	var effect = _get_effect_from_pool(effect_name)
	if not effect:
		print("EffectsManager: 无法获取特效 - ", effect_name)
		return
	
	# 设置位置和方向
	effect.global_position = position
	effect.visible = true
	
	var particles = effect.get_node("Particles") as CPUParticles2D
	if particles:
		particles.direction = direction
		particles.restart()
		particles.emitting = true
	
	# 清理活跃特效列表中的无效引用
	_clean_active_effects()
	
	# 添加到活跃特效列表
	active_effects.append(effect)
	
	# 设置自动清理
	var config = effect_configs.get(effect_name, {})
	var lifetime = config.get("lifetime", 1.0)
	
	var timer = get_tree().create_timer(lifetime + 0.5)  # 额外0.5秒确保粒子完全消失
	timer.timeout.connect(func(): _return_effect_to_pool(effect_name, effect))
	
	print("EffectsManager: 播放特效 - ", effect_name, " 位置: ", position)

func _get_effect_from_pool(effect_name: String) -> Node2D:
	"""从对象池获取特效"""
	if effect_name not in effect_pool:
		print("EffectsManager: 未知的特效类型 - ", effect_name)
		return null
	
	var pool = effect_pool[effect_name]
	
	# 清理池中无效的对象引用
	_clean_pool(pool)
	
	# 查找空闲的特效对象
	for effect in pool:
		if is_instance_valid(effect) and not effect.visible:
			return effect
	
	# 如果没有空闲对象，创建新的
	var new_effect = _create_particle_effect(effect_name)
	if new_effect:
		pool.append(new_effect)
	return new_effect

func _return_effect_to_pool(effect_name: String, effect: Node2D):
	"""将特效返回到对象池"""
	if not is_instance_valid(effect):
		return
	
	effect.visible = false
	var particles = effect.get_node("Particles") as CPUParticles2D
	if particles:
		particles.emitting = false
	
	# 从活跃列表中移除
	active_effects.erase(effect)
	
	print("EffectsManager: 特效返回池 - ", effect_name)

func _clean_pool(pool: Array):
	"""清理对象池中的无效引用"""
	var valid_effects = []
	for effect in pool:
		if is_instance_valid(effect):
			valid_effects.append(effect)
	pool.clear()
	pool.append_array(valid_effects)

func _clean_active_effects():
	"""清理活跃特效列表中的无效引用"""
	var valid_effects = []
	for effect in active_effects:
		if is_instance_valid(effect):
			valid_effects.append(effect)
	active_effects.clear()
	active_effects.append_array(valid_effects)

## 便捷方法 - 预定义特效
func play_hit_effect(position: Vector2):
	var particles = _create_hit_particles()
	particles.global_position = position
	get_tree().current_scene.add_child(particles)
	
	# 播放粒子
	particles.restart()
	particles.emitting = true
	
	# 自动清理
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): 
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _create_hit_particles() -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.name = "HitEffect"
	
	# 配置粒子
	particles.amount = 20
	particles.lifetime = 0.5
	particles.direction = Vector2(0, -1)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.color = Color.RED
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.gravity = Vector2(0, 98)
	
	return particles

func play_pickup_effect(position: Vector2):
	var particles = _create_pickup_particles()
	particles.global_position = position
	get_tree().current_scene.add_child(particles)
	
	particles.restart()
	particles.emitting = true
	
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func(): 
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _create_pickup_particles() -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.name = "PickupEffect"
	
	particles.amount = 15
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 360.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.color = Color.YELLOW
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.2
	particles.gravity = Vector2(0, -20)  # 向上飘
	
	return particles

func play_level_complete_effect(position: Vector2):
	"""播放关卡完成特效"""
	print("EffectsManager: 请求播放关卡完成特效，位置: ", position)
	
	# 检查特效配置是否存在
	if "level_complete_effect" not in effect_configs:
		print("EffectsManager: 关卡完成特效配置不存在，使用备用特效")
		create_explosion_effect(position, 80.0, Color.GOLD)
		return
	
	# 安全播放特效
	play_effect("level_complete_effect", position)

func play_door_open_effect(position: Vector2):
	"""播放门开启特效"""
	play_effect("door_open_effect", position)

func play_enemy_death_effect(position: Vector2):
	"""播放敌人死亡特效"""
	play_effect("enemy_death_effect", position)

## 高级特效
func create_explosion_effect(position: Vector2, radius: float = 100.0, color: Color = Color.ORANGE):
	"""创建爆炸特效"""
	var explosion = Node2D.new()
	explosion.name = "ExplosionEffect"
	explosion.global_position = position
	
	# 创建多层粒子效果
	for i in range(3):
		var particles = CPUParticles2D.new()
		particles.name = "ExplosionLayer" + str(i)
		explosion.add_child(particles)
		
		# 配置爆炸粒子
		particles.amount = 30 + i * 10
		particles.lifetime = 0.5 + i * 0.2
		particles.direction = Vector2(0, -1)
		particles.spread = 360.0
		particles.initial_velocity_min = radius * 0.5
		particles.initial_velocity_max = radius * (1.0 + i * 0.3)
		
		# 颜色变化
		var explosion_color = color
		explosion_color.a = 1.0 - i * 0.3
		particles.color = explosion_color
		
		particles.scale_amount_min = 0.3 + i * 0.2
		particles.scale_amount_max = 1.0 + i * 0.5
		particles.gravity = Vector2(0, 50)
		particles.color_ramp = _create_alpha_ramp()
		
		particles.restart()
		particles.emitting = true
	
	# 添加到场景
	get_tree().current_scene.add_child(explosion)
	
	# 自动清理
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if is_instance_valid(explosion):
			explosion.queue_free()
	)
	
	print("EffectsManager: 创建爆炸特效，位置: ", position, " 半径: ", radius)

func create_heal_effect(position: Vector2):
	"""创建治疗特效"""
	var heal_effect = Node2D.new()
	heal_effect.name = "HealEffect"
	heal_effect.global_position = position
	
	var particles = CPUParticles2D.new()
	heal_effect.add_child(particles)
	
	# 配置治疗粒子（向上飘浮的绿色粒子）
	particles.amount = 20
	particles.lifetime = 1.5
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.color = Color.GREEN
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.2
	particles.gravity = Vector2(0, -20)  # 负重力，向上飘
	particles.color_ramp = _create_alpha_ramp()
	
	particles.restart()
	particles.emitting = true
	
	get_tree().current_scene.add_child(heal_effect)
	
	# 自动清理
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if is_instance_valid(heal_effect):
			heal_effect.queue_free()
	)

func create_trail_effect(start_pos: Vector2, end_pos: Vector2, color: Color = Color.WHITE):
	"""创建轨迹特效"""
	var trail = Node2D.new()
	trail.name = "TrailEffect"
	trail.global_position = start_pos
	
	var particles = CPUParticles2D.new()
	trail.add_child(particles)
	
	# 计算方向
	var direction = (end_pos - start_pos).normalized()
	
	# 配置轨迹粒子
	particles.amount = 15
	particles.lifetime = 0.3
	particles.direction = direction
	particles.spread = 15.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 150.0
	particles.color = color
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.8
	particles.color_ramp = _create_alpha_ramp()
	
	particles.restart()
	particles.emitting = true
	
	get_tree().current_scene.add_child(trail)
	
	# 自动清理
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): 
		if is_instance_valid(trail):
			trail.queue_free()
	)

## 屏幕特效
func create_screen_flash(color: Color = Color.WHITE, duration: float = 0.2):
	print("EffectsManager: Creating screen flash effect")
	
	# 确保当前场景存在
	if not get_tree() or not get_tree().current_scene:
		print("EffectsManager: No current scene, skipping screen flash")
		return
	
	var overlay = ColorRect.new()
	overlay.name = "ScreenFlashOverlay"
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var canvas = CanvasLayer.new()
	canvas.name = "ScreenFlashCanvas"
	canvas.layer = 1000
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS  # 确保在暂停时也能工作
	canvas.add_child(overlay)
	get_tree().current_scene.add_child(canvas)
	
	# 使用timer作为备用清理机制
	var cleanup_timer = get_tree().create_timer(duration + 1.0)  # 额外1秒确保清理
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(canvas):
			print("EffectsManager: Timer cleanup of screen flash")
			canvas.queue_free()
	)
	
	# 使用tween进行淡出动画
	var tween = create_tween()
	if tween:
		tween.tween_property(overlay, "modulate:a", 0.0, duration)
		tween.tween_callback(func():
			if is_instance_valid(canvas):
				print("EffectsManager: Tween cleanup of screen flash")
				canvas.queue_free()
		)
	else:
		# 如果tween创建失败，直接使用timer清理
		print("EffectsManager: Tween creation failed, using timer for cleanup")
	
	print("EffectsManager: Screen flash effect created with duration: ", duration)

func create_damage_number(position: Vector2, damage: int, color: Color = Color.RED):
	var label = Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.global_position = position
	label.z_index = 100
	
	get_tree().current_scene.add_child(label)
	
	# 动画
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y - 50, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)

## 清理所有特效
func clear_all_effects():
	"""清理所有活跃的特效"""
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	active_effects.clear()
	
	# 清理屏幕闪烁效果
	clear_screen_flash_effects()
	
	print("EffectsManager: 已清理所有特效")

func clear_screen_flash_effects():
	"""清理所有屏幕闪烁效果"""
	if not get_tree() or not get_tree().current_scene:
		return
	
	var current_scene = get_tree().current_scene
	var canvas_layers = current_scene.find_children("ScreenFlashCanvas", "", true, false)
	
	for canvas in canvas_layers:
		if is_instance_valid(canvas):
			print("EffectsManager: Removing residual screen flash canvas: ", canvas.name)
			canvas.queue_free()
	
	# 也检查任何可能遗留的ColorRect
	var flash_overlays = current_scene.find_children("ScreenFlashOverlay", "", true, false)
	for overlay in flash_overlays:
		if is_instance_valid(overlay):
			print("EffectsManager: Removing residual screen flash overlay: ", overlay.name)
			overlay.queue_free()

## 获取特效统计
func get_active_effects_count() -> int:
	return active_effects.size()

func get_pool_size(effect_name: String) -> int:
	return effect_pool.get(effect_name, []).size() 
