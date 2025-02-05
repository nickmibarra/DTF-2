# Wave System Documentation

## Overview
The wave system manages enemy spawning, wave progression, and difficulty scaling. It supports both campaign and endless modes.

## Wave Configuration
```gdscript
base_enemies_per_wave = 10
wave_enemy_increase = 5
spawn_interval = 1.0  # seconds
```

## Game Modes
### Campaign Mode
- 10 waves to complete
- Fixed difficulty progression
- Victory condition on wave 10 completion

### Endless Mode
- Infinite waves
- Continuous difficulty scaling
- No victory condition

## Signals
- `wave_started(wave_number)`
- `wave_completed`
- `all_waves_completed`

## Enemy Scaling
Each wave increases enemy stats:
```gdscript
new_health = base_health * pow(1.2, wave - 1)
new_speed = base_speed * pow(1.1, wave - 1)
new_gold = base_gold * pow(1.15, wave - 1)
new_damage = base_damage * pow(1.1, wave - 1)
```

## Key Methods
- `start_wave()`: Begins next wave
- `start_endless_mode()`: Activates endless mode
- `spawn_enemy()`: Creates and initializes enemy
- `calculate_enemies_for_wave()`: Determines wave size

## Usage Example
```gdscript
# Start normal campaign
wave_manager.wave_started.connect(_on_wave_started)
wave_manager.start_wave()

# Start endless mode
wave_manager.start_endless_mode()
```

## Wave Progression
1. Wave starts
2. Enemies spawn at interval
3. Wave completes when all enemies defeated/reached flag
4. Brief pause for player preparation
5. Next wave available to start 