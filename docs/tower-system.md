# Tower System Documentation

## Overview
The tower system manages defensive structures that can be placed on the grid to attack incoming enemies. Each tower type has unique properties and can gain experience through kills.

## Tower Types
```gdscript
enum TOWER_TYPE {
    BALLISTA,      # High single-target damage
    FLAMETHROWER,  # Area damage, fast attack speed
    ARCANE         # Medium damage, special effects
}
```

## Tower Properties
| Type         | Damage | Range | Attack Speed | Cost |
|--------------|--------|-------|--------------|------|
| Ballista     | 20.0   | 200   | 1.0/sec     | 50g  |
| Flamethrower | 10.0   | 150   | 2.0/sec     | 75g  |
| Arcane       | 15.0   | 180   | 1.5/sec     | 100g |

## Veteran System
Towers gain experience through kills and can rank up:

| Rank | Kills Required | Damage Bonus |
|------|---------------|--------------|
| 1    | 0            | +0%          |
| 2    | 10           | +5%          |
| 3    | 25           | +12%         |
| 4    | 50           | +22%         |
| 5    | 100          | +37%         |

## Key Methods
- `set_type(type)`: Sets tower type and initializes properties
- `find_new_target()`: Acquires closest enemy in range
- `attack(enemy)`: Deals damage to target
- `check_rank_up()`: Checks and applies veteran bonuses

## Visual Feedback
- Range indicator circle
- Color intensity increases with rank
- Base appearance varies by type

## Usage Example
```gdscript
# Create and place a tower
var tower = tower_scene.instantiate()
tower.position = grid_position
tower.set_type(TOWER_TYPE.BALLISTA)
add_child(tower)
``` 