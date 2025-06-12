# InventoryPanel.gd - Inventory Interface Management
extends Control

@onready var weapons_list: VBoxContainer = $WeaponsSection/WeaponsList
@onready var keys_list: VBoxContainer = $KeysSection/KeysList
@onready var background: ColorRect = $Background

var player_reference: Node = null
var weapon_button_group: ButtonGroup
var update_timer: float = 0.0
var update_interval: float = 0.5  # Update interval (seconds)
var connection_retry_timer: float = 0.0
var connection_retry_interval: float = 1.0  # Retry interval for player connection

var is_updating_from_ui: bool = false  # Prevent UI update loops

func _ready():
	# Set background (if adjustment needed in code)
	background.color = Color(0, 0, 0, 0.7)  # Semi-transparent black background
	
	# Create weapon button group (for single selection)
	weapon_button_group = ButtonGroup.new()
	
	# Try to connect to player
	_try_connect_player()
	
	# Hidden by default
	visible = false

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
		# Check if signal is already connected
		if player_reference.has_signal("inventory_changed"):
			# Disconnect existing connections to avoid duplicates
			if player_reference.inventory_changed.is_connected(_on_inventory_changed):
				player_reference.inventory_changed.disconnect(_on_inventory_changed)
			# Reconnect signal
			player_reference.inventory_changed.connect(_on_inventory_changed)
			print("Inventory UI: Successfully connected to player's inventory_changed signal")
		else:
			print("Inventory UI: Warning - Player does not have inventory_changed signal")
		
		# Update display immediately after successful connection
		_update_display()
	else:
		print("Inventory UI: Warning - Player reference not found, will retry later")

func _on_inventory_changed():
	# Update display immediately when player inventory changes (even if inventory is not visible)
	print("Inventory UI: Received inventory_changed signal, updating display")
	if visible:
		_update_display()
	# Even if not visible, mark for update, so it will be up to date next time it's shown
	# A flag could be added here to record update needs

func _update_display():
	if not player_reference:
		print("Inventory UI: No player reference, cannot update display")
		_try_connect_player()  # Try to connect again
		return
	
	_update_weapons_display()
	_update_keys_display()

func _update_weapons_display():
	# Clear existing weapon display
	for child in weapons_list.get_children():
		child.queue_free()
	
	if not player_reference:
		print("Inventory UI: No player reference")
		return
	
	# Check if player has weapon system methods
	if not player_reference.has_method("get_available_weapons"):
		print("Inventory UI: Player has no weapon system methods")
		return
	
	var weapons = player_reference.get_available_weapons()
	var current_weapon = player_reference.get_current_weapon()
	var current_weapon_index = -1
	
	# Get current weapon index through weapon system (if weapon system exists)
	if player_reference.weapon_system:
		current_weapon_index = player_reference.weapon_system.get_current_weapon_index()
	else:
		# Backward compatibility: Get index by finding current weapon position in array
		if current_weapon:
			for i in range(weapons.size()):
				if weapons[i].weapon_id == current_weapon.weapon_id:
					current_weapon_index = i
					break
	
	print("Inventory UI: Updating weapon display, total weapons:", weapons.size())
	print("Inventory UI: Current weapon:", current_weapon.weapon_name if current_weapon else "None", "Index:", current_weapon_index)
	for i in range(weapons.size()):
		print("Inventory UI: Weapon", i, ":", weapons[i].weapon_name, "Attack Power:", weapons[i].attack_power)
	
	# Temporarily disable UI update flag to prevent selection events during UI rebuild
	is_updating_from_ui = true
	
	for i in range(weapons.size()):
		var weapon = weapons[i]
		var is_current = (i == current_weapon_index)
		var weapon_button = _create_weapon_button(weapon, i, is_current)
		weapons_list.add_child(weapon_button)
	
	# Re-enable UI updates
	await get_tree().process_frame
	is_updating_from_ui = false

func _create_weapon_button(weapon: WeaponData, index: int, is_current: bool) -> Control:
	var button_container = HBoxContainer.new()
	
	# Weapon selection button (radio button)
	var radio_button = CheckBox.new()
	radio_button.button_group = weapon_button_group
	radio_button.button_pressed = is_current
	radio_button.custom_minimum_size = Vector2(20, 20)
	
	# Number key label
	var number_label = Label.new()
	number_label.text = "[%d]" % (index + 1)
	number_label.custom_minimum_size = Vector2(30, 20)
	number_label.add_theme_font_size_override("font_size", 10)
	number_label.modulate = Color.CYAN
	
	# Weapon info label
	var weapon_label = Label.new()
	weapon_label.text = "%s (Attack: %d)" % [weapon.weapon_name, weapon.attack_power]
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Set weapon label font size
	weapon_label.add_theme_font_size_override("font_size", 10)
	
	# Connect button signal
	radio_button.toggled.connect(_weapon_selected_wrapper.bind(index))
	
	# Highlight if current weapon
	if is_current:
		weapon_label.modulate = Color.YELLOW
		number_label.modulate = Color.YELLOW
		print("Marking current selected weapon: ", weapon.weapon_name)
	
	button_container.add_child(radio_button)
	button_container.add_child(number_label)
	button_container.add_child(weapon_label)
	
	return button_container

# Wrapper function to handle weapon selection safely
func _weapon_selected_wrapper(index: int, pressed: bool):
	_on_weapon_selected(index, pressed)

func _on_weapon_selected(index: int, pressed: bool):
	if pressed and player_reference and not is_updating_from_ui:
		var current_index = -1
		if player_reference.weapon_system:
			current_index = player_reference.weapon_system.get_current_weapon_index()
		print("Inventory UI: Selected weapon index:", index, "Current player weapon index:", current_index)
		is_updating_from_ui = true
		player_reference.switch_to_weapon_by_index(index)
		# Delay resetting flag to ensure signal processing is complete
		await get_tree().process_frame
		is_updating_from_ui = false

func _update_keys_display():
	# Clear existing keys display
	for child in keys_list.get_children():
		child.queue_free()
	
	if not player_reference:
		print("Inventory UI: No player reference, cannot display keys")
		return
	
	# Check if player has key system methods
	if not player_reference.has_method("get_keys"):
		print("Inventory UI: Player has no key system methods")
		return
	
	var keys = player_reference.get_keys()
	print("Inventory UI: Updating keys display, total keys:", keys.size(), "Keys:", keys)
	
	if keys.is_empty():
		var no_keys_label = Label.new()
		no_keys_label.text = "No keys"
		no_keys_label.modulate = Color.GRAY
		# Set font size
		no_keys_label.add_theme_font_size_override("font_size", 10)
		keys_list.add_child(no_keys_label)
	else:
		for key in keys:
			var key_label = Label.new()
			key_label.text = "🔑 " + key
			# Set font size
			key_label.add_theme_font_size_override("font_size", 10)
			keys_list.add_child(key_label)

func toggle_visibility():
	visible = !visible
	if visible:
		# When displaying inventory, ensure player connection and update immediately
		if not player_reference:
			_try_connect_player()
		_update_display()

func show_inventory():
	visible = true
	# Ensure player connection and update display immediately
	if not player_reference:
		_try_connect_player()
	_update_display()

func hide_inventory():
	visible = false
