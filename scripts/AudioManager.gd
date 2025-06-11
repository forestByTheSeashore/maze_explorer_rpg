extends Node

## Simplified Audio Manager
## Designed for maze+rpg game, includes only necessary audio functions

# Audio players
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer = null

# SFX and music cache
var sfx_cache: Dictionary = {}
var music_cache: Dictionary = {}

# Volume settings
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0

# Current playback status
var current_music: AudioStream = null

# Simplified SFX configuration - keep only core effects
var audio_config: Dictionary = {
	"move": "res://audio/sfx/move.ogg",           # Movement sound
	"attack": "res://audio/sfx/attack.ogg",       # Attack sound
	"pickup": "res://audio/sfx/pickup.ogg",       # Item pickup sound
	"door_open": "res://audio/sfx/door.ogg",      # Door open sound
	"button": "res://audio/sfx/button.ogg",       # Button/menu sound
	"victory": "res://audio/sfx/victory.ogg"      # Victory sound
}

# Simplified music configuration - keep only basic music
var music_config: Dictionary = {
	"menu": "res://audio/music/menu.ogg",         # Menu music
	"game": "res://audio/music/game.ogg"          # Game music
}

func _ready():
	add_to_group("audio_manager")
	_initialize_audio_system()
	_load_audio_settings()
	
	# Preload all audio files
	call_deferred("preload_audio")
	
	if OS.is_debug_build():
		call_deferred("check_audio_files_status")
		call_deferred("test_audio_system")
		call_deferred("diagnose_audio_issues")

func _initialize_audio_system():
	print("AudioManager: Initializing simplified audio system")
	
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	# Create SFX player pool (reduced to 4)
	for i in range(4):
		var sfx_player = AudioStreamPlayer.new()
		sfx_player.name = "SFXPlayer" + str(i)
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		sfx_players.append(sfx_player)
	
	print("AudioManager: Simplified audio system initialization complete")

func _load_audio_settings():
	"""Load audio settings from config file"""
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_volume = config.get_value("audio", "master_volume", 1.0)
		music_volume = config.get_value("audio", "music_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		_apply_volume_settings()

func _apply_volume_settings():
	"""Apply volume settings to audio buses"""
	if AudioServer.get_bus_count() > 0:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
		
		if AudioServer.get_bus_index("Music") != -1:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
		
		if AudioServer.get_bus_index("SFX") != -1:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))

## Play sound effect
func play_sfx(effect_name: String, volume_db: float = 0.0):
	print("AudioManager: Attempting to play SFX - ", effect_name)
	var audio_stream = _get_audio_stream(effect_name, sfx_cache, audio_config)
	if not audio_stream:
		print("AudioManager: Failed to get audio stream for - ", effect_name)
		return
	
	var player = _get_available_sfx_player()
	if not player:
		print("AudioManager: No available SFX player found")
		return
	
	player.stream = audio_stream
	player.volume_db = volume_db
	player.play()
	print("AudioManager: Successfully started playing SFX - ", effect_name, " on player: ", player.name)

## Play background music
func play_music(music_name: String, loop: bool = true):
	var audio_stream = _get_audio_stream(music_name, music_cache, music_config)
	if not audio_stream:
		print("AudioManager: Cannot load music - ", music_name)
		return
	
	# Don't replay if the same music is already playing
	if current_music == audio_stream and music_player.playing:
		print("AudioManager: Music already playing - ", music_name)
		return
	
	current_music = audio_stream
	music_player.stream = audio_stream
	if audio_stream is AudioStreamOggVorbis:
		audio_stream.loop = loop
	music_player.play()
	print("AudioManager: Starting to play music - ", music_name, " (Loop: ", loop, ")")

## Stop background music
func stop_music():
	music_player.stop()
	current_music = null

## Stop all sound effects
func stop_all_sfx():
	for player in sfx_players:
		if player.playing:
			player.stop()

func _get_audio_stream(audio_name: String, cache: Dictionary, config: Dictionary) -> AudioStream:
	"""Get audio stream, prioritize from cache"""
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
		print("AudioManager: Successfully loaded audio - ", audio_name, " Path: ", audio_path)
	else:
		cache[audio_name] = null
		print("AudioManager: Failed to load audio - ", audio_name, " Path: ", audio_path)
	
	return audio_stream

func _get_available_sfx_player() -> AudioStreamPlayer:
	"""Get available SFX player"""
	for i in range(sfx_players.size()):
		var player = sfx_players[i]
		if not player.playing:
			print("AudioManager: Found available SFX player: ", player.name)
			return player
	
	# If all players are busy, use the first one (interrupt)
	print("AudioManager: All SFX players busy, using first player (interrupting)")
	return sfx_players[0] if not sfx_players.is_empty() else null

## Set volume
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	_apply_volume_settings()

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	_apply_volume_settings()

func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	_apply_volume_settings()

## Preload audio
func preload_audio():
	"""Preload common sound effects"""
	for effect_name in audio_config.keys():
		_get_audio_stream(effect_name, sfx_cache, audio_config)
	
	for music_name in music_config.keys():
		_get_audio_stream(music_name, music_cache, music_config)

## Convenience methods - Game core sound effects
func play_move_sound():
	play_sfx("move", -12.0)  # Movement sound at lower volume

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

# Remove redundant sound methods, maintain backward compatibility
func play_door_locked_sound():
	play_door_open_sound()  # Use door open sound instead

func play_enemy_hit_sound():
	play_attack_sound()  # Use attack sound instead

func play_player_hurt_sound():
	play_attack_sound()  # Use attack sound instead

func play_level_complete_sound():
	play_victory_sound()

func play_footsteps_sound():
	play_move_sound()

## Simplified music control
func play_menu_music():
	play_music("menu")

func play_game_music():
	play_music("game")

# Maintain backward compatible aliases
func play_main_menu_music():
	play_menu_music()

func play_gameplay_music():
	play_game_music()

func play_victory_music():
	play_victory_sound()
	stop_music()

# Remove ambient sound related functionality
func play_ambient(ambient_name: String, loop: bool = true):
	pass  # Empty implementation for compatibility

func stop_ambient():
	pass  # Empty implementation for compatibility

func is_music_playing() -> bool:
	return music_player != null and music_player.playing

func is_ambient_playing() -> bool:
	return false  # Simplified version doesn't support ambient sound

func get_current_music_name() -> String:
	for name in music_config.keys():
		if music_cache.get(name) == current_music:
			return name
	return ""

func clear_audio_cache():
	sfx_cache.clear()
	music_cache.clear()

## Check audio files status
func check_audio_files_status():
	print("=== Simplified audio system - File status check ===")
	
	print("SFX files:")
	for effect_name in audio_config.keys():
		var audio_path = audio_config[effect_name]
		var exists = FileAccess.file_exists(audio_path)
		print("  [", "✓" if exists else "✗", "] ", effect_name, " -> ", audio_path)
	
	print("Music files:")
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
	"""Test audio system functionality"""
	print("=== Audio system test ===")
	
	# Test audio buses
	print("Master audio bus index: ", AudioServer.get_bus_index("Master"))
	print("Music audio bus index: ", AudioServer.get_bus_index("Music"))
	print("SFX audio bus index: ", AudioServer.get_bus_index("SFX"))
	
	# Test volume settings
	print("Master volume: ", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))
	print("Music volume: ", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))))
	print("SFX volume: ", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))))
	
	# Test audio player status
	print("Music player status: ", music_player.playing if music_player else "null")
	print("SFX player count: ", sfx_players.size())
	
	# Test SFX player states
	for i in range(sfx_players.size()):
		var player = sfx_players[i]
		print("SFX Player ", i, " (", player.name, ") - Playing: ", player.playing)
	
	print("====================")

func diagnose_audio_issues():
	"""Diagnose common audio issues"""
	print("=== Audio System Diagnosis ===")
	
	# Check file existence
	var missing_files = []
	for effect_name in audio_config.keys():
		var audio_path = audio_config[effect_name]
		if not FileAccess.file_exists(audio_path):
			missing_files.append(effect_name + " -> " + audio_path)
	
	if missing_files.size() > 0:
		print("MISSING AUDIO FILES:")
		for file in missing_files:
			print("  ❌ ", file)
	else:
		print("✅ All SFX files exist")
	
	# Check cache status
	print("Cache status:")
	print("  SFX cached: ", sfx_cache.size(), "/", audio_config.size())
	print("  Music cached: ", music_cache.size(), "/", music_config.size())
	
	# Check volume levels
	if AudioServer.get_bus_index("SFX") != -1:
		var sfx_volume = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
		if sfx_volume < 0.1:
			print("⚠️  SFX volume is very low: ", sfx_volume)
		else:
			print("✅ SFX volume: ", sfx_volume)
	
	print("===============================") 