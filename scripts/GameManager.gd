extends Node

# Game Manager Singleton
# Used to manage global game state and scene transitions

# Scene transition function
func change_scene(scene_path: String) -> void:
	print("GameManager: Changing scene to ", scene_path)
	# Ensure game is not paused before changing scene
	get_tree().paused = false
	# Use call_deferred to ensure scene change happens on next frame
	get_tree().call_deferred("change_scene_to_file", scene_path)

