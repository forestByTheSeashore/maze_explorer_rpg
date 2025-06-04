extends Node

# 游戏管理器单例
# 用于管理全局游戏状态和场景切换

# 场景切换函数
func change_scene(scene_path: String) -> void:
	print("GameManager: Changing scene to ", scene_path)
	# 确保游戏非暂停状态再切换场景
	get_tree().paused = false
	# 使用 call_deferred 确保在下一帧执行场景切换
	get_tree().call_deferred("change_scene_to_file", scene_path)

# ... existing code ... 