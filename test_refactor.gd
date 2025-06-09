# test_refactor.gd - 重构验证测试脚本
extends Node

func _ready():
	print("=== 重构验证测试开始 ===")
	test_player_systems()

func test_player_systems():
	# 等待一帧确保所有节点都准备好了
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ 测试失败：未找到玩家节点")
		return
	
	print("✅ 找到玩家节点：", player.name)
	
	# 测试系统组件
	if not player.inventory_system:
		print("❌ 背包系统未初始化")
		return
	else:
		print("✅ 背包系统已初始化：", player.inventory_system.name)
	
	if not player.weapon_system:
		print("❌ 武器系统未初始化")
		return
	else:
		print("✅ 武器系统已初始化：", player.weapon_system.name)
	
	# 测试武器系统
	var current_weapon = player.get_current_weapon()
	if current_weapon:
		print("✅ 当前武器：", current_weapon.weapon_name, " 攻击力：", current_weapon.attack_power)
	else:
		print("❌ 无当前武器")
	
	var weapon_count = player.get_weapon_count()
	print("✅ 武器总数：", weapon_count)
	
	# 测试背包系统
	var keys = player.get_keys()
	print("✅ 钥匙数量：", keys.size(), " 钥匙列表：", keys)
	
	# 测试添加钥匙
	player.add_key("test_key")
	var keys_after = player.get_keys()
	if "test_key" in keys_after:
		print("✅ 钥匙添加测试成功")
	else:
		print("❌ 钥匙添加测试失败")
	
	# 测试武器切换（如果有多把武器）
	if weapon_count > 1:
		var original_weapon = player.get_current_weapon()
		player.switch_to_next_weapon()
		var new_weapon = player.get_current_weapon()
		if new_weapon and new_weapon.weapon_id != original_weapon.weapon_id:
			print("✅ 武器切换测试成功")
		else:
			print("❌ 武器切换测试失败")
	
	print("=== 重构验证测试完成 ===") 