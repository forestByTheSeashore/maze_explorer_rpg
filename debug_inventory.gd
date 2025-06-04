# debug_inventory.gd - 临时调试脚本
extends Node

func _ready():
	print("=== 库存面板调试 ===")
	# 等待一帧确保场景加载完成
	await get_tree().process_frame
	
	check_ui_manager()
	check_player()
	check_inventory_panel()
	
func check_ui_manager():
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager:
		print("✓ UIManager找到:", ui_manager.name, "路径:", ui_manager.get_path())
		print("  UIManager脚本:", ui_manager.get_script())
		
		if ui_manager.has_method("toggle_inventory"):
			print("  ✓ toggle_inventory方法存在")
		else:
			print("  ✗ toggle_inventory方法不存在")
	else:
		print("✗ UIManager未找到")

func check_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("✓ Player找到:", player.name, "路径:", player.get_path())
		
		if player.has_method("_handle_weapon_input"):
			print("  ✓ _handle_weapon_input方法存在")
		else:
			print("  ✗ _handle_weapon_input方法不存在")
			
		if player.has_method("_toggle_inventory_panel"):
			print("  ✓ _toggle_inventory_panel方法存在")
		else:
			print("  ✗ _toggle_inventory_panel方法不存在")
	else:
		print("✗ Player未找到")

func check_inventory_panel():
	var ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager:
		var inventory_panel = ui_manager.get_node_or_null("InventoryPanel")
		if inventory_panel:
			print("✓ InventoryPanel找到:", inventory_panel.name)
			print("  当前可见性:", inventory_panel.visible)
		else:
			print("✗ InventoryPanel未找到")
			# 列出UIManager的子节点
			print("  UIManager子节点:")
			for child in ui_manager.get_children():
				print("    -", child.name, "类型:", child.get_class())
	
func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		print("=== 检测到I键按下 ===")
		
		var player = get_tree().get_first_node_in_group("player")
		if player:
			print("调用玩家的_toggle_inventory_panel...")
			player._toggle_inventory_panel()
		else:
			print("未找到玩家节点") 