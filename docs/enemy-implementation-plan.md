# Enemy Behavior Implementation Plan

## Phase 1: Basic Framework
1. Create EnemyBehavior component:
   ```gdscript
   # scripts/components/EnemyBehavior.gd
   class_name EnemyBehavior
   extends Node
   
   # Core stats (matching existing Enemy.gd)
   @export var attack_damage: float = 10.0
   @export var movement_speed: float = 100.0
   @export var can_break_walls: bool = true
   
   # Initial behavior weights
   @export var path_weight: float = 1.0
   @export var attack_weight: float = 1.0
   ```

2. Modify existing Enemy.gd:
   ```gdscript
   # scripts/Enemy.gd
   @onready var behavior: EnemyBehavior = $EnemyBehavior
   
   # Move existing stats to behavior component
   func _ready():
       add_to_group("enemies")
       assert(behavior != null, "Enemy must have EnemyBehavior component")
   ```

3. Update Enemy scene:
   ```
   Enemy (Node2D)
   ├── Sprite2D
   ├── HealthBar
   ├── HealthBarBG
   └── EnemyBehavior
   ```

## Phase 2: Path Evaluation
1. Add path cost calculation to EnemyBehavior:
   ```gdscript
   func calculate_path_cost(path: Array) -> float:
       var cost = 0.0
       cost += path.size() * path_weight  # Distance cost
       
       var walls = count_walls_in_path(path)
       if can_break_walls:
           cost += (walls * (100.0 / attack_damage)) * attack_weight
       else:
           cost = INF if walls > 0 else cost
           
       return cost
   ```

2. Modify existing pathfinding in Enemy.gd:
   ```gdscript
   func _find_target() -> Node2D:
       var paths = find_possible_paths()
       var best_path = null
       var lowest_cost = INF
       
       for path in paths:
           var cost = behavior.calculate_path_cost(path)
           if cost < lowest_cost:
               lowest_cost = cost
               best_path = path
               
       return best_path[0] if best_path else get_parent().flag
   ```

## Phase 3: Basic Testing
1. Create test scene:
   ```gdscript
   # scenes/tests/EnemyBehaviorTest.tscn
   - Spawn points
   - Multiple wall configurations
   - Flag target
   ```

2. Test cases to verify:
   ```gdscript
   func test_basic_pathfinding():
       # Verify enemy takes shortest path when no walls
       
   func test_wall_breaking():
       # Verify enemy breaks wall when optimal
       
   func test_path_finding():
       # Verify enemy goes around when optimal
   ```

## Phase 4: Add Threat Response
1. Add threat properties to EnemyBehavior:
   ```gdscript
   @export var threat_priority: float = 0.5
   @export var threat_range: float = 150.0
   
   func assess_threats() -> Dictionary:
       var threats = get_tree().get_nodes_in_group("towers")
       # Initial simple implementation
       for threat in threats:
           if position.distance_to(threat.position) <= threat_range:
               return {
                   "has_threats": true,
                   "threat": threat
               }
       return {"has_threats": false}
   ```

2. Modify Enemy decision making:
   ```gdscript
   func _process_movement(delta):
       var threat = behavior.assess_threats()
       if threat.has_threats and behavior.threat_priority > 0.5:
           target = threat.threat
           current_state = AI_STATE.ATTACKING
       else:
           # Existing flag-focused logic
   ```

## Phase 5: Create Second Enemy Type
1. Create Runner variant:
   ```gdscript
   # scenes/FastRunner.tscn (inherited from Enemy.tscn)
   - Override EnemyBehavior properties:
     movement_speed = 130.0
     threat_priority = 0.2
     attack_weight = 2.0
   ```

2. Create Defender variant:
   ```gdscript
   # scenes/Defender.tscn (inherited from Enemy.tscn)
   - Override EnemyBehavior properties:
     attack_damage = 15.0
     threat_priority = 0.8
     attack_weight = 0.5
   ```

## Testing Plan

### Basic Movement Tests
1. Empty path to flag
2. Single wall in path
3. Multiple path options

### Threat Response Tests
1. Tower in range, no walls
2. Tower behind wall
3. Multiple towers

### Mixed Unit Tests
1. Runner + Defender combination
2. Multiple wall configurations
3. Tower placement scenarios

## Implementation Order
1. Basic EnemyBehavior component
2. Path cost calculation
3. Simple threat detection
4. Basic unit testing
5. Second enemy type
6. Comprehensive testing

## Success Criteria
1. Enemies consistently choose efficient paths to flag
2. Wall breaking decisions make sense
3. Appropriate threat response
4. Different enemy types show distinct behavior
5. Performance remains good with multiple units 