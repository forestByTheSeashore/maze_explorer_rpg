extends Node

# Name of the next level
var next_level_name: String = ""

# Level configurations
const LEVEL_CONFIGS = {
	"level_1": {
		"maze_width": 81,           # Smaller maze, suitable for beginners
		"maze_height": 81,
		"corridor_width": 12,       # Wider corridors for easier movement
		"enemies": {
			"Goblin": 3,            # Moderate number of enemies
			"Skeleton": 2,
			"Slime": 4
		},
		"items": {
			"Key": 1,
			"Hp_bean": 30,          # Abundant supplies
			"IronSword": {
				"type0": 3,         # More weapon choices
				"type1": 2,
				"type2": 2,
				"type3": 1
			}
		}
	},
	"level_2": {
		"maze_width": 81,           # Slightly larger maze
		"maze_height": 81,
		"corridor_width": 12,       # Slightly narrower than level_1 but still manageable
		"enemies": {
			"Goblin": 4,            # Moderate increase from level_1
			"Skeleton": 2,
			"Slime": 5
		},
		"items": {
			"Key": 1,
			"Hp_bean": 25,          # Reduced supplies
			"IronSword": {
				"type0": 2,
				"type1": 2,
				"type2": 2,
				"type3": 1
			}
		}
	},
	"level_3": {
		"maze_width": 81,           # Even larger maze
		"maze_height": 81,
		"corridor_width": 10,       # More narrow corridors, increasing difficulty
		"enemies": {
			"Goblin": 6,            # Further increase in enemies
			"Skeleton": 4,
			"Slime": 8
		},
		"items": {
			"Key": 1,
			"Hp_bean": 20,          # Further reduced supplies
			"IronSword": {
				"type0": 2,
				"type1": 2,
				"type2": 1,
				"type3": 1
			}
		}
	},
	"level_4": {
		"maze_width": 81,           # Largest maze
		"maze_height": 81,
		"corridor_width": 6,        # Narrowest corridors, highest difficulty
		"enemies": {
			"Goblin": 12,           # Many enemies, final challenge
			"Skeleton": 8,
			"Slime": 15
		},
		"items": {
			"Key": 1,
			"Hp_bean": 15,          # Minimal supplies
			"IronSword": {
				"type0": 1,         # Minimal weapons, increasing challenge
				"type1": 1,
				"type2": 1,
				"type3": 1
			}
		}
	},
	"level_5": {
		"maze_width": 81,          # Ultimate challenge maze
		"maze_height": 81,
		"corridor_width": 4,        # Extremely narrow corridors
		"enemies": {
			"Goblin": 20,           # Ultimate enemy count
			"Skeleton": 15,
			"Slime": 25
		},
		"items": {
			"Key": 1,
			"Hp_bean": 10,          # Very few supplies
			"IronSword": {
				"type0": 1,
				"type1": 1,
				"type2": 0,         # Advanced weapons are scarce
				"type3": 0
			}
		}
	}
}

# Prefab paths
const PREFAB_PATHS = {
	"Player": "res://scenes/Player.tscn",
	"Door": "res://scenes/Door.tscn",
	"Key": "res://scenes/Key.tscn",
	"Hp_bean": "res://scenes/Hp_bean.tscn",
	"IronSword": "res://scenes/IronSword.tscn",
	"Goblin": "res://scenes/goblin.tscn",
	"Skeleton": "res://scenes/skelontonEnemy.tscn",
	"Slime": "res://scenes/slime.tscn"
}

# Current level instance
var current_level: Node2D = null
# Whether to initialize the next level
var _should_initialize := false
# New: Signal to notify when level scene is ready for initialization
signal level_ready_to_initialize(level_name: String)

func _ready():
	print("=== LevelManager Initialization Start ===")
	print("LevelManager _ready triggered")
	# Wait a few frames to ensure scene is fully loaded
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# If marked for initialization and has valid next level name, emit signal
	if _should_initialize and next_level_name != "":
		print("LevelManager detected initialization flag and valid next_level_name: ", next_level_name)
		# Emit signal to notify level scene to initialize
		await get_tree().process_frame  # Wait one more frame to ensure scene is ready
		level_ready_to_initialize.emit(next_level_name)
	else:
		print("LevelManager did not detect initialization flag or next_level_name is empty")
	
	print("=== LevelManager _ready Complete ===")

# New: Method to prepare next level initialization
func prepare_next_level():
	print("LevelManager: Preparing to initialize next level - ", next_level_name)
	_should_initialize = true
	print("_should_initialize has been set to true")

# New: Separated initialization logic
func initialize_level():
	print("LevelManager.initialize_level() called")
	
	# Initialize level if next level name exists
	if next_level_name == "":
		push_error("LevelManager.initialize_level(): No next level name!")
		return
		
	print("Preparing to initialize level: ", next_level_name)
	var current_scene = get_tree().current_scene
	
	print("Current scene: ", current_scene.name if current_scene else "null")
	print("current_scene type: ", typeof(current_scene))
	print("current_scene has init_level method: ", current_scene.has_method("init_level") if current_scene else "N/A")
	
	await get_tree().process_frame # Wait one more frame to ensure current_scene is fully ready
	
	if current_scene == null:
		push_error("LevelManager.initialize_level(): Current scene is null!")
		return
		
	if not current_scene.has_method("init_level"):
		push_error("LevelManager.initialize_level(): Current scene doesn't have init_level method!")
		return
		
	print("Found current level scene: ", current_scene.name)
	# Set level properties
	print("LevelManager: Attempting to get level configuration - ", next_level_name)
	print("LevelManager: Available level configurations: ", LEVEL_CONFIGS.keys())
	
	var config = LEVEL_CONFIGS.get(next_level_name)
	if config == null:
		push_error("Level configuration not found: " + next_level_name + ". Available configurations: " + str(LEVEL_CONFIGS.keys()))
		return
		
	print("Found level configuration, setting properties")
	print("Configuration details: ", config)
	
	current_scene.current_level_name = next_level_name
	current_scene.maze_width = config.maze_width
	current_scene.maze_height = config.maze_height
	current_scene.corridor_width = config.corridor_width
	
	# Set enemy and item counts
	current_scene.desired_counts = {
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
	
	print("Properties set, starting level initialization")
	print("Set desired_counts: ", current_scene.desired_counts)
	
	# Initialize level
	# Directly use await to call init_level method
	print("Waiting for init_level() coroutine to complete...")
	await current_scene.init_level()
		
	print("Level initialization complete")
	
	# Notify UI system to update level information
	var ui_managers = get_tree().get_nodes_in_group("ui_manager")
	for ui in ui_managers:
		if ui.has_method("update_level_info"):
			ui.update_level_info(current_scene.current_level_name)
			print("LevelManager: Notified UI manager to update level info: ", current_scene.current_level_name)
	
	# Clear next level name and initialization flag
	next_level_name = ""
	_should_initialize = false
	print("Next level name and initialization flag cleared")

func get_next_level_name(current_level_name: String) -> String:
	var level_names = LEVEL_CONFIGS.keys()
	var current_index = level_names.find(current_level_name)
	if current_index >= 0 and current_index < level_names.size() - 1:
		return level_names[current_index + 1]
	return ""
