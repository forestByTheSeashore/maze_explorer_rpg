# UIManager.gd - Game UI Manager
extends CanvasLayer

@onready var inventory_panel: Control = $StatusBar/InventoryPanel
@onready var status_bar: Control = $StatusBar
@onready var hp_bar = $StatusBar/LeftSection/BarsContainer/HPContainer/HPBar
@onready var exp_bar = $StatusBar/LeftSection/BarsContainer/EXPContainer/EXPBar
@onready var btn_nav = $StatusBar/ButtonSection/BtnNav
@onready var nav_menu = $StatusBar/ButtonSection/BtnNav/NavMenu
@onready var btn_inventory = $StatusBar/ButtonSection/BtnInventory
@onready var btn_map = $StatusBar/ButtonSection/BtnMap

# Animation related variables
var _last_max_hp: float = 100.0
var _hp_animation_tween: Tween = null

# Player connection management
var player_reference: Node = null
var connection_retry_timer: float = 0.0
var connection_retry_interval: float = 1.0

signal minimap_toggled(enabled)
signal key_door_display_toggled(enabled)
signal show_key_path_toggled(enabled)
signal show_door_path_toggled(enabled)

var minimap_enabled := false
var key_door_display_enabled := false
var show_key_path_enabled := false
var show_door_path_enabled := false

func _ready():
	add_to_group("ui_manager")
	print("UIManager initialized, initial max_hp = ", _last_max_hp)
	
	# Disable keyboard focus for buttons, allow mouse clicks only
	btn_nav.focus_mode = Control.FOCUS_NONE
	btn_inventory.focus_mode = Control.FOCUS_NONE
	btn_map.focus_mode = Control.FOCUS_NONE

	# Try to connect to player
	_try_connect_player()
	
	# Connect level manager signals (if exists)
	if LevelManager:
		if LevelManager.has_signal("level_ready_to_initialize"):
			LevelManager.level_ready_to_initialize.connect(_on_level_changed)

	# Connect button signals
	btn_nav.pressed.connect(_on_btn_nav_pressed)
	btn_inventory.pressed.connect(_on_btn_inventory_pressed)
	btn_map.pressed.connect(_on_btn_map_pressed)
	nav_menu.id_pressed.connect(_on_nav_menu_id_pressed)
	
	# Delay level info update to ensure all systems are initialized
	call_deferred("_update_level_display")
	
	# Additional delay for update to ensure save loading and other operations are complete
	call_deferred("_delayed_level_update")

func _process(delta: float):
	# If no player reference, periodically try to reconnect
	if not player_reference:
		connection_retry_timer += delta
		if connection_retry_timer >= connection_retry_interval:
			connection_retry_timer = 0.0
			_try_connect_player()

func _try_connect_player():
	# Find player
	player_reference = get_tree().get_first_node_in_group("player")
	if player_reference:
		print("UIManager: Successfully found player reference")
		# Update player status immediately
		_update_player_status()
	else:
		print("UIManager: Warning - Player reference not found, will retry later")

func _update_player_status():
	if not player_reference:
		return
	
	# Get current player status
	var hp = player_reference.current_hp if "current_hp" in player_reference else 100
	var max_hp = player_reference.max_hp if "max_hp" in player_reference else 100
	var exp = player_reference.current_exp if "current_exp" in player_reference else 0
	var exp_to_next = player_reference.exp_to_next_level if "exp_to_next_level" in player_reference else 50
	
	update_player_status(hp, max_hp, exp, exp_to_next)

func toggle_inventory():
	if inventory_panel:
		inventory_panel.toggle_visibility()

func _input(event):
	# ESC key to close inventory
	if event.is_action_pressed("ui_cancel") and inventory_panel and inventory_panel.visible:
		inventory_panel.hide_inventory()
		get_viewport().set_input_as_handled()

func update_player_status(hp, max_hp, exp, exp_to_next_level):
	print("--- UIManager Update ---")
	print("Received: hp = ", hp, ", max_hp = ", max_hp)
	print("Last max_hp = ", _last_max_hp)
	
	# Check if HP max increase animation is needed
	if max_hp > _last_max_hp:
		print("HP max increase detected! From ", _last_max_hp, " to ", max_hp)
		_play_hp_increase_animation(hp, max_hp)
	else:
		print("HP max not increased, updating values directly")
		# Set values directly
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	# Set experience values
	exp_bar.max_value = exp_to_next_level
	exp_bar.value = exp
	
	# Force update
	hp_bar.queue_redraw()
	exp_bar.queue_redraw()
	
	# Update last max_hp value
	_last_max_hp = max_hp
	
	# Confirm values
	print("After setting: HPBar value = ", hp_bar.value, ", max_value = ", hp_bar.max_value)
	print("EXPBar value = ", exp_bar.value, ", max_value = ", exp_bar.max_value)
	print("------------------------")

func _play_hp_increase_animation(new_hp: float, new_max_hp: float):
	print("Starting HP increase animation")
	
	# Stop previous animation if playing
	if _hp_animation_tween and _hp_animation_tween.is_valid():
		print("Stopping previous animation")
		_hp_animation_tween.kill()
	
	# Create new animation
	_hp_animation_tween = create_tween()
	_hp_animation_tween.set_parallel(true)  # Allow parallel animations
	
	# Make HP bar flash (more noticeable effect)
	_hp_animation_tween.tween_property(hp_bar, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.3)
	_hp_animation_tween.tween_property(hp_bar, "modulate", Color(1, 1, 1, 1), 0.3).set_delay(0.3)
	
	# Add scale effect
	_hp_animation_tween.tween_property(hp_bar, "scale", Vector2(1.1, 1.1), 0.3)
	_hp_animation_tween.tween_property(hp_bar, "scale", Vector2(1, 1), 0.3).set_delay(0.3)
	
	# Update values
	_hp_animation_tween.tween_callback(func():
		print("Updating HP values: ", new_hp, "/", new_max_hp)
		hp_bar.max_value = new_max_hp
		hp_bar.value = new_hp
		hp_bar.queue_redraw()
	).set_delay(0.1)
	
	print("Animation setup complete")

# ============================================================================
# Level Information Management
# ============================================================================
func _on_level_changed(level_name: String):
	"""Update display when level changes"""
	print("UIManager: Received level change signal: ", level_name)
	_update_level_display(level_name)

func _update_level_display(level_name: String = ""):
	"""Update level display"""
	if status_bar and status_bar.has_method("update_level_info"):
		status_bar.update_level_info(level_name)
		print("UIManager: Level display updated: ", level_name)
	else:
		print("UIManager: Warning - StatusBar does not have update_level_info method")

func update_level_info(level_name: String):
	"""Public interface: Update level information"""
	_update_level_display(level_name)

func _delayed_level_update():
	"""Delayed level info update to ensure all data is loaded"""
	await get_tree().create_timer(0.2).timeout  # Wait 200ms
	_update_level_display()

# ============================================================================
# Button Event Handling
# ============================================================================
func _on_btn_nav_pressed():
	# Calculate button's global position
	var button_global_pos = btn_nav.global_position
	var button_size = btn_nav.size
	
	# Set menu position: display below button
	var menu_pos = Vector2i(
		int(button_global_pos.x),
		int(button_global_pos.y + button_size.y)
	)
	
	# Popup menu at specified position
	nav_menu.popup_on_parent(Rect2i(menu_pos, Vector2i(0, 0)))
	print("NAV menu displayed at position: ", menu_pos)

func _on_btn_inventory_pressed():
	toggle_inventory()

func _on_btn_map_pressed():
	minimap_enabled = !minimap_enabled
	emit_signal("minimap_toggled", minimap_enabled)
	# You need to listen for this signal in the scene to control minimap show/hide

func _on_nav_menu_id_pressed(id):
	if id == 0: # key
		show_key_path_enabled = !show_key_path_enabled
		nav_menu.set_item_checked(0, show_key_path_enabled)
		emit_signal("show_key_path_toggled", show_key_path_enabled)
	elif id == 1: # exit door
		show_door_path_enabled = !show_door_path_enabled
		nav_menu.set_item_checked(1, show_door_path_enabled)
		emit_signal("show_door_path_toggled", show_door_path_enabled)
