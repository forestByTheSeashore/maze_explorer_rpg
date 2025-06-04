extends Control

# 添加 GameManager 引用 - 使用更安全的获取方式
var game_manager
var save_manager

# 按钮引用
@onready var resume_button = $VBoxContainer/ResumeButton
@onready var save_button = $VBoxContainer/SaveButton
@onready var load_button = $VBoxContainer/LoadButton
# @onready var settings_button = $VBoxContainer/SettingsButton # 已删除
@onready var main_menu_button = $VBoxContainer/MainMenuButton
@onready var quit_button = $VBoxContainer/QuitButton

# 状态显示标签
@onready var status_label = $VBoxContainer/StatusLabel

# 场景路径常量
# const SETTINGS_SCENE_PATH = "res://scenes/settings.tscn" # 不再需要，注释掉或删除
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# 加载设置场景资源 # 不再需要，注释掉或删除
# const SettingsScene = preload(SETTINGS_SCENE_PATH)

func _ready():
	print("暂停菜单: 开始初始化...")
	
	# 安全获取管理器引用
	game_manager = get_node_or_null("/root/GameManager")
	save_manager = get_node_or_null("/root/SaveManager")
	
	if not game_manager:
		print("警告: 找不到GameManager")
	if not save_manager:
		print("警告: 找不到SaveManager")
	
	# 连接按钮信号
	if resume_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_button_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	
	# 连接SaveManager信号 - 延迟执行
	call_deferred("_connect_save_manager_signals")
	
	# 确保暂停菜单在游戏暂停时显示
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 延迟更新存档信息显示
	call_deferred("_update_save_info")
	
	print("暂停菜单: 初始化完成")

func _connect_save_manager_signals():
	if save_manager and save_manager.has_signal("save_completed"):
		if not save_manager.save_completed.is_connected(_on_save_completed):
			save_manager.save_completed.connect(_on_save_completed)
		if not save_manager.load_completed.is_connected(_on_load_completed):
			save_manager.load_completed.connect(_on_load_completed)
		print("暂停菜单: SaveManager信号已连接")

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC键
		if visible:
			_on_resume_button_pressed()
		else:
			show()
		# 阻止事件继续传播给其他节点
		get_viewport().set_input_as_handled()

func _on_resume_button_pressed():
	# 继续游戏
	print("暂停菜单: Resume按钮被点击!")
	print("暂停菜单: 当前暂停状态:", get_tree().paused)
	print("暂停菜单: 当前可见状态:", visible)
	
	hide()
	get_tree().paused = false
	
	print("暂停菜单: 已隐藏暂停菜单，已取消暂停")
	print("暂停菜单: 新的暂停状态:", get_tree().paused)

func _on_save_button_pressed():
	print("暂停菜单: 保存按钮被点击")
	_show_status("正在保存游戏...", Color.YELLOW)
	
	# 禁用保存按钮防止重复点击
	save_button.disabled = true
	
	# 执行快速保存
	var success = save_manager.quick_save()
	
	# 如果快速保存失败，立即显示错误
	if not success:
		_show_status("保存失败!", Color.RED)
		save_button.disabled = false

func _on_load_button_pressed():
	print("暂停菜单: 加载按钮被点击")
	
	# 检查是否有存档
	if not save_manager.has_save():
		_show_status("没有找到存档文件!", Color.RED)
		return
	
	_show_status("正在加载游戏...", Color.YELLOW)
	
	# 禁用读档按钮
	load_button.disabled = true
	
	# 读取存档数据
	var save_data = save_manager.load_progress()
	
	if save_data.is_empty():
		_show_status("加载失败!", Color.RED)
		load_button.disabled = false
		return
	
	# 如果有有效的关卡数据，切换到该关卡
	var level_name = save_data.get("current_level", "")
	if level_name != "":
		_show_status("加载成功! 正在切换关卡...", Color.GREEN)
		
		# 延迟切换场景，让用户看到成功消息
		await get_tree().create_timer(1.0).timeout
		
		# 恢复游戏状态并切换场景
		get_tree().paused = false
		
		# 尝试切换到保存的关卡
		var scene_path = "res://levels/" + level_name + ".tscn"
		if FileAccess.file_exists(scene_path):
			game_manager.change_scene(scene_path)
		else:
			# 如果找不到确切的场景文件，尝试一些常见的变体
			var alternative_paths = [
				"res://scenes/" + level_name + ".tscn",
				"res://levels/" + level_name.to_lower() + ".tscn",
				"res://scenes/" + level_name.to_lower() + ".tscn"
			]
			
			var found_scene = false
			for path in alternative_paths:
				if FileAccess.file_exists(path):
					game_manager.change_scene(path)
					found_scene = true
					break
			
			if not found_scene:
				_show_status("找不到关卡文件: " + level_name, Color.RED)
				load_button.disabled = false
	else:
		_show_status("存档数据无效!", Color.RED)
		load_button.disabled = false

# 移除设置按钮的信号处理函数和设置菜单关闭信号处理函数
# func _on_settings_button_pressed():
#	...
# func _on_settings_closed():
#	...

func _on_main_menu_button_pressed():
	print("Main Menu button pressed in pause menu")
	# 恢复游戏进程
	get_tree().paused = false  # 取消暂停
	# 使用 GameManager 进行场景切换
	game_manager.change_scene(MAIN_MENU_SCENE_PATH)

func _on_quit_button_pressed():
	# 退出游戏
	get_tree().quit() 

# SaveManager信号处理函数
func _on_save_completed(success: bool, message: String):
	if success:
		_show_status("保存成功!", Color.GREEN)
	else:
		_show_status("保存失败: " + message, Color.RED)
	
	# 重新启用保存按钮
	save_button.disabled = false
	
	# 更新存档信息
	_update_save_info()

func _on_load_completed(success: bool, message: String):
	if success:
		_show_status("读取成功!", Color.GREEN)
	else:
		_show_status("读取失败: " + message, Color.RED)
	
	# 重新启用读档按钮
	load_button.disabled = false

# 显示状态消息
func _show_status(text: String, color: Color = Color.WHITE):
	if status_label:
		status_label.text = text
		status_label.modulate = color
		print("暂停菜单状态: ", text)
		
		# 创建一个渐隐效果
		if status_label.has_meta("_status_tween"):
			var old_tween = status_label.get_meta("_status_tween")
			if is_instance_valid(old_tween):
				old_tween.kill()
			var tween = create_tween()
			status_label.set_meta("_status_tween", tween)
			tween.tween_property(status_label, "modulate:a", 1.0, 0.1)
			tween.tween_delay(3.0)  # 显示3秒
			tween.tween_property(status_label, "modulate:a", 0.3, 1.0)

# 更新存档信息显示
func _update_save_info():
	if not save_manager:
		return
		
	# 更新读档按钮状态
	if load_button:
		load_button.disabled = not save_manager.has_save()
		
		if save_manager.has_save():
			var save_info = save_manager.get_save_info()
			if not save_info.is_empty():
				var tooltip_text = "存档信息:\n"
				tooltip_text += "关卡: " + save_info.get("level_name", "未知") + "\n"
				tooltip_text += "时间: " + save_info.get("timestamp", "未知") + "\n"
				tooltip_text += "生命值: " + str(save_info.get("player_hp", 0)) + "/" + str(save_info.get("player_max_hp", 0))
				load_button.tooltip_text = tooltip_text
			else:
				load_button.tooltip_text = "点击加载游戏"
		else:
			load_button.tooltip_text = "没有可用的存档" 