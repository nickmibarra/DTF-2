# Combat System Documentation

## Overview
The combat system manages interactions between enemies, walls, and the flag. It uses a component-based approach with the `Attackable` component handling damage and health management.

## Key Components

### Attackable Component
```gdscript
# Core properties
max_health: float = 100.0
current_health: float
armor: float = 0.0

# Signals
signal health_changed(current, max_health)
signal destroyed(position)
signal damage_taken(amount, source)
```

### Enemy Attack Behavior
- Attack Range: 40.0 units
- Attack Interval: 0.5 seconds
- Wall Damage: 20 damage per hit
- Flag Damage: 1 damage per hit

## Target Prioritization
1. **Walls First**: Enemies prioritize attacking nearby walls within 1.5x attack range
2. **Flag Second**: If no walls are in range, enemies target the flag
3. **Range Check**: Enemies must be within `ATTACK_RANGE` (40.0 units) to attack

```gdscript
# Enemy target selection logic
func _find_target() -> Node2D:
    # Check for nearby walls first
    var walls = get_tree().get_nodes_in_group("walls")
    var closest_wall = null
    var closest_dist = INF
    
    for wall in walls:
        var dist = position.distance_to(wall.position)
        if dist < closest_dist:
            closest_wall = wall
            closest_dist = dist
    
    # Target wall if within extended range
    if closest_wall and closest_dist <= ATTACK_RANGE * 1.5:
        return closest_wall
    
    # Otherwise target flag
    return get_parent().flag
```

## Scene Setup Requirements
1. Attackable objects must be in appropriate groups:
   - Walls: "walls" group
   - Flag: "flags" group
   - All attackable: "attackable" group

2. Required Components:
   ```
   Node2D (Wall/Flag)
   ├── Sprite/Shape
   ├── HealthBarBG
   │   └── HealthBar
   └── Attackable
   ```

## Health Bar System
- Health bars are implemented as ColorRect nodes
- HealthBar should be child of HealthBarBG
- Use z_index to ensure visibility (recommended: 10)
- Colors change based on health percentage:
  - > 60%: Green
  - > 30%: Yellow
  - ≤ 30%: Red

## Usage Example
```gdscript
# Adding a new attackable object
func setup_attackable():
    add_to_group("attackable")
    attackable.initialize(100.0)  # Set initial health
    attackable.health_changed.connect(_on_health_changed)
    attackable.destroyed.connect(_on_destroyed)

# Handling damage
func take_damage(amount: float):
    if attackable:
        attackable.take_damage(amount)
```

## Important Notes
1. Always instance complete scenes rather than creating nodes directly
2. Ensure proper signal connections for health and destruction
3. Keep attack ranges balanced for gameplay (walls should protect flag)
4. Use groups for proper target identification
5. Health bars should be children of their background for proper scaling 