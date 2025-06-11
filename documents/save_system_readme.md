# Game Save System Documentation

## Overview
A complete save system has been added to your maze exploration game, including pause menu saves, quick save/load functionality, and comprehensive error handling mechanisms.

## Features

### 1. Pause Menu Save Function
- **Location**: Game pause interface (press ESC to open)
- **Features**: 
  - Save Game button: Save current game progress
  - Load Game button: Load saved game progress
  - Status Display: Real-time display of save/load status and results

### 2. Hotkey Functions
- **F5**: Quick save current game state
- **F6**: Quick load most recent save
- **ESC**: Open/Close pause menu

### 3. Saved Data Contents
- Current level name
- Player health and maximum health
- Player experience and experience needed for level up
- Player current position
- Save timestamp
- Game version information

### 4. Error Handling Mechanisms
- File access error detection
- Data format validation
- Level file existence check
- User-friendly error message display

### 5. Notification System
- Save success/failure notifications
- Load success/failure notifications
- Top-right floating notifications
- Auto-disappearing animation effects

## Technical Implementation

### Core Components
1. **SaveManager**: Global save manager
2. **NotificationManager**: Notification system manager
3. **Pause Menu Enhancement**: Added save/load interface

### File Structure
```
scripts/
├── SaveManager.gd          # Save manager
├── NotificationManager.gd  # Notification manager
└── GameManager.gd          # Game manager

scenes/
├── pause_menu.gd          # Pause menu script
└── pause_menu.tscn        # Pause menu scene

levels/
└── level_1.gd             # Level script (added hotkey support)
```

### Save File Location
- **Path**: `user://save_game.dat`
- **Format**: Godot VAR format (binary)
- **Content**: Dictionary structure of game data

## Usage Instructions

### Basic Operations
1. **Save Game**: 
   - Press ESC to open pause menu
   - Click "Save Game" button
   - Or press F5 for quick save

2. **Load Game**:
   - Press ESC to open pause menu
   - Click "Load Game" button (requires existing save)
   - Or press F6 for quick load

### Advanced Features
- **Save Info Preview**: Hover mouse over "Load Game" button to view save details
- **Automatic Error Recovery**: System automatically handles various error scenarios
- **Scene Transition Support**: Automatically switches to saved level when loading

## Extension Suggestions

### Future Features to Add
1. **Multiple Save Slots**: Support for multiple save slots
2. **Save Thumbnails**: Save game screenshots as save previews
3. **Auto Save**: Periodic automatic game progress saving
4. **Cloud Saves**: Support for cloud save synchronization
5. **Save Encryption**: Prevent save file modification

### Custom Configuration
The following settings can be modified in `SaveManager.gd`:
- `SAVE_PATH`: Save file path
- Save data structure and content
- Error handling strategies

## Important Notes

1. **Performance Considerations**: Save operations occur on main thread, large games may need async processing
2. **Data Security**: Current version doesn't include save encryption, suitable for single-player games
3. **Compatibility**: Consider save format backward compatibility when updating game
4. **Save Location**: Uses Godot's user data directory, cross-platform compatible

## Troubleshooting

### Common Issues
1. **Save Failure**: Check disk space and file permissions
2. **Load Failure**: Verify save file exists and format is correct
3. **Unresponsive Buttons**: Check if SaveManager is correctly configured as Autoload
4. **Missing Notifications**: Confirm NotificationManager is added as global singleton

### Debug Tips
- Check console output for detailed error messages
- Inspect save files in `user://` directory
- Verify Autoload configuration in project.godot 