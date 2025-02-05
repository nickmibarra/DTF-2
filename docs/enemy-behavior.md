# Enemy Behavior System

## Core Philosophy
The system focuses on goal-oriented behavior with the flag as the primary objective, while intelligently responding to immediate threats that could prevent reaching that objective.

## Behavior Component
```gdscript
class_name EnemyBehavior
extends Node

# Core capabilities - These define WHAT the enemy can do
@export var can_break_walls: bool = true
@export var attack_damage: float = 10.0
@export var movement_speed: float = 100.0

# Efficiency weights - These define HOW the enemy makes decisions
@export_range(0.1, 10.0) var path_weight: float = 1.0      # Higher = prefers shorter paths
@export_range(0.1, 10.0) var attack_weight: float = 1.0    # Higher = prefers attacking

# Threat response - How this unit handles threats
@export var threat_priority: float = 0.5     # How likely to engage threats vs ignore them
@export var threat_range: float = 150.0      # How far to check for threats
@export var ally_protection: float = 0.0     # How much to care about allies under attack

# Optional capabilities for future expansion
@export var can_fly: bool = false
@export var can_climb: bool = false
```

## Path and Threat Evaluation
```gdscript
class_name PathEvaluator
extends Node

# Cache for path calculations
var _path_cache := {}
var _cache_lifetime := 1.0  # Seconds before recalculation

func evaluate_path_to_flag() -> Dictionary:
    # Check cache first
    var cache_key = str(global_position)
    if _path_cache.has(cache_key) and _path_cache[cache_key].time > Time.get_ticks_msec() - 1000:
        return _path_cache[cache_key].paths
        
    # Get possible paths to flag
    var direct_path = find_path_to_flag()
    var paths = find_alternate_paths(3)  # Get up to 3 alternatives
    
    # Calculate costs for each option
    var options = {}
    for path in paths:
        var cost = calculate_path_cost(path)
        options[path] = cost
    
    # Cache result
    _path_cache[cache_key] = {
        "time": Time.get_ticks_msec(),
        "paths": options
    }
    
    return options

func calculate_path_cost(path: Array) -> float:
    var cost = 0.0
    
    # Base distance cost
    cost += path.size() * path_weight
    
    # Wall breaking cost
    var walls_to_break = count_walls_in_path(path)
    if can_break_walls:
        # Consider time and damage needed to break through
        var break_time = walls_to_break * (100.0 / attack_damage)  # Assuming 100 health walls
        cost += break_time * attack_weight
    else:
        cost = INF if walls_to_break > 0 else cost
    
    # Threat avoidance cost
    var threats = get_threats_in_path(path)
    for threat in threats:
        var threat_cost = calculate_threat_cost(threat)
        cost += threat_cost * (1.0 - threat_priority)  # Lower priority = higher cost to engage
        
    return cost

func calculate_threat_cost(threat: Node2D) -> float:
    var base_cost = 0.0
    
    # Consider threat's damage output
    if threat.has_method("get_dps"):
        base_cost += threat.get_dps() * 2.0
    
    # Consider allies under attack
    var allies_threatened = get_allies_threatened_by(threat)
    base_cost += allies_threatened.size() * ally_protection * 10.0
    
    # Consider our ability to deal with the threat
    var time_to_destroy = threat.health / attack_damage if threat.has_method("get_health") else 5.0
    base_cost *= time_to_destroy
    
    return base_cost
```

## Threat Response System
```gdscript
func assess_threats() -> Dictionary:
    var threats = get_nearby_threats(threat_range)
    if threats.is_empty():
        return {"has_threats": false}
        
    var most_dangerous = null
    var highest_priority = 0.0
    
    for threat in threats:
        var priority = calculate_threat_priority(threat)
        if priority > highest_priority:
            most_dangerous = threat
            highest_priority = priority
    
    # Only respond if threat is significant enough
    if highest_priority > threat_priority:
        return {
            "has_threats": true,
            "threat": most_dangerous,
            "priority": highest_priority
        }
    
    return {"has_threats": false}

func calculate_threat_priority(threat: Node2D) -> float:
    var priority = 0.0
    
    # Base threat level
    if threat.has_method("get_dps"):
        priority += threat.get_dps() / 10.0
    
    # Allies being attacked
    var threatened_allies = get_allies_threatened_by(threat)
    priority += threatened_allies.size() * ally_protection
    
    # Distance factor (closer = higher priority)
    var distance = global_position.distance_to(threat.global_position)
    priority *= 1.0 / (distance / threat_range)
    
    return priority
```

## Decision Making
```gdscript
func choose_best_action() -> Dictionary:
    # First check for critical threats
    var threat_assessment = assess_threats()
    if threat_assessment.has_threats:
        return {
            "action": ACTION.ENGAGE_THREAT,
            "target": threat_assessment.threat
        }
    
    # If no threats, proceed with normal flag-oriented behavior
    if can_attack_flag_directly():
        return {
            "action": ACTION.ATTACK_FLAG,
            "target": flag
        }
    
    # Rest of the path evaluation logic...
```

## Enemy Type Examples
```gdscript
# Defender - Protects allies from towers
func setup_defender():
    behavior.can_break_walls = true
    behavior.attack_damage = 15.0
    behavior.movement_speed = 90.0
    behavior.threat_priority = 0.8    # High priority on threats
    behavior.ally_protection = 1.0    # Maximum ally protection

# Flag Runner - Ignores threats, focuses on flag
func setup_runner():
    behavior.can_break_walls = true
    behavior.movement_speed = 130.0
    behavior.threat_priority = 0.2    # Mostly ignores threats
    behavior.ally_protection = 0.0    # Doesn't protect allies
```

## Implementation Notes

### Threat Response Guidelines
1. Only engage threats that are actively causing problems
2. Consider group benefit when deciding to engage
3. Don't get distracted by minor threats
4. Cache threat calculations to prevent constant recalculation

### Common Scenarios
1. **Tower Harassment**
   - Low threat_priority units continue to flag
   - High threat_priority units engage tower
   - Nearby allies benefit from tower removal

2. **Path Blocking**
   - Calculate if breaking through or going around is faster
   - Consider threat level of path alternatives
   - Factor in ally positions and health

3. **Group Protection**
   - Defenders engage threats targeting allies
   - Runners exploit the protection to reach objective
   - Dynamic threat priority based on situation

Remember: The goal is still reaching the flag, but sometimes removing a threat is the most efficient path to that goal. 