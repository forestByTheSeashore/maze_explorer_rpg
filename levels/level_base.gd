extends Node2D

# === 节点引用 ===
@onready var player = $Player
@onready var entry_door: Node = $DoorRoot/Door_entrance
@onready var exit_door: Node = $DoorRoot/Door_exit
@onready var tile_map: TileMap = $TileMap
@onready var minimap = $CanvasLayer/MiniMap
@onready var pause_menu = get_node_or_null("CanvasLayer/PauseMenu") # 添加暂停菜单引用
@onready var ui_manager = $UiManager

# === 迷宫生成参数 ===
@export var maze_width: int = 81   # 迷宫宽度
@export var maze_height: int = 81  # 迷宫高度
@export var wall_tile_id: Vector2i = Vector2i(6, 0)      # 墙壁瓦片ID（有碰撞）
@export var floor_tile_id: Vector2i = Vector2i(0, 15)    # 地板瓦片ID（导航层）
@export var corridor_width: int = 8  # 走廊宽度

# 迷宫数据结构
var maze_grid: Array = []
var entrance_pos: Vector2i
var exit_pos: Vector2i

# 四个方向（右、下、左、上）
const DIRECTIONS = [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2)]

# 枚举类型
enum CellType { WALL, PATH }

# === 物品/敌人配置 ===
var packed_scenes = {
	"Key": preload("res://scenes/Key.tscn"),
	"Hp_bean": preload("res://scenes/Hp_bean.tscn"),
	"IronSword_type0": preload("res://scenes/IronSword.tscn"),
	"IronSword_type1": preload("res://scenes/IronSword.tscn"),
	"IronSword_type2": preload("res://scenes/IronSword.tscn"),
	"IronSword_type3": preload("res://scenes/IronSword.tscn"),
	"Enemy_Goblin": preload("res://scenes/goblin.tscn"),
	"Enemy_Skeleton": preload("res://scenes/skelontonEnemy.tscn"),
	"Enemy_Slime": preload("res://scenes/slime.tscn")
}

# 物品和敌人数量配置
var desired_counts = {
	"Key": 1,
	"Hp_bean": 20,
	"IronSword_type0": 2,
	"IronSword_type1": 2,
	"IronSword_type2": 1,
	"IronSword_type3": 1,
	"Enemy_Goblin": 2,
	"Enemy_Skeleton": 1,
	"Enemy_Slime": 2
}

# 添加路径显示状态变量
var show_path_to_key := false
var show_path_to_door := false
var path_lines := []  # 存储所有路径线

# 当前关卡名称（由LevelManager设置）
var current_level_name: String = ""

func _ready():
	print("=== 关卡初始化开始 ===")
	print("当前场景名称: ", scene_file_path)
	print("当前节点名称: ", name)
	
	# 连接UIManager信号
	if ui_manager:
		if ui_manager.has_signal("minimap_toggled"):
			ui_manager.minimap_toggled.connect(_on_minimap_toggled)
		if ui_manager.has_signal("show_key_path_toggled"):
			ui_manager.show_key_path_toggled.connect(_on_show_key_path_toggled)
		if ui_manager.has_signal("show_door_path_toggled"):
			ui_manager.show_door_path_toggled.connect(_on_show_door_path_toggled)
		print("UIManager信号已连接")
	
	# 只做节点引用和分组
	if player:
		player.add_to_group("player")
		player.visible = true  # 确保玩家可见
		# 确保玩家的可视化子节点可见（跳过不支持visible属性的节点）
		for child in player.get_children():
			if child.has_method("set_visible") or "visible" in child:
				child.visible = true
		print("玩家节点状态：", "存在" if player else "不存在")
		print("玩家可见性：", player.visible)
		print("玩家位置：", player.global_position)
	else:
		push_error("玩家节点不存在!")
	
	if tile_map:
		tile_map.add_to_group("tilemap")
		print("TileMap 已添加到组")
	else:
		push_error("TileMap节点不存在!")
	
	if exit_door:
		exit_door.add_to_group("doors")
		print("出口门已添加到组")
	else:
		push_error("出口门节点不存在!")
	
	if entry_door:
		entry_door.add_to_group("doors")
		print("入口门已添加到组")
	else:
		push_error("入口门节点不存在!")
	
	# 获取LevelManager并连接信号
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		print("找到LevelManager，连接信号")
		# 确保没有重复连接
		if level_manager.level_ready_to_initialize.is_connected(_on_level_ready_to_initialize):
			level_manager.level_ready_to_initialize.disconnect(_on_level_ready_to_initialize)
		
		# 连接信号
		level_manager.level_ready_to_initialize.connect(_on_level_ready_to_initialize)
		
		# 如果LevelManager已准备好初始化，立即调用初始化
		if level_manager._should_initialize and level_manager.next_level_name != "":
			print("LevelManager已准备好初始化，立即初始化关卡")
			await level_manager.initialize_level()
		else:
			print("LevelManager未准备好初始化，使用默认配置")
			await init_level()
	else:
		print("未找到LevelManager，使用默认配置")
		await init_level()
	
	print("=== 关卡初始化完成 ===")

	# 默认隐藏minimap
	if minimap:
		minimap.visible = false
	
	# 确保暂停菜单初始是隐藏的，游戏处于非暂停状态
	if pause_menu:
		pause_menu.hide()
		print("暂停菜单已隐藏")
	else:
		print("警告: 未找到暂停菜单节点")
	
	# 确保游戏处于非暂停状态
	get_tree().paused = false
	print("游戏暂停状态已重置为: ", get_tree().paused)

# 信号处理函数
func _on_level_ready_to_initialize(level_name: String):
	print("收到level_ready_to_initialize信号，关卡名称: ", level_name)
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		print("调用LevelManager.initialize_level()")
		await level_manager.initialize_level()
	else:
		push_error("信号处理中找不到LevelManager!")

func init_level() -> void:
	print("=== 程序化迷宫生成开始 ===")
	print("当前关卡: ", current_level_name if current_level_name != "" else "未知")
	print("调用者: ", get_stack()[1]["function"] if get_stack().size() > 1 else "未知")
	print("迷宫配置: 宽度=", maze_width, " 高度=", maze_height, " 走廊宽度=", corridor_width)

	# 确保节点已经在场景树中
	if not is_inside_tree():
		push_error("节点尚未添加到场景树中，无法初始化关卡")
		return

	# 通知UI管理器当前关卡信息
	if ui_manager and current_level_name != "":
		if ui_manager.has_method("update_level_info"):
			ui_manager.update_level_info(current_level_name)
			print("LevelBase: 已通知UI管理器当前关卡：", current_level_name)

	# 连接出口门的打开信号
	if exit_door:
		if exit_door.has_signal("door_opened"):
			# 先断开所有已存在的连接
			if exit_door.door_opened.is_connected(on_exit_door_has_opened):
				exit_door.door_opened.disconnect(on_exit_door_has_opened)
			# 重新连接信号
			exit_door.door_opened.connect(on_exit_door_has_opened)
			print("已连接出口门的打开信号")
		else:
			print("警告: 出口门没有 'door_opened' 信号!")

	print("步骤 1: 开始生成迷宫...")
	generate_optimized_maze()
	print("步骤 1: 迷宫生成完成")

	print("步骤 2: 开始绘制迷宫到 TileMap...")
	await draw_maze_to_tilemap()
	print("步骤 2: TileMap 绘制完成")

	print("步骤 3: 设置玩家和门的位置...")
	setup_player_and_doors_fixed()
	print("步骤 3: 玩家和门设置完成")

	await get_tree().process_frame
	verify_tilemap()

	print("步骤 4: 确保从入口到出口有一条可行路径...")
	ensure_path_from_entrance_to_exit()

	print("步骤 5: 重新绘制迷宫...")
	await draw_maze_to_tilemap()

	print("步骤 6: 重新定位敌人和物品...")
	reposition_enemies_and_items_optimized()
	print("步骤 6: 敌人和物品重新定位完成")

	draw_path()
	print("=== 迷宫生成完成 ===")

func _process(_delta):
	# 处理路径显示按键
	if Input.is_action_just_pressed("way_to_key"):  # F1
		show_path_to_key = !show_path_to_key
		show_path_to_door = false
	
	if Input.is_action_just_pressed("way_to_door"):  # F2
		show_path_to_door = !show_path_to_door
		show_path_to_key = false

	# 实时更新路径
	update_paths()

	# 玩家与出口门的交互逻辑
	if Input.is_action_just_pressed("interact"):
		if player and exit_door:
			var distance_to_exit_door = player.global_position.distance_to(exit_door.global_position)
			if distance_to_exit_door < 30:
				if exit_door.has_method("interact"):
					exit_door.interact()
				else:
					print("错误: 出口门节点没有 'interact' 方法!")

	# 处理暂停按键 (Escape)
	if Input.is_action_just_pressed("ui_cancel"): # 默认 Escape 映射到 ui_cancel
		# 只有在游戏未结束时才能暂停
		if is_instance_valid(player) and is_instance_valid(exit_door):
			toggle_pause()

# 出口门打开后的处理函数
func on_exit_door_has_opened():
	print("出口门已打开，当前关卡完成！")
	
	# 确保游戏处于非暂停状态再切换场景
	get_tree().paused = false
	
	var next_level = get_next_level_name()
	if next_level:
		print("切换到下一关: ", next_level)
		# 使用正确的LevelManager机制
		var level_manager = get_node("/root/LevelManager")
		if level_manager:
			level_manager.next_level_name = next_level
			level_manager.prepare_next_level()  # 添加这行
			# 使用场景切换而不是节点管理
			get_tree().change_scene_to_file("res://levels/base_level.tscn")
		else:
			print("错误：找不到LevelManager")
	else:
		print("恭喜！您已完成所有关卡！")
		# 这里可以添加游戏结束的处理逻辑

# 获取下一个关卡名称
func get_next_level_name() -> String:
	var level_manager = get_node("/root/LevelManager")
	if level_manager and current_level_name != "":
		return level_manager.get_next_level_name(current_level_name)
	return ""

# 获取当前关卡名称（供UI系统调用）
func get_current_level_name() -> String:
	return current_level_name

# 递归分割法生成迷宫
func generate_optimized_maze():
	maze_grid.clear()
	for y in range(maze_height):
		var row = []
		for x in range(maze_width):
			if x == 0 or x == maze_width-1 or y == 0 or y == maze_height-1:
				row.append(CellType.WALL)
			else:
				row.append(CellType.PATH)
		maze_grid.append(row)
	_recursive_divide(1, 1, maze_width-2, maze_height-2)
	create_entrance_and_exit_fixed()

func draw_maze_to_tilemap():
	if not tile_map:
		return
	tile_map.clear()
	for y in range(maze_height):
		for x in range(maze_width):
			var cell_type = maze_grid[y][x]
			var tile_pos = Vector2i(x, y)
			if cell_type == CellType.WALL:
				tile_map.set_cell(0, tile_pos, 0, wall_tile_id)
			else:
				tile_map.set_cell(0, tile_pos, 0, floor_tile_id)
	for x in range(maze_width):
		tile_map.set_cell(0, Vector2i(x, 0), 0, wall_tile_id)
		tile_map.set_cell(0, Vector2i(x, maze_height - 1), 0, wall_tile_id)
	for y in range(maze_height):
		tile_map.set_cell(0, Vector2i(0, y), 0, wall_tile_id)
		tile_map.set_cell(0, Vector2i(maze_width - 1, y), 0, wall_tile_id)
	await get_tree().process_frame
	var nav_maps = NavigationServer2D.get_maps()
	if not nav_maps.is_empty():
		NavigationServer2D.map_force_update(nav_maps[0])

func setup_player_and_doors_fixed():
	# 防止 maze_grid 未初始化导致越界
	if maze_grid.is_empty() or maze_grid[0].is_empty():
		print("错误：maze_grid 未初始化，不能设置门和玩家位置！")
		return
	"""设置玩家和门的位置（使用固定坐标）"""
	print("设置玩家和门的位置...")
	
	# 固定入口和出口门的位置
	var entrance_world_pos = Vector2(10, 31)
	var exit_world_pos = Vector2(1288, 1264)
	
	# 确保门位置的瓦片是地板
	entrance_pos = get_tile_position(entrance_world_pos)
	exit_pos = get_tile_position(exit_world_pos)
	
	# 确保入口和出口位置是路径
	if entrance_pos.x < maze_width and entrance_pos.y < maze_height:
		maze_grid[entrance_pos.y][entrance_pos.x] = CellType.PATH
		# 创建入口区域
		for y in range(entrance_pos.y - 3, entrance_pos.y + 4):
			for x in range(entrance_pos.x - 3, entrance_pos.x + 4):
				if x >= 0 and x < maze_width and y >= 0 and y < maze_height:
					maze_grid[y][x] = CellType.PATH
	
	if exit_pos.x < maze_width and exit_pos.y < maze_height:
		maze_grid[exit_pos.y][exit_pos.x] = CellType.PATH
		# 创建出口区域
		for y in range(exit_pos.y - 3, exit_pos.y + 4):
			for x in range(exit_pos.x - 3, exit_pos.x + 4):
				if x >= 0 and x < maze_width and y >= 0 and y < maze_height:
					maze_grid[y][x] = CellType.PATH
	
	# 设置门的位置
	if entry_door:
		entry_door.global_position = entrance_world_pos + Vector2(0,50)
		entry_door.visible = true
		entry_door.z_index = 10
		print("入口门设置在: ", entry_door.global_position)
	
	if exit_door:
		exit_door.global_position = exit_world_pos
		exit_door.requires_key = true
		exit_door.required_key_type = "master_key"
		exit_door.consume_key_on_open = true
		exit_door.visible = true
		exit_door.z_index = 10
		print("出口门设置在: ", exit_door.global_position)
	
	# 设置玩家位置和可见性
	if player:
		player.global_position = entry_door.global_position + Vector2(20,0)
		player.visible = true
		player.z_index = 5  # 确保玩家在适当的层级
		# 确保玩家的可视化子节点可见（跳过不支持visible属性的节点）
		for child in player.get_children():
			if child.has_method("set_visible") or "visible" in child:
				child.visible = true
		print("玩家设置在: ", player.global_position)
		print("玩家可见性：", player.visible)

func verify_tilemap():
	if not tile_map:
		return

func ensure_path_from_entrance_to_exit():
	if entrance_pos.x >= maze_width or entrance_pos.y >= maze_height or exit_pos.x >= maze_width or exit_pos.y >= maze_height:
		return
	create_path_between(entrance_pos.x, entrance_pos.y, exit_pos.x, exit_pos.y)
	widen_specific_path(entrance_pos.x, entrance_pos.y, exit_pos.x, exit_pos.y)

func reposition_enemies_and_items_optimized():
	print("智能重新定位敌人和物品 (整合版)...")

	# 1. 准备实体 (整合自第一个脚本的逻辑)
	var entities_map: Dictionary = _prepare_entities_for_placement(desired_counts)

	var keys_to_place: Array = entities_map.get("Key", [])
	var hp_beans_to_place: Array = entities_map.get("Hp_bean", [])
	var weapons_to_place: Array = []
	weapons_to_place.append_array(entities_map.get("IronSword_type0", []))
	weapons_to_place.append_array(entities_map.get("IronSword_type1", []))
	weapons_to_place.append_array(entities_map.get("IronSword_type2", []))
	weapons_to_place.append_array(entities_map.get("IronSword_type3", []))
	var enemies_to_place: Array = []
	enemies_to_place.append_array(entities_map.get("Enemy_Goblin", []))
	enemies_to_place.append_array(entities_map.get("Enemy_Skeleton", []))
	enemies_to_place.append_array(entities_map.get("Enemy_Slime", []))

	# 将所有需要放置的节点先加入场景树 (如果它们还没在里面的话)
	# 这样它们的 global_position 才能被正确设置
	var all_entities_to_place_flat: Array = []
	all_entities_to_place_flat.append_array(keys_to_place)
	all_entities_to_place_flat.append_array(hp_beans_to_place)
	all_entities_to_place_flat.append_array(weapons_to_place)
	all_entities_to_place_flat.append_array(enemies_to_place)

	for entity_node in all_entities_to_place_flat:
		if not entity_node.is_inside_tree():
			add_child(entity_node) # 添加到当前 Level2 节点下
		entity_node.visible = true # 确保可见

	# 2. 收集所有真正安全的、居中的世界坐标
	var all_safe_centered_world_positions = []
	if not tile_map or not tile_map.tile_set:
		printerr("TileMap 或 TileSet 未初始化，无法获取格子尺寸!")
		return
		
	var tile_center_offset = tile_map.tile_set.tile_size / 2.0

	# 玩家出生点及其安全半径
	var player_spawn_pos = player.global_position
	var player_safe_radius = 120.0 # 你可以根据实际调整

	for y_tile in range(1, maze_height - 1):
		for x_tile in range(1, maze_width - 1):
			if _is_truly_safe_position(x_tile, y_tile):
				var local_tile_pos_top_left = tile_map.map_to_local(Vector2i(x_tile, y_tile))
				var global_tile_pos_centered = tile_map.to_global(local_tile_pos_top_left + tile_center_offset)
				# 排除玩家出生点附近
				if global_tile_pos_centered.distance_to(player_spawn_pos) < player_safe_radius:
					continue
				all_safe_centered_world_positions.append(global_tile_pos_centered)
	
	all_safe_centered_world_positions.shuffle() # 打乱顺序增加随机性
	print("找到 ", all_safe_centered_world_positions.size(), " 个居中的安全世界位置")

	if all_safe_centered_world_positions.is_empty() and not all_entities_to_place_flat.is_empty() :
		print("警告: 安全位置不足，尝试创建额外的安全区域...")
		_create_additional_safe_areas() # 你脚本中已有的函数
		await get_tree().process_frame # 等待 maze_grid 更新
		await draw_maze_to_tilemap()   # 重绘 TileMap
		
		# 重新收集位置
		all_safe_centered_world_positions.clear()
		for y_tile in range(1, maze_height - 1):
			for x_tile in range(1, maze_width - 1):
				if _is_truly_safe_position(x_tile, y_tile):
					var local_tile_pos_top_left = tile_map.map_to_local(Vector2i(x_tile, y_tile))
					var global_tile_pos_centered = tile_map.to_global(local_tile_pos_top_left + tile_center_offset)
					# 排除玩家出生点附近
					if global_tile_pos_centered.distance_to(player_spawn_pos) < player_safe_radius:
						continue
					all_safe_centered_world_positions.append(global_tile_pos_centered)
		all_safe_centered_world_positions.shuffle()
		print("创建额外区域后找到 ", all_safe_centered_world_positions.size(), " 个居中的安全世界位置")

	if all_safe_centered_world_positions.is_empty() and not all_entities_to_place_flat.is_empty():
		printerr("致命错误: 即使创建了额外区域，仍然没有可用的安全位置!")
		# 将未放置的物品隐藏
		for entity_node in all_entities_to_place_flat: entity_node.visible = false
		return

	# 3. 使用统一的 `globally_used_positions` 进行放置
	var globally_used_positions: Array = []

	# 参数: (要放置的节点数组, 所有可用安全位置, 已用位置数组(会修改这个数组), 此类物品的最小间距)
	if not keys_to_place.is_empty():
		_place_keys_modified(keys_to_place, all_safe_centered_world_positions, globally_used_positions, 200.0)
	
	# 对于 HP_beans, weapons, enemies, 它们在你的脚本里共用 _place_items_safely
	# 我们需要修改 _place_items_safely 来接受并更新 globally_used_positions
	if not hp_beans_to_place.is_empty():
		_place_items_safely_modified(hp_beans_to_place, all_safe_centered_world_positions, globally_used_positions, 70.0, "Hp_bean") # 减小了间距
	if not weapons_to_place.is_empty():
		_place_items_safely_modified(weapons_to_place, all_safe_centered_world_positions, globally_used_positions, 150.0, "Weapon")
	if not enemies_to_place.is_empty():
		_place_items_safely_modified(enemies_to_place, all_safe_centered_world_positions, globally_used_positions, 120.0, "Enemy")
	
	# 检查是否有物品未能成功放置 (简单的检查方法是看它的位置是否还是初始的 Vector2.ZERO)
	for entity_node in all_entities_to_place_flat:
		if is_instance_valid(entity_node) and entity_node.global_position.is_equal_approx(Vector2.ZERO) and entity_node.visible:
			# 这个检查不够完美，因为物品可能被实例化在 (0,0)
			# 更好的方式是在放置函数中标记或返回未放置的物品
			# print("警告: 物品 ", entity_node.name, " 可能未被成功放置，当前位置: ", entity_node.global_position)
			var found_in_used = false
			for used_pos in globally_used_positions:
				if entity_node.global_position.is_equal_approx(used_pos):
					found_in_used = true
					break
			if not found_in_used and entity_node.name != player.name : # 排除玩家节点
				print("警告: 物品 ", entity_node.name, " 未能找到放置位置或仍在原点，将被隐藏。")
				entity_node.visible = false


	print("物品和敌人重新定位完成 (整合版)")


func _place_keys_modified(keys: Array, available_positions: Array, globally_used_positions: Array, min_distance: float):
	print("特别处理 ", keys.size(), " 个钥匙放置...")
	var positions_copy = available_positions.duplicate() # 操作副本，避免影响其他类型物品的可选位置总表
	
	# 获取重要位置的坐标，避免钥匙生成在这些地方附近
	var player_spawn_pos = player.global_position if player else Vector2.ZERO
	var exit_door_pos = exit_door.global_position if exit_door else Vector2.ZERO
	var entry_door_pos = entry_door.global_position if entry_door else Vector2.ZERO
	
	var exclusion_radius = 300.0  # 排除半径（像素）
	var preferred_distance_from_exit = 500.0  # 优先距离出口门更远的位置
	
	# 过滤掉太靠近重要位置的坐标
	var filtered_positions = []
	for pos in positions_copy:
		var too_close_to_important_locations = false
		
		# 检查是否太靠近玩家出生点
		if player_spawn_pos != Vector2.ZERO and pos.distance_to(player_spawn_pos) < exclusion_radius:
			too_close_to_important_locations = true
		
		# 检查是否太靠近出口门（最重要的排除条件）
		if exit_door_pos != Vector2.ZERO and pos.distance_to(exit_door_pos) < exclusion_radius:
			too_close_to_important_locations = true
		
		# 检查是否太靠近入口门
		if entry_door_pos != Vector2.ZERO and pos.distance_to(entry_door_pos) < exclusion_radius * 0.7:  # 入口门的排除半径稍小
			too_close_to_important_locations = true
		
		if not too_close_to_important_locations:
			filtered_positions.append(pos)
	
	print("过滤前位置数量: ", positions_copy.size(), " 过滤后位置数量: ", filtered_positions.size())
	
	# 如果过滤后位置太少，则逐步放宽条件
	if filtered_positions.size() < keys.size() * 3:
		print("过滤后位置不足，放宽条件...")
		exclusion_radius = 200.0  # 减小排除半径
		filtered_positions.clear()
		
		for pos in positions_copy:
			var too_close_to_important_locations = false
			
			# 只保留对出口门的严格排除
			if exit_door_pos != Vector2.ZERO and pos.distance_to(exit_door_pos) < exclusion_radius:
				too_close_to_important_locations = true
			
			# 对玩家出生点的排除半径减半
			if player_spawn_pos != Vector2.ZERO and pos.distance_to(player_spawn_pos) < exclusion_radius * 0.5:
				too_close_to_important_locations = true
			
			if not too_close_to_important_locations:
				filtered_positions.append(pos)
		
		print("放宽条件后位置数量: ", filtered_positions.size())
	
	# 按照距离出口门的远近排序，优先选择离出口门较远的位置
	if exit_door_pos != Vector2.ZERO:
		filtered_positions.sort_custom(func(a, b): 
			var dist_a = a.distance_to(exit_door_pos)
			var dist_b = b.distance_to(exit_door_pos)
			return dist_a > dist_b  # 距离远的排在前面
		)
		print("已按距离出口门远近排序，最远距离: ", filtered_positions[0].distance_to(exit_door_pos) if not filtered_positions.is_empty() else "无位置")
	else:
		filtered_positions.shuffle()

	var placed_count = 0
	for key_node in keys:
		var placed_successfully = false
		var attempts = 0
		for candidate_pos in filtered_positions:
			attempts += 1
			var tile_pos = tile_map.local_to_map(tile_map.to_local(candidate_pos))

			# 1. 检查瓦片本身是否绝对安全且附近没有墙
			var is_tile_super_safe = _is_truly_safe_position(tile_pos.x, tile_pos.y) and \
								 not _has_nearby_wall(tile_pos.x, tile_pos.y, 2) # 附近2格没墙

			if not is_tile_super_safe:
				continue

			# 2. 检查与已放置物品的距离
			var too_close_to_others = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance:
					too_close_to_others = true
					break
			
			# 3. 额外检查：确保距离出口门足够远（二次确认）
			var distance_to_exit = candidate_pos.distance_to(exit_door_pos) if exit_door_pos != Vector2.ZERO else 1000.0
			if distance_to_exit < 250.0:  # 二次确认距离出口门至少250像素
				continue
			
			if not too_close_to_others:
				key_node.global_position = candidate_pos
				globally_used_positions.append(candidate_pos) # 更新全局已用位置
				# 从 filtered_positions 中移除已用位置，防止重复给同一类型的其他钥匙
				filtered_positions.erase(candidate_pos)
				print(key_node.name, " 成功放置在: ", Vector2i(candidate_pos), " (尝试次数: ", attempts, ", 距离出口门: ", int(distance_to_exit), ")")
				placed_successfully = true
				placed_count += 1
				break # 处理下一个钥匙
		
		if not placed_successfully:
			print("警告：无法为钥匙 ", key_node.name, " 找到一个理想的安全位置。它将被隐藏。")
			key_node.visible = false
	print("成功放置 %d/%d 个钥匙。" % [placed_count, keys.size()])


func _place_items_safely_modified(items_in_category: Array, available_positions: Array, globally_used_positions: Array, min_distance_for_category: float, category_name_for_log: String):
	if items_in_category.is_empty():
		return
	print("开始为类别 '%s' 放置 %d 个物品..." % [category_name_for_log, items_in_category.size()])

	var positions_copy = available_positions.duplicate()
	positions_copy.shuffle()
	
	var placed_count = 0

	for item_node in items_in_category:
		var placed_successfully = false
		var attempts = 0
		# 尝试从可用位置中寻找
		for candidate_pos in positions_copy:
			attempts += 1
			var tile_pos = tile_map.local_to_map(tile_map.to_local(candidate_pos))

			# 针对不同类型做更严格的安全检查
			var is_tile_safe_enough = false
			if category_name_for_log == "Enemy":
				is_tile_safe_enough = _is_area_clear_for_enemy(tile_pos.x, tile_pos.y, get_enemy_clearance_radius(item_node))
			elif category_name_for_log == "Weapon":
				is_tile_safe_enough = _is_truly_safe_position(tile_pos.x, tile_pos.y)
			elif category_name_for_log == "Hp_bean":
				is_tile_safe_enough = _is_truly_safe_position(tile_pos.x, tile_pos.y)
			else:
				is_tile_safe_enough = _is_basic_safe_position(tile_pos.x, tile_pos.y)

			if not is_tile_safe_enough:
				continue

			# 2. 检查与已放置物品的距离
			var too_close_to_others = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance_for_category:
					too_close_to_others = true
					break
			
			if not too_close_to_others:
				item_node.global_position = candidate_pos
				globally_used_positions.append(candidate_pos)
				positions_copy.erase(candidate_pos) # 从这个类别的可用位置中移除
				print(item_node.name, "(",category_name_for_log,")"," 成功放置在: ", Vector2i(candidate_pos), " (尝试次数: ", attempts, ")")
				placed_successfully = true
				placed_count +=1
				break # 处理这个类别的下一个物品
		
		if not placed_successfully:
			# 如果在精选位置中找不到，可以尝试一个更宽松的后备查找，或者直接放弃
			# print("警告：在精选位置中无法为 ", item_node.name, " (", category_name_for_log, ") 找到位置。")
			# var fallback_pos = _find_any_safe_position_modified(available_positions, globally_used_positions, 32.0) # 使用一个较小的后备间距
			# if fallback_pos != Vector2.ZERO:
			# 	item_node.global_position = fallback_pos
			# 	globally_used_positions.append(fallback_pos)
			# 	print(item_node.name, "(",category_name_for_log,")"," 使用备用位置放置在: ", fallback_pos.round())
			# 	placed_successfully = true
			# 	placed_count +=1
			# else:
			print("警告：无法为 ", item_node.name, " (", category_name_for_log, ") 找到任何位置。它将被隐藏。")
			item_node.visible = false
	print("类别 '%s' 成功放置 %d/%d 个物品。" % [category_name_for_log, placed_count, items_in_category.size()])


func get_enemy_clearance_radius(enemy_node: Node2D) -> int:
	if enemy_node.name.begins_with("Goblin") or enemy_node.name.begins_with("Skeleton"):
		return 8
	elif enemy_node.name.begins_with("Slime"):
		return 4 # 假设史莱姆需要的空间小一点
	else:
		return 1

func _is_area_clear_for_enemy(cx: int, cy: int, radius: int) -> bool:
	if cx < radius or cx >= maze_width - radius or \
	   cy < radius or cy >= maze_height - radius:
		return false

	for dy_offset in range(-radius, radius + 1):
		for dx_offset in range(-radius, radius + 1):
			var check_x = cx + dx_offset
			var check_y = cy + dy_offset
			
			if check_x < 0 or check_x >= maze_width or \
			   check_y < 0 or check_y >= maze_height:
				return false 
			if maze_grid[check_y][check_x] != CellType.PATH:
				return false
	return true

func _is_ample_space_for_enemy(tile_x: int, tile_y: int, enemy_node: Node2D) -> bool:
	var required_radius = get_enemy_clearance_radius(enemy_node)
	return _is_area_clear_for_enemy(tile_x, tile_y, required_radius)

func _get_nodes_by_type(items: Array, type: String) -> Array:
	var result = []
	for item in items:
		if item.name.begins_with(type):
			result.append(item)
	return result

func _get_nodes_by_name_prefix(nodes_array: Array, prefix: String) -> Array:
	var result = []
	for node_item in nodes_array:
		if is_instance_valid(node_item) and node_item.name.begins_with(prefix):
			result.append(node_item)
	return result

func _get_nodes_by_name_prefix_and_property(nodes_array: Array, prefix: String, prop_name: String, prop_value) -> Array:
	var result = []
	for node_item in nodes_array:
		if is_instance_valid(node_item) and node_item.name.begins_with(prefix):
			var actual_prop_value = null
			if node_item.has_method("get_" + prop_name):
				actual_prop_value = node_item.call("get_" + prop_name)
			elif prop_name in node_item:
				actual_prop_value = node_item.get(prop_name)
			
			if actual_prop_value == prop_value:
				result.append(node_item)
	return result

func _prepare_entities_for_placement(p_desired_counts: Dictionary) -> Dictionary:
	var entities_map: Dictionary = {}
	var items_group = get_tree().get_nodes_in_group("items") # 获取场景中已有的
	var enemies_group = get_tree().get_nodes_in_group("enemies")

	# 构建一个包含当前场景中已存在节点的映射
	var p_existing_nodes_map = {
		"Key": _get_nodes_by_name_prefix(items_group, "Key"),
		"Hp_bean": _get_nodes_by_name_prefix(items_group, "Hp_bean"),
		"IronSword_type0": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 0),
		"IronSword_type1": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 1),
		"IronSword_type2": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 2),
		"IronSword_type3": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 3),
		"Enemy_Goblin": _get_nodes_by_name_prefix(enemies_group, "Goblin"),
		"Enemy_Skeleton": _get_nodes_by_name_prefix(enemies_group, "Skeleton"),	
		"Enemy_Slime": _get_nodes_by_name_prefix(enemies_group, "Slime")
	}

	for type_str in p_desired_counts:
		var desired_num = p_desired_counts[type_str]
		var existing_nodes_of_type: Array = p_existing_nodes_map.get(type_str, [])
		var nodes_for_this_type: Array = []

		var num_to_take_from_existing = min(desired_num, existing_nodes_of_type.size())
		for i in range(num_to_take_from_existing):
			if is_instance_valid(existing_nodes_of_type[i]):
				nodes_for_this_type.append(existing_nodes_of_type[i])
		
		var num_to_instance = desired_num - nodes_for_this_type.size()
		if num_to_instance > 0:
			if packed_scenes.has(type_str) and packed_scenes[type_str] is PackedScene:
				var packed_scene: PackedScene = packed_scenes[type_str]
				for _i in range(num_to_instance):
					var instance = packed_scene.instantiate()
					# 如果是剑，设置sword_type
					var sword_type_to_set = -1
					if type_str == "IronSword_type0": sword_type_to_set = 0
					elif type_str == "IronSword_type1": sword_type_to_set = 1
					elif type_str == "IronSword_type2": sword_type_to_set = 2
					elif type_str == "IronSword_type3": sword_type_to_set = 3
					
					if sword_type_to_set != -1:
						if "sword_type" in instance:
							instance.sword_type = sword_type_to_set
					elif instance.has_method("set_sword_type"):
						instance.set_sword_type(sword_type_to_set)
					
					# 重要：这里先不 add_child，由放置逻辑统一处理
					nodes_for_this_type.append(instance)
			else:
				printerr("错误: 类型 ", type_str, " 的 PackedScene 未在 packed_scenes 中正确配置!")

		entities_map[type_str] = nodes_for_this_type
		
		# 处理多余的已存在节点 (如果需要)
		if existing_nodes_of_type.size() > num_to_take_from_existing:
			for i in range(num_to_take_from_existing, existing_nodes_of_type.size()):
				var surplus_node = existing_nodes_of_type[i]
				if is_instance_valid(surplus_node) and surplus_node.is_inside_tree():
					print("移除多余的预设节点: ", surplus_node.name)
					surplus_node.queue_free()
	return entities_map

func draw_path():
	var player = get_node("Player")
	var key = get_node_or_null("Key")
	var door_exit = get_node("DoorRoot/Door_exit")
	var tile_map = get_node("TileMap")
	
	# 如果钥匙不存在且正在显示到钥匙的路径，则关闭路径显示
	if not key and show_path_to_key:
		show_path_to_key = false
		print("钥匙已被收集，关闭到钥匙的路径显示")
	
	if not (player and door_exit and tile_map):
		return

	var nav_maps = NavigationServer2D.get_maps()
	if nav_maps.is_empty():
		print("警告：没有可用的导航地图")
		return
		
	var nav_map = nav_maps[0]

	if show_path_to_key and key:  # 只有在钥匙存在时才显示到钥匙的路径
		var path_to_key = NavigationServer2D.map_get_path(nav_map, player.global_position, key.global_position, true)
		draw_path_lines(path_to_key, Color(1, 0, 0))  # 红色表示到钥匙的路径

	if show_path_to_door:
		var path_to_door = NavigationServer2D.map_get_path(nav_map, player.global_position, door_exit.global_position, true)
		draw_path_lines(path_to_door, Color(0, 0, 1))  # 蓝色表示到门的路径

func draw_path_lines(path: PackedVector2Array, color: Color):
	for i in range(path.size() - 1):
		var line = Line2D.new()
		line.add_point(path[i])
		line.add_point(path[i + 1])
		line.width = 2
		line.default_color = color
		add_child(line)
		path_lines.append(line)

func update_paths():
	# 清除所有现有的路径线
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

	# 如果需要显示路径，则重新绘制
	if show_path_to_key or show_path_to_door:
		draw_path()

# 递归分割法：将区域分割成更小的子区域并添加墙体
func _recursive_divide(x1: int, y1: int, x2: int, y2: int):
	# 减小最小区域大小，让分割更细致
	if x2 - x1 < 6 or y2 - y1 < 6:  # 从8改为6
		return
	var width = x2 - x1
	var height = y2 - y1
	var horizontal = width < height
	if horizontal and height > 4:  # 从6改为4
		var wall_space = height - 4  # 从6改为4
		var wall_pos = 1  # 从2改为1
		if wall_space > 0:
			wall_pos = randi() % wall_space
		var wall_y = y1 + 1 + wall_pos  # 从2改为1
		for x in range(x1, x2 + 1):
			if x >= 0 and x < maze_width:
				maze_grid[wall_y][x] = CellType.WALL
		var door_space = width - 2  # 从4改为2
		if door_space < 3:  # 确保至少3格宽的门（从5改为3）
			door_space = 3
		var door_x = x1 + 1 + randi() % max(1, door_space - 2)  # 从2改为1，为3格宽门留空间
		if door_x >= 0 and door_x < maze_width:
			for dx in range(-1, 2):  # 创建3格宽的门洞（从-2,3改为-1,2）
				var x = door_x + dx
				if x >= x1 and x < x2 + 1 and x >= 0 and x < maze_width:
					maze_grid[wall_y][x] = CellType.PATH
		if wall_y - y1 > 2:  # 从3改为2
			_recursive_divide(x1, y1, x2, wall_y - 1)
		if y2 - wall_y > 2:  # 从3改为2
			_recursive_divide(x1, wall_y + 1, x2, y2)
	elif width > 4:  # 从6改为4
		var wall_space = width - 4  # 从6改为4
		var wall_pos = 1  # 从2改为1
		if wall_space > 0:
			wall_pos = randi() % wall_space
		var wall_x = x1 + 1 + wall_pos  # 从2改为1
		for y in range(y1, y2 + 1):
			if y >= 0 and y < maze_height:
				maze_grid[y][wall_x] = CellType.WALL
		var door_space = height - 2  # 从4改为2
		if door_space < 3:  # 确保至少3格高的门（从5改为3）
			door_space = 3
		var door_y = y1 + 1 + randi() % max(1, door_space - 2)  # 从2改为1，为3格高门留空间
		if door_y >= 0 and door_y < maze_height:
			for dy in range(-1, 2):  # 创建3格高的门洞（从-2,3改为-1,2）
				var y = door_y + dy
				if y >= y1 and y < y2 + 1 and y >= 0 and y < maze_height:
					maze_grid[y][wall_x] = CellType.PATH
		if wall_x - x1 > 2:  # 从3改为2
			_recursive_divide(x1, y1, wall_x - 1, y2)
		if x2 - wall_x > 2:  # 从3改为2
			_recursive_divide(wall_x + 1, y1, x2, y2)

func create_entrance_and_exit_fixed():
	var entrance_x = 0
	var entrance_y = int(maze_height / 2)
	var exit_x = maze_width - 1
	var exit_y = int(maze_height / 2)
	for i in range(5):
		var y = entrance_y + i - 2
		if y >= 0 and y < maze_height:
			for x in range(5):
				var cur_x = entrance_x + x
				if cur_x >= 0 and cur_x < maze_width:
					maze_grid[y][cur_x] = CellType.PATH
	for i in range(5):
		var y = exit_y + i - 2
		if y >= 0 and y < maze_height:
			for x in range(5):
				var cur_x = exit_x - x
				if cur_x >= 0 and cur_x < maze_width:
					maze_grid[y][cur_x] = CellType.PATH
	entrance_pos = Vector2i(int(entrance_x), int(entrance_y))
	exit_pos = Vector2i(int(exit_x), int(exit_y))

func get_tile_position(world_pos: Vector2) -> Vector2i:
	if not tile_map:
		return Vector2i(0, 0)
	var local_pos = tile_map.to_local(world_pos)
	var tile_pos = tile_map.local_to_map(local_pos)
	return tile_pos

func create_path_between(x1: int, y1: int, x2: int, y2: int):
	var current_x = x1
	var current_y = y1
	while current_x != x2:
		if current_x >= 0 and current_x < maze_width and current_y >= 0 and current_y < maze_height:
			maze_grid[current_y][current_x] = CellType.PATH
		if current_x < x2:
			current_x += 1
		else:
			current_x -= 1
	while current_y != y2:
		if current_x >= 0 and current_x < maze_width and current_y >= 0 and current_y < maze_height:
			maze_grid[current_y][current_x] = CellType.PATH
		if current_y < y2:
			current_y += 1
		else:
			current_y -= 1
	if x2 >= 0 and x2 < maze_width and y2 >= 0 and y2 < maze_height:
		maze_grid[y2][x2] = CellType.PATH

func widen_specific_path(x1: int, y1: int, x2: int, y2: int):
	var width = 2
	var current_x = x1
	var current_y = y1
	while current_x != x2:
		for dy in range(-width, width + 1):
			for dx in range(-width, width + 1):
				var nx = current_x + dx
				var ny = current_y + dy
				if nx >= 0 and nx < maze_width and ny >= 0 and ny < maze_height:
					maze_grid[ny][nx] = CellType.PATH
		if current_x < x2:
			current_x += 1
		else:
			current_x -= 1
	while current_y != y2:
		for dy in range(-width, width + 1):
			for dx in range(-width, width + 1):
				var nx = current_x + dx
				var ny = current_y + dy
				if nx >= 0 and nx < maze_width and ny >= 0 and ny < maze_height:
					maze_grid[ny][nx] = CellType.PATH
		if current_y < y2:
			current_y += 1
		else:
			current_y -= 1
	
# 检查位置是否真正安全（严格检查）
func _is_truly_safe_position(x: int, y: int) -> bool:
	# 检查边界
	if x <= 0 or x >= maze_width - 1 or y <= 0 or y >= maze_height - 1:
		return false
	
	# 检查当前位置是否为路径
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	# 检查周围3x3区域是否都是路径
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var check_x = x + dx
			var check_y = y + dy
			if check_x < 0 or check_x >= maze_width or check_y < 0 or check_y >= maze_height:
				return false
			if maze_grid[check_y][check_x] != CellType.PATH:
				return false
	
	return true

# 检查位置是否基本安全
func _is_basic_safe_position(x: int, y: int) -> bool:
	# 检查边界
	if x <= 0 or x >= maze_width - 1 or y <= 0 or y >= maze_height - 1:
		return false
	
	# 检查当前位置是否为路径
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	return true

# 检查附近是否有墙
func _has_nearby_wall(x: int, y: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var check_x = x + dx
			var check_y = y + dy
			if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
				if maze_grid[check_y][check_x] == CellType.WALL:
					return true
	return false

# 创建额外的安全区域
func _create_additional_safe_areas():
	print("创建额外的安全区域...")
	var areas_created = 0
	
	# 在迷宫中随机创建一些小的安全区域
	for attempt in range(20):
		var center_x = randi() % (maze_width - 10) + 5
		var center_y = randi() % (maze_height - 10) + 5
		
		# 创建5x5的安全区域
		var can_create = true
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var check_x = center_x + dx
				var check_y = center_y + dy
				if check_x < 1 or check_x >= maze_width - 1 or check_y < 1 or check_y >= maze_height - 1:
					can_create = false
					break
			if not can_create:
				break
		
		if can_create:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var area_x = center_x + dx
					var area_y = center_y + dy
					maze_grid[area_y][area_x] = CellType.PATH
			areas_created += 1
			if areas_created >= 5:  # 最多创建5个额外区域
				break
	
	print("创建了 ", areas_created, " 个额外安全区域")

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

# 切换暂停状态函数
func toggle_pause():
	print("Base_Level: toggle_pause 被调用")
	print("Base_Level: 当前暂停状态: ", get_tree().paused)
	print("Base_Level: 暂停菜单节点: ", pause_menu)
	
	get_tree().paused = !get_tree().paused
	print("Base_Level: 新的暂停状态: ", get_tree().paused)
	
	if pause_menu:
		pause_menu.visible = get_tree().paused # 暂停时显示菜单，否则隐藏
		print("Base_Level: 暂停菜单可见性设置为: ", pause_menu.visible)
	else:
		print("Base_Level: 错误 - 暂停菜单节点为null!")

