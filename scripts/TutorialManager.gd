extends Node

## Tutorial Manager
## Provides game guidance and instructions for new players

signal tutorial_step_completed(step_name: String)
signal tutorial_finished()

# Tutorial step definitions
enum TutorialStep {
	WELCOME,
	MOVEMENT,
	INVENTORY,
	COMBAT,
	DOORS_AND_KEYS,
	MINIMAP,
	SAVING,
	COMPLETED
}

var current_step: TutorialStep = TutorialStep.WELCOME
var tutorial_enabled: bool = true
var tutorial_overlay: Control = null
var step_completed: Array[bool] = []

func _ready():
	add_to_group("tutorial_manager")
	# Initialize completion status array
	step_completed.resize(TutorialStep.size())
	step_completed.fill(false)
	
	# Check if player is new
	_check_first_time_player()

func _check_first_time_player():
	var config = ConfigFile.new()
	var config_path = "user://tutorial_config.cfg"
	
	if config.load(config_path) == OK:
		tutorial_enabled = not config.get_value("tutorial", "completed", false)
	
	if tutorial_enabled:
		print("TutorialManager: Detected new player, starting tutorial")
		call_deferred("start_tutorial")

func start_tutorial():
	print("TutorialManager: Starting tutorial")
	current_step = TutorialStep.WELCOME
	_create_tutorial_overlay()
	_show_tutorial_step(current_step)

func _create_tutorial_overlay():
	if tutorial_overlay:
		return
	
	# Create tutorial UI overlay
	tutorial_overlay = Control.new()
	tutorial_overlay.name = "TutorialOverlay"
	tutorial_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create tutorial panel
	var tutorial_panel = Panel.new()
	tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tutorial_panel.size = Vector2(800, 150)
	tutorial_panel.position.y = -180
	tutorial_panel.position.x = (get_viewport().get_visible_rect().size.x - 800) / 2
	
	# Add tutorial text
	var tutorial_label = RichTextLabel.new()
	tutorial_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_label.add_theme_font_size_override("normal_font_size", 18)
	tutorial_label.fit_content = true
	tutorial_label.scroll_active = false
	tutorial_panel.add_child(tutorial_label)
	
	# Add close button
	var close_button = Button.new()
	close_button.text = "Skip Tutorial"
	close_button.size = Vector2(100, 30)
	close_button.position = Vector2(tutorial_panel.size.x - 110, 10)
	close_button.pressed.connect(_skip_tutorial)
	tutorial_panel.add_child(close_button)
	
	# Add next button
	var next_button = Button.new()
	next_button.text = "Next"
	next_button.size = Vector2(80, 30)
	next_button.position = Vector2(tutorial_panel.size.x - 200, 10)
	next_button.pressed.connect(_next_tutorial_step)
	tutorial_panel.add_child(next_button)
	
	tutorial_overlay.add_child(tutorial_panel)
	
	# Add to scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(tutorial_overlay)
		tutorial_overlay.z_index = 1000  # Ensure it's on top

func _show_tutorial_step(step: TutorialStep):
	if not tutorial_overlay:
		return
	
	var label = tutorial_overlay.get_node_or_null("Panel/RichTextLabel")
	if not label:
		return
	
	var tutorial_texts = {
		TutorialStep.WELCOME: "[center][b]Welcome to Maze Fighting Explorer![/b][/center]\nThis is an adventure game about exploring mazes, collecting items, and fighting enemies.\nLet's start the tutorial and learn the basic controls!",
		
		TutorialStep.MOVEMENT: "[center][b]Movement Controls[/b][/center]\nUse [b]WASD[/b] keys or [b]Arrow Keys[/b] to move your character.\nTry moving around now!",
		
		TutorialStep.INVENTORY: "[center][b]Inventory System[/b][/center]\nPress [b]I[/b] to open inventory and view items.\nUse [b]1-4[/b] number keys to quickly switch weapons.\nPress [b]Tab[/b] to cycle through weapons.",
		
		TutorialStep.COMBAT: "[center][b]Combat System[/b][/center]\nPress [b]J[/b] to attack enemies.\nYour attack power must be greater than the enemy's to defeat them.\nCollect stronger weapons to increase your attack power!",
		
		TutorialStep.DOORS_AND_KEYS: "[center][b]Doors and Keys[/b][/center]\nRed doors require keys to open.\nGet close to a door and press [b]F[/b] to interact.\nCollect keys and find the exit door to complete the level!",
		
		TutorialStep.MINIMAP: "[center][b]Minimap and Path Hints[/b][/center]\nPress [b]M[/b] to toggle minimap display.\nPress [b]F1[/b] to show path to key.\nPress [b]F2[/b] to show path to exit door.",
		
		TutorialStep.SAVING: "[center][b]Saving Game[/b][/center]\nPress [b]ESC[/b] to open pause menu for save/load.\nPress [b]F5[/b] for quick save, [b]F6[/b] for quick load.\nYour progress will be securely encrypted!",
		
		TutorialStep.COMPLETED: "[center][b]Tutorial Completed![/b][/center]\nCongratulations! You've mastered all basic controls.\nNow go explore the maze, find keys, and defeat enemies!\nHave fun playing!"
	}
	
	label.text = tutorial_texts.get(step, "Tutorial text not found")
	print("TutorialManager: Showing tutorial step ", TutorialStep.keys()[step])

func _next_tutorial_step():
	step_completed[current_step] = true
	tutorial_step_completed.emit(TutorialStep.keys()[current_step])
	
	if current_step < TutorialStep.COMPLETED:
		current_step += 1
		_show_tutorial_step(current_step)
		
		if current_step == TutorialStep.COMPLETED:
			# Delay tutorial closing
			await get_tree().create_timer(3.0).timeout
			_finish_tutorial()
	else:
		_finish_tutorial()

func _skip_tutorial():
	print("TutorialManager: Player skipped tutorial")
	_finish_tutorial()

func _finish_tutorial():
	print("TutorialManager: Tutorial ended")
	tutorial_finished.emit()
	
	# Save tutorial completion status
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", true)
	config.save("user://tutorial_config.cfg")
	
	# Remove tutorial UI
	if tutorial_overlay:
		tutorial_overlay.queue_free()
		tutorial_overlay = null
	
	tutorial_enabled = false

func reset_tutorial():
	"""Reset tutorial status, used for testing or rewatching"""
	var config = ConfigFile.new()
	config.set_value("tutorial", "completed", false)
	config.save("user://tutorial_config.cfg")
	tutorial_enabled = true
	step_completed.fill(false)
	current_step = TutorialStep.WELCOME
	print("TutorialManager: Tutorial status has been reset")

func is_tutorial_active() -> bool:
	return tutorial_enabled and tutorial_overlay != null

# Functions for other systems to call
func mark_step_completed(step: TutorialStep):
	if step < TutorialStep.size():
		step_completed[step] = true

func get_tutorial_progress() -> float:
	var completed_count = 0
	for completed in step_completed:
		if completed:
			completed_count += 1
	return float(completed_count) / float(TutorialStep.size()) 