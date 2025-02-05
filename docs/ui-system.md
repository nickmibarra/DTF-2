# UI System Documentation

## Overview
The UI system provides game information and controls to the player. It's designed to be responsive and work with various screen sizes.

## Layout Components
### Top Bar
- Gold display (left)
- Wave counter (center)
- Start Wave button (right)
- Height: 60 pixels
- Full width

### Tower Panel
- Located at bottom left
- Width: 400 pixels
- Height: 100 pixels
- Contains tower selection buttons

### Tower Buttons
- Ballista (50g)
- Flamethrower (75g)
- Arcane (100g)
- Size: 100x60 pixels each
- Shows cost and type
- Visual feedback for selection/affordability

## Game State Screens
### Victory Screen
- Full screen overlay
- Centered "Victory!" message
- Appears after wave 10 completion

### Game Over Screen
- Full screen overlay
- Centered "Game Over!" message
- Appears when flag is destroyed

## UI Updates
```gdscript
# Gold display
gold_label.text = "Gold: %d" % gold

# Wave display
wave_label.text = "Wave: %d" % wave_manager.current_wave

# Tower button states
button.disabled = gold < tower_cost
button.modulate = Color(0.7, 1.0, 0.7) # When selected
```

## Input Handling
- Left click: Place selected tower
- Right click: Place wall
- Space bar/button: Start wave
- Tower buttons: Select tower type

## Responsive Design
- UI scales with window size
- Maintains aspect ratio
- Preserves readability
- Anchored to screen edges 