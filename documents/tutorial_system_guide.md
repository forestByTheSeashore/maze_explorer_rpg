# Tutorial System User Guide

## Overview

This project now includes a complete tutorial system where players can access game operation guides through multiple methods.

## Features

### 1. Main Menu Access
- Added "Tutorial" button in the main menu
- Click to view complete game operation guide
- Suitable for new players to learn controls before starting

### 2. In-Game Quick Access
- **F7 Key** - Press F7 anytime during gameplay to view tutorial
- Interface pauses the game, seamlessly returns after viewing
- Convenient for players to quickly check controls during gameplay

### 3. Pause Menu Integration
- Added "Tutorial" button in the game pause menu
- When opened from pause menu, automatically returns there upon closing
- Provides convenient access path

### 4. In-Game Convenient Access
- Access tutorial anytime in-game via F7 key
- Direct keyboard shortcut access without menu navigation
- Displays in paused game state, automatically resumes game upon closing

## Tutorial Contents

The tutorial interface includes these main sections:

### 🚶 Character Movement
- WASD keys or arrow keys control character movement
- Detailed explanation of directional key functions

### 🔄 Interaction
- F key to interact with items, doors, etc.
- Instructions for picking up items and opening doors

### ⚔️ Combat System
- J key to attack enemies
- Number keys 1-4 for quick weapon switching
- Detailed explanation of Tab key weapon switching

### 🎒 Item Management
- I key to open/close inventory
- Inventory function explanation

### 🧭 Navigation Assistance
- F1 key shows path to keys
- F2 key shows path to exit door
- M key opens/closes minimap

### 💾 Save/Load
- F5 key for quick save
- F6 key for quick load
- F7 key displays tutorial

### ⏸️ Game Pause
- ESC key to pause/resume game

### 🎯 Game Objectives
- Detailed explanation of main game goals and tasks

### 💡 Game Tips
- Provides useful exploration and combat tips

## Technical Implementation

### File Structure
```
scenes/
├── tutorial.tscn     # Tutorial interface scene
├── tutorial.gd       # Tutorial interface script
├── main_menu.tscn    # Main menu (modified)
├── main_menu.gd      # Main menu script (modified)
├── pause_menu.tscn   # Pause menu (modified)
└── pause_menu.gd     # Pause menu script (modified)
```

### Key Features
1. **Responsive Interface** - Uses ScrollContainer for content scrolling
2. **Pause Compatible** - Properly handles game pause state
3. **Smart Navigation** - Intelligently returns to correct interface based on access method
4. **Color Coding** - Uses BBCode to set different colors for different operation types
5. **Emojis** - Uses emojis to enhance visual effect

### Input Mapping
Added in `project.godot`:
```
show_tutorial={
"deadzone": 0.5,
"events": [F7 key event]
}
```

## Usage Instructions

### For Players
1. **First Time** - Click "Tutorial" in main menu to learn controls
2. **In-Game Reference** - Press F7 key anytime to view operation guide
3. **Pause Menu Access** - Click "Tutorial" in pause menu
4. **Quick Access** - Access quickly via F7 key in any game state

### For Developers
1. **Modify Content** - Edit RichTextLabel content in `tutorial.tscn`
2. **Add New Operations** - Add new instructions in appropriate sections
3. **Style Adjustments** - Modify BBCode tags to change colors and formatting

## Extension Suggestions

1. **Multi-language Support** - Can add language switching functionality
2. **Dynamic Content** - Display different tips based on game progress
3. **Interactive Tutorial** - Add actual operation demonstrations
4. **Custom Keybinds** - Dynamically update instructions based on player's custom keybinds
5. **Video Tutorials** - Integrate video playback functionality

## Important Notes

1. Ensure F7 key doesn't conflict with other functions
2. Correctly set pause state when calling `_show_tutorial_in_game()` method in game scenes
3. Pause menu needs to be correctly added to "pause_menu" group for tutorial system to find it
4. All tutorial-related interfaces should be set to `PROCESS_MODE_WHEN_PAUSED` mode

This tutorial system provides players with convenient access to operation guides, significantly improving the game's user experience. 