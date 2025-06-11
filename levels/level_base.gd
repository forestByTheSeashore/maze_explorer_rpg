extends Node2D

# === Node References ===
@onready var player = $Player
@onready var entry_door: Node = $DoorRoot/Door_entrance
@onready var exit_door: Node = $DoorRoot/Door_exit
@onready var tile_map: TileMap = $TileMap
@onready var minimap = $CanvasLayer/MiniMap
@onready var pause_menu = get_node_or_null("CanvasLayer/PauseMenu") # Add pause menu reference
@onready var ui_manager = $UiManager

# === Maze Generation Parameters ===
@export var maze_width: int = 81   # Maze width
@export var maze_height: int = 81  # Maze height
@export var wall_tile_id: Vector2i = Vector2i(6, 0)      # Wall tile ID (with collision)
@export var floor_tile_id: Vector2i = Vector2i(0, 15)    # Floor tile ID (navigation layer)
@export var corridor_width: int = 8  # Corridor width

# Maze data structure
var maze_grid: Array = []
var entrance_pos: Vector2i
var exit_pos: Vector2i

# Four directions (right, down, left, up)
const DIRECTIONS = [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2)]

# Enum type
enum CellType { WALL, PATH }

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

# Item and enemy count configuration
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

# Add path display status variables
var show_path_to_key := false
var show_path_to_door := false
var path_lines := []  # Store all path lines

# New: Path display settings (unified with Level1 approach)
var path_width := 4.0       # Path line width
var path_smoothing := true  # Whether to smooth the path
var path_gradient := true   # Whether to use gradient color

# Unified color scheme
const PATH_COLORS = {
	"key": Color.YELLOW,      # Key path: yellow
	"door": Color.CYAN,       # Door path: cyan
	"weapon": Color.GREEN,    # Weapon path: green (extension)
	"hp": Color.ORANGE        # HP bean path: orange (extension)
}

# Current level name (set by LevelManager)
var current_level_name: String = ""

func _ready():
	print("=== Level Initialization Started ===")
	print("Current scene name: ", scene_file_path)
	print("Current node name: ", name)
	
	# Play game music
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_game_music()
		print("LevelBase: Started playing game music")
	else:
		print("LevelBase: AudioManager not found")
	
	# Initialize path state (unified with Level1 approach)
	show_path_to_key = false
	show_path_to_door = false
	path_lines.clear()
	
	# Connect signals with UIManager
	if ui_manager:
		if ui_manager.has_signal("minimap_toggled"):
			ui_manager.minimap_toggled.connect(_on_minimap_toggled)
		if ui_manager.has_signal("show_key_path_toggled"):
			ui_manager.show_key_path_toggled.connect(_on_show_key_path_toggled)
		if ui_manager.has_signal("show_door_path_toggled"):
			ui_manager.show_door_path_toggled.connect(_on_show_door_path_toggled)
		print("UIManager signals connected")
	
	# Only do node references and grouping
	if player:
		player.add_to_group("player")
		player.visible = true  # Ensure player is visible
		# Ensure the visible child nodes of the player are visible (skip nodes that don't support visible property)
		for child in player.get_children():
			if child.has_method("set_visible") or "visible" in child:
				child.visible = true
		print("Player node status:", "exists" if player else "does not exist")
		print("Player visibility:", player.visible)
		print("Player position:", player.global_position)
	else:
		push_error("Player node does not exist!")
	
	if tile_map:
		tile_map.add_to_group("tilemap")
		print("TileMap added to group")
	else:
		push_error("TileMap node does not exist!")
	
	if exit_door:
		exit_door.add_to_group("doors")
		print("Exit door added to group")
	else:
		push_error("Exit door node does not exist!")
	
	if entry_door:
		entry_door.add_to_group("doors")
		print("Entry door added to group")
	else:
		push_error("Entry door node does not exist!")
	
	# Get LevelManager and connect signals
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		print("Found LevelManager, connecting signals")
		# Ensure no duplicate connections
		if level_manager.level_ready_to_initialize.is_connected(_on_level_ready_to_initialize):
			level_manager.level_ready_to_initialize.disconnect(_on_level_ready_to_initialize)
		
		# Connect signal
		level_manager.level_ready_to_initialize.connect(_on_level_ready_to_initialize)
		
		# If LevelManager is ready to initialize, immediately call initialization
		if level_manager._should_initialize and level_manager.next_level_name != "":
			print("LevelManager ready to initialize, initializing level immediately")
			print("LevelManager.next_level_name:", level_manager.next_level_name)
			
			# Check if level configuration exists
			if level_manager.LEVEL_CONFIGS.has(level_manager.next_level_name):
				await level_manager.initialize_level()
			else:
				print("LevelManager not ready for initialization, using default configuration")
				current_level_name = "level_2" # Default to level_2
				await init_level()
	else:
		print("LevelManager not found, using default configuration")
		current_level_name = "level_2" # Default to level_2
		await init_level()
		
		print("=== Level Initialization Completed ===")

	# Default hide minimap
	if minimap:
		minimap.visible = false
	
	# Ensure pause menu is initially hidden, game is not paused
	if pause_menu:
		pause_menu.hide()
		print("Pause menu hidden")
	else:
		print("Warning: Pause menu node not found")
	
	# Ensure game is not paused
	get_tree().paused = false
	print("Game pause state reset to:", get_tree().paused)

# Signal processing function
func _on_level_ready_to_initialize(level_name: String):
	print("Received level_ready_to_initialize signal, level name:", level_name)
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		print("Calling LevelManager.initialize_level()")
		await level_manager.initialize_level()
	else:
		push_error("Signal processing failed to find LevelManager!")

func init_level() -> void:
	print("=== Programmatic Maze Generation Started ===")
	print("Current level:", current_level_name if current_level_name != "" else "Unknown")
	print("Caller:", get_stack()[1]["function"] if get_stack().size() > 1 else "Unknown")
	print("Maze configuration: width=", maze_width, " height=", maze_height, " corridor width=", corridor_width)

	# Ensure node is already in the scene tree
	if not is_inside_tree():
		push_error("Node not added to scene tree yet, cannot initialize level")
		return

	# Notify UI manager about current level information
	if ui_manager and current_level_name != "":
		if ui_manager.has_method("update_level_info"):
			ui_manager.update_level_info(current_level_name)
			print("LevelBase: UI manager notified about current level:", current_level_name)
	
	# Also update SaveManager's current_level_name
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and current_level_name != "":
		save_manager.current_level_name = current_level_name
		print("LevelBase: SaveManager's current level updated:", current_level_name)

	# Connect signal for opening exit door
	if exit_door:
		if exit_door.has_signal("door_opened"):
			# First, disconnect any existing connections
			if exit_door.door_opened.is_connected(on_exit_door_has_opened):
				exit_door.door_opened.disconnect(on_exit_door_has_opened)
			# Reconnect signal
			exit_door.door_opened.connect(on_exit_door_has_opened)
			print("Exit door open signal connected")
		else:
			print("Warning: Exit door does not have 'door_opened' signal!")

	print("Step 1: Starting maze generation...")
	generate_optimized_maze()
	print("Step 1: Maze generation completed")

	print("Step 2: Starting to draw maze to TileMap...")
	await draw_maze_to_tilemap()
	print("Step 2: TileMap drawing completed")

	print("Step 3: Setting player and doors' positions...")
	setup_player_and_doors_fixed()
	print("Step 3: Player and doors settings completed")

	await get_tree().process_frame
	verify_tilemap()

	print("Step 4: Ensuring there's a path from entrance to exit...")
	ensure_path_from_entrance_to_exit()

	print("Step 4.5: Validating and improving maze quality...")
	validate_and_improve_maze_quality()

	print("Step 5: Redrawing maze...")
	await draw_maze_to_tilemap()

	print("Step 6: Repositioning enemies and items...")
	reposition_enemies_and_items_optimized()
	print("Step 6: Enemy and item repositioning completed")

	# Final navigation grid update and validation
	print("Step 7: Final navigation grid update...")
	var nav_maps = NavigationServer2D.get_maps()
	if not nav_maps.is_empty():
		NavigationServer2D.map_force_update(nav_maps[0])
		await get_tree().create_timer(0.5).timeout  # Longer wait time
		print("LevelBase: Final navigation grid update completed")

	# Set position tracking (unified with Level1 approach)
	_setup_position_tracking()

	draw_path()
	print("=== Maze Generation Completed ===")

func _process(_delta):
	# Handle path display key presses
	if Input.is_action_just_pressed("way_to_key"):  # F1
		_handle_key_navigation()
	
	if Input.is_action_just_pressed("way_to_door"):  # F2
		_handle_door_navigation()

	# Player interaction with exit door
	if Input.is_action_just_pressed("interact"):
		if player and exit_door:
			var distance_to_exit_door = player.global_position.distance_to(exit_door.global_position)
			if distance_to_exit_door < 30:
				if exit_door.has_method("interact"):
					exit_door.interact()
				else:
					print("Error: Exit door node does not have 'interact' method!")

	# Handle pause key press (Escape)
	if Input.is_action_just_pressed("ui_cancel"): # Default Escape mapping to ui_cancel
		# Can only pause if game is not over
		if is_instance_valid(player) and is_instance_valid(exit_door):
			toggle_pause()

# Exit door opened processing function
func on_exit_door_has_opened():
	print("Exit door opened, current level completed!")
	
	# Play level completion sound and effect
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		audio_manager.play_level_complete_sound()
	
	var effects_manager = get_node_or_null("/root/EffectsManager")
	if effects_manager and exit_door and is_instance_valid(exit_door):
		print("LevelBase: Playing level completion effect")
		effects_manager.play_level_complete_effect(exit_door.global_position)
	else:
		print("LevelBase: Skipping effect - EffectsManager or exit_door invalid")
	
	# Update victory manager
	var victory_manager = get_node_or_null("/root/VictoryManager")
	if victory_manager:
		victory_manager.mark_level_completed(current_level_name)
	
	# Ensure game is not paused before switching scene
	get_tree().paused = false
	
	var next_level = get_next_level_name()
	if next_level:
		print("Switching to next level:", next_level)
		# Use correct LevelManager mechanism
		var level_manager = get_node("/root/LevelManager")
		if level_manager:
			level_manager.next_level_name = next_level
			level_manager.prepare_next_level()  # Add this line
			# Use scene switching instead of node management
			get_tree().change_scene_to_file("res://levels/base_level.tscn")
		else:
			print("Error: LevelManager not found")
	else:
		print("Congratulations! You've completed all levels!")
		# Game end handling will be handled automatically by VictoryManager

# Get next level name
func get_next_level_name() -> String:
	var level_manager = get_node("/root/LevelManager")
	if level_manager and current_level_name != "":
		return level_manager.get_next_level_name(current_level_name)
	return ""

# Get current level name (for UI system)
func get_current_level_name() -> String:
	return current_level_name

# Recursive division method to generate maze
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
	
	# Draw maze to TileMap
	for y in range(maze_height):
		for x in range(maze_width):
			var cell_type = maze_grid[y][x]
			var tile_pos = Vector2i(x, y)
			if cell_type == CellType.WALL:
				tile_map.set_cell(0, tile_pos, 0, wall_tile_id)
			else:
				tile_map.set_cell(0, tile_pos, 0, floor_tile_id)
	
	# Add boundary walls
	for x in range(maze_width):
		tile_map.set_cell(0, Vector2i(x, 0), 0, wall_tile_id)
		tile_map.set_cell(0, Vector2i(x, maze_height - 1), 0, wall_tile_id)
	for y in range(maze_height):
		tile_map.set_cell(0, Vector2i(0, y), 0, wall_tile_id)
		tile_map.set_cell(0, Vector2i(maze_width - 1, y), 0, wall_tile_id)
	
	# Force update navigation grid (fixing wall-through problem)
	await get_tree().process_frame
	await get_tree().process_frame  # Double wait to ensure update is complete
	
	var nav_maps = NavigationServer2D.get_maps()
	if not nav_maps.is_empty():
		print("LevelBase: Force updating navigation grid...")
		NavigationServer2D.map_force_update(nav_maps[0])
		# Wait for navigation grid update to complete
		await get_tree().create_timer(0.3).timeout
		print("LevelBase: Navigation grid update completed")
	else:
		print("LevelBase: Warning - Navigation grid not found")

func setup_player_and_doors_fixed():
	# Prevent maze_grid from being uninitialized causing out-of-bounds
	if maze_grid.is_empty() or maze_grid[0].is_empty():
		print("Error: maze_grid not initialized, cannot set doors and player positions!")
		return
	"""Set player and doors' positions (using fixed coordinates)"""
	print("Setting player and doors' positions...")
	
	# Fixed entrance and exit door positions
	var entrance_world_pos = Vector2(10, 31)
	var exit_world_pos = Vector2(1288, 1264)
	
	# Ensure tile of door position is floor
	entrance_pos = get_tile_position(entrance_world_pos)
	exit_pos = get_tile_position(exit_world_pos)
	
	# Ensure entrance and exit positions are paths
	if entrance_pos.x < maze_width and entrance_pos.y < maze_height:
		maze_grid[entrance_pos.y][entrance_pos.x] = CellType.PATH
		# Create entrance area
		for y in range(entrance_pos.y - 3, entrance_pos.y + 4):
			for x in range(entrance_pos.x - 3, entrance_pos.x + 4):
				if x >= 0 and x < maze_width and y >= 0 and y < maze_height:
					maze_grid[y][x] = CellType.PATH
	
	if exit_pos.x < maze_width and exit_pos.y < maze_height:
		maze_grid[exit_pos.y][exit_pos.x] = CellType.PATH
		# Create exit area
		for y in range(exit_pos.y - 3, exit_pos.y + 4):
			for x in range(exit_pos.x - 3, exit_pos.x + 4):
				if x >= 0 and x < maze_width and y >= 0 and y < maze_height:
					maze_grid[y][x] = CellType.PATH
	
	# Set doors' positions
	if entry_door:
		entry_door.global_position = entrance_world_pos + Vector2(0,50)
		entry_door.visible = true
		entry_door.z_index = 10
		print("Entry door set at:", entry_door.global_position)
	
	if exit_door:
		exit_door.global_position = exit_world_pos
		exit_door.requires_key = true
		exit_door.required_key_type = "master_key"
		exit_door.consume_key_on_open = true
		exit_door.visible = true
		exit_door.z_index = 10
		print("Exit door set at:", exit_door.global_position)
	
	# Set player position and visibility
	if player:
		player.global_position = entry_door.global_position + Vector2(20,0)
		player.visible = true
		player.z_index = 5  # Ensure player is at appropriate level
		# Ensure visible child nodes of the player are visible (skip nodes that don't support visible property)
		for child in player.get_children():
			if child.has_method("set_visible") or "visible" in child:
				child.visible = true
		print("Player set at:", player.global_position)
		print("Player visibility:", player.visible)

func verify_tilemap():
	if not tile_map:
		return

func ensure_path_from_entrance_to_exit():
	if entrance_pos.x >= maze_width or entrance_pos.y >= maze_height or exit_pos.x >= maze_width or exit_pos.y >= maze_height:
		return
	create_path_between(entrance_pos.x, entrance_pos.y, exit_pos.x, exit_pos.y)
	widen_specific_path(entrance_pos.x, entrance_pos.y, exit_pos.x, exit_pos.y)

func reposition_enemies_and_items_optimized():
	print("Smart repositioning of enemies and items (integrated version)...")

	# 1. Prepare entities (logic integrated from the first script)
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

	# Add all nodes to place in the scene tree (if they're not already there)
	# This way their global_position can be correctly set
	var all_entities_to_place_flat: Array = []
	all_entities_to_place_flat.append_array(keys_to_place)
	all_entities_to_place_flat.append_array(hp_beans_to_place)
	all_entities_to_place_flat.append_array(weapons_to_place)
	all_entities_to_place_flat.append_array(enemies_to_place)

	for entity_node in all_entities_to_place_flat:
		if not entity_node.is_inside_tree():
			add_child(entity_node) # Add to current Level2 node
		entity_node.visible = true # Ensure visible

	# 2. Collect all truly safe, centrally located world coordinates
	var all_safe_centered_world_positions = []
	if not tile_map or not tile_map.tile_set:
		printerr("TileMap or TileSet not initialized, unable to get grid size!")
		return
		
	var tile_center_offset = tile_map.tile_set.tile_size / 2.0

	# Player spawn point and its safety radius
	var player_spawn_pos = player.global_position
	var player_safe_radius = 120.0 # You can adjust this based on actual

	for y_tile in range(1, maze_height - 1):
		for x_tile in range(1, maze_width - 1):
			if _is_truly_safe_position(x_tile, y_tile):
				var local_tile_pos_top_left = tile_map.map_to_local(Vector2i(x_tile, y_tile))
				var global_tile_pos_centered = tile_map.to_global(local_tile_pos_top_left + tile_center_offset)
				# Exclude player spawn point nearby
				if global_tile_pos_centered.distance_to(player_spawn_pos) < player_safe_radius:
					continue
				all_safe_centered_world_positions.append(global_tile_pos_centered)
	
	all_safe_centered_world_positions.shuffle() # Shuffle order for randomness
	print("Found ", all_safe_centered_world_positions.size(), " centrally located safe world positions")

	if all_safe_centered_world_positions.is_empty() and not all_entities_to_place_flat.is_empty() :
		print("Warning: Insufficient safe positions, attempting to create additional safe areas...")
		_create_additional_safe_areas() # Function already present in your script
		await get_tree().process_frame # Wait for maze_grid to update
		await draw_maze_to_tilemap()   # Re-draw TileMap
		
		# Recollect positions
		all_safe_centered_world_positions.clear()
		for y_tile in range(1, maze_height - 1):
			for x_tile in range(1, maze_width - 1):
				if _is_truly_safe_position(x_tile, y_tile):
					var local_tile_pos_top_left = tile_map.map_to_local(Vector2i(x_tile, y_tile))
					var global_tile_pos_centered = tile_map.to_global(local_tile_pos_top_left + tile_center_offset)
					# Exclude player spawn point nearby
					if global_tile_pos_centered.distance_to(player_spawn_pos) < player_safe_radius:
						continue
					all_safe_centered_world_positions.append(global_tile_pos_centered)
		all_safe_centered_world_positions.shuffle()
		print("Created additional areas, found ", all_safe_centered_world_positions.size(), " centrally located safe world positions")

	if all_safe_centered_world_positions.is_empty() and not all_entities_to_place_flat.is_empty():
		printerr("Fatal error: Even after creating additional areas, no usable safe positions available!")
		# Hide unplaced items
		for entity_node in all_entities_to_place_flat: entity_node.visible = false
		return

	# 3. Use unified `globally_used_positions` for placement
	var globally_used_positions: Array = []

	# Parameters: (array of items to place, all available safe positions, array of used positions (this array will be modified), minimum spacing for this type of item)
	if not keys_to_place.is_empty():
		_place_keys_modified(keys_to_place, all_safe_centered_world_positions, globally_used_positions, 200.0)
	
	# For HP_beans, weapons, enemies, they share _place_items_safely in your script
	# We need to modify _place_items_safely to accept and update globally_used_positions
	if not hp_beans_to_place.is_empty():
		_place_items_safely_modified(hp_beans_to_place, all_safe_centered_world_positions, globally_used_positions, 70.0, "Hp_bean") # Decreased spacing
	if not weapons_to_place.is_empty():
		_place_items_safely_modified(weapons_to_place, all_safe_centered_world_positions, globally_used_positions, 150.0, "Weapon")
	if not enemies_to_place.is_empty():
		_place_items_safely_modified(enemies_to_place, all_safe_centered_world_positions, globally_used_positions, 120.0, "Enemy")
	
	# Check if any items failed to be placed (simple check is to see if its position is still initial Vector2.ZERO)
	for entity_node in all_entities_to_place_flat:
		if is_instance_valid(entity_node) and entity_node.global_position.is_equal_approx(Vector2.ZERO) and entity_node.visible:
			# This check is not perfect, as items might be instantiated at (0,0)
			# A better approach is to mark or return unplaced items in the placement function
			# print("Warning: Item ", entity_node.name, " might not be successfully placed, current position: ", entity_node.global_position)
			var found_in_used = false
			for used_pos in globally_used_positions:
				if entity_node.global_position.is_equal_approx(used_pos):
					found_in_used = true
					break
			if not found_in_used and entity_node.name != player.name : # Exclude player node
				print("Warning: Item ", entity_node.name, " could not find placement or is still at origin, will be hidden.")
				entity_node.visible = false


	print("Enemies and items repositioned (integrated version)")


func _place_keys_modified(keys: Array, available_positions: Array, globally_used_positions: Array, min_distance: float):
	print("Special handling ", keys.size(), " keys to place...")
	var positions_copy = available_positions.duplicate() # Operate on copy to avoid affecting other types' available positions list
	
	# Get coordinates of important locations to avoid keys being generated near them
	var player_spawn_pos = player.global_position if player else Vector2.ZERO
	var exit_door_pos = exit_door.global_position if exit_door else Vector2.ZERO
	var entry_door_pos = entry_door.global_position if entry_door else Vector2.ZERO
	
	var exclusion_radius = 300.0  # Exclusion radius (pixels)
	var preferred_distance_from_exit = 500.0  # Preferred distance from exit door
	
	# Filter out coordinates too close to important locations
	var filtered_positions = []
	for pos in positions_copy:
		var too_close_to_important_locations = false
		
		# Check if too close to player spawn point
		if player_spawn_pos != Vector2.ZERO and pos.distance_to(player_spawn_pos) < exclusion_radius:
			too_close_to_important_locations = true
		
		# Check if too close to exit door (most important exclusion condition)
		if exit_door_pos != Vector2.ZERO and pos.distance_to(exit_door_pos) < exclusion_radius:
			too_close_to_important_locations = true
		
		# Check if too close to entry door
		if entry_door_pos != Vector2.ZERO and pos.distance_to(entry_door_pos) < exclusion_radius * 0.7:  # Entry door exclusion radius slightly smaller
			too_close_to_important_locations = true
		
		if not too_close_to_important_locations:
			filtered_positions.append(pos)
	
	print("Number of positions before filtering:", positions_copy.size(), " Number of positions after filtering:", filtered_positions.size())
	
	# If filtered positions are too few, gradually relax conditions
	if filtered_positions.size() < keys.size() * 3:
		print("Filtered positions insufficient, relaxing conditions...")
		exclusion_radius = 200.0  # Decrease exclusion radius
		filtered_positions.clear()
		
		for pos in positions_copy:
			var too_close_to_important_locations = false
			
			# Only keep strict exclusion for exit door
			if exit_door_pos != Vector2.ZERO and pos.distance_to(exit_door_pos) < exclusion_radius:
				too_close_to_important_locations = true
			
			# Halve exclusion radius for player spawn point
			if player_spawn_pos != Vector2.ZERO and pos.distance_to(player_spawn_pos) < exclusion_radius * 0.5:
				too_close_to_important_locations = true
			
			if not too_close_to_important_locations:
				filtered_positions.append(pos)
		
		print("Number of positions after relaxing conditions:", filtered_positions.size())
	
	# Sort positions by distance from exit door, prioritize choosing positions further from exit door
	if exit_door_pos != Vector2.ZERO:
		filtered_positions.sort_custom(func(a, b): 
			var dist_a = a.distance_to(exit_door_pos)
			var dist_b = b.distance_to(exit_door_pos)
			return dist_a > dist_b  # Further positions come first
		)
		print("Positions sorted by distance from exit door, furthest distance:", filtered_positions[0].distance_to(exit_door_pos) if not filtered_positions.is_empty() else "No positions")
	else:
		filtered_positions.shuffle()

	var placed_count = 0
	for key_node in keys:
		var placed_successfully = false
		var attempts = 0
		for candidate_pos in filtered_positions:
			attempts += 1
			var tile_pos = tile_map.local_to_map(tile_map.to_local(candidate_pos))

			# 1. Check if tile itself is absolutely safe and no nearby walls
			var is_tile_super_safe = _is_truly_safe_position(tile_pos.x, tile_pos.y) and \
								 not _has_nearby_wall(tile_pos.x, tile_pos.y, 2) # 2 tiles away from walls

			if not is_tile_super_safe:
				continue

			# 2. Check distance to already placed items
			var too_close_to_others = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance:
					too_close_to_others = true
					break
			
			# 3. Additional check: ensure distance to exit door is sufficient (second confirmation)
			var distance_to_exit = candidate_pos.distance_to(exit_door_pos) if exit_door_pos != Vector2.ZERO else 1000.0
			if distance_to_exit < 250.0:  # Second confirmation distance to exit door at least 250 pixels
				continue
			
			if not too_close_to_others:
				key_node.global_position = candidate_pos
				globally_used_positions.append(candidate_pos) # Update globally used positions
				# Remove used position from filtered_positions to prevent giving same type of other keys
				filtered_positions.erase(candidate_pos)
				print(key_node.name, " placed at: ", Vector2i(candidate_pos), " (Attempts: ", attempts, ", Distance to exit door: ", int(distance_to_exit), ")")
				placed_successfully = true
				placed_count += 1
				break # Move to next key
		
		if not placed_successfully:
			print("Warning: Unable to find a suitable safe position for key ", key_node.name, ". It will be hidden.")
			key_node.visible = false
	print("Successfully placed %d/%d keys." % [placed_count, keys.size()])


func _place_items_safely_modified(items_in_category: Array, available_positions: Array, globally_used_positions: Array, min_distance_for_category: float, category_name_for_log: String):
	if items_in_category.is_empty():
		return
	print("Starting to place %d items for category '%s'..." % [items_in_category.size(), category_name_for_log])

	var positions_copy = available_positions.duplicate()
	positions_copy.shuffle()
	
	var placed_count = 0

	for item_node in items_in_category:
		var placed_successfully = false
		var attempts = 0
		# Try to find a suitable position among available ones
		for candidate_pos in positions_copy:
			attempts += 1
			var tile_pos = tile_map.local_to_map(tile_map.to_local(candidate_pos))

			# Perform stricter safety checks for different types
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

			# 2. Check distance to already placed items
			var too_close_to_others = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance_for_category:
					too_close_to_others = true
					break
			
			if not too_close_to_others:
				item_node.global_position = candidate_pos
				globally_used_positions.append(candidate_pos)
				positions_copy.erase(candidate_pos) # Remove from available positions for this category
				print(item_node.name, "(",category_name_for_log,")"," placed at: ", Vector2i(candidate_pos), " (Attempts: ", attempts, ")")
				placed_successfully = true
				placed_count +=1
				break # Move to next item in this category
		
		if not placed_successfully:
			# If no suitable position found, try a more lenient fallback search, or just give up
			# print("Warning: Unable to find a position for ", item_node.name, " (", category_name_for_log, ") in selected positions.")
			# var fallback_pos = _find_any_safe_position_modified(available_positions, globally_used_positions, 32.0) # Use a smaller fallback spacing
			# if fallback_pos != Vector2.ZERO:
			# 	item_node.global_position = fallback_pos
			# 	globally_used_positions.append(fallback_pos)
			# 	print(item_node.name, "(",category_name_for_log,")"," placed using fallback position: ", fallback_pos.round())
			# 	placed_successfully = true
			# 	placed_count +=1
			# else:
			print("Warning: Unable to find any position for ", item_node.name, " (", category_name_for_log, "). It will be hidden.")
			item_node.visible = false
	print("Successfully placed %d/%d items for category '%s'." % [placed_count, items_in_category.size(), category_name_for_log])


func get_enemy_clearance_radius(enemy_node: Node2D) -> int:
	if enemy_node.name.begins_with("Goblin") or enemy_node.name.begins_with("Skeleton"):
		return 8
	elif enemy_node.name.begins_with("Slime"):
		return 4 # Assuming Slime needs a smaller space
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
	var items_group = get_tree().get_nodes_in_group("items") # Get existing nodes in the scene
	var enemies_group = get_tree().get_nodes_in_group("enemies")

	# Build a map of existing nodes in the current scene
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
					# If it's a sword, set sword_type
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
					
					# Important: Here we don't add_child yet, as placement logic will handle it
					nodes_for_this_type.append(instance)
			else:
				printerr("Error: Type ", type_str, " PackedScene not correctly configured in packed_scenes!")

		entities_map[type_str] = nodes_for_this_type
		
		# Handle excess existing nodes (if any)
		if existing_nodes_of_type.size() > num_to_take_from_existing:
			for i in range(num_to_take_from_existing, existing_nodes_of_type.size()):
				var surplus_node = existing_nodes_of_type[i]
				if is_instance_valid(surplus_node) and surplus_node.is_inside_tree():
					print("Removing excess preset nodes: ", surplus_node.name)
					surplus_node.queue_free()
	return entities_map

func draw_path():
	# Find target (using unified search method)
	var key = _find_key_in_scene()
	var door_exit = get_node_or_null("DoorRoot/Door_exit")
	
	# If key does not exist and path is being displayed to key, turn off path display
	if not key and show_path_to_key:
		show_path_to_key = false
		print("LevelBase: Key does not exist or has been collected, turning off key path display")
		return

	# Draw key path
	if show_path_to_key and key:
		# Add debug information
		print("LevelBase: Calculating key path - from ", player.global_position, " to ", key.global_position)
		var path_to_key = _get_safe_navigation_path(player.global_position, key.global_position)
		
		# Validate path validity
		if path_to_key.size() > 1:
			_draw_single_path(path_to_key, PATH_COLORS["key"])
			print("LevelBase: Drawing path to key, containing ", path_to_key.size(), " points")
			_debug_path_validity(path_to_key, "key")
		else:
			print("LevelBase: Warning - Invalid or empty path to key")

	# Draw door path
	if show_path_to_door and door_exit:
		# Add debug information
		print("LevelBase: Calculating door path - from ", player.global_position, " to ", door_exit.global_position)
		var path_to_door = _get_safe_navigation_path(player.global_position, door_exit.global_position)
		
		# Validate path validity
		if path_to_door.size() > 1:
			_draw_single_path(path_to_door, PATH_COLORS["door"])
			print("LevelBase: Drawing path to door, containing ", path_to_door.size(), " points")
			_debug_path_validity(path_to_door, "door")
		else:
			print("LevelBase: Warning - Invalid or empty path to door")

# New: Smart path calculation function
func _get_safe_navigation_path(from_pos: Vector2, to_pos: Vector2) -> PackedVector2Array:
	"""Smart path calculation, automatically handles unreachable situations"""
	var nav_maps = NavigationServer2D.get_maps()
	if nav_maps.is_empty():
		print("LevelBase: No available navigation map")
		return PackedVector2Array()
	
	var navigation_map = nav_maps[0]
	
	# First try direct path
	var direct_path = NavigationServer2D.map_get_path(navigation_map, from_pos, to_pos, true)
	if direct_path.size() > 1:
		return direct_path
	
	# If direct path fails, find nearest navigable point
	print("LevelBase: Direct path failed, finding nearest navigable point...")
	var closest_navigable_pos = _find_closest_navigable_position(to_pos)
	if closest_navigable_pos != Vector2.ZERO:
		print("LevelBase: Found nearest navigable point: ", closest_navigable_pos)
		return NavigationServer2D.map_get_path(navigation_map, from_pos, closest_navigable_pos, true)
	
	print("LevelBase: Unable to find valid navigation path")
	return PackedVector2Array()

# New: Find nearest navigable position
func _find_closest_navigable_position(target_pos: Vector2) -> Vector2:
	"""Search for nearest navigable tile around target position"""
	if not tile_map:
		return Vector2.ZERO
	
	var target_tile = tile_map.local_to_map(tile_map.to_local(target_pos))
	var search_radius = 10  # Search radius (number of tiles)
	
	# Spiral search for nearest floor tile
	for radius in range(1, search_radius + 1):
		for angle in range(0, 360, 15):  # Check every 15 degrees
			var radian = deg_to_rad(angle)
			var check_x = target_tile.x + int(radius * cos(radian))
			var check_y = target_tile.y + int(radius * sin(radian))
			var check_tile = Vector2i(check_x, check_y)
			
			# Check boundaries
			if check_x < 0 or check_x >= maze_width or check_y < 0 or check_y >= maze_height:
				continue
			
			# Check if it's a floor tile
			var atlas_coords = tile_map.get_cell_atlas_coords(0, check_tile)
			var source_id = tile_map.get_cell_source_id(0, check_tile)
			
			if source_id != -1 and atlas_coords == floor_tile_id:
				# Found floor tile, convert to world coordinates
				var local_pos = tile_map.map_to_local(check_tile)
				var world_pos = tile_map.to_global(local_pos)
				return world_pos
	
	return Vector2.ZERO

# New: Path validity debugging function
func _debug_path_validity(path: PackedVector2Array, target_name: String):
	"""Debug path to see if it goes through walls"""
	if not tile_map or path.size() < 2:
		return
	
	var wall_intersections = 0
	for i in range(path.size() - 1):
		var start_point = path[i]
		var end_point = path[i + 1]
		
		# Check if line goes through walls
		var steps = int(start_point.distance_to(end_point) / 8.0)  # Check every 8 pixels
		for step in range(steps + 1):
			var check_point = start_point.lerp(end_point, float(step) / max(steps, 1))
			var tile_pos = tile_map.local_to_map(tile_map.to_local(check_point))
			
			# Check if point is on a wall
			var atlas_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
			var source_id = tile_map.get_cell_source_id(0, tile_pos)
			
			if source_id != -1 and atlas_coords == wall_tile_id:
				wall_intersections += 1
				print("LevelBase: Warning - ", target_name, " path intersects at point", check_point, " (tile", tile_pos, ")")
	
	if wall_intersections > 0:
		print("LevelBase: Error - ", target_name, " path goes through", wall_intersections, " wall points")
	else:
		print("LevelBase: ", target_name, " path validated, no wall intersections")

# Unified method to draw a single path
func _draw_single_path(path: PackedVector2Array, color: Color):
	if path.size() > 1:
		var line = Line2D.new()
		line.width = path_width
		line.default_color = color
		line.z_index = 10
		
		# Add advanced style (if enabled)
		if path_smoothing:
			line.antialiased = true
		
		add_child(line)
		path_lines.append(line)
		
		for point in path:
			line.add_point(point)

func draw_path_lines(path: PackedVector2Array, color: Color):
	# Keep original method for compatibility, but change to call new unified method
	_draw_single_path(path, color)

func update_paths():
	# Clear all existing path lines
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

	# If paths need to be displayed, redraw them
	if show_path_to_key or show_path_to_door:
		draw_path()
	else:
		print("LevelBase: All paths turned off, cleanup completed")

# Recursive division method: dividing area into smaller sub-areas and adding walls
# Conservative improvement version: only doing necessary navigation optimization
func _recursive_divide(x1: int, y1: int, x2: int, y2: int):
	# Increase minimum area size slightly, balancing maze complexity and navigation needs
	var min_room_size = 8  # Increased from 6 slightly, maintaining maze complexity
	if x2 - x1 < min_room_size or y2 - y1 < min_room_size:
		return
	
	var width = x2 - x1
	var height = y2 - y1
	var horizontal = width < height
	
	if horizontal and height > min_room_size:
		# Horizontal split: moderate wall margins
		var min_wall_margin = 3  # Conservative margin, increased from original 1 to 3
		var available_space = height - 2 * min_wall_margin
		if available_space <= 0:
			return
		
		var wall_offset = randi() % available_space
		var wall_y = y1 + min_wall_margin + wall_offset
		
		# Create horizontal wall
		for x in range(x1, x2 + 1):
			if x >= 0 and x < maze_width:
				maze_grid[wall_y][x] = CellType.WALL
		
		# Increase door width slightly
		var door_width = 4  # Increased from 3 to 4, balancing navigation and challenge
		var door_margin = 2  # Conservative door margin
		var door_available_space = width - 2 * door_margin
		
		if door_available_space >= door_width:
			var door_offset = randi() % max(1, door_available_space - door_width + 1)
			var door_x = x1 + door_margin + door_offset
			
			# Create door
			for dx in range(door_width):
				var x = door_x + dx
				if x >= x1 and x <= x2 and x >= 0 and x < maze_width:
					maze_grid[wall_y][x] = CellType.PATH
		
		# Recursive divide (keeping original divide logic)
		if wall_y - y1 >= min_room_size:
			_recursive_divide(x1, y1, x2, wall_y - 1)
		if y2 - wall_y >= min_room_size:
			_recursive_divide(x1, wall_y + 1, x2, y2)
			
	elif width > min_room_size:
		# Vertical split: moderate wall margins
		var min_wall_margin = 3  # Conservative margin
		var available_space = width - 2 * min_wall_margin
		if available_space <= 0:
			return
		
		var wall_offset = randi() % available_space
		var wall_x = x1 + min_wall_margin + wall_offset
		
		# Create vertical wall
		for y in range(y1, y2 + 1):
			if y >= 0 and y < maze_height:
				maze_grid[y][wall_x] = CellType.WALL
		
		# Increase door width slightly
		var door_height = 4  # Increased from 3 to 4
		var door_margin = 2  # Conservative door margin
		var door_available_space = height - 2 * door_margin
		
		if door_available_space >= door_height:
			var door_offset = randi() % max(1, door_available_space - door_height + 1)
			var door_y = y1 + door_margin + door_offset
			
			# Create door
			for dy in range(door_height):
				var y = door_y + dy
				if y >= y1 and y <= y2 and y >= 0 and y < maze_height:
					maze_grid[y][wall_x] = CellType.PATH
		
		# Recursive divide
		if wall_x - x1 >= min_room_size:
			_recursive_divide(x1, y1, wall_x - 1, y2)
		if x2 - wall_x >= min_room_size:
			_recursive_divide(wall_x + 1, y1, x2, y2)

func create_entrance_and_exit_fixed():
	var entrance_x = 0
	var entrance_y = int(maze_height / 2)
	var exit_x = maze_width - 1
	var exit_y = int(maze_height / 2)
	
	# Increase entrance/exit area slightly (from 5x5 to 7x7)
	var area_size = 7  # Conservative increase in area size, maintaining maze complexity
	var half_size = area_size / 2
	
	for i in range(area_size):
		var y = entrance_y + i - half_size
		if y >= 0 and y < maze_height:
			for x in range(area_size):
				var cur_x = entrance_x + x
				if cur_x >= 0 and cur_x < maze_width:
					maze_grid[y][cur_x] = CellType.PATH
	
	# Create corresponding exit area
	for i in range(area_size):
		var y = exit_y + i - half_size
		if y >= 0 and y < maze_height:
			for x in range(area_size):
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
	# Increase main path width slightly, balancing navigation needs and maze complexity
	var width = 3  # Increased from 2 slightly, maintaining reasonable maze density
	var current_x = x1
	var current_y = y1
	
	# Create main path from start to end
	while current_x != x2:
		# Create wide channel at current position
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
		# Create wide channel at current position
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
	
	# Ensure end point has reasonable space
	for dy in range(-width, width + 1):
		for dx in range(-width, width + 1):
			var nx = x2 + dx
			var ny = y2 + dy
			if nx >= 0 and nx < maze_width and ny >= 0 and ny < maze_height:
				maze_grid[ny][nx] = CellType.PATH
	
# Check if position is truly safe (strict check)
func _is_truly_safe_position(x: int, y: int) -> bool:
	# Check boundaries
	if x <= 0 or x >= maze_width - 1 or y <= 0 or y >= maze_height - 1:
		return false
	
	# Check if current position is a path
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	# Check if surrounding 3x3 area is all paths
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var check_x = x + dx
			var check_y = y + dy
			if check_x < 0 or check_x >= maze_width or check_y < 0 or check_y >= maze_height:
				return false
			if maze_grid[check_y][check_x] != CellType.PATH:
				return false
	
	return true

# Check if position is basically safe
func _is_basic_safe_position(x: int, y: int) -> bool:
	# Check boundaries
	if x <= 0 or x >= maze_width - 1 or y <= 0 or y >= maze_height - 1:
		return false
	
	# Check if current position is a path
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	return true

# Check if there's a nearby wall
func _has_nearby_wall(x: int, y: int, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var check_x = x + dx
			var check_y = y + dy
			if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
				if maze_grid[check_y][check_x] == CellType.WALL:
					return true
	return false

# Create additional safe areas
func _create_additional_safe_areas():
	print("Creating additional safe areas...")
	var areas_created = 0
	
	# Create some small safe areas randomly in the maze
	for attempt in range(20):
		var center_x = randi() % (maze_width - 10) + 5
		var center_y = randi() % (maze_height - 10) + 5
		
		# Create 5x5 safe area
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
			if areas_created >= 5:  # Maximum of 5 additional areas
				break
	
	print("Created ", areas_created, " additional safe areas")

# UIManager button callback function
func _on_minimap_toggled(enabled: bool):
	print("MiniMap toggle:", enabled)
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

# Toggle pause state function
func toggle_pause():
	print("Base_Level: toggle_pause called")
	print("Base_Level: Current pause state:", get_tree().paused)
	print("Base_Level: Pause menu node:", pause_menu)
	
	get_tree().paused = !get_tree().paused
	print("Base_Level: New pause state:", get_tree().paused)
	
	if pause_menu:
		pause_menu.visible = get_tree().paused # Show menu when paused, hide otherwise
		print("Base_Level: Pause menu visibility set to:", pause_menu.visible)
	else:
		print("Base_Level: Error - Pause menu node is null!")

# Smart key navigation handling (unified with Level1 approach)
func _handle_key_navigation():
	var notification_manager = get_node_or_null("/root/NotificationManager")
	
	if _is_key_collected():
		# Key already collected
		if notification_manager:
			notification_manager.notify_key_already_collected()
		show_path_to_key = false
		print("LevelBase: Key has been collected, prompting player to navigate to exit door")
	else:
		# Key still there, switch display
		show_path_to_key = !show_path_to_key
		show_path_to_door = false
		
		if notification_manager:
			if show_path_to_key:
				notification_manager.notify_navigation_to_key()
			else:
				notification_manager.notify_navigation_disabled()
		print("LevelBase: Switching key path display state:", show_path_to_key)
	
	update_paths()

# Door navigation handling (unified with Level1 approach)
func _handle_door_navigation():
	show_path_to_door = !show_path_to_door
	show_path_to_key = false
	
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		if show_path_to_door:
			notification_manager.notify_navigation_to_door()
		else:
			notification_manager.notify_navigation_disabled()
	
	update_paths()

# Unified check for key status (Level1 approach)
func _is_key_collected() -> bool:
	# Check player's inventory
	if player and player.has_method("has_key"):
		if player.has_key("master_key"):
			return true
	
	# Check if there's still a key in the scene
	return not _key_exists_in_scene()

func _key_exists_in_scene() -> bool:
	var key = _find_key_in_scene()
	return key != null

func _find_key_in_scene() -> Node:
	# Smart key search (applicable to both types of levels)
	var items = get_tree().get_nodes_in_group("items")
	for item in items:
		if item.name.begins_with("Key") and item.visible and is_instance_valid(item):
			return item
	
	# Backup search (Level_base compatibility)
	return get_node_or_null("Key")

# Set position tracking (unified with Level1 approach)
func _setup_position_tracking():
	if player:
		# Check if player has position_changed signal
		if player.has_signal("position_changed"):
			player.position_changed.connect(_on_player_position_changed)
		else:
			# Use timer to periodically update path
			var timer = Timer.new()
			timer.wait_time = 0.1  # Update every 0.1 seconds
			timer.timeout.connect(_on_player_position_changed)
			timer.autostart = true
			add_child(timer)
			print("LevelBase: Using timer to update path")

func _on_player_position_changed():
	"""Update path when player's position changes"""
	if show_path_to_key or show_path_to_door:
		update_paths()

# Force clear all paths (unified with Level1 approach)
func clear_all_paths():
	"""Clear all drawn path lines immediately"""
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()
	show_path_to_key = false
	show_path_to_door = false
	print("LevelBase: Force clearing all paths completed")

# Cleanup method (unified with Level1 approach)
func _exit_tree():
	"""Clean up resources when exiting scene"""
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

# New: Maze quality validation and optimization function
func validate_and_improve_maze_quality():
	"""Conservative maze quality validation, only fixing severe navigation issues"""
	print("LevelBase: Starting to validate and improve maze quality...")
	
	var improvements_made = 0
	var min_corridor_width = 2  # Decrease minimum corridor width requirement, maintaining maze complexity
	
	# Only detect and fix severely narrow corridors (1-tile wide dead end)
	for y in range(2, maze_height - 2):  # Reduce detection range
		for x in range(2, maze_width - 2):
			if maze_grid[y][x] == CellType.PATH:
				# Only fix extremely narrow corridors
				if _is_isolated_narrow_corridor(x, y):
					_carefully_widen_corridor(x, y)
					improvements_made += 1
	
	print("LevelBase: Maze quality improved, ", improvements_made, " conservative improvements made")

# Check if it's an isolated narrow corridor
func _is_isolated_narrow_corridor(x: int, y: int) -> bool:
	if maze_grid[y][x] != CellType.PATH:
		return false
	
	# Check if surrounded by walls (only a few exit points)
	var path_neighbors = 0
	var directions = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	
	for dir in directions:
		var check_x = x + dir.x
		var check_y = y + dir.y
		if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
			if maze_grid[check_y][check_x] == CellType.PATH:
				path_neighbors += 1
	
	# Only points with 1 or fewer exit points are considered problematic corridors
	return path_neighbors <= 1

# Carefully widen corridors
func _carefully_widen_corridor(center_x: int, center_y: int):
	# Only create paths in adjacent positions, avoiding destroying maze structure
	var directions = [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
	
	for dir in directions:
		var nx = center_x + dir.x
		var ny = center_y + dir.y
		if nx >= 1 and nx < maze_width - 1 and ny >= 1 and ny < maze_height - 1:
			# Only create paths in places where it's safe to do so
			if _safe_to_create_path(nx, ny):
				maze_grid[ny][nx] = CellType.PATH

# Check if creating a path in a specified position is safe
func _safe_to_create_path(x: int, y: int) -> bool:
	# Ensure we don't create too large an open area
	var surrounding_paths = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var check_x = x + dx
			var check_y = y + dy
			if check_x >= 0 and check_x < maze_width and check_y >= 0 and check_y < maze_height:
				if maze_grid[check_y][check_x] == CellType.PATH:
					surrounding_paths += 1
	
	# If there's already too many paths, don't create any more
	return surrounding_paths <= 3

# Removed overly aggressive corridor detection function, using more conservative quality validation strategy

