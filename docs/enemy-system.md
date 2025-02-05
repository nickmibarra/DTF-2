# Enemy System Documentation

## Overview
The enemy system handles hostile units that follow paths from the spawn point to the flag. Enemies scale in difficulty over time and provide gold rewards when defeated.

## Enemy Properties
- Health: Base 100, scales with wave number
- Speed: Base 100 units/sec, scales with wave number
- Gold Value: Base 10, scales with wave number
- Flag Damage: Base 1, scales with wave number

## Scaling Factors (per wave)
```gdscript
health_scale = 1.2   # +20% health per wave
speed_scale = 1.1    # +10% speed per wave
gold_scale = 1.15    # +15% gold per wave
damage_scale = 1.1   # +10% damage per wave
```

## Signals
- `died(gold_value)`: Emitted when enemy is destroyed
- `reached_flag(damage)`: Emitted when enemy reaches the flag

## Visual Features
- Health bar above enemy
- Size: 32x32 pixels (half grid size)
- Color-coded by type (base: red)

## Movement System
- Follows path from spawn to flag
- Uses grid's pathfinding system
- Smooth movement between grid points
- 5-unit threshold for waypoint advancement

## Usage Example
```gdscript
# Create and initialize an enemy
var enemy = enemy_scene.instantiate()
enemy.set_stats(health, speed, gold, damage)
enemy.set_path(path_to_flag)
add_child(enemy)

# Connect signals
enemy.died.connect(_on_enemy_died)
enemy.reached_flag.connect(_on_enemy_reached_flag)
```

## Wave Spawning
Handled by WaveManager:
- Base: 10 enemies per wave
- +5 enemies per subsequent wave
- 1-second spawn interval
- Automatic difficulty scaling 