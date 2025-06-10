extends CanvasLayer

# 通知管理器 - 用于显示游戏中的各种消息
# 例如：保存成功、加载失败等

var notification_container: VBoxContainer
var notification_queue = []
var max_notifications = 5  # 增加最大通知数量
var notification_duration = 3.0

# 通知类型配置
var notification_types = {
	"success": {
		"color": Color(0.2, 0.8, 0.2, 0.95),
		"icon": "✓",
		"sound": "pickup"
	},
	"error": {
		"color": Color(0.8, 0.2, 0.2, 0.95),
		"icon": "✗",
		"sound": "door_locked"
	},
	"warning": {
		"color": Color(0.9, 0.7, 0.2, 0.95),
		"icon": "⚠",
		"sound": "button_click"
	},
	"info": {
		"color": Color(0.2, 0.5, 0.9, 0.95),
		"icon": "ℹ",
		"sound": null
	},
	"achievement": {
		"color": Color(0.8, 0.4, 0.9, 0.95),
		"icon": "🏆",
		"sound": "level_complete"
	},
	"pickup": {
		"color": Color(0.3, 0.9, 0.6, 0.95),
		"icon": "📦",
		"sound": "pickup"
	},
	"navigation": {
		"color": Color(0.4, 0.8, 0.9, 0.95),
		"icon": "🧭",
		"sound": null
	}
}

func _ready():
	print("NotificationManager: 开始初始化...")
	
	# 确保通知系统在暂停时也能工作
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 创建通知容器
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notification_container.position = Vector2(-320, 20)  # 右上角位置
	notification_container.custom_minimum_size = Vector2(300, 0)
	add_child(notification_container)
	
	print("NotificationManager: 初始化完成")

# 显示通知消息
func show_notification(message: String, type: String = "info", duration: float = 3.0):
	print("NotificationManager: 显示通知 - ", message)
	
	# 播放音效
	_play_notification_sound(type)
	
	# 创建通知节点
	var notification = create_notification_node(message, type)
	
	# 添加到容器
	notification_container.add_child(notification)
	notification_queue.append(notification)
	
	# 如果通知太多，移除最早的
	while notification_queue.size() > max_notifications:
		var old_notification = notification_queue.pop_front()
		if is_instance_valid(old_notification):
			remove_notification(old_notification)
	
	# 设置自动移除
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): remove_notification(notification))
	
	# 显示动画
	animate_notification_in(notification)

# 创建通知节点
func create_notification_node(message: String, type: String) -> Control:
	var notification = Panel.new()
	notification.custom_minimum_size = Vector2(300, 70)
	
	# 获取类型配置
	var type_config = notification_types.get(type, notification_types["info"])
	
	# 设置样式
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = type_config.color
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color.WHITE.lerp(type_config.color, 0.3)
	notification.add_theme_stylebox_override("panel", style_box)
	
	# 创建主容器
	var main_container = HBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 10)
	notification.add_child(main_container)
	
	# 添加图标
	var icon_label = Label.new()
	icon_label.text = type_config.icon
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(40, 0)
	main_container.add_child(icon_label)
	
	# 添加文本标签
	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(label)
	
	return notification

# 播放通知音效
func _play_notification_sound(type: String):
	var type_config = notification_types.get(type, notification_types["info"])
	var sound_name = type_config.get("sound")
	
	if sound_name:
		var audio_manager = get_node_or_null("/root/AudioManager")
		if audio_manager and audio_manager.has_method("play_sfx"):
			# 简化版音频系统的音效映射
			var simple_sound = ""
			match sound_name:
				"pickup":
					simple_sound = "pickup"
				"door_locked":
					simple_sound = "door_open"
				"button_click":
					simple_sound = "button"
				"level_complete":
					simple_sound = "victory"
				_:
					simple_sound = "button"  # 默认使用按钮音效
			
			audio_manager.play_sfx(simple_sound, -5.0)

# 移除通知
func remove_notification(notification: Control):
	if is_instance_valid(notification) and notification in notification_queue:
		notification_queue.erase(notification)
		animate_notification_out(notification)

# 显示动画
func animate_notification_in(notification: Control):
	notification.modulate.a = 0.0
	notification.scale = Vector2(0.8, 0.8)
	notification.position.x += 50  # 从右侧滑入
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.4)
	tween.tween_property(notification, "scale", Vector2(1.0, 1.0), 0.4)
	tween.tween_property(notification, "position:x", notification.position.x - 50, 0.4)

# 隐藏动画
func animate_notification_out(notification: Control):
	if not is_instance_valid(notification):
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 0.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(0.8, 0.8), 0.3)
	tween.tween_property(notification, "position:x", notification.position.x + 50, 0.3)
	tween.tween_callback(func(): 
		if is_instance_valid(notification):
			notification.queue_free()
	).set_delay(0.3)

# 清除所有通知
func clear_all_notifications():
	for notification in notification_queue:
		if is_instance_valid(notification):
			notification.queue_free()
	notification_queue.clear()

# 便捷方法
func show_success(message: String, duration: float = 3.0):
	show_notification(message, "success", duration)

func show_error(message: String, duration: float = 4.0):
	show_notification(message, "error", duration)

func show_warning(message: String, duration: float = 3.5):
	show_notification(message, "warning", duration)

func show_info(message: String, duration: float = 3.0):
	show_notification(message, "info", duration)

func show_achievement(message: String, duration: float = 5.0):
	show_notification(message, "achievement", duration)

func show_pickup(message: String, duration: float = 2.5):
	show_notification(message, "pickup", duration)

func show_navigation(message: String, duration: float = 3.0):
	show_notification(message, "navigation", duration)

## ============================================================================
## 游戏特定的通知方法
## ============================================================================

# 钥匙相关通知
func notify_key_obtained(key_type: String = "钥匙"):
	show_pickup("🔑 成功获得" + key_type + "！现在可以打开门了", 4.0)

func notify_key_used(key_type: String = "钥匙"):
	show_info("🔑 使用了" + key_type)

func notify_key_required(key_type: String = "钥匙"):
	show_warning("🚪 这扇门需要" + key_type + "才能打开")

func notify_key_already_collected():
	show_navigation("🔑 钥匙已经被拾取！请导航到出口门")

# 导航相关通知
func notify_navigation_to_key():
	show_navigation("🧭 显示到钥匙的路径")

func notify_navigation_to_door():
	show_navigation("🧭 显示到出口门的路径")

func notify_navigation_disabled():
	show_info("🧭 路径提示已关闭")

# 物品拾取通知
func notify_weapon_obtained(weapon_name: String, attack_power: int):
	show_pickup("⚔️ 获得武器：" + weapon_name + "（攻击力+" + str(attack_power) + "）", 3.5)

func notify_hp_increased(amount: int):
	show_pickup("❤️ 生命值永久增加+" + str(amount) + "！", 3.0)

# 战斗相关通知
func notify_enemy_defeated(enemy_name: String):
	show_success("⚔️ 击败了" + enemy_name + "！")

func notify_player_hurt(damage: int):
	show_warning("💔 受到" + str(damage) + "点伤害！")

# 游戏进度通知
func notify_level_complete():
	show_achievement("🎉 关卡完成！恭喜通关！", 6.0)

func notify_door_opened():
	show_success("🚪 门已打开！")

func notify_door_locked():
	show_warning("🔒 门被锁住了")

# 系统通知
func notify_game_saved():
	show_success("💾 游戏已保存")

func notify_game_loaded():
	show_success("📁 游戏已加载")

func notify_quick_save():
	show_info("💾 快速保存中...")

func notify_quick_load():
	show_info("📁 快速加载中...") 