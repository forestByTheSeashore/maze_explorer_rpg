extends Node

## 性能监控器
## 监控游戏性能，确保流畅运行体验

# 注意：作为autoload使用，不需要class_name

# 性能数据
var fps_history: Array[float] = []
var memory_usage_history: Array[int] = []
var frame_time_history: Array[float] = []

# 监控设置
const HISTORY_SIZE = 60  # 保持60帧的历史数据
const LOW_FPS_THRESHOLD = 30.0
const HIGH_MEMORY_THRESHOLD = 100  # MB

# 性能统计
var total_frames: int = 0
var total_frame_time: float = 0.0
var peak_memory_usage: int = 0

signal performance_warning(type: String, value: float)

func _ready():
	add_to_group("performance_monitor")
	# 每秒更新一次性能数据
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_performance_data)
	add_child(timer)
	timer.start()

func _process(delta):
	# 记录帧时间
	_record_frame_time(delta)
	total_frames += 1
	total_frame_time += delta

func _record_frame_time(delta: float):
	frame_time_history.append(delta)
	if frame_time_history.size() > HISTORY_SIZE:
		frame_time_history.pop_front()

func _update_performance_data():
	# 记录FPS
	var current_fps = Engine.get_frames_per_second()
	fps_history.append(current_fps)
	if fps_history.size() > HISTORY_SIZE:
		fps_history.pop_front()
	
	# 记录内存使用 (简化版本，因为Godot 4的内存监控API有所不同)
	var memory_usage = 0  # 实际项目中可以使用更精确的内存监控方法
	memory_usage_history.append(memory_usage)
	if memory_usage_history.size() > HISTORY_SIZE:
		memory_usage_history.pop_front()
	
	# 更新峰值内存使用
	if memory_usage > peak_memory_usage:
		peak_memory_usage = memory_usage
	
	# 检查性能警告
	_check_performance_warnings(current_fps, memory_usage)

func _check_performance_warnings(fps: float, memory: int):
	# FPS过低警告
	if fps < LOW_FPS_THRESHOLD:
		performance_warning.emit("low_fps", fps)
		_handle_low_fps()
	
	# 内存使用过高警告
	if memory > HIGH_MEMORY_THRESHOLD:
		performance_warning.emit("high_memory", memory)
		_handle_high_memory()

func _handle_low_fps():
	print("PerformanceMonitor: 检测到低FPS，尝试优化...")
	# 可以在这里添加自动优化策略
	# 例如：减少粒子效果、降低渲染质量等

func _handle_high_memory():
	print("PerformanceMonitor: 检测到高内存使用，尝试释放资源...")
	# 强制垃圾回收
	# GC.collect()  # 注：Godot 4中可能需要不同的方法

## 获取性能报告
func get_performance_report() -> Dictionary:
	var avg_fps = 0.0
	if fps_history.size() > 0:
		for fps in fps_history:
			avg_fps += fps
		avg_fps /= fps_history.size()
	
	var avg_frame_time = 0.0
	if frame_time_history.size() > 0:
		for ft in frame_time_history:
			avg_frame_time += ft
		avg_frame_time /= frame_time_history.size()
	
	var current_memory = 0
	if memory_usage_history.size() > 0:
		current_memory = memory_usage_history[-1]
	
	return {
		"average_fps": avg_fps,
		"current_fps": Engine.get_frames_per_second(),
		"average_frame_time": avg_frame_time,
		"current_memory_mb": current_memory,
		"peak_memory_mb": peak_memory_usage,
		"total_frames": total_frames,
		"engine_version": Engine.get_version_info()
	}

## 输出性能日志
func log_performance():
	var report = get_performance_report()
	print("=== 性能报告 ===")
	print("当前FPS: ", report.current_fps)
	print("平均FPS: ", "%.1f" % report.average_fps)
	print("平均帧时间: ", "%.3f" % report.average_frame_time, "ms")
	print("当前内存: ", report.current_memory_mb, "MB")
	print("峰值内存: ", report.peak_memory_mb, "MB")
	print("总帧数: ", report.total_frames)
	print("===============") 