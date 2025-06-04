extends Node

# 下一关的名称
var next_level_name: String = ""

# 关卡配置
const LEVEL_CONFIGS = {
	"level_1": {
		"maze_width": 81,           # 较小的迷宫，适合新手
		"maze_height": 81,
		"corridor_width": 12,       # 较宽的走廊，便于移动
		"enemies": {
			"Goblin": 3,            # 适中的敌人数量
			"Skeleton": 2,
			"Slime": 4
		},
		"items": {
			"Key": 1,
			"Hp_bean": 30,          # 充足的补给
			"IronSword": {
				"type0": 3,         # 较多的武器选择
				"type1": 2,
				"type2": 2,
				"type3": 1
			}
		}
	},
	"level_2": {
		"maze_width": 81,           # 稍大的迷宫
		"maze_height": 81,
		"corridor_width": 10,       # 稍窄的走廊
		"enemies": {
			"Goblin": 5,            # 增加敌人数量
			"Skeleton": 3,
			"Slime": 6
		},
		"items": {
			"Key": 1,
			"Hp_bean": 25,          # 减少补给
			"IronSword": {
				"type0": 2,
				"type1": 2,
				"type2": 2,
				"type3": 1
			}
		}
	},
	"level_3": {
		"maze_width": 81,           # 更大的迷宫
		"maze_height": 81,
		"corridor_width": 8,        # 更窄的走廊，增加难度
		"enemies": {
			"Goblin": 8,            # 显著增加敌人数量
			"Skeleton": 5,
			"Slime": 10
		},
		"items": {
			"Key": 1,
			"Hp_bean": 20,          # 继续减少补给
			"IronSword": {
				"type0": 2,
				"type1": 2,
				"type2": 1,
				"type3": 1
			}
		}
	},
	"level_4": {
		"maze_width": 81,           # 最大的迷宫
		"maze_height": 81,
		"corridor_width": 6,        # 最窄的走廊，最高难度
		"enemies": {
			"Goblin": 12,           # 大量敌人，最终挑战
			"Skeleton": 8,
			"Slime": 15
		},
		"items": {
			"Key": 1,
			"Hp_bean": 15,          # 最少的补给
			"IronSword": {
				"type0": 1,         # 最少的武器，增加挑战性
				"type1": 1,
				"type2": 1,
				"type3": 1
			}
		}
	},
	"level_5": {
		"maze_width": 81,          # 终极挑战迷宫
		"maze_height": 81,
		"corridor_width": 4,        # 极窄走廊
		"enemies": {
			"Goblin": 20,           # 终极敌人数量
			"Skeleton": 15,
			"Slime": 25
		},
		"items": {
			"Key": 1,
			"Hp_bean": 10,          # 极少补给
			"IronSword": {
				"type0": 1,
				"type1": 1,
				"type2": 0,         # 高级武器稀缺
				"type3": 0
			}
		}
	}
}

# 预制件路径
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

# 当前关卡实例
var current_level: Node2D = null
# 是否准备初始化下一关
var _should_initialize := false
# 新增：信号，用于通知关卡场景已准备好初始化
signal level_ready_to_initialize(level_name: String)

func _ready():
	print("=== LevelManager 初始化开始 ===")
	print("LevelManager _ready 触发")
	# 多等待几帧确保场景完全加载
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 如果标记为应该初始化，则发出信号
	if _should_initialize and next_level_name != "":
		print("LevelManager检测到初始化标记和有效的next_level_name: ", next_level_name)
		# 发出信号，通知关卡场景初始化
		await get_tree().process_frame  # 再等一帧确保场景已准备好
		level_ready_to_initialize.emit(next_level_name)
	else:
		print("LevelManager未检测到初始化标记或next_level_name为空")
	
	print("=== LevelManager _ready 完成 ===")

# 新增：准备初始化下一关的方法
func prepare_next_level():
	print("LevelManager: 准备初始化下一关 - ", next_level_name)
	_should_initialize = true
	print("_should_initialize已设置为true")

# 新增：分离出的初始化逻辑
func initialize_level():
	print("LevelManager.initialize_level()被调用")
	
	# 如果有下一关名称，初始化关卡
	if next_level_name == "":
		push_error("LevelManager.initialize_level(): 无下一关名称!")
		return
		
	print("准备初始化关卡: ", next_level_name)
	var current_scene = get_tree().current_scene
	
	print("当前场景: ", current_scene.name if current_scene else "null")
	print("current_scene类型: ", typeof(current_scene))
	print("current_scene has init_level方法: ", current_scene.has_method("init_level") if current_scene else "N/A")
	
	await get_tree().process_frame # 再等一帧，确保 current_scene 完全 ready
	
	if current_scene == null:
		push_error("LevelManager.initialize_level(): 当前场景为null!")
		return
		
	if not current_scene.has_method("init_level"):
		push_error("LevelManager.initialize_level(): 当前场景没有init_level方法!")
		return
		
	print("找到当前关卡场景: ", current_scene.name)
	# 设置关卡属性
	var config = LEVEL_CONFIGS.get(next_level_name)
	if config == null:
		push_error("未找到关卡配置: " + next_level_name)
		return
		
	print("找到关卡配置，开始设置属性")
	print("配置详情: ", config)
	
	current_scene.current_level_name = next_level_name
	current_scene.maze_width = config.maze_width
	current_scene.maze_height = config.maze_height
	current_scene.corridor_width = config.corridor_width
	
	# 设置敌人和物品数量
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
	
	print("属性设置完成，开始初始化关卡")
	print("设置的desired_counts: ", current_scene.desired_counts)
	
	# 初始化关卡
	# 直接使用await调用init_level方法
	print("等待init_level()协程完成...")
	await current_scene.init_level()
		
	print("关卡初始化完成")
	
	# 清除下一关名称和初始化标记
	next_level_name = ""
	_should_initialize = false
	print("下一关名称和初始化标记已清除")

func get_next_level_name(current_level_name: String) -> String:
	var level_names = LEVEL_CONFIGS.keys()
	var current_index = level_names.find(current_level_name)
	if current_index >= 0 and current_index < level_names.size() - 1:
		return level_names[current_index + 1]
	return ""
