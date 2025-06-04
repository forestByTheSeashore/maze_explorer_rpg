# UIManager.gd - 游戏UI总管理器
extends CanvasLayer

@onready var inventory_panel: Control = $StatusBar/InventoryPanel
@onready var hp_bar = $StatusBar/LeftSection/BarsContainer/HPContainer/HPBar
@onready var exp_bar = $StatusBar/LeftSection/BarsContainer/EXPContainer/EXPBar

# 动画相关变量
var _last_max_hp: float = 100.0
var _hp_animation_tween: Tween = null

# 玩家连接管理
var player_reference: Node = null
var connection_retry_timer: float = 0.0
var connection_retry_interval: float = 1.0

func _ready():
	add_to_group("ui_manager")
	print("UIManager 初始化完成，初始 max_hp = ", _last_max_hp)
	
	# 尝试连接玩家
	_try_connect_player()

func _process(delta: float):
	# 如果没有玩家引用，定期尝试重新连接
	if not player_reference:
		connection_retry_timer += delta
		if connection_retry_timer >= connection_retry_interval:
			connection_retry_timer = 0.0
			_try_connect_player()

func _try_connect_player():
	# 查找玩家
	player_reference = get_tree().get_first_node_in_group("player")
	if player_reference:
		print("UIManager: 成功找到玩家引用")
		# 立即更新一次玩家状态
		_update_player_status()
	else:
		print("UIManager: 警告 - 未找到玩家引用，将在稍后重试")

func _update_player_status():
	if not player_reference:
		return
	
	# 获取玩家当前状态
	var hp = player_reference.current_hp if "current_hp" in player_reference else 100
	var max_hp = player_reference.max_hp if "max_hp" in player_reference else 100
	var exp = player_reference.current_exp if "current_exp" in player_reference else 0
	var exp_to_next = player_reference.exp_to_next_level if "exp_to_next_level" in player_reference else 50
	
	update_player_status(hp, max_hp, exp, exp_to_next)

func toggle_inventory():
	if inventory_panel:
		inventory_panel.toggle_visibility()

func _input(event):
	# ESC键关闭背包
	if event.is_action_pressed("ui_cancel") and inventory_panel and inventory_panel.visible:
		inventory_panel.hide_inventory()
		get_viewport().set_input_as_handled()

func update_player_status(hp, max_hp, exp, exp_to_next_level):
	print("--- UIManager Update ---")
	print("Received: hp = ", hp, ", max_hp = ", max_hp)
	print("Last max_hp = ", _last_max_hp)
	
	# 检查是否需要播放HP上限增加的动画
	if max_hp > _last_max_hp:
		print("检测到HP上限增加！从 ", _last_max_hp, " 增加到 ", max_hp)
		_play_hp_increase_animation(hp, max_hp)
	else:
		print("HP上限未增加，直接更新值")
		# 直接设置值
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	# 设置经验值
	exp_bar.max_value = exp_to_next_level
	exp_bar.value = exp
	
	# 强制更新
	hp_bar.queue_redraw()
	exp_bar.queue_redraw()
	
	# 更新上次的max_hp值
	_last_max_hp = max_hp
	
	# 再次确认值
	print("After setting: HPBar value = ", hp_bar.value, ", max_value = ", hp_bar.max_value)
	print("EXPBar value = ", exp_bar.value, ", max_value = ", exp_bar.max_value)
	print("------------------------")

func _play_hp_increase_animation(new_hp: float, new_max_hp: float):
	print("开始播放HP增加动画")
	
	# 如果已经有动画在播放，先停止它
	if _hp_animation_tween and _hp_animation_tween.is_valid():
		print("停止之前的动画")
		_hp_animation_tween.kill()
	
	# 创建新的动画
	_hp_animation_tween = create_tween()
	_hp_animation_tween.set_parallel(true)  # 允许动画并行执行
	
	# 让HP条闪烁（更明显的效果）
	_hp_animation_tween.tween_property(hp_bar, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.3)
	_hp_animation_tween.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), 0.3).set_delay(0.3)
	
	# 添加缩放效果
	_hp_animation_tween.tween_property(hp_bar, "scale", Vector2(1.1, 1.1), 0.3)
	_hp_animation_tween.tween_property(hp_bar, "scale", Vector2(1, 1), 0.3).set_delay(0.3)
	
	# 更新值
	_hp_animation_tween.tween_callback(func():
		print("更新HP值：", new_hp, "/", new_max_hp)
		hp_bar.max_value = new_max_hp
		hp_bar.value = new_hp
		hp_bar.queue_redraw()
	).set_delay(0.1)
	
	print("动画设置完成")
