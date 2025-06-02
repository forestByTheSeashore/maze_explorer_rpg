# level_1.gd
extends Node2D

@onready var player = $Player
@onready var entry_door: Node = $DoorRoot/Door_entrance # 确保名称匹配
@onready var exit_door: Node = $DoorRoot/Door_exit   # 确保名称匹配

# 移除  signal player_reached_exit，因为我们将直接响应门的打开事件

func _ready():
    if entry_door == null:
        push_error("Error: EntryDoor node not found in scene!")
        return
    if exit_door == null:
        push_error("Error: ExitDoor node not found in scene!")
        return

    # 1. 入口门逻辑 (基本不变)
    # entry_door.door_opened.connect(on_entry_door_opened) # 如果需要入口门打开时的特殊逻辑
    # 假设入口门在 _ready() 中已经自行处理了初始打开状态 (根据 door.gd)

    # 将玩家放置在入口门的位置
    if player and entry_door:
        player.global_position = entry_door.global_position

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

# func on_entry_door_opened(): # 如果有入口门打开后的特定逻辑，保留此函数
#     print("入口门已打开，玩家可以进入迷宫。")

func on_exit_door_has_opened(): # 当出口门的 door_opened 信号发出时调用
    print("出口门已打开，Level 1 结束！")
    print("进入 Level 2 - 程序化迷宫关卡")
    # 跳转到 Level 2
    get_tree().change_scene_to_file("res://levels/level_2.tscn")

func _process(_delta):
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

    # 移除了原先的自动距离检测开门逻辑，以避免冲突，专注于按 'F' 键交互
    # 如果你确实需要基于距离的自动触发，请仔细考虑它与按键交互的关系