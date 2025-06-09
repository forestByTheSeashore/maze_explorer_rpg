# level_1.gd
extends Node2D

# 关卡信息
var current_level_name: String = "level_1"

# 添加 GameManager 引用
@onready var game_manager = get_node("/root/GameManager")

@onready var player = $Player
@onready var entry_door: Node = $DoorRoot/Door_entrance # 确保名称匹配
@onready var exit_door: Node = $DoorRoot/Door_exit   # 确保名称匹配
@onready var tile_map: TileMap = $TileMap
@onready var minimap = $CanvasLayer/MiniMap
@onready var pause_menu = get_node_or_null("CanvasLayer/PauseMenu") # 安全获取暂停菜单节点引用
@onready var ui_manager = $UiManager

# 添加路径显示状态变量
var show_path_to_key := false
var show_path_to_door := false
var path_lines := []  # 存储所有路径线
# 新增：路径显示设置
var path_width := 4.0       # 路径线宽度
var path_smoothing := true  # 是否平滑路径
var path_gradient := true   # 是否使用渐变色

# 移除  signal player_reached_exit，因为我们将直接响应门的打开事件

func _ready():
	print("Level_1: _ready 开始...")
	
	if entry_door == null:
		push_error("Error: EntryDoor node not found in scene!")
		return
	if exit_door == null:
		push_error("Error: ExitDoor node not found in scene!")
		return

	# 检查暂停菜单
	print("Level_1: 检查暂停菜单节点...")
	pause_menu = get_node_or_null("CanvasLayer/PauseMenu")
	if pause_menu:
		print("Level_1: 暂停菜单找到了: ", pause_menu.name)
	else:
		print("Level_1: 警告 - 暂停菜单未找到，尝试其他路径...")
		# 尝试其他可能的路径
		pause_menu = get_node_or_null("PauseMenu")
		if pause_menu:
			print("Level_1: 在根路径找到暂停菜单")
		else:
			var canvas_layer = get_node_or_null("CanvasLayer")
			if canvas_layer:
				print("Level_1: 找到CanvasLayer，子节点列表:")
				for child in canvas_layer.get_children():
					print("  - ", child.name, " (类型: ", child.get_class(), ")")
			else:
				print("Level_1: 连CanvasLayer都没找到")

	# 连接UIManager信号
	if ui_manager:
		if ui_manager.has_signal("minimap_toggled"):
			ui_manager.minimap_toggled.connect(_on_minimap_toggled)
		if ui_manager.has_signal("show_key_path_toggled"):
			ui_manager.show_key_path_toggled.connect(_on_show_key_path_toggled)
		if ui_manager.has_signal("show_door_path_toggled"):
			ui_manager.show_door_path_toggled.connect(_on_show_door_path_toggled)
		print("UIManager信号已连接")
		
		# 通知UI管理器当前关卡信息
		if ui_manager.has_method("update_level_info"):
			ui_manager.update_level_info(current_level_name)
			print("Level_1: 已通知UI管理器当前关卡：", current_level_name)

	# 1. 入口门逻辑 (基本不变)
	# entry_door.door_opened.connect(on_entry_door_opened) # 如果需要入口门打开时的特殊逻辑
	# 假设入口门在 _ready() 中已经自行处理了初始打开状态 (根据 door.gd)

	# 将玩家放置在入口门的位置
	if player and entry_door:
		player.global_position = entry_door.global_position + Vector2(32,10)

	# 设置出口门需要钥匙
	if exit_door:
		exit_door.requires_key = true
		exit_door.required_key_type = "master_key"
		exit_door.consume_key_on_open = true
		print("出口门已设置为需要钥匙：", exit_door.required_key_type)

	# 2. 连接出口门的 door_opened 信号到关卡结束处理函数
	if exit_door: # 确保 exit_door 存在
		# 确保 exit_door 确实有 door_opened 信号 (它是在 door.gd 中定义的)
		if exit_door.has_signal("door_opened"):
			exit_door.door_opened.connect(on_exit_door_has_opened)
		else:
			push_error("Error: ExitDoor does not have 'door_opened' signal!")

	# 设置节点组
	if player:
		player.add_to_group("player")
	if tile_map:
		tile_map.add_to_group("tilemap")
	if exit_door:
		exit_door.add_to_group("doors")
	if entry_door:
		entry_door.add_to_group("doors")

	# 等待导航系统初始化
	await get_tree().process_frame
	var nav_maps = NavigationServer2D.get_maps()
	if not nav_maps.is_empty():
		NavigationServer2D.map_force_update(nav_maps[0])  # 强制更新第一个导航地图
	await get_tree().create_timer(0.2).timeout  # 等待更长时间
	draw_path()

	# 确保暂停菜单初始是隐藏的
	if pause_menu:
		pause_menu.hide()
	
	# 默认隐藏minimap
	if minimap:
		minimap.visible = false

func get_current_level_name() -> String:
	"""返回当前关卡名称"""
	return current_level_name

# UIManager按钮回调函数
func _on_minimap_toggled(enabled: bool):
	print("小地图开关：", enabled)
	if minimap:
		minimap.visible = enabled

func _on_show_key_path_toggled(enabled: bool):
	print("钥匙路径开关：", enabled)
	show_path_to_key = enabled
	if enabled:
		show_path_to_door = false
	update_paths()

func _on_show_door_path_toggled(enabled: bool):
	print("门路径开关：", enabled)
	show_path_to_door = enabled
	if enabled:
		show_path_to_key = false
	update_paths()

func on_exit_door_has_opened(): # 当出口门的 door_opened 信号发出时调用
	print("出口门已打开，Level 1 结束！")
	print("进入 Level 2 - 程序化迷宫关卡")
	
	# 确保游戏处于非暂停状态再切换场景
	get_tree().paused = false
	
	# 使用LevelManager切换关卡
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		# 设置下一关名称
		level_manager.next_level_name = "level_2"
		# 准备初始化下一关
		level_manager.prepare_next_level()
		# 使用场景切换
		print("准备切换到base_level.tscn...")
		
		# 延迟一帧再切换场景，确保所有标记都被设置
		await get_tree().process_frame
		var error = get_tree().change_scene_to_file("res://levels/base_level.tscn")
		if error != OK:
			push_error("场景切换失败! 错误码: " + str(error))
	else:
		push_error("错误：找不到LevelManager")

func _process(_delta):
	# 处理路径显示按键
	if Input.is_action_just_pressed("way_to_key"):  # F1
		print("show way to key")
		show_path_to_key = !show_path_to_key
		show_path_to_door = false
	
	if Input.is_action_just_pressed("way_to_door"):
		print("show way to door")  # F2
		show_path_to_door = !show_path_to_door
		show_path_to_key = false

	# 快速保存和加载
	if Input.is_action_just_pressed("quick_save"):  # F5
		print("快速保存游戏...")
		var save_manager = get_node("/root/SaveManager")
		if save_manager:
			save_manager.quick_save()
		else:
			print("错误：找不到SaveManager")
	
	if Input.is_action_just_pressed("quick_load"):  # F6
		print("快速加载游戏...")
		var save_manager = get_node("/root/SaveManager")
		if save_manager and save_manager.has_save():
			var save_data = save_manager.load_progress()
			if not save_data.is_empty():
				print("加载成功，准备切换场景...")
				# 这里可以根据需要处理加载后的场景切换逻辑
		else:
			print("没有可用的存档或找不到SaveManager")

	# 实时更新路径
	update_paths()

	# 玩家与出口门的交互逻辑
	if Input.is_action_just_pressed("interact"): # "interact" 应该映射到 'F' 键
		if player and exit_door:
			# 检查玩家是否足够接近出口门
			var distance_to_exit_door = player.global_position.distance_to(exit_door.global_position)
			if distance_to_exit_door < 30: # 交互范围，可以调整
				# 确保 exit_door 节点有 interact 方法
				if exit_door.has_method("interact"):
					exit_door.interact() # 调用 Door.gd 中的 interact() 方法
				else:
					push_error("Error: ExitDoor node does not have 'interact' method!")

	# 处理暂停按键 (Escape)
	if Input.is_action_just_pressed("ui_cancel"): # 默认 Escape 映射到 ui_cancel
		# 只有在游戏未结束时才能暂停
		if is_instance_valid(player) and is_instance_valid(exit_door):
			toggle_pause()

func update_paths():
	# 清除所有现有的路径线
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

	# 如果需要显示路径，则重新绘制
	if show_path_to_key or show_path_to_door:
		draw_path()

func draw_path():
	# 使用已有的player变量而不是重新声明
	var key = get_node_or_null("Key")
	var door_exit = get_node("DoorRoot/Door_exit")
	var tile_map = get_node("TileMap")
	
	# 如果钥匙不存在且正在显示到钥匙的路径，则关闭路径显示
	if not key and show_path_to_key:
		show_path_to_key = false
		print("钥匙已被收集，关闭到钥匙的路径显示")
	
	if player and door_exit and tile_map:
		var nav_maps = NavigationServer2D.get_maps()
		if nav_maps.is_empty():
			print("警告：没有可用的导航地图")
			return
			
		var nav_map = nav_maps[0]  # 使用第一个可用的导航地图
		if show_path_to_key and key:  # 只有在钥匙存在时才显示到钥匙的路径
			var path_to_key = NavigationServer2D.map_get_path(nav_map, player.global_position, key.global_position, true)
			if path_smoothing:
				path_to_key = smooth_path(path_to_key)
			draw_path_lines(path_to_key, Color(1, 0, 0), Color(1, 1, 0))  # 红色到黄色渐变表示到钥匙的路径

		if show_path_to_door:
			var path_to_door = NavigationServer2D.map_get_path(nav_map, player.global_position, door_exit.global_position, true)
			if path_smoothing:
				path_to_door = smooth_path(path_to_door)
			draw_path_lines(path_to_door, Color(0, 0, 1), Color(0, 1, 1))  # 蓝色到青色渐变表示到门的路径

# 新增：路径平滑处理函数
func smooth_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2:
		return path
		
	var smoothed_path = PackedVector2Array()
	smoothed_path.append(path[0])  # 起点
	
	# 使用贝塞尔曲线平滑中间点
	for i in range(1, path.size() - 1):
		var prev = path[i-1]
		var current = path[i]
		var next = path[i+1]
		
		# 计算控制点（简化的贝塞尔曲线）
		var control1 = prev.lerp(current, 0.5)
		var control2 = current.lerp(next, 0.5)
		
		# 添加插值点（可以增加点数以获得更平滑的曲线）
		var steps = 5
		for j in range(1, steps):
			var t = float(j) / steps
			var point = control1.lerp(control2, t)
			smoothed_path.append(point)
			
	smoothed_path.append(path[path.size()-1])  # 终点
	return smoothed_path

func draw_path_lines(path: PackedVector2Array, start_color: Color, end_color: Color = start_color):
	if path.size() < 2:
		return
		
	var line = Line2D.new()
	line.points = path
	line.width = path_width
	
	# 设置渐变色
	if path_gradient and start_color != end_color:
		var gradient = Gradient.new()
		gradient.colors = PackedColorArray([start_color, end_color])
		line.gradient = gradient
	else:
		line.default_color = start_color
		
	# 设置线条样式
	line.antialiased = true  # 抗锯齿
	line.joint_mode = Line2D.LINE_JOINT_ROUND  # 圆角连接
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND  # 圆头起点
	line.end_cap_mode = Line2D.LINE_CAP_ROUND    # 圆头终点
	
	# 添加到场景并存储引用
	add_child(line)
	path_lines.append(line)
	
	# 在路径终点添加一个标记点（可选）
	var end_marker = Sprite2D.new()
	# 你需要为此准备一个标记图标，或者使用ColorRect代替
	# end_marker.texture = preload("res://assets/path_marker.png")
	# 如果没有专用图标，创建一个简单的圆形标记
	var circle = create_circle_marker(8, end_color)  # 8像素半径
	end_marker.texture = circle
	end_marker.position = path[path.size() - 1]
	add_child(end_marker)
	path_lines.append(end_marker)  # 也将标记添加到路径元素列表中

# 新增：创建圆形标记
func create_circle_marker(radius: int, color: Color) -> ImageTexture:
	var image = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # 透明背景
	
	# 绘制圆形
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dist = Vector2(x - radius, y - radius).length()
			if dist <= radius:
				# 创建从中心到边缘的衰减透明度
				var alpha = 1.0 - (dist / radius) * 0.8
				var pixel_color = Color(color.r, color.g, color.b, color.a * alpha)
				image.set_pixel(x, y, pixel_color)
	
	# 创建纹理
	var texture = ImageTexture.create_from_image(image)
	return texture

func _input(event):
	pass

# 新增：切换暂停状态函数
func toggle_pause():
	print("Level_1: toggle_pause 被调用")
	print("Level_1: 当前暂停状态: ", get_tree().paused)
	print("Level_1: 暂停菜单节点: ", pause_menu)
	
	get_tree().paused = !get_tree().paused
	print("Level_1: 新的暂停状态: ", get_tree().paused)
	
	if pause_menu:
		pause_menu.visible = get_tree().paused # 暂停时显示菜单，否则隐藏
		print("Level_1: 暂停菜单可见性设置为: ", pause_menu.visible)
	else:
		print("Level_1: 错误 - 暂停菜单节点为null!")
