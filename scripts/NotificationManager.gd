extends CanvasLayer

# 通知管理器 - 用于显示游戏中的各种消息
# 例如：保存成功、加载失败等

var notification_container: VBoxContainer
var notification_queue = []
var max_notifications = 3
var notification_duration = 3.0

func _ready():
	print("NotificationManager: 开始初始化...")
	
	# 确保通知系统在暂停时也能工作
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 创建通知容器
	notification_container = VBoxContainer.new()
	notification_container.name = "NotificationContainer"
	notification_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	notification_container.position = Vector2(-300, 20)  # 右上角位置
	add_child(notification_container)
	
	print("NotificationManager: 初始化完成")

# 显示通知消息
func show_notification(message: String, type: String = "info", duration: float = 3.0):
	print("NotificationManager: 显示通知 - ", message)
	
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
	notification.custom_minimum_size = Vector2(280, 60)
	
	# 设置样式
	var style_box = StyleBoxFlat.new()
	match type:
		"success":
			style_box.bg_color = Color(0.2, 0.8, 0.2, 0.9)  # 绿色
		"error":
			style_box.bg_color = Color(0.8, 0.2, 0.2, 0.9)  # 红色
		"warning":
			style_box.bg_color = Color(0.8, 0.8, 0.2, 0.9)  # 黄色
		_:
			style_box.bg_color = Color(0.2, 0.2, 0.8, 0.9)  # 蓝色
	
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	notification.add_theme_stylebox_override("panel", style_box)
	
	# 添加文本标签
	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	
	# 设置标签布局
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.position = Vector2(10, 10)
	label.size = Vector2(260, 40)
	
	notification.add_child(label)
	return notification

# 移除通知
func remove_notification(notification: Control):
	if is_instance_valid(notification) and notification in notification_queue:
		notification_queue.erase(notification)
		animate_notification_out(notification)

# 显示动画
func animate_notification_in(notification: Control):
	notification.modulate.a = 0.0
	notification.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(1.0, 1.0), 0.3)

# 隐藏动画
func animate_notification_out(notification: Control):
	if not is_instance_valid(notification):
		return
		
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 0.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(0.8, 0.8), 0.3)
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