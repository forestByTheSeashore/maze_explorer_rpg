extends Control

# Minimap configuration
@export_group("Map Settings")
@export var map_size: Vector2 = Vector2(200, 200)
@export var map_margin: int = 10
@export var show_grid: bool = true
@export var grid_size: int = 16
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.3)

@export_group("Marker Settings")
@export var player_marker_size: float = 6.0
@export var item_marker_size: float = 4.0
@export var player_color: Color = Color(0, 1, 0)  # Green
@export var key_color: Color = Color(1, 1, 0)     # Yellow
@export var door_color: Color = Color(0, 0.7, 1)  # Blue
@export var enemy_color: Color = Color(1, 0, 0)   # Red
@export var border_color: Color = Color(1, 1, 1)  # White

# Node references
var player: Node2D
var level: Node2D
var tile_map: TileMap

# Map state
var world_rect: Rect2
var scale_factor: Vector2
var show_minimap: bool = true
var needs_redraw: bool = true

# Cache
var _cached_grid_points: Array[Vector2] = []
var _last_player_pos: Vector2
var _last_player_angle: float

func _ready() -> void:
	# Set position and size
	anchors_preset = Control.PRESET_TOP_RIGHT
	global_position = Vector2(get_viewport_rect().size.x - map_size.x - map_margin, map_margin + 110)
	custom_minimum_size = map_size
	size = map_size

	# Initialize world bounds first to ensure scale_factor is valid
	calculate_world_bounds()

	# Initialize
	call_deferred("initialize_map")

	# Precalculate grid points
	if show_grid:
		_precalculate_grid_points()

func initialize_map() -> void:
	# Get necessary nodes
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("Player node not found!")
		return
	
	level = player.get_parent()
	if not level:
		push_error("Cannot determine level node!")
		return
	
	tile_map = level.get_node_or_null("TileMap")
	if not tile_map:
		push_error("TileMap node not found!")
		return
	
	# Calculate world bounds
	calculate_world_bounds()
	
	# Set up periodic updates
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = false
	timer.timeout.connect(calculate_world_bounds)
	add_child(timer)
	timer.start()

func _process(_delta: float) -> void:
	# Toggle display
	if Input.is_action_just_pressed("toggle_minimap"):
		show_minimap = !show_minimap
		visible = show_minimap
		needs_redraw = true
	
	# Check if redraw is needed
	if show_minimap and is_instance_valid(player):
		var current_pos = player.global_position
		var current_angle = player.rotation
		
		if current_pos != _last_player_pos or current_angle != _last_player_angle:
			needs_redraw = true
			_last_player_pos = current_pos
			_last_player_angle = current_angle
	
	# Redraw
	if needs_redraw:
		queue_redraw()
		needs_redraw = false

func _draw() -> void:
	if not show_minimap or not player or not level or not world_rect:
		return

	# Draw background
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0, 0, 0, 0.7), true)

	# Calculate minimap display area in world space
	var half_map_size = map_size / (2 * scale_factor)
	var min_x = world_rect.position.x + half_map_size.x
	var max_x = world_rect.position.x + world_rect.size.x - half_map_size.x
	var min_y = world_rect.position.y + half_map_size.y
	var max_y = world_rect.position.y + world_rect.size.y - half_map_size.y

	# Calculate minimap center point (constrained by world bounds)
	var center_x = clamp(player.global_position.x, min_x, max_x)
	var center_y = clamp(player.global_position.y, min_y, max_y)
	var map_center_world = Vector2(center_x, center_y)
	var map_center_screen = map_size / 2

	# Draw grid
	if show_grid:
		_draw_grid_with_center(map_center_world, map_center_screen)

	# Draw border
	draw_rect(Rect2(Vector2.ZERO, map_size), border_color, false, 2.0)

	# Draw player
	_draw_player_marker(map_center_screen, player.global_position, map_center_world)

	# Draw items and doors
	_draw_items_and_doors_with_center(map_center_world, map_center_screen)

	# Draw enemies
	_draw_enemies_with_center(map_center_world, map_center_screen)

func calculate_world_bounds() -> void:
	if not level:
		return
	
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	# Check TileMap bounds
	if tile_map:
		var rect = tile_map.get_used_rect()
		var cell_size = tile_map.tile_set.tile_size
		min_pos = Vector2(min(min_pos.x, rect.position.x * cell_size.x),
						 min(min_pos.y, rect.position.y * cell_size.y))
		max_pos = Vector2(max(max_pos.x, (rect.position.x + rect.size.x) * cell_size.x),
						 max(max_pos.y, (rect.position.y + rect.size.y) * cell_size.y))
	
	# Consider all visible nodes
	for node in level.get_children():
		if node is Node2D and node.visible:
			min_pos.x = min(min_pos.x, node.global_position.x - 100)
			min_pos.y = min(min_pos.y, node.global_position.y - 100)
			max_pos.x = max(max_pos.x, node.global_position.x + 100)
			max_pos.y = max(max_pos.y, node.global_position.y + 100)
	
	# Update world bounds
	world_rect = Rect2(min_pos, max_pos - min_pos)
	
	# Calculate scale factors
	scale_factor = Vector2(
		map_size.x / world_rect.size.x,
		map_size.y / world_rect.size.y
	)
	
	# Maintain aspect ratio
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
		print("Warning: Minimap grid_step is 0, skipping grid point calculation")
		return  # Prevent crash

	# Precalculate grid line endpoints
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
	# Player position on minimap
	var player_map_pos = world_to_map(player_world) - world_to_map(map_center_world) + center_screen
	# Draw player marker (triangle)
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
	# Keys
	var keys = get_tree().get_nodes_in_group("keys")
	for key in keys:
		if is_instance_valid(key) and key.visible:
			var key_pos = world_to_map(key.global_position) - center_map + center_screen
			draw_circle(key_pos, item_marker_size, key_color)
	# Doors
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
