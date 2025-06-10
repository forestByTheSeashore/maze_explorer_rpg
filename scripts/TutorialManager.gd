extends Node

## 教程管理器
## 为新玩家提供游戏引导和说明

signal tutorial_step_completed(step_name: String)
signal tutorial_finished()

# 教程步骤定义
enum TutorialStep {
	WELCOME,
	MOVEMENT,
	INVENTORY,
	COMBAT,
	DOORS_AND_KEYS,
	MINIMAP,
	SAVING,
	COMPLETED
}

var current_step: TutorialStep = TutorialStep.WELCOME
var tutorial_enabled: bool = true
var tutorial_overlay: Control = null
var step_completed: Array[bool] = []

func _ready():
	add_to_group("tutorial_manager")
	# 初始化完成状态数组
	step_completed.resize(TutorialStep.size())
	step_completed.fill(false)
	
	# 检查玩家是否是新手
	_check_first_time_player()

func _check_first_time_player():
	var config = ConfigFile.new()
	var config_path = "user://tutorial_config.cfg"
	
	if config.load(config_path) == OK:
		tutorial_enabled = not config.get_value("tutorial", "completed", false)
	
	if tutorial_enabled:
		print("TutorialManager: 检测到新玩家，启动教程")
		call_deferred("start_tutorial")

func start_tutorial():
	print("TutorialManager: 开始教程")
	current_step = TutorialStep.WELCOME
	_create_tutorial_overlay()
	_show_tutorial_step(current_step)

func _create_tutorial_overlay():
	if tutorial_overlay:
		return
	
	# 创建教程UI覆盖层
	tutorial_overlay = Control.new()
	tutorial_overlay.name = "TutorialOverlay"
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 创建教程框
	var tutorial_panel = Panel.new()
	tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tutorial_panel.size = Vector2(800, 150)
	tutorial_panel.position.y = -180
	tutorial_panel.position.x = (get_viewport().get_visible_rect().size.x - 800) / 2
	
	# 添加教程文本
	var tutorial_label = RichTextLabel.new()
	tutorial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_label.add_theme_font_size_override("normal_font_size", 18)
	tutorial_label.fit_content = true
	tutorial_label.scroll_active = false
	tutorial_panel.add_child(tutorial_label)
	
	# 添加关闭按钮
	var close_button = Button.new()
	close_button.text = "跳过教程"
	close_button.size = Vector2(100, 30)
	close_button.position = Vector2(tutorial_panel.size.x - 110, 10)
	close_button.pressed.connect(_skip_tutorial)
	tutorial_panel.add_child(close_button)
	
	# 添加下一步按钮
	var next_button = Button.new()
	next_button.text = "下一步"
	next_button.size = Vector2(80, 30)
	next_button.position = Vector2(tutorial_panel.size.x - 200, 10)
	next_button.pressed.connect(_next_tutorial_step)
	tutorial_panel.add_child(next_button)
	
	tutorial_overlay.add_child(tutorial_panel)
	
	# 添加到场景
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(tutorial_overlay)
		tutorial_overlay.z_index = 1000  # 确保在最上层

func _show_tutorial_step(step: TutorialStep):
	if not tutorial_overlay:
		return
	
	var label = tutorial_overlay.get_node_or_null("Panel/RichTextLabel")
	if not label:
		return
	
	var tutorial_texts = {
		TutorialStep.WELCOME: "[center][b]欢迎来到森林海岸迷宫探险![/b][/center]\n这是一个探索迷宫、收集物品、对抗敌人的冒险游戏。\n让我们开始教程，学习基本操作！",
		
		TutorialStep.MOVEMENT: "[center][b]移动控制[/b][/center]\n使用 [b]WASD[/b] 键或[b]方向键[/b]移动你的角色。\n试试现在移动一下！",
		
		TutorialStep.INVENTORY: "[center][b]背包系统[/b][/center]\n按 [b]I[/b] 键打开背包查看物品。\n使用 [b]1-4[/b] 数字键快速切换武器。\n按 [b]Tab[/b] 键循环切换武器。",
		
		TutorialStep.COMBAT: "[center][b]战斗系统[/b][/center]\n按 [b]J[/b] 键攻击敌人。\n你的攻击力必须大于敌人的攻击力才能击败他们。\n收集更强的武器来提升攻击力！",
		
		TutorialStep.DOORS_AND_KEYS: "[center][b]门和钥匙[/b][/center]\n红色的门需要钥匙才能打开。\n靠近门并按 [b]F[/b] 键互动。\n收集钥匙并找到出口门来完成关卡！",
		
		TutorialStep.MINIMAP: "[center][b]小地图和路径提示[/b][/center]\n按 [b]M[/b] 键切换小地图显示。\n按 [b]F1[/b] 显示到钥匙的路径。\n按 [b]F2[/b] 显示到出口门的路径。",
		
		TutorialStep.SAVING: "[center][b]保存游戏[/b][/center]\n按 [b]ESC[/b] 键打开暂停菜单进行保存/加载。\n按 [b]F5[/b] 快速保存，按 [b]F6[/b] 快速加载。\n你的进度会被安全加密保存！",
		
		TutorialStep.COMPLETED: "[center][b]教程完成！[/b][/center]\n恭喜！你已经掌握了所有基本操作。\n现在去探索迷宫，寻找钥匙，击败敌人吧！\n祝你游戏愉快！"
	}
	
	label.text = tutorial_texts.get(step, "教程文本未找到")
	print("TutorialManager: 显示教程步骤 ", TutorialStep.keys()[step])

func _next_tutorial_step():
	step_completed[current_step] = true
	tutorial_step_completed.emit(TutorialStep.keys()[current_step])
	
	if current_step < TutorialStep.COMPLETED:
		current_step += 1
		_show_tutorial_step(current_step)
		
		if current_step == TutorialStep.COMPLETED:
			# 延迟关闭教程
			await get_tree().create_timer(3.0).timeout
			_finish_tutorial()
	else:
		_finish_tutorial()

func _skip_tutorial():
	print("TutorialManager: 玩家跳过教程")
	_finish_tutorial()

func _finish_tutorial():
	print("TutorialManager: 教程结束")
	tutorial_finished.emit()
	
	# 保存教程完成状态
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", true)
	config.save("user://tutorial_config.cfg")
	
	# 移除教程UI
	if tutorial_overlay:
		tutorial_overlay.queue_free()
		tutorial_overlay = null
	
	tutorial_enabled = false

func reset_tutorial():
	"""重置教程状态，用于测试或重新观看"""
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", false)
	config.save("user://tutorial_config.cfg")
	tutorial_enabled = true
	step_completed.fill(false)
	current_step = TutorialStep.WELCOME
	print("TutorialManager: 教程状态已重置")

func is_tutorial_active() -> bool:
	return tutorial_enabled and tutorial_overlay != null

# 供其他系统调用的函数
func mark_step_completed(step: TutorialStep):
	if step < TutorialStep.size():
		step_completed[step] = true

func get_tutorial_progress() -> float:
	var completed_count = 0
	for completed in step_completed:
		if completed:
			completed_count += 1
	return float(completed_count) / float(TutorialStep.size()) 