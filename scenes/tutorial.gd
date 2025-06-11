extends Control

# Button references
@onready var back_button = $BackButton
@onready var close_button = $CloseButton

# Scene path constants
const MAIN_MENU_SCENE_PATH = "res://scenes/main_menu.tscn"

# Flag for whether opened from pause menu
var opened_from_pause_menu: bool = false

func _ready():
	# Connect button signals
	back_button.pressed.connect(_on_back_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# If shown in game, set to process when paused
	if get_tree().get_first_node_in_group("player"):
		process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Set initial state
	_setup_ui()

func _setup_ui():
	"""Set up initial UI state"""
	# Ensure scroll container starts from top
	var scroll_container = $ScrollContainer
	if scroll_container:
		scroll_container.scroll_vertical = 0

func _on_back_button_pressed():
	"""Back to main menu button event"""
	print("Returning to main menu")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_close_button_pressed():
	"""Close button event - If opened in game, close UI, otherwise return to main menu"""
	print("Closing tutorial")
	
	# Check if in game (by checking for player node)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Hide UI
		queue_free()
		
		# If opened from pause menu, return to pause menu
		if opened_from_pause_menu:
			var pause_menu = get_tree().get_first_node_in_group("pause_menu")
			if not pause_menu:
				# Try finding pause menu by path
				var current_scene = get_tree().current_scene
				if current_scene:
					pause_menu = current_scene.get_node_or_null("CanvasLayer/PauseMenu")
					if not pause_menu:
						pause_menu = current_scene.find_child("PauseMenu", true, false)
			
			if pause_menu:
				pause_menu.show()
				print("Returning to pause menu")
			else:
				get_tree().paused = false
				print("Pause menu not found, resuming game")
		else:
			# If opened via F7 key, resume game directly
			get_tree().paused = false
			print("Resuming game")
	else:
		# Not in game, return to main menu
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _input(event):
	"""Handle input events"""
	# ESC key closes UI
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()

# Static method: Show tutorial in game
static func show_tutorial_in_game():
	"""Static method to show tutorial UI in game"""
	# Dynamic load to avoid circular reference
	var tutorial_scene = load("res://scenes/tutorial.tscn")
	if not tutorial_scene:
		print("Error: Cannot load tutorial scene")
		return
		
	var tutorial_instance = tutorial_scene.instantiate()
	
	# Get current scene
	var current_scene = Engine.get_main_loop().current_scene
	if current_scene:
		# Pause game
		current_scene.get_tree().paused = true
		# Add to scene tree
		current_scene.add_child(tutorial_instance)
		# Ensure displayed on top
		tutorial_instance.z_index = 1000
		
		print("Showing tutorial UI in game")
	else:
		print("Error: Cannot get current scene") 