# InventoryPanel.gd - 背包界面管理
extends Control

@onready var weapons_list: VBoxContainer = $WeaponsSection/WeaponsList
@onready var keys_list: VBoxContainer = $KeysSection/KeysList
@onready var background: ColorRect = $Background

var player_reference: Node = null
var weapon_button_group: ButtonGroup
var update_timer: float = 0.0
var update_interval: float = 0.5  # 更新间隔（秒）

func _ready():
	# 设置背景（如果需要在代码中调整）
	background.color = Color(0, 0, 0, 0.7)  # 半透明黑色背景
	
	# 创建武器按钮组（用于单选）
	weapon_button_group = ButtonGroup.new()
	
	# 查找玩家
	player_reference = get_tree().get_first_node_in_group("player")
	if player_reference:
		# 连接玩家的背包变化信号
		if player_reference.has_signal("inventory_changed"):
			player_reference.inventory_changed.connect(_on_inventory_changed)
			print("背包UI: 成功连接玩家的inventory_changed信号")
		else:
			print("背包UI: 警告 - 玩家没有inventory_changed信号")
	else:
		print("背包UI: 警告 - 未找到玩家引用")
	
	# 初始显示
	_update_display()
	
	# 默认隐藏
	visible = false

func _process(_delta: float):
	# 暂时禁用定时更新，只通过信号更新
	pass

func _on_inventory_changed():
	# 当玩家背包发生变化时立即更新显示（即使背包不可见也要准备更新）
	print("背包UI: 收到inventory_changed信号，更新显示")
	if visible:
		_update_display()
	# 即使不可见，也标记需要更新，这样下次显示时会是最新状态
	# 这里可以添加一个标志来记录需要更新

func _update_display():
	_update_weapons_display()
	_update_keys_display()

func _update_weapons_display():
	# 清除现有武器显示
	for child in weapons_list.get_children():
		child.queue_free()
	
	if not player_reference:
		print("背包UI: 没有玩家引用")
		return
	
	var weapons = player_reference.get_available_weapons()
	var current_weapon = player_reference.get_current_weapon()
	var current_weapon_index = player_reference.current_weapon_index
	
	print("背包UI: 更新武器显示，共有", weapons.size(), "把武器")
	print("背包UI: 当前武器:", current_weapon.weapon_name if current_weapon else "无", "索引:", current_weapon_index)
	for i in range(weapons.size()):
		print("背包UI: 武器", i, ":", weapons[i].weapon_name, "攻击力:", weapons[i].attack_power)
	
	# 暂时禁用UI更新标志，防止在重建UI时触发选择事件
	is_updating_from_ui = true
	
	for i in range(weapons.size()):
		var weapon = weapons[i]
		var is_current = (i == current_weapon_index)
		var weapon_button = _create_weapon_button(weapon, i, is_current)
		weapons_list.add_child(weapon_button)
	
	# 重新启用UI更新
	await get_tree().process_frame
	is_updating_from_ui = false

func _create_weapon_button(weapon: WeaponData, index: int, is_current: bool) -> Control:
	var button_container = HBoxContainer.new()
    
    # 武器选择按钮（单选按钮）
	var radio_button = CheckBox.new()
	radio_button.button_group = weapon_button_group
	radio_button.button_pressed = is_current
	radio_button.custom_minimum_size = Vector2(20, 20)
    
    # 数字键标签
	var number_label = Label.new()
	number_label.text = "[%d]" % (index + 1)
	number_label.custom_minimum_size = Vector2(30, 20)
	number_label.add_theme_font_size_override("font_size", 10)
	number_label.modulate = Color.CYAN
    
    # 武器信息标签
	var weapon_label = Label.new()
	weapon_label.text = "%s (攻击力: %d)" % [weapon.weapon_name, weapon.attack_power]
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    # 设置武器标签的字体大小
	weapon_label.add_theme_font_size_override("font_size", 10)
    
    # 连接按钮信号
	radio_button.toggled.connect(_on_weapon_selected.bind(index))
    
    # 如果是当前武器，高亮显示
	if is_current:
		weapon_label.modulate = Color.YELLOW
		number_label.modulate = Color.YELLOW
		print("标记当前选中武器: ", weapon.weapon_name)
    
	button_container.add_child(radio_button)
	button_container.add_child(number_label)
	button_container.add_child(weapon_label)
    
	return button_container

var is_updating_from_ui: bool = false  # 防止UI更新循环

func _on_weapon_selected(index: int, pressed: bool):
	if pressed and player_reference and not is_updating_from_ui:
		print("背包UI: 选择武器索引:", index, "当前玩家武器索引:", player_reference.current_weapon_index)
		is_updating_from_ui = true
		player_reference.switch_to_weapon_by_index(index)
		# 延迟重置标志，确保信号处理完毕
		await get_tree().process_frame
		is_updating_from_ui = false

func _update_keys_display():
	# 清除现有钥匙显示
	for child in keys_list.get_children():
		child.queue_free()
	
	if not player_reference:
		return
	
	var keys = player_reference.get_keys()
	
	if keys.is_empty():
		var no_keys_label = Label.new()
		no_keys_label.text = "没有钥匙"
		no_keys_label.modulate = Color.GRAY
		# 设置字体大小
		no_keys_label.add_theme_font_size_override("font_size", 10)
		keys_list.add_child(no_keys_label)
	else:
		for key in keys:
			var key_label = Label.new()
			key_label.text = "🔑 " + key
			# 设置字体大小
			key_label.add_theme_font_size_override("font_size", 10)
			keys_list.add_child(key_label)

func toggle_visibility():
	visible = !visible
	if visible:
		# 当显示背包时立即更新一次，确保显示最新状态
		_update_display()

func show_inventory():
	visible = true
	# 立即更新显示，确保显示最新的钥匙状态
	_update_display()

func hide_inventory():
	visible = false
