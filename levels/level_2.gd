# level_2.gd
extends Node2D

@onready var player = $Player
@onready var entry_door: Node = $DoorRoot/Door_entrance
@onready var exit_door: Node = $DoorRoot/Door_exit
@onready var tile_map: TileMap = $TileMap

# === 迷宫生成参数 ===
@export var maze_width: int = 81   # 迷宫宽度（恢复到81x81）
@export var maze_height: int = 81  # 迷宫高度（恢复到81x81）
@export var wall_tile_id: Vector2i = Vector2i(6, 0)      # 墙壁瓦片ID（有碰撞）
@export var floor_tile_id: Vector2i = Vector2i(0, 15)    # 地板瓦片ID（导航层）
@export var corridor_width: int = 8  # 走廊宽度（增大到8格）

# 迷宫数据结构
var maze_grid: Array = []
var entrance_pos: Vector2i
var exit_pos: Vector2i

# 四个方向（右、下、左、上）
const DIRECTIONS = [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2)]

# 枚举类型
enum CellType { WALL, PATH }

func _ready():
	print("=== Level 2 - 程序化迷宫生成开始 ===")
	print("迷宫尺寸: ", maze_width, "x", maze_height)
	print("墙壁瓦片ID (有碰撞): ", wall_tile_id)
	print("地板瓦片ID: ", floor_tile_id)
	print("走廊宽度: ", corridor_width)
	
	# 检查TileMap节点
	if not tile_map:
		print("致命错误: TileMap 节点未找到!")
		return
	else:
		print("TileMap 节点找到: ", tile_map.name)
	
	# 连接出口门的打开信号
	if exit_door:
		if exit_door.has_signal("door_opened"):
			exit_door.door_opened.connect(on_exit_door_has_opened)
			print("已连接出口门的打开信号")
		else:
			print("警告: 出口门没有 'door_opened' 信号!")
	
	# 1. 生成迷宫（使用优化后的迷宫生成算法）
	print("步骤 1: 开始生成迷宫...")
	generate_optimized_maze()  # 使用优化后的迷宫生成算法
	print("步骤 1: 迷宫生成完成")
	
	# 2. 绘制迷宫到 TileMap
	print("步骤 2: 开始绘制迷宫到 TileMap...")
	await draw_maze_to_tilemap()
	print("步骤 2: TileMap 绘制完成")
	
	# 3. 设置玩家和门的位置
	print("步骤 3: 设置玩家和门的位置...")
	setup_player_and_doors_fixed()
	print("步骤 3: 玩家和门设置完成")
	
	# 强制等待一帧，然后验证TileMap
	await get_tree().process_frame
	verify_tilemap()
	
	# 4. 确保从入口到出口有一条可行路径
	print("步骤 4: 确保从入口到出口有一条可行路径...")
	ensure_path_from_entrance_to_exit()
	
	# 5. 重新绘制迷宫（应用路径修正）
	print("步骤 5: 重新绘制迷宫...")
	await draw_maze_to_tilemap()
	
	# 6. 重新定位敌人和物品到迷宫内的可行走区域
	print("步骤 6: 重新定位敌人和物品...")
	reposition_enemies_and_items_optimized()
	print("步骤 6: 敌人和物品重新定位完成")
	
	print("=== Level 2 迷宫生成完成 ===")

func _process(_delta):
	# 玩家与出口门的交互逻辑
	if Input.is_action_just_pressed("interact"):  # "interact" 应该映射到 'F' 键
		if player and exit_door:
			# 检查玩家是否足够接近出口门
			var distance_to_exit_door = player.global_position.distance_to(exit_door.global_position)
			if distance_to_exit_door < 30:  # 交互范围，可以调整
				# 确保 exit_door 节点有 interact 方法
				if exit_door.has_method("interact"):
					print("玩家正在尝试与出口门交互...")
					exit_door.interact()  # 调用 Door.gd 中的 interact() 方法
				else:
					print("错误: 出口门节点没有 'interact' 方法!")

# 出口门打开后的处理函数
func on_exit_door_has_opened():
	print("出口门已打开，Level 2 完成！")
	print("游戏胜利！")
	# 这里可以添加你的胜利画面或下一关逻辑
	# 例如：显示胜利UI或返回主菜单
	# get_tree().change_scene_to_file("res://scenes/victory_screen.tscn")

func generate_optimized_maze():
	"""使用递归分割法生成迷宫，创建类似图片的效果"""
	print("生成迷宫: 递归分割法")
	maze_grid.clear()
	
	# 初始化：内部全为路径，外墙为墙
	for y in range(maze_height):
		var row = []
		for x in range(maze_width):
			if x == 0 or x == maze_width-1 or y == 0 or y == maze_height-1:
				row.append(CellType.WALL)  # 外墙
			else:
				row.append(CellType.PATH)  # 内部初始为路径
		maze_grid.append(row)
	
	# 使用递归分割法生成内部迷宫
	_recursive_divide(1, 1, maze_width-2, maze_height-2)
	
	# 清理入口和出口区域
	create_entrance_and_exit_fixed()
	print("迷宫生成完成")

# 递归分割法：将区域分割成更小的子区域并添加墙体
func _recursive_divide(x1: int, y1: int, x2: int, y2: int):
	"""递归分割区域，创建墙体和通道"""
	# 如果区域太小，停止分割
	if x2 - x1 < 8 or y2 - y1 < 8:  # 增加最小区域大小
		return
	
	# 计算区域大小
	var width = x2 - x1
	var height = y2 - y1
	
	# 决定水平分割还是垂直分割
	var horizontal = width < height
	
	if horizontal and height > 6:  # 增加最小高度要求
		# 计算可用于放置墙的空间
		var wall_space = height - 6  # 留出更多空间
		var wall_pos = 2  # 从距离边缘至少2格开始
		if wall_space > 0:
			wall_pos = randi() % wall_space
		var wall_y = y1 + 2 + wall_pos
		
		# 在指定y坐标创建横墙
		for x in range(x1, x2 + 1):
			if x >= 0 and x < maze_width:
				maze_grid[wall_y][x] = CellType.WALL
		
		# 在墙上开一个宽门
		var door_space = width - 4  # 留出更多门空间
		if door_space < 3:  # 确保至少3格宽的门
			door_space = 3
		var door_x = x1 + 2 + randi() % max(1, door_space - 2)
		if door_x >= 0 and door_x < maze_width:
			# 创建3格宽的门
			for dx in range(-1, 2):  # 左中右三格
				var x = door_x + dx
				if x >= 0 and x < maze_width:
					maze_grid[wall_y][x] = CellType.PATH
		
		# 递归分割上下两部分
		if wall_y - y1 > 3:
			_recursive_divide(x1, y1, x2, wall_y - 1)
		if y2 - wall_y > 3:
			_recursive_divide(x1, wall_y + 1, x2, y2)
	elif width > 6:  # 增加最小宽度要求
		# 计算可用于放置墙的空间
		var wall_space = width - 6  # 留出更多空间
		var wall_pos = 2  # 从距离边缘至少2格开始
		if wall_space > 0:
			wall_pos = randi() % wall_space
		var wall_x = x1 + 2 + wall_pos
		
		# 在指定x坐标创建竖墙
		for y in range(y1, y2 + 1):
			if y >= 0 and y < maze_height:
				maze_grid[y][wall_x] = CellType.WALL
		
		# 在墙上开一个高门
		var door_space = height - 4  # 留出更多门空间
		if door_space < 3:  # 确保至少3格高的门
			door_space = 3
		var door_y = y1 + 2 + randi() % max(1, door_space - 2)
		if door_y >= 0 and door_y < maze_height:
			# 创建3格高的门
			for dy in range(-1, 2):  # 上中下三格
				var y = door_y + dy
				if y >= 0 and y < maze_height:
					maze_grid[y][wall_x] = CellType.PATH
		
		# 递归分割左右两部分
		_recursive_divide(x1, y1, wall_x - 1, y2)
		_recursive_divide(wall_x + 1, y1, x2, y2)

# 主路径加宽函数
func _widen_main_paths(w: int):
	"""加宽迷宫中的通道，使走廊更宽敞"""
	if w <= 0:
		return
	
	var temp = []
	for row in maze_grid:
		temp.append(row.duplicate())
	
	# 对所有PATH周围w范围内设为PATH
	for y in range(1, maze_height-1):
		for x in range(1, maze_width-1):
			if maze_grid[y][x] == CellType.PATH:
				for dy in range(-w, w+1):
					for dx in range(-w, w+1):
						var nx = x + dx
						var ny = y + dy
						if nx > 0 and nx < maze_width-1 and ny > 0 and ny < maze_height-1:
							temp[ny][nx] = CellType.PATH
	
	maze_grid = temp
	print("路径加宽完成，宽度: ", w)

# 创建入口和出口区域
func create_entrance_and_exit_fixed():
	"""在迷宫中创建入口和出口区域"""
	print("创建入口和出口区域...")
	
	# 在左侧创建入口（打破外墙）
	var entrance_x = 0
	var entrance_y = int(maze_height / 2)
	
	# 在右侧创建出口（打破外墙）
	var exit_x = maze_width - 1
	var exit_y = int(maze_height / 2)
	
	# 创建入口通道（更宽的入口区域）
	for i in range(5):  # 增加到5格高
		var y = entrance_y + i - 2
		if y >= 0 and y < maze_height:
			# 创建4格宽的入口
			for x in range(5):  # 增加到5格宽
				var cur_x = entrance_x + x
				if cur_x >= 0 and cur_x < maze_width:
					maze_grid[y][cur_x] = CellType.PATH
	
	# 创建出口通道（更宽的出口区域）
	for i in range(5):  # 增加到5格高
		var y = exit_y + i - 2
		if y >= 0 and y < maze_height:
			# 创建4格宽的出口
			for x in range(5):  # 增加到5格宽
				var cur_x = exit_x - x
				if cur_x >= 0 and cur_x < maze_width:
					maze_grid[y][cur_x] = CellType.PATH
	
	# 更新入口和出口位置
	entrance_pos = Vector2i(int(entrance_x), int(entrance_y))
	exit_pos = Vector2i(int(exit_x), int(exit_y))
	
	print("入口位置: ", entrance_pos)
	print("出口位置: ", exit_pos)

func draw_maze_to_tilemap():
	"""将迷宫绘制到TileMap上"""
	print("开始将迷宫绘制到TileMap...")
	
	# 清空TileMap
	tile_map.clear()
	
	# 遍历迷宫网格，绘制到TileMap
	for y in range(maze_height):
		for x in range(maze_width):
			var cell_type = maze_grid[y][x]
			var tile_pos = Vector2i(x, y)
			
			if cell_type == CellType.WALL:
				# 设置墙壁瓦片
				tile_map.set_cell(0, tile_pos, 0, wall_tile_id)
			else:
				# 设置地板瓦片
				tile_map.set_cell(0, tile_pos, 0, floor_tile_id)
	
	# 绘制外墙边界
	for x in range(maze_width):
		tile_map.set_cell(0, Vector2i(x, 0), 0, wall_tile_id)
		tile_map.set_cell(0, Vector2i(x, maze_height - 1), 0, wall_tile_id)
	for y in range(maze_height):
		tile_map.set_cell(0, Vector2i(0, y), 0, wall_tile_id)
		tile_map.set_cell(0, Vector2i(maze_width - 1, y), 0, wall_tile_id)
	
	# 确保TileMap应用更改
	await get_tree().process_frame
	print("迷宫已成功绘制到TileMap")
	return true

func setup_player_and_doors_fixed():
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
		for y in range(entrance_pos.y - 2, entrance_pos.y + 3):
			for x in range(entrance_pos.x - 2, entrance_pos.x + 3):
				if x >= 0 and x < maze_width and y >= 0 and y < maze_height:
					maze_grid[y][x] = CellType.PATH
	
	if exit_pos.x < maze_width and exit_pos.y < maze_height:
		maze_grid[exit_pos.y][exit_pos.x] = CellType.PATH
		# 创建出口区域
		for y in range(exit_pos.y - 2, exit_pos.y + 3):
			for x in range(exit_pos.x - 2, exit_pos.x + 3):
				if x >= 0 and x < maze_width and y >= 0 and y < maze_height:
					maze_grid[y][x] = CellType.PATH
	
	# 设置门的位置
	if entry_door:
		entry_door.global_position = entrance_world_pos
		print("入口门设置在: ", entry_door.global_position)
	
	if exit_door:
		exit_door.global_position = exit_world_pos
		exit_door.requires_key = true
		exit_door.required_key_type = "master_key"
		exit_door.consume_key_on_open = true
		print("出口门设置在: ", exit_door.global_position)
	
	# 设置玩家位置在入口门旁
	if player:
		var player_offset = Vector2(20, 0) # 玩家放在入口门右侧
		player.global_position = entrance_world_pos + player_offset
		print("玩家设置在: ", player.global_position)

func ensure_path_from_entrance_to_exit():
	"""确保从入口到出口有一条可行的路径"""
	print("确保从入口到出口有一条可行路径...")
	
	# 如果入口或出口超出迷宫范围，则不处理
	if entrance_pos.x >= maze_width or entrance_pos.y >= maze_height or \
	   exit_pos.x >= maze_width or exit_pos.y >= maze_height:
		print("警告：入口或出口超出迷宫范围，无法创建路径")
		return
	
	# 创建从入口到出口的路径
	create_path_between(entrance_pos.x, entrance_pos.y, exit_pos.x, exit_pos.y)
	
	# 拓宽路径以便于导航
	widen_specific_path(entrance_pos.x, entrance_pos.y, exit_pos.x, exit_pos.y)
	
	print("入口到出口的路径已创建")

# 验证TileMap
func verify_tilemap():
	"""验证TileMap是否正确设置"""
	print("验证TileMap设置...")
	if not tile_map:
		print("错误：TileMap节点未找到")
		return
	
	# 检查TileMap的基本属性
	print("TileMap验证完成")

# 将世界坐标转换为瓦片坐标
func get_tile_position(world_pos: Vector2) -> Vector2i:
	"""将世界坐标转换为瓦片坐标"""
	if not tile_map:
		return Vector2i(0, 0)
	
	# 使用TileMap的内置方法
	var local_pos = tile_map.to_local(world_pos)
	var tile_pos = tile_map.local_to_map(local_pos)
	return tile_pos

# 在两点之间创建路径
func create_path_between(x1: int, y1: int, x2: int, y2: int):
	"""在两点之间创建路径"""
	print("在两点之间创建路径: (", x1, ",", y1, ") -> (", x2, ",", y2, ")")
	
	# 简单的A*或直线路径算法
	var current_x = x1
	var current_y = y1
	
	# 先水平移动，再垂直移动
	while current_x != x2:
		if current_x >= 0 and current_x < maze_width and current_y >= 0 and current_y < maze_height:
			maze_grid[current_y][current_x] = CellType.PATH
		
		if current_x < x2:
			current_x += 1
		else:
			current_x -= 1
	
	# 垂直移动
	while current_y != y2:
		if current_x >= 0 and current_x < maze_width and current_y >= 0 and current_y < maze_height:
			maze_grid[current_y][current_x] = CellType.PATH
		
		if current_y < y2:
			current_y += 1
		else:
			current_y -= 1
	
	# 确保终点也是路径
	if x2 >= 0 and x2 < maze_width and y2 >= 0 and y2 < maze_height:
		maze_grid[y2][x2] = CellType.PATH

# 拓宽特定路径
func widen_specific_path(x1: int, y1: int, x2: int, y2: int):
	"""拓宽从起点到终点的路径"""
	print("拓宽路径...")
	
	# 在路径周围创建更宽的通道
	var width = 2  # 路径宽度
	
	# 先水平移动，再垂直移动
	var current_x = x1
	var current_y = y1
	
	# 水平路径拓宽
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
	
	# 垂直路径拓宽
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

# 重新定位敌人和物品到迷宫内的可行走区域
func reposition_enemies_and_items_optimized():
	"""智能重新定位敌人和物品到迷宫内的合适位置"""
	print("智能重新定位敌人和物品...")
	
	# 收集所有真正安全的路径位置
	var safe_positions = []
	
	# 更严格的安全位置检查：扫描整个迷宫，确保位置周围有足够空间
	for y in range(3, maze_height-3):  # 增加边界缓冲
		for x in range(3, maze_width-3):
			if _is_truly_safe_position(x, y):
				var world_pos = tile_map.to_global(tile_map.map_to_local(Vector2i(x, y)))
				safe_positions.append(world_pos)
	
	print("找到 ", safe_positions.size(), " 个安全位置")
	
	if safe_positions.size() < 10:  # 如果安全位置太少，降低标准
		print("安全位置不足，使用宽松标准...")
		safe_positions.clear()
		for y in range(2, maze_height-2):
			for x in range(2, maze_width-2):
				if _is_basic_safe_position(x, y):
					var world_pos = tile_map.to_global(tile_map.map_to_local(Vector2i(x, y)))
					safe_positions.append(world_pos)
		print("宽松标准找到 ", safe_positions.size(), " 个位置")
	
	# 获取所有物品和敌人
	var items = get_tree().get_nodes_in_group("items")
	var enemies = get_tree().get_nodes_in_group("enemies")
	var keys = _get_nodes_by_type(items, "Key")
	var hp_beans = _get_nodes_by_type(items, "Hp_bean")
	var weapons = _get_nodes_by_type(items, "IronSword")
	
	print("物品统计:")
	print("- 钥匙: ", keys.size())
	print("- HP豆: ", hp_beans.size())
	print("- 武器: ", weapons.size())
	print("- 敌人: ", enemies.size())
	
	# 如果没有足够的安全位置，创建更多
	if safe_positions.size() < (keys.size() + hp_beans.size() + weapons.size() + enemies.size()):
		print("安全位置不足，创建额外的安全区域...")
		_create_additional_safe_areas()
		# 重新收集位置
		safe_positions.clear()
		for y in range(2, maze_height-2):
			for x in range(2, maze_width-2):
				if _is_basic_safe_position(x, y):
					var world_pos = tile_map.to_global(tile_map.map_to_local(Vector2i(x, y)))
					safe_positions.append(world_pos)
		print("创建安全区域后找到 ", safe_positions.size(), " 个位置")
	
	# 使用改进的放置策略
	var used_positions = []
	_place_keys(keys, safe_positions, used_positions, 200)
	_place_items_safely(hp_beans, safe_positions, 100)
	_place_items_safely(weapons, safe_positions, 150)
	_place_items_safely(enemies, safe_positions, 120)
	
	print("物品和敌人重新定位完成")

# 特殊处理钥匙的放置
func _place_keys(keys: Array, positions: Array, used_positions: Array, min_distance: float):
	"""特别处理钥匙的放置，确保它们放在远离墙壁的安全位置"""
	print("特别处理 ", keys.size(), " 个钥匙放置...")
    
    # 筛选出最安全的位置（远离墙壁）
	var safe_key_positions = []
	for pos in positions:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
		if _is_truly_safe_position(tile_pos.x, tile_pos.y) and not _has_nearby_wall(tile_pos.x, tile_pos.y, 2):
			safe_key_positions.append(pos)
    
	print("找到 ", safe_key_positions.size(), " 个适合放置钥匙的位置")
    
    # 如果安全位置不足，寻找更多位置
	if safe_key_positions.size() < keys.size() * 2:
		for y in range(3, maze_height-3, 2):
			for x in range(3, maze_width-3, 2):
				if safe_key_positions.size() >= keys.size() * 4:
					break
                
				if _is_basic_safe_position(x, y) and not _has_nearby_wall(x, y, 2):
					var world_pos = tile_map.to_global(tile_map.map_to_local(Vector2i(x, y)))
					if not safe_key_positions.has(world_pos):
						safe_key_positions.append(world_pos)
    
    # 打乱安全位置列表
	safe_key_positions.shuffle()
    
    # 为每个钥匙找位置
	for key in keys:
		var placed = false
		var max_attempts = 50
        
		for attempt in range(max_attempts):
			if attempt < safe_key_positions.size():
				var pos = safe_key_positions[attempt]
                
                # 检查与已使用位置的距离
				var too_close = false
				for used_pos in used_positions:
					if pos.distance_to(used_pos) < min_distance:
						too_close = true
						break
                
				if not too_close:
                    # 再次确认这个位置是安全的
					var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
					if _is_basic_safe_position(tile_pos.x, tile_pos.y) and not _has_nearby_wall(tile_pos.x, tile_pos.y, 2):
						key.global_position = pos
						used_positions.append(pos)
						print(key.name, " 成功放置在安全位置: ", pos, " (尝试次数: ", attempt + 1, ")")
						placed = true
						break
        
		if not placed:
            # 使用常规方法尝试放置
			var fallback_pos = _find_any_safe_position(positions, used_positions)
			if fallback_pos != Vector2.ZERO:
				var tile_pos = tile_map.local_to_map(tile_map.to_local(fallback_pos))
				if not _has_nearby_wall(tile_pos.x, tile_pos.y, 1):
					key.global_position = fallback_pos
					used_positions.append(fallback_pos)
					print(key.name, " 使用备用位置: ", fallback_pos)
				else:
					print("警告：无法为 ", key.name, " 找到远离墙壁的安全位置")

# 更严格的安全位置检查
func _is_truly_safe_position(x: int, y: int) -> bool:
	# 检查边界
	if x < 2 or x >= maze_width-2 or y < 2 or y >= maze_height-2:
		return false
	
	# 检查当前位置是否为路径
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	# 检查2x2范围内都是路径
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var check_x = x + dx
			var check_y = y + dy
			if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
				if maze_grid[check_y][check_x] != CellType.PATH:
					return false
	
	return true

# 基本的安全位置检查
func _is_basic_safe_position(x: int, y: int) -> bool:
	# 检查边界
	if x < 1 or x >= maze_width-1 or y < 1 or y >= maze_height-1:
		return false
	
	# 检查当前位置是否为路径
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	# 检查至少有一个相邻位置是路径
	var adjacent_paths = 0
	var directions = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	
	for dir in directions:
		var check_x = x + dir.x
		var check_y = y + dir.y
		if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
			if maze_grid[check_y][check_x] == CellType.PATH:
				adjacent_paths += 1
	
	return adjacent_paths >= 2

# 创建额外的安全区域
func _create_additional_safe_areas():
	"""在迷宫中创建额外的安全区域用于放置物品"""
	print("创建额外的安全区域...")
	
	# 在迷宫中创建一些2x2的安全区域
	var areas_created = 0
	var max_attempts = 50
	
	for attempt in range(max_attempts):
		var x = randi() % (maze_width - 4) + 2
		var y = randi() % (maze_height - 4) + 2
		
		# 检查这个区域是否可以转换为安全区域
		var can_create = true
		for dy in range(3):
			for dx in range(3):
				var check_x = x + dx
				var check_y = y + dy
				if check_x >= maze_width or check_y >= maze_height:
					can_create = false
					break
			if not can_create:
				break
		
		if can_create:
			# 创建3x3的安全区域
			for dy in range(3):
				for dx in range(3):
					var new_x = x + dx
					var new_y = y + dy
					if new_x < maze_width and new_y < maze_height:
						maze_grid[new_y][new_x] = CellType.PATH
			
			areas_created += 1
			if areas_created >= 10:  # 最多创建10个区域
				break
	
	print("创建了 ", areas_created, " 个额外的安全区域")

# 安全的物品放置函数
func _place_items_safely(items: Array, positions: Array, min_distance: float):
	"""安全地放置物品，确保不重叠"""
	if positions.is_empty() or items.is_empty():
		print("跳过物品放置：位置或物品数组为空")
		return
	
	var used_positions = []
	var max_attempts_per_item = 100  # 增加尝试次数，特别是对HP bean
	
	# 先为HP豆找安全位置
	var hp_beans = []
	var other_items = []
	for item in items:
		if item.name.begins_with("Hp_bean"):
			hp_beans.append(item)
		else:
			other_items.append(item)
	
	# 特殊处理HP豆，增加最小距离要求
	if not hp_beans.is_empty():
		_place_hp_beans(hp_beans, positions, used_positions, min_distance * 1.5)
	
	# 处理其他物品
	for item in other_items:
		var placed = false
		
		# 尝试多次放置
		for attempt in range(max_attempts_per_item):
			var candidate_pos = _find_safe_placement_position(positions, used_positions, min_distance)
			if candidate_pos != Vector2.ZERO:
				# 最后验证这个位置是否真的安全
				var tile_pos = tile_map.local_to_map(tile_map.to_local(candidate_pos))
				if _is_basic_safe_position(tile_pos.x, tile_pos.y):
					item.global_position = candidate_pos
					used_positions.append(candidate_pos)
					print(item.name, " 成功放置在: ", candidate_pos, " (尝试次数: ", attempt + 1, ")")
					placed = true
					break
		
		if not placed:
			# 如果无法安全放置，使用任意一个基本安全的位置
			var fallback_pos = _find_any_safe_position(positions, used_positions)
			if fallback_pos != Vector2.ZERO:
				item.global_position = fallback_pos
				used_positions.append(fallback_pos)
				print(item.name, " 使用备用位置: ", fallback_pos)
			else:
				print("警告：无法为 ", item.name, " 找到任何安全位置")

# 特殊处理HP豆的放置
func _place_hp_beans(beans: Array, positions: Array, used_positions: Array, min_distance: float):
	"""特别处理HP豆的放置，确保它们放在完全安全的位置"""
	print("特别处理 ", beans.size(), " 个HP豆放置...")
	
	# 筛选出最安全的位置
	var extra_safe_positions = []
	for pos in positions:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
		if _is_truly_safe_position(tile_pos.x, tile_pos.y):
			extra_safe_positions.append(pos)
	
	print("找到 ", extra_safe_positions.size(), " 个超级安全位置")
	
	# 如果安全位置不足，创建更多
	if extra_safe_positions.size() < beans.size() * 2:
		for y in range(3, maze_height-3, 3):  # 间隔搜索，提高效率
			for x in range(3, maze_width-3, 3):
				if extra_safe_positions.size() >= beans.size() * 5:
					break # 足够多了就停止搜索
					
				if _is_basic_safe_position(x, y) and not _has_nearby_wall(x, y, 2):
					var world_pos = tile_map.to_global(tile_map.map_to_local(Vector2i(x, y)))
					extra_safe_positions.append(world_pos)
	
	# 打乱安全位置列表
	extra_safe_positions.shuffle()
	
	# 为每个HP豆找位置
	for bean in beans:
		var placed = false
		var max_attempts = 100  # HP豆多尝试几次
		
		for attempt in range(max_attempts):
			if attempt < extra_safe_positions.size():
				var pos = extra_safe_positions[attempt]
				
				# 检查与已使用位置的距离
				var too_close = false
				for used_pos in used_positions:
					if pos.distance_to(used_pos) < min_distance:
						too_close = true
						break
				
				if not too_close:
					# 将世界坐标转换为瓦片坐标进行最终验证
					var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
					if _is_basic_safe_position(tile_pos.x, tile_pos.y):
						bean.global_position = pos
						used_positions.append(pos)
						print(bean.name, " 成功放置在安全位置: ", pos, " (尝试次数: ", attempt + 1, ")")
						placed = true
						break
		
		if not placed:
			# 使用常规方法尝试放置
			var fallback_pos = _find_any_safe_position(positions, used_positions)
			if fallback_pos != Vector2.ZERO:
				bean.global_position = fallback_pos
				used_positions.append(fallback_pos)
				print(bean.name, " 使用备用位置: ", fallback_pos)
			else:
				print("警告：无法为 ", bean.name, " 找到任何安全位置")

# 检查指定位置附近是否有墙
func _has_nearby_wall(x: int, y: int, radius: int) -> bool:
	for dy in range(-radius, radius+1):
		for dx in range(-radius, radius+1):
			var check_x = x + dx
			var check_y = y + dy
			if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
				if maze_grid[check_y][check_x] == CellType.WALL:
					return true
	return false

# 寻找安全的放置位置
func _find_safe_placement_position(positions: Array, used_positions: Array, min_distance: float) -> Vector2:
	# 随机打乱位置数组
	var shuffled_positions = positions.duplicate()
	shuffled_positions.shuffle()
	
	# 尝试前30个位置
	var search_count = min(30, shuffled_positions.size())
	for i in range(search_count):
		var pos = shuffled_positions[i]
		var is_safe = true
		
		# 检查与已使用位置的距离
		for used_pos in used_positions:
			if pos.distance_to(used_pos) < min_distance:
				is_safe = false
				break
		
		if is_safe:
			# 验证瓦片位置的安全性
			var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
			if _is_basic_safe_position(tile_pos.x, tile_pos.y):
				return pos
	
	return Vector2.ZERO

# 寻找任意安全位置
func _find_any_safe_position(positions: Array, used_positions: Array) -> Vector2:
	# 在所有位置中寻找第一个基本安全的位置
	for pos in positions:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
		if _is_basic_safe_position(tile_pos.x, tile_pos.y):
			# 确保与已使用位置有最小距离
			var too_close = false
			for used_pos in used_positions:
				if pos.distance_to(used_pos) < 32:  # 最小32像素距离
					too_close = true
					break
			
			if not too_close:
				return pos
	
	# 如果还找不到，返回第一个路径位置
	for pos in positions:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
		if tile_pos.x > 0 and tile_pos.x < maze_width-1 and tile_pos.y > 0 and tile_pos.y < maze_height-1:
			if maze_grid[tile_pos.y][tile_pos.x] == CellType.PATH:
				return pos
	
	return Vector2.ZERO

# 检查一个位置是否安全且适合放置物品
func _is_in_room(x: int, y: int) -> bool:
	# 首先检查当前位置是否为路径
	if x < 0 or x >= maze_width or y < 0 or y >= maze_height:
		return false
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	# 检查直接相邻的位置（1x1范围）是否有足够的空间
	var path_count = 0
	var wall_count = 0
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var check_y = y + dy
			var check_x = x + dx
			if check_y >= 0 and check_y < maze_height and check_x >= 0 and check_x < maze_width:
				if maze_grid[check_y][check_x] == CellType.PATH:
					path_count += 1
				elif maze_grid[check_y][check_x] == CellType.WALL:
					wall_count += 1
	
	# 如果周围至少有4个路径格子，且不被完全包围，就认为是安全位置
	return path_count >= 4 and wall_count <= 5

# 从物品数组中获取指定类型的节点
func _get_nodes_by_type(items: Array, type: String) -> Array:
	var result = []
	for item in items:
		if item.name.begins_with(type):
			result.append(item)
	return result

# 智能放置物品，确保它们之间有足够的距离
func _place_items_in_positions(items: Array, positions: Array, min_distance: float):
	if positions.is_empty() or items.is_empty():
		print("跳过物品放置：位置或物品数组为空")
		return
		
	var used_positions = []
	positions.shuffle() # 随机打乱位置
	
	for item in items:
		# 找到一个合适的位置
		var best_pos = _find_best_position(positions, used_positions, min_distance)
		if best_pos:
			# 将世界坐标转换为瓦片坐标进行验证
			var tile_pos = tile_map.local_to_map(tile_map.to_local(best_pos))
			
			# 验证位置的安全性
			if _is_safe_position(tile_pos.x, tile_pos.y):
				item.global_position = best_pos
				used_positions.append(best_pos)
				print(item.name, " 成功放置在瓦片: ", tile_pos, " 世界坐标: ", best_pos)
			else:
				# 如果位置不安全，寻找备用位置
				var backup_pos = _find_backup_position(positions, used_positions)
				if backup_pos:
					item.global_position = backup_pos
					used_positions.append(backup_pos)
					var backup_tile = tile_map.local_to_map(tile_map.to_local(backup_pos))
					print(item.name, " 放置在备用位置，瓦片: ", backup_tile, " 世界坐标: ", backup_pos)
				else:
					print("警告：无法为 ", item.name, " 找到安全位置")
		else:
			print("警告：无法为 ", item.name, " 找到任何位置")

# 简化的位置安全检查
func _is_safe_position(x: int, y: int) -> bool:
	# 检查边界
	if x < 1 or x >= maze_width-1 or y < 1 or y >= maze_height-1:
		return false
	
	# 检查当前位置是否为路径
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	# 检查基本的可达性（至少一个相邻位置是路径）
	var adjacent_paths = 0
	var directions = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	
	for dir in directions:
		var check_x = x + dir.x
		var check_y = y + dir.y
		if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
			if maze_grid[check_y][check_x] == CellType.PATH:
				adjacent_paths += 1
	
	# 至少需要一个相邻的路径位置
	return adjacent_paths >= 1

# 寻找备用位置
func _find_backup_position(positions: Array, used_positions: Array) -> Vector2:
	# 简单的备用策略：找到第一个安全的位置
	for pos in positions:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
		if _is_safe_position(tile_pos.x, tile_pos.y):
			# 检查与已使用位置的距离
			var too_close = false
			for used_pos in used_positions:
				if pos.distance_to(used_pos) < 50: # 最小距离50像素
					too_close = true
					break
			
			if not too_close:
				return pos
	
	# 如果找不到理想位置，返回任意一个安全位置
	for pos in positions:
		var tile_pos = tile_map.local_to_map(tile_map.to_local(pos))
		if _is_safe_position(tile_pos.x, tile_pos.y):
			return pos
	
	return Vector2.ZERO

# 寻找最佳放置位置
func _find_best_position(positions: Array, used_positions: Array, min_distance: float) -> Vector2:
	# 如果还没有使用过的位置，直接返回第一个
	if used_positions.is_empty():
		return positions[0]
	
	var best_pos = null
	var max_min_distance = 0
	
	# 打乱位置数组以获得随机性
	positions.shuffle()
	
	# 在前20个位置中寻找最佳点
	var search_count = min(20, positions.size())
	for i in range(search_count):
		var pos = positions[i]
		var min_dist = INF
		
		# 计算到已使用位置的最小距离
		for used_pos in used_positions:
			var dist = pos.distance_to(used_pos)
			min_dist = min(min_dist, dist)
		
		# 找到距离其他物品最远的位置
		if min_dist > max_min_distance:
			max_min_distance = min_dist
			best_pos = pos
			
			# 如果找到足够好的位置就提前返回
			if max_min_distance >= min_distance:
				break
	
	# 如果没找到合适的位置，返回任意一个未使用的位置
	return best_pos if best_pos else positions[0]
