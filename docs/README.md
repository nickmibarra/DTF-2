# Defend The Flag - Documentation

## Game Overview
A tower defense game where players strategically place towers and walls to defend their flag from waves of enemies. Features a veteran tower system, scaling difficulty, and both campaign and endless modes.

## Core Systems
- [Grid System](grid-system.md): Manages game board and placement
- [Tower System](tower-system.md): Defensive structures and veteran mechanics
- [Enemy System](enemy-system.md): Hostile units and pathfinding
- [Wave System](wave-system.md): Enemy spawning and difficulty progression
- [UI System](ui-system.md): Game interface and controls

## Quick Start
1. Left click to place selected tower
2. Right click to place walls
3. Space bar or button to start waves
4. Defend your flag!

## Game Features
- Dynamic scaling for all screen sizes
- Optimized for ultrawide displays
- Three tower types with unique properties
- Tower veteran system with kill-based progression
- Campaign and endless game modes
- Wave-based difficulty scaling

## Technical Details
- Built with Godot 4.x
- GDScript implementation
- A* pathfinding
- Responsive UI design
- Signal-based communication between systems

## Development Notes
- Grid size: 32x18 cells
- Base cell size: 64x64 pixels
- Automatic scaling and centering
- UI margins: 5% horizontal, 15% vertical

## Controls
| Input | Action |
|-------|--------|
| Left Click | Place Tower |
| Right Click | Place Wall |
| Space Bar | Start Wave |
| UI Buttons | Select Tower Type | 