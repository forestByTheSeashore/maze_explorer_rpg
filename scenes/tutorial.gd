extends Control

# 按钮引用
@onready var back_button = $BackButton
@onready var close_button = $CloseButton

# 场景路径常量
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# 标记是否从暂停菜单打开
var opened_from_pause_menu: bool = false

func _ready():
	# 连接按钮信号
	back_button.pressed.connect(_on_back_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# 如果在游戏中显示，设置为可在暂停时处理
	if get_tree().get_first_node_in_group("player"):
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# 设置初始状态
	_setup_ui()

func _setup_ui():
	"""设置界面初始状态"""
	# 确保滚动容器从顶部开始
	var scroll_container = $ScrollContainer
	if scroll_container:
		scroll_container.scroll_vertical = 0

func _on_back_button_pressed():
	"""返回主菜单按钮事件"""
	print("返回主菜单")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_close_button_pressed():
	"""关闭按钮事件 - 如果在游戏中打开则关闭界面，否则返回主菜单"""
	print("关闭玩法说明")
	
	# 检查是否在游戏中（通过检查是否存在玩家节点）
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 隐藏界面
		queue_free()
		
		# 如果是从暂停菜单打开的，返回暂停菜单
		if opened_from_pause_menu:
			var pause_menu = get_tree().get_first_node_in_group("pause_menu")
			if not pause_menu:
				# 尝试通过路径查找暂停菜单
				var current_scene = get_tree().current_scene
				if current_scene:
					pause_menu = current_scene.get_node_or_null("CanvasLayer/PauseMenu")
					if not pause_menu:
						pause_menu = current_scene.find_child("PauseMenu", true, false)
			
			if pause_menu:
				pause_menu.show()
				print("返回暂停菜单")
			else:
				get_tree().paused = false
				print("找不到暂停菜单，恢复游戏")
		else:
			# 如果是通过F7键打开的，直接恢复游戏
			get_tree().paused = false
			print("恢复游戏")
	else:
		# 不在游戏中，返回主菜单
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _input(event):
	"""处理输入事件"""
	# ESC键关闭界面
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()

# 静态方法：在游戏中显示玩法说明
static func show_tutorial_in_game():
	"""在游戏中显示玩法说明界面的静态方法"""
	var tutorial_scene = preload("res://scenes/tutorial.tscn")
	var tutorial_instance = tutorial_scene.instantiate()
	
	# 获取当前场景
	var current_scene = Engine.get_main_loop().current_scene
	if current_scene:
		# 暂停游戏
		current_scene.get_tree().paused = true
		# 添加到场景树
		current_scene.add_child(tutorial_instance)
		# 确保在最上层显示
		tutorial_instance.z_index = 1000
		
		print("在游戏中显示玩法说明界面")
	else:
		print("错误：无法获取当前场景") 