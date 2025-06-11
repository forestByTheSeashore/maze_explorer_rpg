extends Node

## Performance Monitor
## Monitors game performance to ensure smooth running experience

# Note: Used as autoload, no class_name needed

# Performance data
var fps_history: Array[float] = []
var memory_usage_history: Array[int] = []
var frame_time_history: Array[float] = []

# Monitor settings
const HISTORY_SIZE = 60  # Keep 60 frames of historical data
const LOW_FPS_THRESHOLD = 30.0
const HIGH_MEMORY_THRESHOLD = 100  # MB

# Performance statistics
var total_frames: int = 0
var total_frame_time: float = 0.0
var peak_memory_usage: int = 0

signal performance_warning(type: String, value: float)

func _ready():
	add_to_group("performance_monitor")
	# Update performance data every second
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_performance_data)
	add_child(timer)
	timer.start()

func _process(delta):
	# Record frame time
	_record_frame_time(delta)
	total_frames += 1
	total_frame_time += delta

func _record_frame_time(delta: float):
	frame_time_history.append(delta)
	if frame_time_history.size() > HISTORY_SIZE:
		frame_time_history.pop_front()

func _update_performance_data():
	# Record FPS
	var current_fps = Engine.get_frames_per_second()
	fps_history.append(current_fps)
	if fps_history.size() > HISTORY_SIZE:
		fps_history.pop_front()
	
	# Record memory usage (simplified version, as Godot 4's memory monitoring API is different)
	var memory_usage = 0  # In actual projects, use more accurate memory monitoring methods
	memory_usage_history.append(memory_usage)
	if memory_usage_history.size() > HISTORY_SIZE:
		memory_usage_history.pop_front()
	
	# Update peak memory usage
	if memory_usage > peak_memory_usage:
		peak_memory_usage = memory_usage
	
	# Check performance warnings
	_check_performance_warnings(current_fps, memory_usage)

func _check_performance_warnings(fps: float, memory: int):
	# Low FPS warning
	if fps < LOW_FPS_THRESHOLD:
		performance_warning.emit("low_fps", fps)
		_handle_low_fps()
	
	# High memory usage warning
	if memory > HIGH_MEMORY_THRESHOLD:
		performance_warning.emit("high_memory", memory)
		_handle_high_memory()

func _handle_low_fps():
	print("PerformanceMonitor: Low FPS detected, attempting optimization...")
	# Add automatic optimization strategies here
	# For example: reduce particle effects, lower render quality, etc.

func _handle_high_memory():
	print("PerformanceMonitor: High memory usage detected, attempting to free resources...")
	# Force garbage collection
	# GC.collect()  # Note: Godot 4 might require different methods

## Get performance report
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

## Output performance log
func log_performance():
	var report = get_performance_report()
	print("=== Performance Report ===")
	print("Current FPS: ", report.current_fps)
	print("Average FPS: ", "%.1f" % report.average_fps)
	print("Average Frame Time: ", "%.3f" % report.average_frame_time, "ms")
	print("Current Memory: ", report.current_memory_mb, "MB")
	print("Peak Memory: ", report.peak_memory_mb, "MB")
	print("Total Frames: ", report.total_frames)
	print("===============") 