extends Control

# 小地图配置
@export_group("地图设置")
@export var map_size: Vector2 = Vector2(200, 200)
@export var map_margin: int = 10
@export var show_grid: bool = true
@export var grid_size: int = 16
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.3)

@export_group("标记设置")
@export var player_marker_size: float = 6.0
@export var item_marker_size: float = 4.0
@export var player_color: Color = Color(0, 1, 0)  # 绿色
@export var key_color: Color = Color(1, 1, 0)     # 黄色
@export var door_color: Color = Color(0, 0.7, 1)  # 蓝色
@export var enemy_color: Color = Color(1, 0, 0)   # 红色
@export var border_color: Color = Color(1, 1, 1)  # 白色

# 节点引用
var player: Node2D
var level: Node2D
var tile_map: TileMap

# 地图状态
var world_rect: Rect2
var scale_factor: Vector2
var show_minimap: bool = true
var needs_redraw: bool = true

# 缓存
var _cached_grid_points: Array[Vector2] = []
var _last_player_pos: Vector2
var _last_player_angle: float

func _ready() -> void:
	# 设置位置和大小
	anchors_preset = Control.PRESET_TOP_RIGHT
	global_position = Vector2(get_viewport_rect().size.x - map_size.x - map_margin, map_margin)
	custom_minimum_size = map_size
	size = map_size

	# 先初始化世界边界，确保 scale_factor 有效
	calculate_world_bounds()

	# 初始化
	call_deferred("initialize_map")

	# 预计算网格点
	if show_grid:
		_precalculate_grid_points()

func initialize_map() -> void:
	# 获取必要节点
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("未找到玩家节点！")
		return
	
	level = player.get_parent()
	if not level:
		push_error("无法确定关卡节点！")
		return
	
	tile_map = level.get_node_or_null("TileMap")
	if not tile_map:
		push_error("未找到TileMap节点！")
		return
	
	# 计算世界边界
	calculate_world_bounds()
	
	# 设置定时更新
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = false
	timer.timeout.connect(calculate_world_bounds)
	add_child(timer)
	timer.start()

func _process(_delta: float) -> void:
	# 切换显示
	if Input.is_action_just_pressed("toggle_minimap"):
		show_minimap = !show_minimap
		visible = show_minimap
		needs_redraw = true
	
	# 检查是否需要重绘
	if show_minimap and is_instance_valid(player):
		var current_pos = player.global_position
		var current_angle = player.rotation
		
		if current_pos != _last_player_pos or current_angle != _last_player_angle:
			needs_redraw = true
			_last_player_pos = current_pos
			_last_player_angle = current_angle
	
	# 重绘
	if needs_redraw:
		queue_redraw()
		needs_redraw = false

func _draw() -> void:
	if not show_minimap or not player or not level or not world_rect:
		return

	# 绘制背景
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0, 0, 0, 0.7), true)

	# 计算小地图在世界中的显示区域
	var half_map_size = map_size / (2 * scale_factor)
	var min_x = world_rect.position.x + half_map_size.x
	var max_x = world_rect.position.x + world_rect.size.x - half_map_size.x
	var min_y = world_rect.position.y + half_map_size.y
	var max_y = world_rect.position.y + world_rect.size.y - half_map_size.y

	# 计算小地图中心点（受限于世界边界）
	var center_x = clamp(player.global_position.x, min_x, max_x)
	var center_y = clamp(player.global_position.y, min_y, max_y)
	var map_center_world = Vector2(center_x, center_y)
	var map_center_screen = map_size / 2

	# 绘制网格
	if show_grid:
		_draw_grid_with_center(map_center_world, map_center_screen)

	# 绘制边界
	draw_rect(Rect2(Vector2.ZERO, map_size), border_color, false, 2.0)

	# 绘制玩家
	_draw_player_marker(map_center_screen, player.global_position, map_center_world)

	# 绘制物品和门
	_draw_items_and_doors_with_center(map_center_world, map_center_screen)

	# 绘制敌人
	_draw_enemies_with_center(map_center_world, map_center_screen)

func calculate_world_bounds() -> void:
	if not level:
		return
	
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	# 检查TileMap边界
	if tile_map:
		var rect = tile_map.get_used_rect()
		var cell_size = tile_map.tile_set.tile_size
		min_pos = Vector2(min(min_pos.x, rect.position.x * cell_size.x),
						 min(min_pos.y, rect.position.y * cell_size.y))
		max_pos = Vector2(max(max_pos.x, (rect.position.x + rect.size.x) * cell_size.x),
						 max(max_pos.y, (rect.position.y + rect.size.y) * cell_size.y))
	
	# 考虑所有可见节点
	for node in level.get_children():
		if node is Node2D and node.visible:
			min_pos.x = min(min_pos.x, node.global_position.x - 100)
			min_pos.y = min(min_pos.y, node.global_position.y - 100)
			max_pos.x = max(max_pos.x, node.global_position.x + 100)
			max_pos.y = max(max_pos.y, node.global_position.y + 100)
	
	# 更新世界边界
	world_rect = Rect2(min_pos, max_pos - min_pos)
	
	# 计算缩放因子
	scale_factor = Vector2(
		map_size.x / world_rect.size.x,
		map_size.y / world_rect.size.y
	)
	
	# 保持纵横比
	var min_scale = min(scale_factor.x, scale_factor.y)
	scale_factor = Vector2(min_scale, min_scale)
	
	needs_redraw = true

func world_to_map(world_pos: Vector2) -> Vector2:
	var rel_pos = world_pos - world_rect.position
	return rel_pos * scale_factor

func _precalculate_grid_points() -> void:
	_cached_grid_points.clear()
	var grid_step = grid_size * scale_factor.x
	if grid_step == 0:
		print("警告：小地图 grid_step 为 0，跳过网格点计算")
		return  # 防止崩溃

	# 预计算网格线端点
	for x in range(0, int(map_size.x) + int(grid_step), int(grid_step)):
		_cached_grid_points.append(Vector2(x, 0))
		_cached_grid_points.append(Vector2(x, map_size.y))

	for y in range(0, int(map_size.y) + int(grid_step), int(grid_step)):
		_cached_grid_points.append(Vector2(0, y))
		_cached_grid_points.append(Vector2(map_size.x, y))

func _draw_grid_with_center(center_world: Vector2, center_screen: Vector2) -> void:
	if _cached_grid_points.is_empty():
		return
	var center_map = world_to_map(center_world)
	for i in range(0, _cached_grid_points.size(), 2):
		var p1 = _cached_grid_points[i] - center_map + center_screen
		var p2 = _cached_grid_points[i + 1] - center_map + center_screen
		draw_line(p1, p2, grid_color)

func _draw_player_marker(center_screen: Vector2, player_world: Vector2, map_center_world: Vector2) -> void:
	# 玩家在小地图上的位置
	var player_map_pos = world_to_map(player_world) - world_to_map(map_center_world) + center_screen
	# 绘制玩家标记（三角形）
	var player_direction = Vector2.RIGHT.rotated(player.rotation)
	var angle = player_direction.angle()
	var points = PackedVector2Array([
		player_map_pos + Vector2(0, -player_marker_size).rotated(angle),
		player_map_pos + Vector2(-player_marker_size/2, player_marker_size/2).rotated(angle),
		player_map_pos + Vector2(player_marker_size/2, player_marker_size/2).rotated(angle)
	])
	draw_colored_polygon(points, player_color)

func _draw_items_and_doors_with_center(center_world: Vector2, center_screen: Vector2) -> void:
	var center_map = world_to_map(center_world)
	# 钥匙
	var keys = get_tree().get_nodes_in_group("keys")
	for key in keys:
		if is_instance_valid(key) and key.visible:
			var key_pos = world_to_map(key.global_position) - center_map + center_screen
			draw_circle(key_pos, item_marker_size, key_color)
	# 门
	var doors = get_tree().get_nodes_in_group("doors")
	for door in doors:
		if is_instance_valid(door) and door.visible:
			var door_pos = world_to_map(door.global_position) - center_map + center_screen
			draw_rect(Rect2(door_pos - Vector2(item_marker_size, item_marker_size)/2, Vector2(item_marker_size, item_marker_size)), door_color, true)

func _draw_enemies_with_center(center_world: Vector2, center_screen: Vector2) -> void:
	var center_map = world_to_map(center_world)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.visible:
			var enemy_pos = world_to_map(enemy.global_position) - center_map + center_screen
			draw_circle(enemy_pos, item_marker_size/1.5, enemy_color)
