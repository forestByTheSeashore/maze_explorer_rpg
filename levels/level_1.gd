# level_1.gd
extends Node2D

# Level information
var current_level_name: String = "level_1"

# Add GameManager reference
@onready var game_manager = get_node("/root/GameManager")

@onready var player = $Player
@onready var entry_door: Node = $DoorRoot/Door_entrance # Ensure name matches
@onready var exit_door: Node = $DoorRoot/Door_exit   # Ensure name matches
@onready var tile_map: TileMap = $TileMap
@onready var minimap = $CanvasLayer/MiniMap
@onready var pause_menu = get_node_or_null("CanvasLayer/PauseMenu") # Safely get pause menu node reference
@onready var ui_manager = $UiManager

# Add path display status variables
var show_path_to_key := false
var show_path_to_door := false
var path_lines := []  # Store all path lines
# New: Path display settings
var path_width := 4.0       # Path line width
var path_smoothing := true  # Whether to smooth the path
var path_gradient := true   # Whether to use gradient color

# === Items/Enemies Configuration ===
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

# Default item and enemy count configuration (will be overridden by LevelManager)
var desired_counts = {
	"Key": 1,
	"Hp_bean": 30,
	"IronSword_type0": 3,
	"IronSword_type1": 2,
	"IronSword_type2": 2,
	"IronSword_type3": 1,
	"Enemy_Goblin": 3,
	"Enemy_Skeleton": 2,
	"Enemy_Slime": 4
}

# Remove signal player_reached_exit, as we'll directly respond to the door's open event

func _ready():
	print("Level_1: _ready started...")
	
	# Play game music
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_game_music()
		print("Level_1: Started playing game music")
	else:
		print("Level_1: AudioManager not found")
	
	# Initialize path state
	show_path_to_key = false
	show_path_to_door = false
	path_lines.clear()
	
	if entry_door == null:
		push_error("Error: EntryDoor node not found in scene!")
		return
	if exit_door == null:
		push_error("Error: ExitDoor node not found in scene!")
		return

	# Check pause menu
	print("Level_1: Checking pause menu node...")
	pause_menu = get_node_or_null("CanvasLayer/PauseMenu")
	if pause_menu:
		print("Level_1: Pause menu found: ", pause_menu.name)
	else:
		print("Level_1: Warning - Pause menu not found, trying other paths...")
		# Try other possible paths
		pause_menu = get_node_or_null("PauseMenu")
		if pause_menu:
			print("Level_1: Found pause menu in root path")
		else:
			var canvas_layer = get_node_or_null("CanvasLayer")
			if canvas_layer:
				print("Level_1: Found CanvasLayer, child node list:")
				for child in canvas_layer.get_children():
					print("  - ", child.name, " (type: ", child.get_class(), ")")
			else:
				print("Level_1: Couldn't even find CanvasLayer")

	# Connect UIManager signals
	if ui_manager:
		if ui_manager.has_signal("minimap_toggled"):
			ui_manager.minimap_toggled.connect(_on_minimap_toggled)
		if ui_manager.has_signal("show_key_path_toggled"):
			ui_manager.show_key_path_toggled.connect(_on_show_key_path_toggled)
		if ui_manager.has_signal("show_door_path_toggled"):
			ui_manager.show_door_path_toggled.connect(_on_show_door_path_toggled)
		print("UIManager signals connected")
		
		# Notify UI manager of current level info
		if ui_manager.has_method("update_level_info"):
			ui_manager.update_level_info(current_level_name)
			print("Level_1: Notified UI manager of current level:", current_level_name)
		
		# Also update SaveManager's current_level_name
		var save_manager = get_node_or_null("/root/SaveManager")
		if save_manager:
			save_manager.current_level_name = current_level_name
			print("Level_1: Updated SaveManager's current level:", current_level_name)

	# 1. Entry door logic (mostly unchanged)
	# entry_door.door_opened.connect(on_entry_door_opened) # If special logic is needed when entry door opens
	# Assume the entry door has already handled its initial open state in _ready() (according to door.gd)

	# Place player at the entry door position
	if player and entry_door:
		player.global_position = entry_door.global_position + Vector2(32,10)

	# Set exit door to require key
	if exit_door:
		exit_door.requires_key = true
		exit_door.required_key_type = "master_key"
		exit_door.consume_key_on_open = true
		print("Exit door set to require key:", exit_door.required_key_type)

	# 2. Connect exit door's door_opened signal to level end handler
	if exit_door: # Ensure exit_door exists
		# Make sure exit_door actually has the door_opened signal (defined in door.gd)
		if exit_door.has_signal("door_opened"):
			exit_door.door_opened.connect(on_exit_door_has_opened)
		else:
			push_error("Error: ExitDoor does not have 'door_opened' signal!")

	# Set up node groups
	if player:
		player.add_to_group("player")
	if tile_map:
		tile_map.add_to_group("tilemap")
	if exit_door:
		exit_door.add_to_group("doors")
	if entry_door:
		entry_door.add_to_group("doors")

	# Get LevelManager configuration and generate items and enemies
	_apply_level_manager_config()
	
	# Wait one frame to ensure nodes are fully initialized
	await get_tree().process_frame
	
	# Connect player position change signal to update paths in real-time
	if player:
		# Check if player has position_changed signal
		if player.has_signal("position_changed"):
			player.position_changed.connect(_on_player_position_changed)
		else:
			# If no signal, use timer to update path periodically
			var timer = Timer.new()
			timer.wait_time = 0.1  # Update every 0.1 seconds
			timer.timeout.connect(_on_player_position_changed)
			timer.autostart = true
			add_child(timer)
			print("Level_1: Using timer to update path")
	
	# Generate items and enemies
	await _generate_level_objects()

	# Wait for navigation system to initialize
	await get_tree().process_frame
	var nav_maps = NavigationServer2D.get_maps()
	if not nav_maps.is_empty():
		NavigationServer2D.map_force_update(nav_maps[0])  # Force update the first navigation map
	await get_tree().create_timer(0.2).timeout  # Wait longer
	draw_path()

	# Ensure pause menu is initially hidden
	if pause_menu:
		pause_menu.hide()
	
	# Hide minimap by default
	if minimap:
		minimap.visible = false

func _apply_level_manager_config():
	"""Apply LevelManager configuration to current level"""
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.LEVEL_CONFIGS.has(current_level_name):
		var config = level_manager.LEVEL_CONFIGS[current_level_name]
		print("Level_1: Applying LevelManager configuration - ", current_level_name)
		
		# Update item and enemy counts
		desired_counts = {
			"Key": config.items.Key,
			"Hp_bean": config.items.Hp_bean,
			"IronSword_type0": config.items.IronSword.type0,
			"IronSword_type1": config.items.IronSword.type1,
			"IronSword_type2": config.items.IronSword.type2,
			"IronSword_type3": config.items.IronSword.type3,
			"Enemy_Goblin": config.enemies.Goblin,
			"Enemy_Skeleton": config.enemies.Skeleton,
			"Enemy_Slime": config.enemies.Slime
		}
		print("Level_1: Configuration update complete - ", desired_counts)
	else:
		print("Level_1: Using default configuration - ", desired_counts)

func _generate_level_objects():
	"""Generate level items and enemies - based on level_base.gd logic"""
	print("Level_1: Starting to generate level items and enemies...")
	
	# 1. Prepare entities (reference level_base.gd's _prepare_entities_for_placement)
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
	
	# Add all entities to the scene tree
	var all_entities_to_place_flat: Array = []
	all_entities_to_place_flat.append_array(keys_to_place)
	all_entities_to_place_flat.append_array(hp_beans_to_place)
	all_entities_to_place_flat.append_array(weapons_to_place)
	all_entities_to_place_flat.append_array(enemies_to_place)
	
	for entity_node in all_entities_to_place_flat:
		if not entity_node.is_inside_tree():
			add_child(entity_node)
		entity_node.visible = true
	
	# 2. Get different safe positions for different item types
	var general_safe_positions = _get_safe_spawn_positions_for_handmade_map()
	var enemy_safe_positions = _get_safe_positions_for_enemies()
	var weapon_safe_positions = _get_safe_positions_for_weapons()
	
	if general_safe_positions.is_empty() and enemy_safe_positions.is_empty() and weapon_safe_positions.is_empty():
		print("Level_1: Warning - No safe spawn positions found")
		return
	
	print("Level_1: Found general positions:", general_safe_positions.size(), " enemy positions:", enemy_safe_positions.size(), " weapon positions:", weapon_safe_positions.size())
	
	# 3. Use unified used positions for placement
	var globally_used_positions: Array = []
	
	# Reference level_base.gd placement strategy
	if not keys_to_place.is_empty():
		_place_keys_in_handmade_map(keys_to_place, general_safe_positions, globally_used_positions, 200.0)
	
	if not hp_beans_to_place.is_empty():
		_place_items_safely_in_handmade_map(hp_beans_to_place, general_safe_positions, globally_used_positions, 70.0, "Hp_bean")
	
	if not weapons_to_place.is_empty():
		_place_items_safely_in_handmade_map(weapons_to_place, weapon_safe_positions, globally_used_positions, 150.0, "Weapon")
	
	if not enemies_to_place.is_empty():
		_place_items_safely_in_handmade_map(enemies_to_place, enemy_safe_positions, globally_used_positions, 120.0, "Enemy")
	
	print("Level_1: Items and enemies generation complete")

func _prepare_entities_for_placement(p_desired_counts: Dictionary) -> Dictionary:
	"""Prepare entities for placement - reference level_base.gd"""
	var entities_map: Dictionary = {}
	var items_group = get_tree().get_nodes_in_group("items")
	var enemies_group = get_tree().get_nodes_in_group("enemies")
	
	# Build existing node mapping
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
		
		# Use existing nodes
		var num_to_take_from_existing = min(desired_num, existing_nodes_of_type.size())
		for i in range(num_to_take_from_existing):
			if is_instance_valid(existing_nodes_of_type[i]):
				nodes_for_this_type.append(existing_nodes_of_type[i])
		
		# Create new nodes
		var num_to_instance = desired_num - nodes_for_this_type.size()
		if num_to_instance > 0:
			if packed_scenes.has(type_str) and packed_scenes[type_str] is PackedScene:
				var packed_scene: PackedScene = packed_scenes[type_str]
				for _i in range(num_to_instance):
					var instance = packed_scene.instantiate()
					
					# Set sword type
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
					
					# Set key type
					if type_str == "Key":
						if "key_type" in instance:
							instance.key_type = "master_key"
						elif instance.has_method("set_key_type"):
							instance.set_key_type("master_key")
					
					nodes_for_this_type.append(instance)
			else:
				print("Error: PackedScene for type ", type_str, " not properly configured!")
		
		entities_map[type_str] = nodes_for_this_type
		
		# Clean up excess existing nodes
		if existing_nodes_of_type.size() > num_to_take_from_existing:
			for i in range(num_to_take_from_existing, existing_nodes_of_type.size()):
				var surplus_node = existing_nodes_of_type[i]
				if is_instance_valid(surplus_node) and surplus_node.is_inside_tree():
					print("Removing excess preset node: ", surplus_node.name)
					surplus_node.queue_free()
	
	return entities_map

func _get_nodes_by_name_prefix(nodes_array: Array, prefix: String) -> Array:
	"""Get nodes by name prefix"""
	var result = []
	for node_item in nodes_array:
		if is_instance_valid(node_item) and node_item.name.begins_with(prefix):
			result.append(node_item)
	return result

func _get_nodes_by_name_prefix_and_property(nodes_array: Array, prefix: String, prop_name: String, prop_value) -> Array:
	"""Get nodes by name prefix and property"""
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

func _get_safe_spawn_positions_for_handmade_map() -> Array:
	"""Get safe spawn positions for handmade map - using different standards for different item types"""
	var safe_positions: Array = []
	
	if not tile_map or not tile_map.tile_set:
		print("Level_1: TileMap or TileSet not initialized")
		return safe_positions
	
	var tile_size = tile_map.tile_set.tile_size
	var tile_center_offset = tile_size / 2.0
	
	# Exclude areas around important positions
	var player_pos = player.global_position
	var entry_pos = entry_door.global_position
	var exit_pos = exit_door.global_position
	var exclusion_radius = 200.0
	var door_exclusion_radius = 250.0
	
	# Traverse map to find safe positions
	var map_rect = tile_map.get_used_rect()
	print("Level_1: Map bounds: ", map_rect)
	
	# Narrow search range, avoid edge areas
	for x in range(map_rect.position.x + 4, map_rect.position.x + map_rect.size.x - 4):
		for y in range(map_rect.position.y + 4, map_rect.position.y + map_rect.size.y - 4):
			var tile_pos = Vector2i(x, y)
			
			# Check if current tile is traversable ground (0,15)
			var atlas_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
			var source_id = tile_map.get_cell_source_id(0, tile_pos)
			
			# Only generate items on valid tiles that are ground tiles (0,15)
			if source_id != -1 and atlas_coords == Vector2i(0, 15):
				# Convert to world coordinates
				var local_pos = tile_map.map_to_local(tile_pos)
				var world_pos = tile_map.to_global(local_pos + tile_center_offset)
				
				# Check if in exclusion zone
				if world_pos.distance_to(player_pos) < exclusion_radius:
					continue
				if world_pos.distance_to(entry_pos) < door_exclusion_radius:
					continue
				if world_pos.distance_to(exit_pos) < door_exclusion_radius:
					continue
				
				# Check if surrounding area is safe (using basic safety standards)
				if _is_position_safe_for_items(x, y):
					safe_positions.append(world_pos)
	
	safe_positions.shuffle()
	print("Level_1: Found ", safe_positions.size(), " safe spawn positions")
	return safe_positions

func _is_position_safe_for_items(x: int, y: int) -> bool:
	"""Check if position is safe for general items (less demanding than for enemies)"""
	# Check 5x5 area
	var floor_count = 0
	var total_count = 0
	
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var check_pos = Vector2i(x + dx, y + dy)
			var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
			var check_source_id = tile_map.get_cell_source_id(0, check_pos)
			total_count += 1
			
			# Only count ground tiles
			if check_source_id != -1 and check_atlas_coords == Vector2i(0, 15):
				floor_count += 1
	
	# Require at least 70% to be ground tiles
	var is_safe = floor_count >= total_count * 0.7
	
	# Ensure center position and direct neighbors are all ground tiles
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var core_pos = Vector2i(x + dx, y + dy)
			var core_atlas = tile_map.get_cell_atlas_coords(0, core_pos)
			var core_source = tile_map.get_cell_source_id(0, core_pos)
			
			if core_source == -1 or core_atlas != Vector2i(0, 15):
				is_safe = false
				break
	
	return is_safe

func _place_keys_in_handmade_map(keys: Array, available_positions: Array, globally_used_positions: Array, min_distance: float):
	"""Place keys in handmade map"""
	print("Level_1: Starting to place ", keys.size(), " keys...")
	
	var positions_copy = available_positions.duplicate()
	var player_pos = player.global_position
	var exit_pos = exit_door.global_position
	
	# Filter positions, prioritize positions far from exit door
	var filtered_positions = []
	for pos in positions_copy:
		if pos.distance_to(exit_pos) > 250.0:  # At least 250 pixels from exit door
			filtered_positions.append(pos)
	
	if filtered_positions.size() < keys.size():
		filtered_positions = positions_copy  # If filtered positions not enough, use all positions
	
	# Sort by distance from exit door
	filtered_positions.sort_custom(func(a, b): 
		return a.distance_to(exit_pos) > b.distance_to(exit_pos)
	)
	
	var placed_count = 0
	for key_node in keys:
		var placed_successfully = false
		
		for candidate_pos in filtered_positions:
			# Check distance from already used positions
			var too_close = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance:
					too_close = true
					break
			
			if not too_close:
				key_node.global_position = candidate_pos
				key_node.add_to_group("items")
				globally_used_positions.append(candidate_pos)
				filtered_positions.erase(candidate_pos)
				placed_successfully = true
				placed_count += 1
				print("Level_1: Key placed at: ", candidate_pos)
				break
		
		if not placed_successfully:
			print("Level_1: Warning - Could not find position for key, hiding it")
			key_node.visible = false
	
	print("Level_1: Successfully placed ", placed_count, "/", keys.size(), " keys")

func _place_items_safely_in_handmade_map(items: Array, available_positions: Array, globally_used_positions: Array, min_distance: float, category_name: String):
	"""Safely place items in handmade map"""
	if items.is_empty():
		return
	
	print("Level_1: Starting to place ", items.size(), " ", category_name)
	
	var positions_copy = available_positions.duplicate()
	positions_copy.shuffle()
	
	var placed_count = 0
	
	for item_node in items:
		var placed_successfully = false
		
		for candidate_pos in positions_copy:
			# Check distance from already used positions
			var too_close = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance:
					too_close = true
					break
			
			# Additional checks based on item type
			if not too_close:
				if category_name == "Enemy":
					if not _is_enemy_position_safe(candidate_pos, item_node):
						too_close = true
				elif category_name == "Weapon":
					if not _is_weapon_position_safe(candidate_pos, item_node):
						too_close = true
			
			if not too_close:
				item_node.global_position = candidate_pos
				# Add to appropriate group
				if category_name == "Enemy":
					item_node.add_to_group("enemies")
				else:
					item_node.add_to_group("items")
				
				globally_used_positions.append(candidate_pos)
				positions_copy.erase(candidate_pos)
				placed_successfully = true
				placed_count += 1
				print("Level_1: ", category_name, " placed at: ", candidate_pos)
				break
		
		if not placed_successfully:
			print("Level_1: Warning - Could not find position for ", category_name, ", hiding it")
			item_node.visible = false
	
	print("Level_1: Successfully placed ", placed_count, "/", items.size(), " ", category_name)

func _is_enemy_position_safe(world_pos: Vector2, enemy_node: Node2D) -> bool:
	"""Check if enemy position is safe, considering enemy volume"""
	if not tile_map:
		return false
	
	# Get enemy collision radius (more conservative estimate)
	var enemy_radius = _get_enemy_collision_radius(enemy_node)
	var tile_size = tile_map.tile_set.tile_size.x
	
	# Convert world coordinates to tile coordinates
	var center_tile_pos = tile_map.local_to_map(tile_map.to_local(world_pos))
	
	# Check tile area occupied by enemy (with larger safety margin)
	var check_range = int(ceil(enemy_radius / tile_size)) + 1  # Add 1 extra tile safety margin
	
	for dx in range(-check_range, check_range + 1):
		for dy in range(-check_range, check_range + 1):
			var check_tile_pos = Vector2i(center_tile_pos.x + dx, center_tile_pos.y + dy)
			
			# Get tile information
			var atlas_coords = tile_map.get_cell_atlas_coords(0, check_tile_pos)
			var source_id = tile_map.get_cell_source_id(0, check_tile_pos)
			
			# If it's a wall tile, reject immediately
			if source_id != -1 and atlas_coords == Vector2i(6, 0):
				return false
			
			# If it's an empty tile (outside maze), also reject
			if source_id == -1:
				return false
			
			# If it's not a ground tile, also reject
			if source_id != -1 and atlas_coords != Vector2i(0, 15):
				return false
	
	# Additional check: Ensure direct neighbors around enemy center are all safe
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbor_pos = Vector2i(center_tile_pos.x + dx, center_tile_pos.y + dy)
			var neighbor_atlas = tile_map.get_cell_atlas_coords(0, neighbor_pos)
			var neighbor_source = tile_map.get_cell_source_id(0, neighbor_pos)
			
			# Direct neighbors must all be ground tiles
			if neighbor_source == -1 or neighbor_atlas != Vector2i(0, 15):
				return false
	
	return true

func _get_enemy_collision_radius(enemy_node: Node2D) -> float:
	"""Get enemy collision radius (more conservative estimate)"""
	var enemy_name = enemy_node.name
	
	# Use larger radius to ensure safety
	if enemy_name.begins_with("Goblin"):
		return 32.0  # Increased to 32 pixels
	elif enemy_name.begins_with("Skeleton"):
		return 36.0  # Increased to 36 pixels
	elif enemy_name.begins_with("Slime"):
		return 28.0  # Increased to 28 pixels
	else:
		return 32.0  # Default 32 pixels

func _is_weapon_position_safe(world_pos: Vector2, weapon_node: Node2D) -> bool:
	"""Check if weapon position is safe, considering weapon's vertical elongated shape"""
	if not tile_map:
		return false
	
	# Approximate weapon dimensions (vertical elongated shape)
	var weapon_width = 16.0   # Smaller width
	var weapon_height = 32.0  # Larger height
	var tile_size = tile_map.tile_set.tile_size.x
	
	# Convert world coordinates to tile coordinates
	var center_tile_pos = tile_map.local_to_map(tile_map.to_local(world_pos))
	
	# Calculate tile range to check (considering vertical elongated shape)
	var width_tiles = int(ceil(weapon_width / tile_size)) + 1
	var height_tiles = int(ceil(weapon_height / tile_size)) + 1
	
	# Check rectangular area occupied by weapon
	for dx in range(-width_tiles, width_tiles + 1):
		for dy in range(-height_tiles, height_tiles + 1):
			var check_tile_pos = Vector2i(center_tile_pos.x + dx, center_tile_pos.y + dy)
			
			# Get tile information
			var atlas_coords = tile_map.get_cell_atlas_coords(0, check_tile_pos)
			var source_id = tile_map.get_cell_source_id(0, check_tile_pos)
			
			# If it's a wall tile, reject immediately
			if source_id != -1 and atlas_coords == Vector2i(6, 0):
				return false
			
			# If it's an empty tile, also reject
			if source_id == -1:
				return false
			
			# If it's not a ground tile, also reject
			if source_id != -1 and atlas_coords != Vector2i(0, 15):
				return false
	
	# Additional check: Ensure enough space around weapon (especially in vertical direction)
	# Check 2 tiles above and below center position
	for dy in range(-2, 3):
		var vertical_check_pos = Vector2i(center_tile_pos.x, center_tile_pos.y + dy)
		var vertical_atlas = tile_map.get_cell_atlas_coords(0, vertical_check_pos)
		var vertical_source = tile_map.get_cell_source_id(0, vertical_check_pos)
		
		# Vertical direction must all be ground tiles
		if vertical_source == -1 or vertical_atlas != Vector2i(0, 15):
			return false
	
	return true

func get_current_level_name() -> String:
	"""Return current level name"""
	return current_level_name

# UIManager button callback functions
func _on_minimap_toggled(enabled: bool):
	print("Minimap toggle:", enabled)
	if minimap:
		minimap.visible = enabled

func _on_show_key_path_toggled(enabled: bool):
	print("Key path toggle:", enabled)
	show_path_to_key = enabled
	if enabled:
		show_path_to_door = false
	update_paths()

func _on_show_door_path_toggled(enabled: bool):
	print("Door path toggle:", enabled)
	show_path_to_door = enabled
	if enabled:
		show_path_to_key = false
	update_paths()

func on_exit_door_has_opened(): # Called when exit door's door_opened signal is emitted
	print("Exit door opened, Level 1 complete!")
	print("Entering Level 2 - Procedural Maze Level")
	
	# Show level complete notification
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		notification_manager.notify_level_complete()
	
	# Ensure game is not paused before switching scenes
	get_tree().paused = false
	
	# Use LevelManager to switch levels
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		# Set next level name
		level_manager.next_level_name = "level_2"
		# Prepare to initialize next level
		level_manager.prepare_next_level()
		# Use scene switching
		print("Preparing to switch to base_level.tscn...")
		
		# Delay one frame before switching scenes to ensure all flags are set
		await get_tree().process_frame
		var error = get_tree().change_scene_to_file("res://levels/base_level.tscn")
		if error != OK:
			push_error("Scene switching failed! Error code: " + str(error))
	else:
		push_error("Error: LevelManager not found")

func _process(_delta):
	# Handle path display keys
	if Input.is_action_just_pressed("way_to_key"):  # F1
		print("Showing path to key")
		
		var notification_manager = get_node_or_null("/root/NotificationManager")
		
		# Check if key has been collected
		if _is_key_collected():
			# Key has been collected
			if notification_manager:
				notification_manager.notify_key_already_collected()
			show_path_to_key = false
			print("Level_1: Key already collected, suggest navigating to exit door")
		else:
			# Key is still in the scene, can show path
			show_path_to_key = !show_path_to_key
			show_path_to_door = false
			
			if notification_manager:
				if show_path_to_key:
					notification_manager.notify_navigation_to_key()
				else:
					notification_manager.notify_navigation_disabled()
			print("Level_1: Toggle key path display state: ", show_path_to_key)
		
		# Immediately update path display
		update_paths()
	
	if Input.is_action_just_pressed("way_to_door"):
		print("Showing path to door")  # F2
		show_path_to_door = !show_path_to_door
		show_path_to_key = false
		
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager:
			if show_path_to_door:
				notification_manager.notify_navigation_to_door()
			else:
				notification_manager.notify_navigation_disabled()
		
		# Immediately update path display
		update_paths()

	# Quick save and load
	if Input.is_action_just_pressed("quick_save"):  # F5
		print("Quick saving game...")
		
		var save_manager = get_node("/root/SaveManager")
		if save_manager:
			save_manager.quick_save()
		else:
			print("Error: SaveManager not found")
			var notification_manager = get_node_or_null("/root/NotificationManager")
			if notification_manager:
				notification_manager.show_error("System error: SaveManager not found")
	
	if Input.is_action_just_pressed("quick_load"):  # F6
		print("Quick loading game...")
		
		var save_manager = get_node("/root/SaveManager")
		if save_manager and save_manager.has_save():
			var save_data = save_manager.load_progress()
			if not save_data.is_empty():
				print("Loading successful, preparing to switch scenes...")
				# Here you can handle scene switching logic after loading as needed
		else:
			# Only show error notification if no save file exists
			var notification_manager = get_node_or_null("/root/NotificationManager")
			if notification_manager:
				notification_manager.show_error("No save file found")
	
	# Show gameplay tutorial
	if Input.is_action_just_pressed("show_tutorial"):  # F7
		print("Showing gameplay tutorial...")
		_show_tutorial_in_game()

# Check if key still exists in the scene
func _check_if_key_exists() -> bool:
	var items = get_tree().get_nodes_in_group("items")
	for item in items:
		if item.name.begins_with("Key") and item.visible and is_instance_valid(item):
			return true
	return false

# Check if player already has the key
func _check_if_player_has_key() -> bool:
	if player and player.has_method("has_key"):
		return player.has_key("master_key")
	return false

# Check key's overall status: whether it has been collected
func _is_key_collected() -> bool:
	# Key is considered collected if:
	# 1. Player has the key, or
	# 2. There's no visible key in the scene
	return _check_if_player_has_key() or not _check_if_key_exists()

# Force clear all paths
func clear_all_paths():
	"""Immediately clear all drawn path lines"""
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()
	show_path_to_key = false
	show_path_to_door = false
	print("Level_1: Forced clearing of all paths complete")

func update_paths():
	# Clear all existing path lines
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

	# If path display is needed, redraw
	if show_path_to_key or show_path_to_door:
		draw_path()
	else:
		print("Level_1: All paths are closed, clearing complete")

func draw_path():
	# Find key in the scene
	var key = null
	var items = get_tree().get_nodes_in_group("items")
	for item in items:
		if item.name.begins_with("Key") and item.visible and is_instance_valid(item):
			key = item
			break
	
	var door_exit = get_node("DoorRoot/Door_exit")
	
	# If key path display is requested but key has been collected, turn off key path display
	if show_path_to_key and not key:
		show_path_to_key = false
		print("Level_1: Key doesn't exist or has been collected, turning off key path display")
		return
	
	# If there's no navigation map, don't draw path
	var nav_maps = NavigationServer2D.get_maps()
	if nav_maps.is_empty():
		print("Level_1: No navigation map available")
		return
	
	var navigation_map = nav_maps[0]
	
	# Draw path to key
	if show_path_to_key and key:
		var path_to_key = NavigationServer2D.map_get_path(
			navigation_map,
			player.global_position,
			key.global_position,
			true
		)
		
		if path_to_key.size() > 1:
			var line = Line2D.new()
			line.width = path_width
			line.default_color = Color.YELLOW
			line.z_index = 10
			add_child(line)
			path_lines.append(line)
			
			for point in path_to_key:
				line.add_point(point)
			
			print("Level_1: Drawing path to key, containing ", path_to_key.size(), " points")
	
	# Draw path to door
	if show_path_to_door and door_exit:
		var path_to_door = NavigationServer2D.map_get_path(
			navigation_map,
			player.global_position,
			door_exit.global_position,
			true
		)
		
		if path_to_door.size() > 1:
			var line = Line2D.new()
			line.width = path_width
			line.default_color = Color.CYAN
			line.z_index = 10
			add_child(line)
			path_lines.append(line)
			
			for point in path_to_door:
				line.add_point(point)
			
			print("Level_1: Drawing path to door, containing ", path_to_door.size(), " points")

func toggle_pause():
	"""Toggle pause state"""
	if not pause_menu:
		print("Pause menu doesn't exist, cannot toggle pause state")
		return
	
	if get_tree().paused:
		# Currently paused, resume game
		get_tree().paused = false
		pause_menu.hide()
		print("Game resumed")
	else:
		# Currently not paused, pause game
		get_tree().paused = true
		pause_menu.show()
		print("Game paused")

func _input(event):
	"""Handle input events"""
	# Handle pause key (Escape)
	if event.is_action_pressed("ui_cancel"): # Default Escape is mapped to ui_cancel
		# Only allow pausing when game is not over
		if player != null and exit_door != null:
			toggle_pause()

	# Player interaction with exit door
	if event.is_action_pressed("interact"): # "interact" should be mapped to 'F' key
		if player and exit_door:
			# Check if player is close enough to exit door
			var distance_to_exit_door = player.global_position.distance_to(exit_door.global_position)
			if distance_to_exit_door < 30: # Interaction range, can be adjusted
				# Ensure exit_door node has interact method
				if exit_door.has_method("interact"):
					exit_door.interact() # Call interact() method in Door.gd
				else:
					push_error("Error: ExitDoor node does not have 'interact' method!")

func _on_player_position_changed():
	"""Update paths when player position changes"""
	if show_path_to_key or show_path_to_door:
		update_paths()

# Show in-game tutorial
func _show_tutorial_in_game():
	"""Display gameplay tutorial interface in-game"""
	# Dynamic loading to avoid circular references
	var tutorial_scene = load("res://scenes/tutorial.tscn")
	if not tutorial_scene:
		print("Error: Cannot load tutorial scene")
		return
	var tutorial_instance = tutorial_scene.instantiate()
	
	# Pause game
	get_tree().paused = true
	
	# Add to scene tree
	add_child(tutorial_instance)
	
	# Ensure display on top layer
	tutorial_instance.z_index = 1000
	tutorial_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	print("Level_1: Displaying gameplay tutorial interface in-game")

# Cleanup method
func _exit_tree():
	"""Clean up resources when scene exits"""
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

func _get_safe_positions_for_enemies() -> Array:
	"""Get especially safe positions for enemies"""
	var safe_positions: Array = []
	
	if not tile_map or not tile_map.tile_set:
		return safe_positions
	
	var tile_size = tile_map.tile_set.tile_size
	var tile_center_offset = tile_size / 2.0
	
	# Exclude areas around important positions
	var player_pos = player.global_position
	var entry_pos = entry_door.global_position
	var exit_pos = exit_door.global_position
	var exclusion_radius = 250.0  # Enemies need larger exclusion radius
	var door_exclusion_radius = 300.0
	
	var map_rect = tile_map.get_used_rect()
	
	# Avoid more edge areas when searching for enemies
	for x in range(map_rect.position.x + 5, map_rect.position.x + map_rect.size.x - 5):
		for y in range(map_rect.position.y + 5, map_rect.position.y + map_rect.size.y - 5):
			var tile_pos = Vector2i(x, y)
			
			var atlas_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
			var source_id = tile_map.get_cell_source_id(0, tile_pos)
			
			if source_id != -1 and atlas_coords == Vector2i(0, 15):
				var local_pos = tile_map.map_to_local(tile_pos)
				var world_pos = tile_map.to_global(local_pos + tile_center_offset)
				
				if world_pos.distance_to(player_pos) < exclusion_radius:
					continue
				if world_pos.distance_to(entry_pos) < door_exclusion_radius:
					continue
				if world_pos.distance_to(exit_pos) < door_exclusion_radius:
					continue
				
				# Use stricter enemy safety check
				if _is_position_safe_for_large_objects(x, y):
					safe_positions.append(world_pos)
	
	safe_positions.shuffle()
	return safe_positions

func _get_safe_positions_for_weapons() -> Array:
	"""Get suitable positions for weapons (considering vertical elongated shape)"""
	var safe_positions: Array = []
	
	if not tile_map or not tile_map.tile_set:
		return safe_positions
	
	var tile_size = tile_map.tile_set.tile_size
	var tile_center_offset = tile_size / 2.0
	
	# Exclude areas around important positions
	var player_pos = player.global_position
	var entry_pos = entry_door.global_position
	var exit_pos = exit_door.global_position
	var exclusion_radius = 180.0
	var door_exclusion_radius = 220.0
	
	var map_rect = tile_map.get_used_rect()
	
	# Search for suitable positions for weapons
	for x in range(map_rect.position.x + 3, map_rect.position.x + map_rect.size.x - 3):
		for y in range(map_rect.position.y + 3, map_rect.position.y + map_rect.size.y - 3):
			var tile_pos = Vector2i(x, y)
			
			var atlas_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
			var source_id = tile_map.get_cell_source_id(0, tile_pos)
			
			if source_id != -1 and atlas_coords == Vector2i(0, 15):
				var local_pos = tile_map.map_to_local(tile_pos)
				var world_pos = tile_map.to_global(local_pos + tile_center_offset)
				
				if world_pos.distance_to(player_pos) < exclusion_radius:
					continue
				if world_pos.distance_to(entry_pos) < door_exclusion_radius:
					continue
				if world_pos.distance_to(exit_pos) < door_exclusion_radius:
					continue
				
				# Use weapon-specific safety check
				if _is_position_safe_for_weapons(x, y):
					safe_positions.append(world_pos)
	
	safe_positions.shuffle()
	return safe_positions

func _is_position_safe_for_large_objects(x: int, y: int) -> bool:
	"""Check if position is safe for large objects (like enemies)"""
	# Check larger area 7x7
	var floor_count = 0
	var total_count = 0
	
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var check_pos = Vector2i(x + dx, y + dy)
			var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
			var check_source_id = tile_map.get_cell_source_id(0, check_pos)
			total_count += 1
			
			# Only count ground tiles
			if check_source_id != -1 and check_atlas_coords == Vector2i(0, 15):
				floor_count += 1
	
	# Require at least 85% to be ground tiles to be considered safe for enemies
	var is_safe = floor_count >= total_count * 0.85
	
	# Additional check: Ensure the center 3x3 area is all ground tiles
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var core_pos = Vector2i(x + dx, y + dy)
			var core_atlas = tile_map.get_cell_atlas_coords(0, core_pos)
			var core_source = tile_map.get_cell_source_id(0, core_pos)
			
			if core_source == -1 or core_atlas != Vector2i(0, 15):
				is_safe = false
				break
	
	return is_safe

func _is_position_safe_for_weapons(x: int, y: int) -> bool:
	"""Check if position is safe for weapons (considering vertical elongated shape)"""
	# Check rectangular area needed for weapon (focus on vertical direction)
	# Check vertical corridor 2 tiles above and below center
	for dy in range(-2, 3):
		var check_pos = Vector2i(x, y + dy)
		var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
		var check_source_id = tile_map.get_cell_source_id(0, check_pos)
		
		# Vertical corridor must all be ground tiles
		if check_source_id == -1 or check_atlas_coords != Vector2i(0, 15):
			return false
	
	# Check horizontal neighbors
	for dx in range(-1, 2):
		var check_pos = Vector2i(x + dx, y)
		var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
		var check_source_id = tile_map.get_cell_source_id(0, check_pos)
		
		# Horizontal neighbors should also be ground tiles
		if check_source_id == -1 or check_atlas_coords != Vector2i(0, 15):
			return false
	
	return true
