extends Node

## 简化版音频管理器
## 专为maze+rpg游戏设计，只包含必要的音频功能

# 音频播放器
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer = null

# 音效和音乐缓存
var sfx_cache: Dictionary = {}
var music_cache: Dictionary = {}

# 音量设置
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

# 当前播放状态
var current_music: AudioStream = null

# 简化的音效配置 - 只保留核心音效
var audio_config: Dictionary = {
	"move": "res://audio/sfx/move.ogg",           # 移动音效
	"attack": "res://audio/sfx/attack.ogg",       # 攻击音效
	"pickup": "res://audio/sfx/pickup.ogg",       # 拾取道具音效
	"door_open": "res://audio/sfx/door.ogg",      # 开门音效
	"button": "res://audio/sfx/button.ogg",       # 按钮/菜单音效
	"victory": "res://audio/sfx/victory.ogg"      # 胜利音效
}

# 简化的音乐配置 - 只保留基本音乐
var music_config: Dictionary = {
	"menu": "res://audio/music/menu.ogg",         # 菜单音乐
	"game": "res://audio/music/game.ogg"          # 游戏音乐
}

func _ready():
	add_to_group("audio_manager")
	_initialize_audio_system()
	_load_audio_settings()
	
	if OS.is_debug_build():
		call_deferred("check_audio_files_status")
		call_deferred("test_audio_system")

func _initialize_audio_system():
	print("AudioManager: 初始化简化版音频系统")
	
	# 创建音乐播放器
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	# 创建音效播放器池（减少到4个）
	for i in range(4):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer" + str(i)
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		sfx_players.append(sfx_player)
	
	print("AudioManager: 简化版音频系统初始化完成")

func _load_audio_settings():
	"""从配置文件加载音频设置"""
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		_apply_volume_settings()

func _apply_volume_settings():
	"""应用音量设置到音频总线"""
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
		
		if AudioServer.get_bus_index("Music") != -1:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
		
		if AudioServer.get_bus_index("SFX") != -1:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))

## 播放音效
func play_sfx(effect_name: String, volume_db: float = 0.0):
	var audio_stream = _get_audio_stream(effect_name, sfx_cache, audio_config)
	if not audio_stream:
		return
	
	var player = _get_available_sfx_player()
	if not player:
		return
	
	player.stream = audio_stream
	player.volume_db = volume_db
	player.play()

## 播放背景音乐
func play_music(music_name: String, loop: bool = true):
	var audio_stream = _get_audio_stream(music_name, music_cache, music_config)
	if not audio_stream:
		print("AudioManager: 无法加载音乐 - ", music_name)
		return
	
	# 如果正在播放相同的音乐，则不重新播放
	if current_music == audio_stream and music_player.playing:
		print("AudioManager: 音乐已在播放 - ", music_name)
		return
	
	current_music = audio_stream
	music_player.stream = audio_stream
	if audio_stream is AudioStreamOggVorbis:
		audio_stream.loop = loop
	music_player.play()
	print("AudioManager: 开始播放音乐 - ", music_name, " (循环: ", loop, ")")

## 停止背景音乐
func stop_music():
	music_player.stop()
	current_music = null

## 停止所有音效
func stop_all_sfx():
	for player in sfx_players:
		if player.playing:
			player.stop()

func _get_audio_stream(audio_name: String, cache: Dictionary, config: Dictionary) -> AudioStream:
	"""获取音频流，优先从缓存中获取"""
	if audio_name in cache:
		return cache[audio_name]
	
	var audio_path = config.get(audio_name, "")
	if audio_path == "":
		cache[audio_name] = null
		return null
	
	if not FileAccess.file_exists(audio_path):
		cache[audio_name] = null
		return null
	
	var audio_stream = load(audio_path)
	if audio_stream:
		cache[audio_name] = audio_stream
		print("AudioManager: 成功加载音频 - ", audio_name, " 路径: ", audio_path)
	else:
		cache[audio_name] = null
		print("AudioManager: 加载音频失败 - ", audio_name, " 路径: ", audio_path)
	
	return audio_stream

func _get_available_sfx_player() -> AudioStreamPlayer:
	"""获取可用的音效播放器"""
	for player in sfx_players:
		if not player.playing:
			return player
	return sfx_players[0] if not sfx_players.is_empty() else null

## 设置音量
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	_apply_volume_settings()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	_apply_volume_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	_apply_volume_settings()

## 预加载音频
func preload_audio():
	"""预加载常用音效"""
	for effect_name in audio_config.keys():
		_get_audio_stream(effect_name, sfx_cache, audio_config)
	
	for music_name in music_config.keys():
		_get_audio_stream(music_name, music_cache, music_config)

## 便捷方法 - 游戏核心音效
func play_move_sound():
	play_sfx("move", -12.0)  # 移动音效音量较低

func play_attack_sound():
	play_sfx("attack")

func play_pickup_sound():
	play_sfx("pickup", -3.0)

func play_door_open_sound():
	play_sfx("door")

func play_button_click_sound():
	play_sfx("button", -8.0)

func play_victory_sound():
	play_sfx("victory", 2.0)

# 移除冗余的音效方法，保持向后兼容
func play_door_locked_sound():
	play_door_open_sound()  # 使用开门音效代替

func play_enemy_hit_sound():
	play_attack_sound()  # 使用攻击音效代替

func play_player_hurt_sound():
	play_attack_sound()  # 使用攻击音效代替

func play_level_complete_sound():
	play_victory_sound()

func play_footsteps_sound():
	play_move_sound()

## 简化的音乐控制
func play_menu_music():
	play_music("menu")

func play_game_music():
	play_music("game")

# 保持向后兼容的别名
func play_main_menu_music():
	play_menu_music()

func play_gameplay_music():
	play_game_music()

func play_victory_music():
	play_victory_sound()
	stop_music()

# 移除环境音相关功能
func play_ambient(ambient_name: String, loop: bool = true):
	pass  # 空实现，保持兼容性

func stop_ambient():
	pass  # 空实现，保持兼容性

func is_music_playing() -> bool:
	return music_player != null and music_player.playing

func is_ambient_playing() -> bool:
	return false  # 简化版不支持环境音

func get_current_music_name() -> String:
	for name in music_config.keys():
		if music_cache.get(name) == current_music:
			return name
	return ""

func clear_audio_cache():
	sfx_cache.clear()
	music_cache.clear()

## 检查音频文件状态
func check_audio_files_status():
	print("=== 简化版音频系统 - 文件状态检查 ===")
	
	print("音效文件:")
	for effect_name in audio_config.keys():
		var audio_path = audio_config[effect_name]
		var exists = FileAccess.file_exists(audio_path)
		print("  [", "✓" if exists else "✗", "] ", effect_name, " -> ", audio_path)
	
	print("音乐文件:")
	for music_name in music_config.keys():
		var audio_path = music_config[music_name]
		var exists = FileAccess.file_exists(audio_path)
		print("  [", "✓" if exists else "✗", "] ", music_name, " -> ", audio_path)
	
	print("=======================================")

func get_audio_status() -> Dictionary:
	return {
		"total_sfx_configured": audio_config.size(),
		"total_music_configured": music_config.size(),
		"sfx_cached": sfx_cache.size(),
		"music_cached": music_cache.size(),
		"music_playing": is_music_playing(),
		"current_music": get_current_music_name()
	}

func test_audio_system():
	"""测试音频系统功能"""
	print("=== 音频系统测试 ===")
	
	# 测试音频总线
	print("Master音频总线索引: ", AudioServer.get_bus_index("Master"))
	print("Music音频总线索引: ", AudioServer.get_bus_index("Music"))
	print("SFX音频总线索引: ", AudioServer.get_bus_index("SFX"))
	
	# 测试音量设置
	print("Master音量: ", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))
	print("Music音量: ", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))))
	print("SFX音量: ", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))))
	
	# 测试音频播放器状态
	print("音乐播放器状态: ", music_player.playing if music_player else "null")
	print("音效播放器数量: ", sfx_players.size())
	
	print("====================") 