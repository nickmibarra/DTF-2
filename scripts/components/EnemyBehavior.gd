class_name EnemyBehavior
extends EntityComponent

# Core stats (matching existing Enemy.gd)
@export var attack_damage: float = 10.0
@export var movement_speed: float = 100.0
@export var can_break_walls: bool = true

# Initial behavior weights
@export_range(0.1, 10.0) var path_weight: float = 1.0      # Higher = prefers shorter paths
@export_range(0.1, 10.0) var attack_weight: float = 1.0    # Lower = prefers attacking

# Debug mode for testing
@export var debug_mode: bool = false

func _initialize() -> void:
    # Validate configuration
    assert(attack_damage > 0, "Attack damage must be positive")
    assert(movement_speed > 0, "Movement speed must be positive")
    
    if debug_mode:
        print("EnemyBehavior initialized with:")
        print("- Attack Damage: ", attack_damage)
        print("- Movement Speed: ", movement_speed)
        print("- Can Break Walls: ", can_break_walls)
        print("- Path Weight: ", path_weight)
        print("- Attack Weight: ", attack_weight)

# Override process from EntityComponent
func process(delta: float) -> void:
    # This function is called every frame to update behavior
    if not entity:
        return
    
    # Update behavior based on current state
    match entity.state_manager.get_current_state():
        "moving":
            _process_movement(delta)
        "attacking":
            _process_combat(delta)
        "idle":
            _process_idle(delta)

func _process_movement(_delta: float) -> void:
    # Movement behavior handled by MovementComponent
    pass

func _process_combat(_delta: float) -> void:
    # Combat behavior handled by CombatComponent
    pass

func _process_idle(_delta: float) -> void:
    # Check for targets or objectives while idle
    pass

# Helper function to get effective damage per second
func get_dps() -> float:
    return attack_damage * (1.0 / 0.5)  # attack_damage / ATTACK_INTERVAL

# Helper function to get effective movement speed with any modifiers
func get_effective_speed() -> float:
    return movement_speed  # Will add modifiers later

# Helper function to determine if target is worth attacking
func should_attack_target(target_health: float, distance_to_target: float) -> bool:
    if not can_break_walls:
        return false
    
    # Calculate time to destroy target
    var dps = get_dps()
    var time_to_destroy = target_health / dps
    
    # Calculate time to move around (estimate)
    var time_to_move = distance_to_target * 2.0  # Simple distance-based estimate
    
    # Always attack if we're already close
    if distance_to_target <= 45.0:  # Slightly more than ATTACK_RANGE
        return true
    
    # Simple decision: attack if it's faster than moving
    return time_to_destroy < time_to_move