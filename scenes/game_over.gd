extends Control

# Game Over 页面管理器
# 当玩家死亡时显示，提供存档或不存档返回主菜单的选项

# 按钮引用
@onready var save_and_return_button = $VBoxContainer/SaveAndReturnButton
@onready var return_without_save_button = $VBoxContainer/ReturnWithoutSaveButton
@onready var status_label = $VBoxContainer/StatusLabel

# 场景路径常量
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# 管理器引用
var save_manager
var game_manager

func _ready():
	# 确保Game Over页面初始时是隐藏的
	hide()
	
	# 设置process_mode确保在游戏暂停时UI仍能工作
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 获取管理器引用
	save_manager = get_node_or_null("/root/SaveManager")
	game_manager = get_node_or_null("/root/GameManager")
	
	if not save_manager:
		print("GameOver: 警告 - 找不到SaveManager")
	if not game_manager:
		print("GameOver: 警告 - 找不到GameManager")
	
	# 连接按钮信号
	if save_and_return_button:
		save_and_return_button.pressed.connect(_on_save_and_return_pressed)
	if return_without_save_button:
		return_without_save_button.pressed.connect(_on_return_without_save_pressed)
	
	# 连接SaveManager信号
	if save_manager and save_manager.has_signal("save_completed"):
		save_manager.save_completed.connect(_on_save_completed)
	
	# 初始化状态
	_show_status("选择你的操作", Color.WHITE)
	
	print("GameOver: 初始化完成")

func _on_save_and_return_pressed():
	print("GameOver: 玩家选择存档并返回主菜单")
	
	# 显示状态
	_show_status("正在保存游戏进度...", Color.YELLOW)
	
	# 禁用按钮防止重复点击
	save_and_return_button.disabled = true
	return_without_save_button.disabled = true
	
	if not save_manager:
		_show_status("错误：找不到存档管理器", Color.RED)
		_enable_buttons()
		return
	
	# 获取当前关卡信息
	var current_scene = get_tree().current_scene
	if not current_scene:
		_show_status("错误：无法获取当前关卡信息", Color.RED)
		_enable_buttons()
		return
	
	var current_level_name = current_scene.scene_file_path.get_file().get_basename()
	print("GameOver: 当前关卡名称：", current_level_name)
	
	# 获取玩家数据（如果玩家还存在的话）
	var player_data = {}
	var player = get_tree().get_first_node_in_group("player")
	if player and "max_hp" in player:
		# 保存玩家的最大生命值等信息，但当前生命值设为最大值（重生后满血）
		var current_exp = 0
		var exp_to_next = 50
		
		# 安全获取经验值
		if "current_exp" in player:
			current_exp = player.current_exp
		if "exp_to_next_level" in player:
			exp_to_next = player.exp_to_next_level
			
		player_data = {
			"hp": player.max_hp,  # 重生时满血
			"max_hp": player.max_hp,
			"exp": current_exp,
			"exp_to_next": exp_to_next,
			"position": Vector2.ZERO  # 重生在起始位置
		}
		print("GameOver: 获取到玩家数据：", player_data)
	else:
		print("GameOver: 未找到玩家数据，使用默认值")
		player_data = {
			"hp": 100,
			"max_hp": 100,
			"exp": 0,
			"exp_to_next": 50,
			"position": Vector2.ZERO
		}
	
	# 执行保存操作
	var save_success = save_manager.save_progress(current_level_name, player_data)
	
	if not save_success:
		_show_status("保存失败，但仍将返回主菜单", Color.ORANGE)
		# 即使保存失败，也延迟一下再返回主菜单
		await get_tree().create_timer(2.0).timeout
		_return_to_main_menu()

func _on_return_without_save_pressed():
	print("GameOver: 玩家选择不存档直接返回主菜单")
	
	_show_status("返回主菜单中...", Color.CYAN)
	
	# 禁用按钮
	save_and_return_button.disabled = true
	return_without_save_button.disabled = true
	
	# 短暂延迟后返回主菜单
	await get_tree().create_timer(1.0).timeout
	_return_to_main_menu()

func _on_save_completed(success: bool, message: String):
	print("GameOver: 保存完成回调 - 成功：", success, "，消息：", message)
	
	if success:
		_show_status("保存成功！正在返回主菜单...", Color.GREEN)
	else:
		_show_status("保存失败：" + message + "，但仍将返回主菜单", Color.ORANGE)
	
	# 延迟后返回主菜单
	await get_tree().create_timer(2.0).timeout
	_return_to_main_menu()

func _return_to_main_menu():
	print("GameOver: 执行返回主菜单")
	
	# 确保游戏不再暂停
	get_tree().paused = false
	
	# 使用GameManager切换场景，如果没有则直接切换
	if game_manager and game_manager.has_method("change_scene"):
		game_manager.change_scene(MAIN_MENU_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _show_status(text: String, color: Color = Color.WHITE):
	if status_label:
		status_label.text = text
		status_label.modulate = color
		print("GameOver 状态：", text)

func _enable_buttons():
	"""重新启用按钮"""
	if save_and_return_button:
		save_and_return_button.disabled = false
	if return_without_save_button:
		return_without_save_button.disabled = false

# 显示Game Over页面的公共方法
func show_game_over():
	print("GameOver: 显示Game Over页面")
	
	# 暂停游戏
	get_tree().paused = true
	
	# 显示页面
	show()
	
	# 重置按钮状态
	_enable_buttons()
	
	# 重置状态文本
	_show_status("选择你的操作", Color.WHITE) 