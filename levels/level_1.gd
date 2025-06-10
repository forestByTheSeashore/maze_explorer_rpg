# level_1.gd
extends Node2D

# 关卡信息
var current_level_name: String = "level_1"

# 添加 GameManager 引用
@onready var game_manager = get_node("/root/GameManager")

@onready var player = $Player
@onready var entry_door: Node = $DoorRoot/Door_entrance # 确保名称匹配
@onready var exit_door: Node = $DoorRoot/Door_exit   # 确保名称匹配
@onready var tile_map: TileMap = $TileMap
@onready var minimap = $CanvasLayer/MiniMap
@onready var pause_menu = get_node_or_null("CanvasLayer/PauseMenu") # 安全获取暂停菜单节点引用
@onready var ui_manager = $UiManager

# 添加路径显示状态变量
var show_path_to_key := false
var show_path_to_door := false
var path_lines := []  # 存储所有路径线
# 新增：路径显示设置
var path_width := 4.0       # 路径线宽度
var path_smoothing := true  # 是否平滑路径
var path_gradient := true   # 是否使用渐变色

# === 物品/敌人配置 ===
var packed_scenes = {
	"Key": preload("res://scenes/Key.tscn"),
	"Hp_bean": preload("res://scenes/Hp_bean.tscn"),
	"IronSword_type0": preload("res://scenes/IronSword.tscn"),
	"IronSword_type1": preload("res://scenes/IronSword.tscn"),
	"IronSword_type2": preload("res://scenes/IronSword.tscn"),
	"IronSword_type3": preload("res://scenes/IronSword.tscn"),
	"Enemy_Goblin": preload("res://scenes/goblin.tscn"),
	"Enemy_Skeleton": preload("res://scenes/skelontonEnemy.tscn"),
	"Enemy_Slime": preload("res://scenes/slime.tscn")
}

# 默认物品和敌人数量配置 (会被LevelManager覆盖)
var desired_counts = {
	"Key": 1,
	"Hp_bean": 30,
	"IronSword_type0": 3,
	"IronSword_type1": 2,
	"IronSword_type2": 2,
	"IronSword_type3": 1,
	"Enemy_Goblin": 3,
	"Enemy_Skeleton": 2,
	"Enemy_Slime": 4
}

# 移除  signal player_reached_exit，因为我们将直接响应门的打开事件

func _ready():
	print("Level_1: _ready 开始...")
	
	# 初始化路径状态
	show_path_to_key = false
	show_path_to_door = false
	path_lines.clear()
	
	if entry_door == null:
		push_error("Error: EntryDoor node not found in scene!")
		return
	if exit_door == null:
		push_error("Error: ExitDoor node not found in scene!")
		return

	# 检查暂停菜单
	print("Level_1: 检查暂停菜单节点...")
	pause_menu = get_node_or_null("CanvasLayer/PauseMenu")
	if pause_menu:
		print("Level_1: 暂停菜单找到了: ", pause_menu.name)
	else:
		print("Level_1: 警告 - 暂停菜单未找到，尝试其他路径...")
		# 尝试其他可能的路径
		pause_menu = get_node_or_null("PauseMenu")
		if pause_menu:
			print("Level_1: 在根路径找到暂停菜单")
		else:
			var canvas_layer = get_node_or_null("CanvasLayer")
			if canvas_layer:
				print("Level_1: 找到CanvasLayer，子节点列表:")
				for child in canvas_layer.get_children():
					print("  - ", child.name, " (类型: ", child.get_class(), ")")
			else:
				print("Level_1: 连CanvasLayer都没找到")

	# 连接UIManager信号
	if ui_manager:
		if ui_manager.has_signal("minimap_toggled"):
			ui_manager.minimap_toggled.connect(_on_minimap_toggled)
		if ui_manager.has_signal("show_key_path_toggled"):
			ui_manager.show_key_path_toggled.connect(_on_show_key_path_toggled)
		if ui_manager.has_signal("show_door_path_toggled"):
			ui_manager.show_door_path_toggled.connect(_on_show_door_path_toggled)
		print("UIManager信号已连接")
		
		# 通知UI管理器当前关卡信息
		if ui_manager.has_method("update_level_info"):
			ui_manager.update_level_info(current_level_name)
			print("Level_1: 已通知UI管理器当前关卡：", current_level_name)
		
		# 同时更新SaveManager的current_level_name
		var save_manager = get_node_or_null("/root/SaveManager")
		if save_manager:
			save_manager.current_level_name = current_level_name
			print("Level_1: 已更新SaveManager的当前关卡：", current_level_name)

	# 1. 入口门逻辑 (基本不变)
	# entry_door.door_opened.connect(on_entry_door_opened) # 如果需要入口门打开时的特殊逻辑
	# 假设入口门在 _ready() 中已经自行处理了初始打开状态 (根据 door.gd)

	# 将玩家放置在入口门的位置
	if player and entry_door:
		player.global_position = entry_door.global_position + Vector2(32,10)

	# 设置出口门需要钥匙
	if exit_door:
		exit_door.requires_key = true
		exit_door.required_key_type = "master_key"
		exit_door.consume_key_on_open = true
		print("出口门已设置为需要钥匙：", exit_door.required_key_type)

	# 2. 连接出口门的 door_opened 信号到关卡结束处理函数
	if exit_door: # 确保 exit_door 存在
		# 确保 exit_door 确实有 door_opened 信号 (它是在 door.gd 中定义的)
		if exit_door.has_signal("door_opened"):
			exit_door.door_opened.connect(on_exit_door_has_opened)
		else:
			push_error("Error: ExitDoor does not have 'door_opened' signal!")

	# 设置节点组
	if player:
		player.add_to_group("player")
	if tile_map:
		tile_map.add_to_group("tilemap")
	if exit_door:
		exit_door.add_to_group("doors")
	if entry_door:
		entry_door.add_to_group("doors")

	# 获取LevelManager配置并生成物品和敌人
	_apply_level_manager_config()
	
	# 等待一帧确保节点完全初始化
	await get_tree().process_frame
	
	# 连接玩家位置变化信号以实时更新路径
	if player:
		# 检查玩家是否有position_changed信号
		if player.has_signal("position_changed"):
			player.position_changed.connect(_on_player_position_changed)
		else:
			# 如果没有信号，使用定时器定期更新路径
			var timer = Timer.new()
			timer.wait_time = 0.1  # 每0.1秒更新一次
			timer.timeout.connect(_on_player_position_changed)
			timer.autostart = true
			add_child(timer)
			print("Level_1: 使用定时器更新路径")
	
	# 生成物品和敌人
	await _generate_level_objects()

	# 等待导航系统初始化
	await get_tree().process_frame
	var nav_maps = NavigationServer2D.get_maps()
	if not nav_maps.is_empty():
		NavigationServer2D.map_force_update(nav_maps[0])  # 强制更新第一个导航地图
	await get_tree().create_timer(0.2).timeout  # 等待更长时间
	draw_path()

	# 确保暂停菜单初始是隐藏的
	if pause_menu:
		pause_menu.hide()
	
	# 默认隐藏minimap
	if minimap:
		minimap.visible = false

func _apply_level_manager_config():
	"""应用LevelManager的配置到当前关卡"""
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.LEVEL_CONFIGS.has(current_level_name):
		var config = level_manager.LEVEL_CONFIGS[current_level_name]
		print("Level_1: 应用LevelManager配置 - ", current_level_name)
		
		# 更新物品和敌人数量
		desired_counts = {
			"Key": config.items.Key,
			"Hp_bean": config.items.Hp_bean,
			"IronSword_type0": config.items.IronSword.type0,
			"IronSword_type1": config.items.IronSword.type1,
			"IronSword_type2": config.items.IronSword.type2,
			"IronSword_type3": config.items.IronSword.type3,
			"Enemy_Goblin": config.enemies.Goblin,
			"Enemy_Skeleton": config.enemies.Skeleton,
			"Enemy_Slime": config.enemies.Slime
		}
		print("Level_1: 更新配置完成 - ", desired_counts)
	else:
		print("Level_1: 使用默认配置 - ", desired_counts)

func _generate_level_objects():
	"""生成关卡中的物品和敌人 - 参考level_base.gd的逻辑"""
	print("Level_1: 开始生成关卡物品和敌人...")
	
	# 1. 准备实体 (参考level_base.gd的_prepare_entities_for_placement)
	var entities_map: Dictionary = _prepare_entities_for_placement(desired_counts)
	
	var keys_to_place: Array = entities_map.get("Key", [])
	var hp_beans_to_place: Array = entities_map.get("Hp_bean", [])
	var weapons_to_place: Array = []
	weapons_to_place.append_array(entities_map.get("IronSword_type0", []))
	weapons_to_place.append_array(entities_map.get("IronSword_type1", []))
	weapons_to_place.append_array(entities_map.get("IronSword_type2", []))
	weapons_to_place.append_array(entities_map.get("IronSword_type3", []))
	var enemies_to_place: Array = []
	enemies_to_place.append_array(entities_map.get("Enemy_Goblin", []))
	enemies_to_place.append_array(entities_map.get("Enemy_Skeleton", []))
	enemies_to_place.append_array(entities_map.get("Enemy_Slime", []))
	
	# 将所有实体添加到场景树
	var all_entities_to_place_flat: Array = []
	all_entities_to_place_flat.append_array(keys_to_place)
	all_entities_to_place_flat.append_array(hp_beans_to_place)
	all_entities_to_place_flat.append_array(weapons_to_place)
	all_entities_to_place_flat.append_array(enemies_to_place)
	
	for entity_node in all_entities_to_place_flat:
		if not entity_node.is_inside_tree():
			add_child(entity_node)
		entity_node.visible = true
	
	# 2. 为不同类型的物品获取不同的安全位置
	var general_safe_positions = _get_safe_spawn_positions_for_handmade_map()
	var enemy_safe_positions = _get_safe_positions_for_enemies()
	var weapon_safe_positions = _get_safe_positions_for_weapons()
	
	if general_safe_positions.is_empty() and enemy_safe_positions.is_empty() and weapon_safe_positions.is_empty():
		print("Level_1: 警告 - 没有找到任何安全的生成位置")
		return
	
	print("Level_1: 找到一般位置:", general_safe_positions.size(), " 敌人位置:", enemy_safe_positions.size(), " 武器位置:", weapon_safe_positions.size())
	
	# 3. 使用统一的已用位置进行放置
	var globally_used_positions: Array = []
	
	# 参考level_base.gd的放置策略
	if not keys_to_place.is_empty():
		_place_keys_in_handmade_map(keys_to_place, general_safe_positions, globally_used_positions, 200.0)
	
	if not hp_beans_to_place.is_empty():
		_place_items_safely_in_handmade_map(hp_beans_to_place, general_safe_positions, globally_used_positions, 70.0, "Hp_bean")
	
	if not weapons_to_place.is_empty():
		_place_items_safely_in_handmade_map(weapons_to_place, weapon_safe_positions, globally_used_positions, 150.0, "Weapon")
	
	if not enemies_to_place.is_empty():
		_place_items_safely_in_handmade_map(enemies_to_place, enemy_safe_positions, globally_used_positions, 120.0, "Enemy")
	
	print("Level_1: 物品和敌人生成完成")

func _prepare_entities_for_placement(p_desired_counts: Dictionary) -> Dictionary:
	"""准备要放置的实体 - 参考level_base.gd"""
	var entities_map: Dictionary = {}
	var items_group = get_tree().get_nodes_in_group("items")
	var enemies_group = get_tree().get_nodes_in_group("enemies")
	
	# 构建现有节点映射
	var p_existing_nodes_map = {
		"Key": _get_nodes_by_name_prefix(items_group, "Key"),
		"Hp_bean": _get_nodes_by_name_prefix(items_group, "Hp_bean"),
		"IronSword_type0": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 0),
		"IronSword_type1": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 1),
		"IronSword_type2": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 2),
		"IronSword_type3": _get_nodes_by_name_prefix_and_property(items_group, "IronSword", "sword_type", 3),
		"Enemy_Goblin": _get_nodes_by_name_prefix(enemies_group, "Goblin"),
		"Enemy_Skeleton": _get_nodes_by_name_prefix(enemies_group, "Skeleton"),
		"Enemy_Slime": _get_nodes_by_name_prefix(enemies_group, "Slime")
	}
	
	for type_str in p_desired_counts:
		var desired_num = p_desired_counts[type_str]
		var existing_nodes_of_type: Array = p_existing_nodes_map.get(type_str, [])
		var nodes_for_this_type: Array = []
		
		# 使用现有节点
		var num_to_take_from_existing = min(desired_num, existing_nodes_of_type.size())
		for i in range(num_to_take_from_existing):
			if is_instance_valid(existing_nodes_of_type[i]):
				nodes_for_this_type.append(existing_nodes_of_type[i])
		
		# 创建新节点
		var num_to_instance = desired_num - nodes_for_this_type.size()
		if num_to_instance > 0:
			if packed_scenes.has(type_str) and packed_scenes[type_str] is PackedScene:
				var packed_scene: PackedScene = packed_scenes[type_str]
				for _i in range(num_to_instance):
					var instance = packed_scene.instantiate()
					
					# 设置剑类型
					var sword_type_to_set = -1
					if type_str == "IronSword_type0": sword_type_to_set = 0
					elif type_str == "IronSword_type1": sword_type_to_set = 1
					elif type_str == "IronSword_type2": sword_type_to_set = 2
					elif type_str == "IronSword_type3": sword_type_to_set = 3
					
					if sword_type_to_set != -1:
						if "sword_type" in instance:
							instance.sword_type = sword_type_to_set
						elif instance.has_method("set_sword_type"):
							instance.set_sword_type(sword_type_to_set)
					
					# 设置钥匙类型
					if type_str == "Key":
						if "key_type" in instance:
							instance.key_type = "master_key"
						elif instance.has_method("set_key_type"):
							instance.set_key_type("master_key")
					
					nodes_for_this_type.append(instance)
			else:
				print("错误: 类型 ", type_str, " 的 PackedScene 未正确配置!")
		
		entities_map[type_str] = nodes_for_this_type
		
		# 清理多余的现有节点
		if existing_nodes_of_type.size() > num_to_take_from_existing:
			for i in range(num_to_take_from_existing, existing_nodes_of_type.size()):
				var surplus_node = existing_nodes_of_type[i]
				if is_instance_valid(surplus_node) and surplus_node.is_inside_tree():
					print("移除多余的预设节点: ", surplus_node.name)
					surplus_node.queue_free()
	
	return entities_map

func _get_nodes_by_name_prefix(nodes_array: Array, prefix: String) -> Array:
	"""根据名称前缀获取节点"""
	var result = []
	for node_item in nodes_array:
		if is_instance_valid(node_item) and node_item.name.begins_with(prefix):
			result.append(node_item)
	return result

func _get_nodes_by_name_prefix_and_property(nodes_array: Array, prefix: String, prop_name: String, prop_value) -> Array:
	"""根据名称前缀和属性获取节点"""
	var result = []
	for node_item in nodes_array:
		if is_instance_valid(node_item) and node_item.name.begins_with(prefix):
			var actual_prop_value = null
			if node_item.has_method("get_" + prop_name):
				actual_prop_value = node_item.call("get_" + prop_name)
			elif prop_name in node_item:
				actual_prop_value = node_item.get(prop_name)
			
			if actual_prop_value == prop_value:
				result.append(node_item)
	return result

func _get_safe_spawn_positions_for_handmade_map() -> Array:
	"""为手绘地图获取安全的生成位置 - 针对不同物品类型使用不同标准"""
	var safe_positions: Array = []
	
	if not tile_map or not tile_map.tile_set:
		print("Level_1: TileMap或TileSet未初始化")
		return safe_positions
	
	var tile_size = tile_map.tile_set.tile_size
	var tile_center_offset = tile_size / 2.0
	
	# 排除重要位置周围的区域
	var player_pos = player.global_position
	var entry_pos = entry_door.global_position
	var exit_pos = exit_door.global_position
	var exclusion_radius = 200.0
	var door_exclusion_radius = 250.0
	
	# 遍历地图寻找安全位置
	var map_rect = tile_map.get_used_rect()
	print("Level_1: 地图范围: ", map_rect)
	
	# 缩小搜索范围，避免边缘区域
	for x in range(map_rect.position.x + 4, map_rect.position.x + map_rect.size.x - 4):
		for y in range(map_rect.position.y + 4, map_rect.position.y + map_rect.size.y - 4):
			var tile_pos = Vector2i(x, y)
			
			# 检查当前瓦片是否是可通行的地面 (0,15)
			var atlas_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
			var source_id = tile_map.get_cell_source_id(0, tile_pos)
			
			# 只在有效瓦片且是地面瓦片(0,15)的位置生成物品
			if source_id != -1 and atlas_coords == Vector2i(0, 15):
				# 转换为世界坐标
				var local_pos = tile_map.map_to_local(tile_pos)
				var world_pos = tile_map.to_global(local_pos + tile_center_offset)
				
				# 检查是否在排除区域内
				if world_pos.distance_to(player_pos) < exclusion_radius:
					continue
				if world_pos.distance_to(entry_pos) < door_exclusion_radius:
					continue
				if world_pos.distance_to(exit_pos) < door_exclusion_radius:
					continue
				
				# 检查周围区域是否安全（使用基本的安全标准）
				if _is_position_safe_for_items(x, y):
					safe_positions.append(world_pos)
	
	safe_positions.shuffle()
	print("Level_1: 找到 ", safe_positions.size(), " 个安全生成位置")
	return safe_positions

func _is_position_safe_for_items(x: int, y: int) -> bool:
	"""检查位置是否对一般物品安全（比敌人要求低一些）"""
	# 检查5x5区域
	var floor_count = 0
	var total_count = 0
	
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var check_pos = Vector2i(x + dx, y + dy)
			var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
			var check_source_id = tile_map.get_cell_source_id(0, check_pos)
			total_count += 1
			
			# 只计算地面瓦片
			if check_source_id != -1 and check_atlas_coords == Vector2i(0, 15):
				floor_count += 1
	
	# 要求至少70%是地面瓦片
	var is_safe = floor_count >= total_count * 0.7
	
	# 确保中心位置和直接邻居都是地面瓦片
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var core_pos = Vector2i(x + dx, y + dy)
			var core_atlas = tile_map.get_cell_atlas_coords(0, core_pos)
			var core_source = tile_map.get_cell_source_id(0, core_pos)
			
			if core_source == -1 or core_atlas != Vector2i(0, 15):
				is_safe = false
				break
	
	return is_safe

func _place_keys_in_handmade_map(keys: Array, available_positions: Array, globally_used_positions: Array, min_distance: float):
	"""在手绘地图中放置钥匙"""
	print("Level_1: 开始放置 ", keys.size(), " 个钥匙...")
	
	var positions_copy = available_positions.duplicate()
	var player_pos = player.global_position
	var exit_pos = exit_door.global_position
	
	# 过滤位置，优先选择离出口门较远的位置
	var filtered_positions = []
	for pos in positions_copy:
		if pos.distance_to(exit_pos) > 250.0:  # 距离出口门至少250像素
			filtered_positions.append(pos)
	
	if filtered_positions.size() < keys.size():
		filtered_positions = positions_copy  # 如果过滤后位置不够，使用所有位置
	
	# 按距离出口门排序
	filtered_positions.sort_custom(func(a, b): 
		return a.distance_to(exit_pos) > b.distance_to(exit_pos)
	)
	
	var placed_count = 0
	for key_node in keys:
		var placed_successfully = false
		
		for candidate_pos in filtered_positions:
			# 检查与已用位置的距离
			var too_close = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance:
					too_close = true
					break
			
			if not too_close:
				key_node.global_position = candidate_pos
				key_node.add_to_group("items")
				globally_used_positions.append(candidate_pos)
				filtered_positions.erase(candidate_pos)
				placed_successfully = true
				placed_count += 1
				print("Level_1: 钥匙放置在: ", candidate_pos)
				break
		
		if not placed_successfully:
			print("Level_1: 警告 - 无法为钥匙找到位置，将其隐藏")
			key_node.visible = false
	
	print("Level_1: 成功放置 ", placed_count, "/", keys.size(), " 个钥匙")

func _place_items_safely_in_handmade_map(items: Array, available_positions: Array, globally_used_positions: Array, min_distance: float, category_name: String):
	"""在手绘地图中安全放置物品"""
	if items.is_empty():
		return
	
	print("Level_1: 开始放置 ", items.size(), " 个 ", category_name)
	
	var positions_copy = available_positions.duplicate()
	positions_copy.shuffle()
	
	var placed_count = 0
	
	for item_node in items:
		var placed_successfully = false
		
		for candidate_pos in positions_copy:
			# 检查与已用位置的距离
			var too_close = false
			for used_pos in globally_used_positions:
				if candidate_pos.distance_to(used_pos) < min_distance:
					too_close = true
					break
			
			# 根据物品类型进行额外检查
			if not too_close:
				if category_name == "Enemy":
					if not _is_enemy_position_safe(candidate_pos, item_node):
						too_close = true
				elif category_name == "Weapon":
					if not _is_weapon_position_safe(candidate_pos, item_node):
						too_close = true
			
			if not too_close:
				item_node.global_position = candidate_pos
				# 添加到适当的组
				if category_name == "Enemy":
					item_node.add_to_group("enemies")
				else:
					item_node.add_to_group("items")
				
				globally_used_positions.append(candidate_pos)
				positions_copy.erase(candidate_pos)
				placed_successfully = true
				placed_count += 1
				print("Level_1: ", category_name, " 放置在: ", candidate_pos)
				break
		
		if not placed_successfully:
			print("Level_1: 警告 - 无法为 ", category_name, " 找到位置，将其隐藏")
			item_node.visible = false
	
	print("Level_1: 成功放置 ", placed_count, "/", items.size(), " 个 ", category_name)

func _is_enemy_position_safe(world_pos: Vector2, enemy_node: Node2D) -> bool:
	"""检查敌人位置是否安全，考虑敌人的体积"""
	if not tile_map:
		return false
	
	# 获取敌人的碰撞体半径（更保守的估计）
	var enemy_radius = _get_enemy_collision_radius(enemy_node)
	var tile_size = tile_map.tile_set.tile_size.x
	
	# 将世界坐标转换为瓦片坐标
	var center_tile_pos = tile_map.local_to_map(tile_map.to_local(world_pos))
	
	# 检查敌人占用的瓦片区域（使用更大的安全边距）
	var check_range = int(ceil(enemy_radius / tile_size)) + 1  # 额外增加1个瓦片的安全边距
	
	for dx in range(-check_range, check_range + 1):
		for dy in range(-check_range, check_range + 1):
			var check_tile_pos = Vector2i(center_tile_pos.x + dx, center_tile_pos.y + dy)
			
			# 获取瓦片信息
			var atlas_coords = tile_map.get_cell_atlas_coords(0, check_tile_pos)
			var source_id = tile_map.get_cell_source_id(0, check_tile_pos)
			
			# 如果是墙壁瓦片，直接拒绝
			if source_id != -1 and atlas_coords == Vector2i(6, 0):
				return false
			
			# 如果是空瓦片（迷宫外），也拒绝
			if source_id == -1:
				return false
			
			# 如果不是地面瓦片，也拒绝
			if source_id != -1 and atlas_coords != Vector2i(0, 15):
				return false
	
	# 额外检查：确保敌人中心周围的直接邻居都是安全的
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbor_pos = Vector2i(center_tile_pos.x + dx, center_tile_pos.y + dy)
			var neighbor_atlas = tile_map.get_cell_atlas_coords(0, neighbor_pos)
			var neighbor_source = tile_map.get_cell_source_id(0, neighbor_pos)
			
			# 直接邻居必须都是地面瓦片
			if neighbor_source == -1 or neighbor_atlas != Vector2i(0, 15):
				return false
	
	return true

func _get_enemy_collision_radius(enemy_node: Node2D) -> float:
	"""获取敌人的碰撞体半径（更保守的估计）"""
	var enemy_name = enemy_node.name
	
	# 使用更大的半径确保安全
	if enemy_name.begins_with("Goblin"):
		return 32.0  # 增加到32像素
	elif enemy_name.begins_with("Skeleton"):
		return 36.0  # 增加到36像素
	elif enemy_name.begins_with("Slime"):
		return 28.0  # 增加到28像素
	else:
		return 32.0  # 默认32像素

func _is_weapon_position_safe(world_pos: Vector2, weapon_node: Node2D) -> bool:
	"""检查武器位置是否安全，考虑武器的竖向长条形状"""
	if not tile_map:
		return false
	
	# 武器的大概尺寸（竖向长条形）
	var weapon_width = 16.0   # 宽度较小
	var weapon_height = 32.0  # 高度较大
	var tile_size = tile_map.tile_set.tile_size.x
	
	# 将世界坐标转换为瓦片坐标
	var center_tile_pos = tile_map.local_to_map(tile_map.to_local(world_pos))
	
	# 计算需要检查的瓦片范围（考虑竖向长条形状）
	var width_tiles = int(ceil(weapon_width / tile_size)) + 1
	var height_tiles = int(ceil(weapon_height / tile_size)) + 1
	
	# 检查武器占用的矩形区域
	for dx in range(-width_tiles, width_tiles + 1):
		for dy in range(-height_tiles, height_tiles + 1):
			var check_tile_pos = Vector2i(center_tile_pos.x + dx, center_tile_pos.y + dy)
			
			# 获取瓦片信息
			var atlas_coords = tile_map.get_cell_atlas_coords(0, check_tile_pos)
			var source_id = tile_map.get_cell_source_id(0, check_tile_pos)
			
			# 如果是墙壁瓦片，直接拒绝
			if source_id != -1 and atlas_coords == Vector2i(6, 0):
				return false
			
			# 如果是空瓦片，也拒绝
			if source_id == -1:
				return false
			
			# 如果不是地面瓦片，也拒绝
			if source_id != -1 and atlas_coords != Vector2i(0, 15):
				return false
	
	# 额外检查：确保武器周围有足够的空间（特别是上下方向）
	# 检查中心位置上下各2个瓦片
	for dy in range(-2, 3):
		var vertical_check_pos = Vector2i(center_tile_pos.x, center_tile_pos.y + dy)
		var vertical_atlas = tile_map.get_cell_atlas_coords(0, vertical_check_pos)
		var vertical_source = tile_map.get_cell_source_id(0, vertical_check_pos)
		
		# 垂直方向必须都是地面瓦片
		if vertical_source == -1 or vertical_atlas != Vector2i(0, 15):
			return false
	
	return true

func get_current_level_name() -> String:
	"""返回当前关卡名称"""
	return current_level_name

# UIManager按钮回调函数
func _on_minimap_toggled(enabled: bool):
	print("小地图开关：", enabled)
	if minimap:
		minimap.visible = enabled

func _on_show_key_path_toggled(enabled: bool):
	print("钥匙路径开关：", enabled)
	show_path_to_key = enabled
	if enabled:
		show_path_to_door = false
	update_paths()

func _on_show_door_path_toggled(enabled: bool):
	print("门路径开关：", enabled)
	show_path_to_door = enabled
	if enabled:
		show_path_to_key = false
	update_paths()

func on_exit_door_has_opened(): # 当出口门的 door_opened 信号发出时调用
	print("出口门已打开，Level 1 结束！")
	print("进入 Level 2 - 程序化迷宫关卡")
	
	# 显示关卡完成通知
	var notification_manager = get_node_or_null("/root/NotificationManager")
	if notification_manager:
		notification_manager.notify_level_complete()
	
	# 确保游戏处于非暂停状态再切换场景
	get_tree().paused = false
	
	# 使用LevelManager切换关卡
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		# 设置下一关名称
		level_manager.next_level_name = "level_2"
		# 准备初始化下一关
		level_manager.prepare_next_level()
		# 使用场景切换
		print("准备切换到base_level.tscn...")
		
		# 延迟一帧再切换场景，确保所有标记都被设置
		await get_tree().process_frame
		var error = get_tree().change_scene_to_file("res://levels/base_level.tscn")
		if error != OK:
			push_error("场景切换失败! 错误码: " + str(error))
	else:
		push_error("错误：找不到LevelManager")

func _process(_delta):
	# 处理路径显示按键
	if Input.is_action_just_pressed("way_to_key"):  # F1
		print("show way to key")
		
		var notification_manager = get_node_or_null("/root/NotificationManager")
		
		# 检查钥匙是否已被收集
		if _is_key_collected():
			# 钥匙已被收集
			if notification_manager:
				notification_manager.notify_key_already_collected()
			show_path_to_key = false
			print("Level_1: 钥匙已被收集，提示玩家导航到出口门")
		else:
			# 钥匙还在场景中，可以显示路径
			show_path_to_key = !show_path_to_key
			show_path_to_door = false
			
			if notification_manager:
				if show_path_to_key:
					notification_manager.notify_navigation_to_key()
				else:
					notification_manager.notify_navigation_disabled()
			print("Level_1: 切换钥匙路径显示状态: ", show_path_to_key)
		
		# 立即更新路径显示
		update_paths()
	
	if Input.is_action_just_pressed("way_to_door"):
		print("show way to door")  # F2
		show_path_to_door = !show_path_to_door
		show_path_to_key = false
		
		var notification_manager = get_node_or_null("/root/NotificationManager")
		if notification_manager:
			if show_path_to_door:
				notification_manager.notify_navigation_to_door()
			else:
				notification_manager.notify_navigation_disabled()
		
		# 立即更新路径显示
		update_paths()

	# 快速保存和加载
	if Input.is_action_just_pressed("quick_save"):  # F5
		print("快速保存游戏...")
		
		var save_manager = get_node("/root/SaveManager")
		if save_manager:
			save_manager.quick_save()
		else:
			print("错误：找不到SaveManager")
			var notification_manager = get_node_or_null("/root/NotificationManager")
			if notification_manager:
				notification_manager.show_error("系统错误：找不到SaveManager")
	
	if Input.is_action_just_pressed("quick_load"):  # F6
		print("快速加载游戏...")
		
		var save_manager = get_node("/root/SaveManager")
		if save_manager and save_manager.has_save():
			var save_data = save_manager.load_progress()
			if not save_data.is_empty():
				print("加载成功，准备切换场景...")
				# 这里可以根据需要处理加载后的场景切换逻辑
		else:
			# 只有在没有存档时才显示错误通知
			var notification_manager = get_node_or_null("/root/NotificationManager")
			if notification_manager:
				notification_manager.show_error("没有找到存档文件")
	
	# 显示玩法说明
	if Input.is_action_just_pressed("show_tutorial"):  # F7
		print("显示玩法说明...")
		_show_tutorial_in_game()

# 检查钥匙是否还存在于场景中
func _check_if_key_exists() -> bool:
	var items = get_tree().get_nodes_in_group("items")
	for item in items:
		if item.name.begins_with("Key") and item.visible and is_instance_valid(item):
			return true
	return false

# 检查玩家是否已拥有钥匙
func _check_if_player_has_key() -> bool:
	if player and player.has_method("has_key"):
		return player.has_key("master_key")
	return false

# 检查钥匙的总体状态：是否已被收集
func _is_key_collected() -> bool:
	# 钥匙被收集的条件：
	# 1. 玩家拥有钥匙，或者
	# 2. 场景中没有可见的钥匙
	return _check_if_player_has_key() or not _check_if_key_exists()

# 强制清除所有路径
func clear_all_paths():
	"""立即清除所有绘制的路径线条"""
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()
	show_path_to_key = false
	show_path_to_door = false
	print("Level_1: 强制清除所有路径完成")

func update_paths():
	# 清除所有现有的路径线
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

	# 如果需要显示路径，则重新绘制
	if show_path_to_key or show_path_to_door:
		draw_path()
	else:
		print("Level_1: 所有路径已关闭，清除完成")

func draw_path():
	# 查找场景中的钥匙
	var key = null
	var items = get_tree().get_nodes_in_group("items")
	for item in items:
		if item.name.begins_with("Key") and item.visible and is_instance_valid(item):
			key = item
			break
	
	var door_exit = get_node("DoorRoot/Door_exit")
	
	# 如果需要显示钥匙路径但钥匙已被收集，关闭钥匙路径显示
	if show_path_to_key and not key:
		show_path_to_key = false
		print("Level_1: 钥匙不存在或已被收集，关闭钥匙路径显示")
		return
	
	# 如果没有导航地图，则不绘制路径
	var nav_maps = NavigationServer2D.get_maps()
	if nav_maps.is_empty():
		print("Level_1: 没有可用的导航地图")
		return
	
	var navigation_map = nav_maps[0]
	
	# 绘制到钥匙的路径
	if show_path_to_key and key:
		var path_to_key = NavigationServer2D.map_get_path(
			navigation_map,
			player.global_position,
			key.global_position,
			true
		)
		
		if path_to_key.size() > 1:
			var line = Line2D.new()
			line.width = path_width
			line.default_color = Color.YELLOW
			line.z_index = 10
			add_child(line)
			path_lines.append(line)
			
			for point in path_to_key:
				line.add_point(point)
			
			print("Level_1: 绘制到钥匙的路径，包含 ", path_to_key.size(), " 个点")
	
	# 绘制到门的路径
	if show_path_to_door and door_exit:
		var path_to_door = NavigationServer2D.map_get_path(
			navigation_map,
			player.global_position,
			door_exit.global_position,
			true
		)
		
		if path_to_door.size() > 1:
			var line = Line2D.new()
			line.width = path_width
			line.default_color = Color.CYAN
			line.z_index = 10
			add_child(line)
			path_lines.append(line)
			
			for point in path_to_door:
				line.add_point(point)
			
			print("Level_1: 绘制到门的路径，包含 ", path_to_door.size(), " 个点")

func toggle_pause():
	"""切换暂停状态"""
	if not pause_menu:
		print("暂停菜单不存在，无法切换暂停状态")
		return
	
	if get_tree().paused:
		# 当前已暂停，恢复游戏
		get_tree().paused = false
		pause_menu.hide()
		print("游戏恢复")
	else:
		# 当前未暂停，暂停游戏
		get_tree().paused = true
		pause_menu.show()
		print("游戏暂停")

func _input(event):
	"""处理输入事件"""
	# 处理暂停按键 (Escape)
	if event.is_action_pressed("ui_cancel"): # 默认 Escape 映射到 ui_cancel
		# 只有在游戏未结束时才能暂停
		if player != null and exit_door != null:
			toggle_pause()

	# 玩家与出口门的交互逻辑
	if event.is_action_pressed("interact"): # "interact" 应该映射到 'F' 键
		if player and exit_door:
			# 检查玩家是否足够接近出口门
			var distance_to_exit_door = player.global_position.distance_to(exit_door.global_position)
			if distance_to_exit_door < 30: # 交互范围，可以调整
				# 确保 exit_door 节点有 interact 方法
				if exit_door.has_method("interact"):
					exit_door.interact() # 调用 Door.gd 中的 interact() 方法
				else:
					push_error("Error: ExitDoor node does not have 'interact' method!")

func _on_player_position_changed():
	"""当玩家位置改变时更新路径"""
	if show_path_to_key or show_path_to_door:
		update_paths()

# 显示游戏内玩法说明
func _show_tutorial_in_game():
	"""在游戏中显示玩法说明界面"""
	var tutorial_scene = preload("res://scenes/tutorial.tscn")
	var tutorial_instance = tutorial_scene.instantiate()
	
	# 暂停游戏
	get_tree().paused = true
	
	# 添加到场景树
	add_child(tutorial_instance)
	
	# 确保在最上层显示
	tutorial_instance.z_index = 1000
	tutorial_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	print("Level_1: 在游戏中显示玩法说明界面")

# 清理方法
func _exit_tree():
	"""场景退出时清理资源"""
	for line in path_lines:
		if is_instance_valid(line):
			line.queue_free()
	path_lines.clear()

func _get_safe_positions_for_enemies() -> Array:
	"""为敌人获取特别安全的位置"""
	var safe_positions: Array = []
	
	if not tile_map or not tile_map.tile_set:
		return safe_positions
	
	var tile_size = tile_map.tile_set.tile_size
	var tile_center_offset = tile_size / 2.0
	
	# 排除重要位置周围的区域
	var player_pos = player.global_position
	var entry_pos = entry_door.global_position
	var exit_pos = exit_door.global_position
	var exclusion_radius = 250.0  # 敌人需要更大的排除半径
	var door_exclusion_radius = 300.0
	
	var map_rect = tile_map.get_used_rect()
	
	# 为敌人搜索时避开更多边缘区域
	for x in range(map_rect.position.x + 5, map_rect.position.x + map_rect.size.x - 5):
		for y in range(map_rect.position.y + 5, map_rect.position.y + map_rect.size.y - 5):
			var tile_pos = Vector2i(x, y)
			
			var atlas_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
			var source_id = tile_map.get_cell_source_id(0, tile_pos)
			
			if source_id != -1 and atlas_coords == Vector2i(0, 15):
				var local_pos = tile_map.map_to_local(tile_pos)
				var world_pos = tile_map.to_global(local_pos + tile_center_offset)
				
				if world_pos.distance_to(player_pos) < exclusion_radius:
					continue
				if world_pos.distance_to(entry_pos) < door_exclusion_radius:
					continue
				if world_pos.distance_to(exit_pos) < door_exclusion_radius:
					continue
				
				# 使用更严格的敌人安全检查
				if _is_position_safe_for_large_objects(x, y):
					safe_positions.append(world_pos)
	
	safe_positions.shuffle()
	return safe_positions

func _get_safe_positions_for_weapons() -> Array:
	"""为武器获取适合的位置（考虑竖向长条形状）"""
	var safe_positions: Array = []
	
	if not tile_map or not tile_map.tile_set:
		return safe_positions
	
	var tile_size = tile_map.tile_set.tile_size
	var tile_center_offset = tile_size / 2.0
	
	# 排除重要位置周围的区域
	var player_pos = player.global_position
	var entry_pos = entry_door.global_position
	var exit_pos = exit_door.global_position
	var exclusion_radius = 180.0
	var door_exclusion_radius = 220.0
	
	var map_rect = tile_map.get_used_rect()
	
	# 为武器搜索合适的位置
	for x in range(map_rect.position.x + 3, map_rect.position.x + map_rect.size.x - 3):
		for y in range(map_rect.position.y + 3, map_rect.position.y + map_rect.size.y - 3):
			var tile_pos = Vector2i(x, y)
			
			var atlas_coords = tile_map.get_cell_atlas_coords(0, tile_pos)
			var source_id = tile_map.get_cell_source_id(0, tile_pos)
			
			if source_id != -1 and atlas_coords == Vector2i(0, 15):
				var local_pos = tile_map.map_to_local(tile_pos)
				var world_pos = tile_map.to_global(local_pos + tile_center_offset)
				
				if world_pos.distance_to(player_pos) < exclusion_radius:
					continue
				if world_pos.distance_to(entry_pos) < door_exclusion_radius:
					continue
				if world_pos.distance_to(exit_pos) < door_exclusion_radius:
					continue
				
				# 使用武器专用的安全检查
				if _is_position_safe_for_weapons(x, y):
					safe_positions.append(world_pos)
	
	safe_positions.shuffle()
	return safe_positions

func _is_position_safe_for_large_objects(x: int, y: int) -> bool:
	"""检查位置是否对大型对象（如敌人）安全"""
	# 检查更大的区域 7x7
	var floor_count = 0
	var total_count = 0
	
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var check_pos = Vector2i(x + dx, y + dy)
			var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
			var check_source_id = tile_map.get_cell_source_id(0, check_pos)
			total_count += 1
			
			# 只计算地面瓦片
			if check_source_id != -1 and check_atlas_coords == Vector2i(0, 15):
				floor_count += 1
	
	# 要求至少85%是地面瓦片才认为对敌人安全
	var is_safe = floor_count >= total_count * 0.85
	
	# 额外检查：确保中心3x3区域全部是地面瓦片
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var core_pos = Vector2i(x + dx, y + dy)
			var core_atlas = tile_map.get_cell_atlas_coords(0, core_pos)
			var core_source = tile_map.get_cell_source_id(0, core_pos)
			
			if core_source == -1 or core_atlas != Vector2i(0, 15):
				is_safe = false
				break
	
	return is_safe

func _is_position_safe_for_weapons(x: int, y: int) -> bool:
	"""检查位置是否对武器安全（考虑竖向长条形状）"""
	# 检查武器需要的矩形区域（重点检查垂直方向）
	# 检查中心上下各2个瓦片的垂直通道
	for dy in range(-2, 3):
		var check_pos = Vector2i(x, y + dy)
		var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
		var check_source_id = tile_map.get_cell_source_id(0, check_pos)
		
		# 垂直通道必须全部是地面瓦片
		if check_source_id == -1 or check_atlas_coords != Vector2i(0, 15):
			return false
	
	# 检查水平方向的邻居
	for dx in range(-1, 2):
		var check_pos = Vector2i(x + dx, y)
		var check_atlas_coords = tile_map.get_cell_atlas_coords(0, check_pos)
		var check_source_id = tile_map.get_cell_source_id(0, check_pos)
		
		# 水平邻居也应该是地面瓦片
		if check_source_id == -1 or check_atlas_coords != Vector2i(0, 15):
			return false
	
	return true
