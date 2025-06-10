extends Node

## 胜利管理器
## 处理游戏完成条件和胜利界面

signal game_completed()
signal level_completed(level_name: String)

# 关卡配置
const TOTAL_LEVELS = 3  # 总关卡数
const FINAL_LEVEL_NAME = "level_3"  # 最后一关的名称

var completed_levels: Array[String] = []
var victory_screen: Control = null
var game_statistics: Dictionary = {}

func _ready():
	add_to_group("victory_manager")
	_initialize_statistics()

func _initialize_statistics():
	game_statistics = {
		"start_time": Time.get_unix_time_from_system(),
		"levels_completed": 0,
		"enemies_defeated": 0,
		"items_collected": 0,
		"deaths": 0,
		"total_play_time": 0.0
	}

func mark_level_completed(level_name: String):
	print("VictoryManager: 关卡完成 - ", level_name)
	
	if level_name not in completed_levels:
		completed_levels.append(level_name)
		game_statistics["levels_completed"] += 1
		level_completed.emit(level_name)
	
	# 检查是否完成了所有关卡
	if _is_game_completed():
		_trigger_game_victory()

func _is_game_completed() -> bool:
	return game_statistics["levels_completed"] >= TOTAL_LEVELS

func _trigger_game_victory():
	print("VictoryManager: 游戏完成！")
	game_statistics["total_play_time"] = Time.get_unix_time_from_system() - game_statistics["start_time"]
	game_completed.emit()
	_show_victory_screen()

func _show_victory_screen():
	print("VictoryManager: 显示胜利界面")
	
	# 暂停游戏
	get_tree().paused = true
	
	# 创建胜利界面
	_create_victory_screen()

func _create_victory_screen():
	if victory_screen:
		return
	
	victory_screen = Control.new()
	victory_screen.name = "VictoryScreen"
	victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 背景
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0, 0, 0, 0.9)
	victory_screen.add_child(background)
	
	# 主容器
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(600, 500)
	main_container.position = Vector2(-300, -250)
	
	# 标题
	var title = Label.new()
	title.text = "🎉 恭喜通关！ 🎉"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	main_container.add_child(title)
	
	# 间距
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(spacer1)
	
	# 统计信息
	var stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 10)
	
	var stats_title = Label.new()
	stats_title.text = "游戏统计"
	stats_title.add_theme_font_size_override("font_size", 24)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(stats_title)
	
	# 创建统计标签
	var stats_labels = [
		"关卡完成: %d / %d" % [game_statistics["levels_completed"], TOTAL_LEVELS],
		"敌人击败: %d" % game_statistics["enemies_defeated"],
		"物品收集: %d" % game_statistics["items_collected"],
		"死亡次数: %d" % game_statistics["deaths"],
		"游戏时长: %s" % _format_time(game_statistics["total_play_time"])
	]
	
	for stat_text in stats_labels:
		var stat_label = Label.new()
		stat_label.text = stat_text
		stat_label.add_theme_font_size_override("font_size", 16)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(stat_label)
	
	main_container.add_child(stats_container)
	
	# 间距
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(spacer2)
	
	# 按钮容器
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	
	# 再次游戏按钮
	var play_again_btn = Button.new()
	play_again_btn.text = "再次游戏"
	play_again_btn.custom_minimum_size = Vector2(120, 50)
	play_again_btn.pressed.connect(_play_again)
	button_container.add_child(play_again_btn)
	
	# 主菜单按钮
	var main_menu_btn = Button.new()
	main_menu_btn.text = "返回主菜单"
	main_menu_btn.custom_minimum_size = Vector2(120, 50)
	main_menu_btn.pressed.connect(_return_to_main_menu)
	button_container.add_child(main_menu_btn)
	
	# 退出游戏按钮
	var quit_btn = Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(120, 50)
	quit_btn.pressed.connect(_quit_game)
	button_container.add_child(quit_btn)
	
	main_container.add_child(button_container)
	victory_screen.add_child(main_container)
	
	# 添加到场景
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(victory_screen)
		victory_screen.z_index = 1000

func _format_time(seconds: float) -> String:
	var hours = int(seconds) / 3600
	var minutes = (int(seconds) % 3600) / 60
	var secs = int(seconds) % 60
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	else:
		return "%02d:%02d" % [minutes, secs]

func _play_again():
	print("VictoryManager: 玩家选择再次游戏")
	_reset_game_state()
	get_tree().paused = false
	
	# 清除胜利界面
	if victory_screen:
		victory_screen.queue_free()
		victory_screen = null
	
	# 重新开始第一关
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.change_scene("res://levels/level_1.tscn")
	else:
		get_tree().change_scene_to_file("res://levels/level_1.tscn")

func _return_to_main_menu():
	print("VictoryManager: 返回主菜单")
	get_tree().paused = false
	
	# 清除胜利界面
	if victory_screen:
		victory_screen.queue_free()
		victory_screen = null
	
	# 返回主菜单
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.change_scene("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _quit_game():
	print("VictoryManager: 退出游戏")
	get_tree().quit()

func _reset_game_state():
	"""重置游戏状态以便重新开始"""
	completed_levels.clear()
	_initialize_statistics()
	
	# 可以选择清除存档
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("clear_progress"):
		save_manager.clear_progress()

# 统计数据更新函数
func increment_enemies_defeated():
	game_statistics["enemies_defeated"] += 1

func increment_items_collected():
	game_statistics["items_collected"] += 1

func increment_deaths():
	game_statistics["deaths"] += 1

func get_completion_percentage() -> float:
	return float(game_statistics["levels_completed"]) / float(TOTAL_LEVELS) * 100.0

func get_game_statistics() -> Dictionary:
	return game_statistics.duplicate()

# 调试功能
func force_victory():
	"""调试用：强制触发胜利"""
	print("VictoryManager: 强制触发胜利（调试用）")
	_trigger_game_victory() 