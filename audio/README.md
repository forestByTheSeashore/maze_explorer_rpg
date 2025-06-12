# Simplified Audio Configuration Guide

## Directory Structure

```
audio/
├── sfx/          # Sound effects files
├── music/        # Background music files
└── README.md     # This guide
```

## Required Audio Files (Simplified)

### Sound Effects (audio/sfx/)
- `move.ogg` - Movement sound (footsteps)
- `attack.ogg` - Attack sound effect
- `pickup.ogg` - Item pickup sound
- `door.ogg` - Door opening sound
- `button.ogg` - Button click/menu sound
- `victory.ogg` - Victory sound

### Background Music Files (audio/music/)
- `menu.ogg` - Menu background music
- `game.ogg` - In-game background music

## Audio Format Requirements

- **Format**: Recommended to use `.ogg` format (Vorbis encoding)
- **Sample Rate**: 44.1kHz
- **Channels**: Stereo or mono
- **Bitrate**: 128 kbps (suitable for games)

## Recommended Audio File Durations

### Sound Effects (Short Sounds)
- **Movement Sound**: 0.2-0.5 seconds
- **Attack Sound**: 0.3-0.8 seconds
- **Pickup Sound**: 0.2-0.5 seconds
- **Door Sound**: 0.5-1.0 seconds
- **Button Sound**: 0.1-0.3 seconds
- **Victory Sound**: 1.0-3.0 seconds

### Background Music (Looping Music)
- **Menu Music**: 30-60 seconds (looping)
- **Game Music**: 60-120 seconds (looping)

## Recommended Free Sound Resources

### General Sound Libraries
- **Freesound.org** - Vast collection of free sounds, registration required
- **Zapsplat.com** - High-quality sound library, registration required
- **OpenGameArt.org** - Game development specific resources

### Targeted Search Keywords
- Movement sounds: "footstep", "step", "walk"
- Attack sounds: "sword", "hit", "strike", "slash"
- Pickup sounds: "pickup", "coin", "item", "collect"
- Door sounds: "door", "open", "creak"
- Button sounds: "click", "button", "menu"
- Victory sounds: "victory", "success", "win", "achievement"
- Menu music: "ambient", "menu", "peaceful"
- Game music: "adventure", "exploration"

## System Features

- ✅ **Robust Design**: Game runs normally when audio files are missing
- ✅ **Auto Detection**: Automatically loads newly added files
- ✅ **Backward Compatible**: Maintains compatibility with older code versions
- ✅ **Simplified Configuration**: Only includes essential sounds for maze+rpg game

## Steps to Add Audio Files

1. Download or create audio files meeting requirements
2. Place files in corresponding directory (`audio/sfx/` or `audio/music/`)
3. Ensure filenames match configuration exactly
4. Restart game to use new audio

## File Size Recommendations

- **Sound Effects**: < 100KB
- **Music Files**: < 2MB
- **Total Audio Package**: < 5MB

This configuration is suitable for assignment submission, reference materials are easy to manage while maintaining basic audio experience.

---

## 📋 Quick Audio File Checklist

**You need to prepare the following 8 audio files:**

### Sound Effects (place in audio/sfx/ folder)
1. **move.ogg** - Player movement footsteps
2. **attack.ogg** - Player attack/enemy hit sound
3. **pickup.ogg** - Item pickup sound
4. **door.ogg** - Door opening sound
5. **button.ogg** - Menu button click sound
6. **victory.ogg** - Victory/level complete sound

### Music Files (place in audio/music/ folder)
7. **menu.ogg** - Main menu background music
8. **game.ogg** - In-game background music

**Only 8 files needed in total, simple to manage!** 