extends Entity

signal died(gold_value)
signal reached_flag(damage)

# Core states with clear transitions
enum AI_STATE {
	MOVING,    # Moving towards target or finding path
	ATTACKING  # Actively attacking target
}

# Combat configuration
const ATTACK_RANGE = 40.0  # Reduced to a more reasonable range
const ATTACK_INTERVAL = 0.5
const OBSTACLE_DAMAGE = 20  # Base damage for walls/towers
const TOWER_DAMAGE_MULT = 0.8  # Towers take 80% damage
const FLAG_DAMAGE = 1

# Movement and state
var current_state: AI_STATE = AI_STATE.MOVING
var current_target: Node2D = null
var attack_timer: float = 0.0
var current_path: Array = []

# Base stats - Now managed by behavior component
@onready var behavior: EnemyBehavior = $EnemyBehavior
@onready var health_bar = $HealthBar
@onready var sprite = $Sprite2D
@onready var grid = get_tree().get_first_node_in_group("grid")

var health: float = 100.0
var max_health: float = 100.0
var gold_value: int = 10

# Add stuck detection
var last_position: Vector2 = Vector2.ZERO
var stuck_time: float = 0.0
const STUCK_THRESHOLD: float = 0.5  # Time in seconds to consider stuck
const MAJOR_STUCK_THRESHOLD: float = 2.0  # Time to consider seriously stuck

var target_position: Vector2 = Vector2.ZERO
var target_grid_pos: Vector2 = Vector2.ZERO
var path_recalc_timer: float = 0.0
const PATH_RECALC_INTERVAL: float = 1.0  # Recalculate path every second if needed

# Add initialization delay
var init_timer: float = 0.0
const INIT_DELAY: float = 0.1  # Short delay before starting pathfinding

# Cache the flag reference
var _flag: Node2D = null

# Add path tracking
var last_path_length: int = 0
var same_path_time: float = 0.0
const PATH_CHANGE_THRESHOLD: float = 1.5  # Time before forcing a new path if length hasn't changed

# Add group behavior variables
var spawn_index: int = -1  # Will be set when spawned

# Add near the top with other constants
const UPDATE_FREQUENCY = 0.1  # Update every 100ms
var update_timer = 0.0

# Add near other variables
var last_obstacle_check_time: float = 0.0
const OBSTACLE_CHECK_INTERVAL: float = 0.2  # Check obstacles every 200ms

func _ready():
	super._ready()
	add_to_group("enemies")
	assert(behavior != null, "Enemy must have EnemyBehavior component")
	assert(grid != null, "Enemy needs Grid node for pathfinding")
	_update_health_bar()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	last_position = position
	
	# Set spawn index based on existing enemies
	spawn_index = get_tree().get_nodes_in_group("enemies").size() - 1
	
	# Connect to grid signals
	grid.obstacle_changed.connect(_on_obstacle_changed)
	
	# Connect to component signals
	if health_component:
		health_component.died.connect(_on_died)
	
	if movement_component:
		movement_component.path_completed.connect(_on_path_completed)
	
	if combat_component:
		combat_component.attack_completed.connect(_on_attack_completed)

func _on_obstacle_changed(pos: Vector2):
	# Only recalculate if the changed obstacle is near our path
	if not current_path.is_empty():
		var obstacle_world_pos = grid.grid_to_world(pos)
		var should_recalc = false
		
		# Check if obstacle is near our current path
		for path_pos in current_path:
			var world_path_pos = grid.grid_to_world(path_pos)
			if world_path_pos.distance_to(obstacle_world_pos) < GameSettings.BASE_GRID_SIZE * 2:
				should_recalc = true
				break
		
		if should_recalc:
			_recalculate_path_if_needed()

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	
	# Update behavior
	if behavior:
		behavior.process(delta)
	
	# Check if we can attack flag from current position
	var flag = _find_flag()
	if flag:
		var dist = position.distance_to(flag.position)
		if dist <= combat_component.attack_range:
			combat_component.set_target(flag)
			return
	
	# Otherwise follow path or attack obstacles
	if movement_component and movement_component.current_path.is_empty():
		_update_path()

func _find_flag() -> Node2D:
	if not _flag:
		_flag = get_tree().get_first_node_in_group("flags")
		if not _flag:
			push_error("Enemy: No flag found in scene!")
			return null
	
	return _flag

func _update_path() -> void:
	var grid = get_tree().get_first_node_in_group("grid")
	if not grid:
		return
	
	var flag = _find_flag()
	if not flag:
		return
	
	var current_grid_pos = grid.world_to_grid(position)
	var flag_grid_pos = grid.world_to_grid(flag.position)
	
	var path_result = grid.find_path(current_grid_pos, flag_grid_pos)
	
	if path_result.blocked_by_obstacle:
		var obstacle = grid.get_blocking_object_at(path_result.obstacle_target)
		if obstacle:
			combat_component.set_target(obstacle)
			return
	
	if not path_result.path.is_empty():
		movement_component.follow_path(path_result.path)

func _on_died():
	died.emit(gold_value)
	queue_free()

func _on_path_completed():
	_update_path()

func _on_attack_completed(target: Node2D):
	if target.is_in_group("flags"):
		reached_flag.emit(FLAG_DAMAGE)

func _process(delta):
	# Wait for initialization delay
	if init_timer < INIT_DELAY:
		init_timer += delta
		return
	
	# Update timer for batched operations
	update_timer += delta
	var should_update = update_timer >= UPDATE_FREQUENCY
	if should_update:
		update_timer = 0.0
		
	match current_state:
		AI_STATE.MOVING:
			_process_movement(delta, should_update)
		AI_STATE.ATTACKING:
			_process_combat(delta)

func _process_movement(delta, should_update: bool):
	# Always check if we can attack flag from current position first
	var flag = _find_flag()
	if flag:
		var dist = position.distance_to(flag.position)
		if dist <= ATTACK_RANGE:
			_transition_to_attack(flag)
			return
	
	# Track if we're making progress on our path
	if not current_path.is_empty():
		if current_path.size() == last_path_length:
			same_path_time += delta
			if same_path_time >= PATH_CHANGE_THRESHOLD and should_update:
				_recalculate_path_if_needed(true)  # Force recalculation
				same_path_time = 0.0
		else:
			same_path_time = 0.0
			last_path_length = current_path.size()
	
	# If we can't attack flag, handle movement
	if current_path.is_empty() and target_position == Vector2.ZERO:
		if flag and should_update:  # Only update path on update tick
			target_position = flag.position  # Path directly to flag
			target_grid_pos = grid.world_to_grid(target_position)
			_recalculate_path_if_needed()
			return
	
	# Check for obstacles if we're stuck or don't have a path
	if (current_path.is_empty() or is_stuck(grid.world_to_grid(position))) and should_update:
		var obstacle_target = _find_obstacle_to_attack()
		if obstacle_target:
			_transition_to_attack(obstacle_target)
			return
		_recalculate_path_if_needed()
	
	# Follow current path
	if not current_path.is_empty():
		_follow_path(delta)

func _find_obstacle_to_attack() -> Node2D:
	var flag = _find_flag()
	if not flag:
		return null
	
	# Rate limit obstacle checking
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_obstacle_check_time < OBSTACLE_CHECK_INTERVAL:
		return null
	last_obstacle_check_time = current_time
	
	# First check if we have a clear path to flag
	var current_grid_pos = grid.world_to_grid(position)
	var flag_grid_pos = grid.world_to_grid(flag.position)
	var path_to_flag = grid.find_path(current_grid_pos, flag_grid_pos)
	
	# If we have a valid path that doesn't require breaking through, don't attack obstacles
	if not path_to_flag.path.is_empty() and not path_to_flag.blocked_by_obstacle:
		return null
	
	# If we got an obstacle target from pathfinding, use that
	if path_to_flag.blocked_by_obstacle and path_to_flag.obstacle_target:
		var obstacle = grid.get_blocking_object_at(path_to_flag.obstacle_target)
		if obstacle and obstacle.has_node("Attackable"):
			var dist = position.distance_to(obstacle.position)
			if dist <= ATTACK_RANGE * 1.5 and behavior.should_attack_target(obstacle.get_node("Attackable").current_health, dist):
				return obstacle
	
	# Only check nearby if we're close to flag
	var dist_to_flag = position.distance_to(flag.position)
	if dist_to_flag > ATTACK_RANGE * 3:
		return null
	
	# Only if the pathfinding didn't give us a good target, check nearby
	var nearby_attackables = grid.get_attackables_in_range(position, ATTACK_RANGE * 1.5)
	var best_target = null
	var best_score = INF
	
	var to_flag_dir = (flag.position - position).normalized()
	
	for potential_target in nearby_attackables:
		# Skip if it's the enemy itself
		if potential_target == self:
			continue
			
		# Only consider obstacles (walls and towers)
		if not grid.is_blocking_obstacle(grid.get_cell_type(grid.world_to_grid(potential_target.position))):
			continue
			
		var attackable_component = potential_target.get_node_or_null("Attackable")
		if not attackable_component:
			continue
			
		var target_pos = potential_target.position
		var dist = position.distance_to(target_pos)
		
		# Skip if too far
		if dist > ATTACK_RANGE * 1.5:
			continue
		
		# Check if obstacle is in the general direction of the flag
		var to_target_dir = (target_pos - position).normalized()
		var dot_product = to_flag_dir.dot(to_target_dir)
		
		# Only consider obstacles in the direction of the flag
		if dot_product > 0.0:
			# Score based on distance and direction
			var base_score = dist * (2.0 - dot_product)  # Lower score is better
			
			# Towers get a slightly higher priority
			if potential_target.is_in_group("towers"):
				base_score *= 0.9  # 10% priority boost for towers
			
			if behavior.should_attack_target(attackable_component.current_health, dist):
				if base_score < best_score:
					best_target = potential_target
					best_score = base_score
	
	return best_target

func _move_towards(target_pos: Vector2, delta: float):
	var direction = (target_pos - position).normalized()
	var move_speed = behavior.get_effective_speed() * delta
	var proposed_position = position + direction * move_speed
	
	# Check if we're moving towards the flag
	var flag = _find_flag()
	if flag:
		var dist_to_flag = position.distance_to(flag.position)
		# If we're getting close to attack range, ignore collisions
		if dist_to_flag <= ATTACK_RANGE * 1.5:  # Within 60 units
			position = proposed_position
			stuck_time = 0.0
			last_position = position
			return
	
	# Cache grid position check for multiple uses
	var check_grid_pos = grid.world_to_grid(proposed_position)
	var cell_type = grid.get_cell_type(check_grid_pos)
	
	# Fast path: If proposed position is clear
	if not grid.is_blocking_obstacle(cell_type):
		position = proposed_position
		stuck_time = 0.0
		last_position = position
		return
	
	# Only do detailed collision checks if we hit an obstacle
	var wall_clearance = GameSettings.BASE_GRID_SIZE * 0.3
	
	# Try diagonal movements first
	var diagonal_directions = [
		direction.rotated(PI/4),
		direction.rotated(-PI/4)
	]
	
	for slide_dir in diagonal_directions:
		var slide_position = position + slide_dir * move_speed
		var slide_grid_pos = grid.world_to_grid(slide_position)
		if not grid.is_blocking_obstacle(grid.get_cell_type(slide_grid_pos)):
			position = slide_position
			stuck_time = 0.0
			last_position = position
			return
	
	# If diagonals failed, try cardinal directions
	var cardinal_directions = [
		Vector2(direction.x, 0).normalized(),
		Vector2(0, direction.y).normalized()
	]
	
	for slide_dir in cardinal_directions:
		var slide_position = position + slide_dir * move_speed
		var slide_grid_pos = grid.world_to_grid(slide_position)
		if not grid.is_blocking_obstacle(grid.get_cell_type(slide_grid_pos)):
			position = slide_position
			stuck_time = 0.0
			last_position = position
			return
	
	# If we get here, we're truly stuck
	stuck_time += delta
	if stuck_time >= STUCK_THRESHOLD:
		_recalculate_path_if_needed()

func _transition_to_attack(new_target: Node2D):
	current_target = new_target
	current_state = AI_STATE.ATTACKING
	attack_timer = ATTACK_INTERVAL  # Reset timer to allow immediate first attack
	current_path.clear()

func _recalculate_path_if_needed(force: bool = false):
	var current_grid_pos = grid.world_to_grid(position)
	
	# If we're forced to recalc, try direct path first
	if force:
		var direct_result = grid.find_path(current_grid_pos, target_grid_pos)
		if not direct_result.path.is_empty():
			current_path = direct_result.path
			return
		
		# If direct path failed, try ONE offset
		var offset = Vector2(-1 if randf() < 0.5 else 1, 0)
		if randf() < 0.5:
			offset = Vector2(0, -1 if randf() < 0.5 else 1)
		
		var try_target = target_grid_pos + offset
		if grid.is_valid_cell(try_target) and grid.get_cell_type(try_target) == grid.TILE_TYPE.EMPTY:
			var try_result = grid.find_path(current_grid_pos, try_target)
			if not try_result.path.is_empty():
				current_path = try_result.path
				return
	
	# Fall back to normal pathfinding
	var path_result = grid.find_path(current_grid_pos, target_grid_pos)
	
	if path_result.blocked_by_obstacle:
		var obstacle = grid.get_blocking_object_at(path_result.obstacle_target)
		if obstacle:
			_transition_to_attack(obstacle)
			return
	
	# If we got an empty path and no obstacle to attack, try to find any nearby obstacle
	if path_result.path.is_empty():
		var obstacle_target = _find_obstacle_to_attack()
		if obstacle_target:
			_transition_to_attack(obstacle_target)
			return
		else:
			# If still no path and no obstacle, try moving towards flag while avoiding obstacles
			var flag = _find_flag()
			if flag:
				var direction_to_flag = (flag.position - position).normalized()
				# Try a few angles to find a clear direction
				var angles = [-PI/4, 0, PI/4]  # Try 45 degrees left, straight, and 45 degrees right
				for angle in angles:
					var try_dir = direction_to_flag.rotated(angle)
					var try_pos = grid.world_to_grid(position + try_dir * GameSettings.BASE_GRID_SIZE * 2)
					if grid.is_valid_cell(try_pos) and not grid.is_blocking_obstacle(grid.get_cell_type(try_pos)):
						path_result = grid.find_path(current_grid_pos, try_pos)
						if not path_result.path.is_empty():
							current_path = path_result.path
							return
	
	current_path = path_result.path

# Simplify _evaluate_path since it's only used for direct path checks
func _evaluate_path(path: Array) -> float:
	if path.is_empty():
		return INF
	return path.size() * 1.0  # Just use path length as score

func _follow_path(delta: float):
	if current_path.is_empty():
		return
	
	# Check attack range before moving
	var flag = _find_flag()
	if flag:
		var dist = position.distance_to(flag.position)
		if dist <= ATTACK_RANGE:
			_transition_to_attack(flag)
			return
		
	var next_point = grid.grid_to_world(current_path[0])
	var dist_to_next = position.distance_to(next_point)
	
	# If this is the last waypoint and it's the flag, move directly to flag
	if current_path.size() == 1 and flag:
		var dist_to_flag = position.distance_to(flag.position)
		if dist_to_flag <= ATTACK_RANGE * 1.5:  # Within approach range
			_move_towards(flag.position, delta)
			return
	
	# Check if we've reached the current waypoint
	if dist_to_next < GameSettings.BASE_GRID_SIZE * 0.3:
		current_path.pop_front()
		if not current_path.is_empty():
			next_point = grid.grid_to_world(current_path[0])
	
	if not current_path.is_empty():
		_move_towards(next_point, delta)

func _process_combat(delta):
	if not current_target or not is_instance_valid(current_target):
		current_state = AI_STATE.MOVING
		current_target = null
		return
		
	var dist = position.distance_to(current_target.position)
	
	# If we're too far away, move closer
	if dist > ATTACK_RANGE:
		var direction = (current_target.position - position).normalized()
		var proposed_position = position + direction * behavior.get_effective_speed() * delta
		
		# Check if proposed position would be in a wall/tower (that's not our target)
		var proposed_grid_pos = grid.world_to_grid(proposed_position)
		var cell_type = grid.get_cell_type(proposed_grid_pos)
		var can_move = true
		
		if grid.is_blocking_obstacle(cell_type):
			var obstacle = grid.get_blocking_object_at(proposed_grid_pos)
			if obstacle != current_target:
				can_move = false
		
		if can_move:
			position = proposed_position
	else:
		# We're in range, perform attack
		attack_timer += delta
		if attack_timer >= ATTACK_INTERVAL:
			attack_timer = 0.0
			_attack_current_target()

func _attack_current_target():
	if not current_target or not is_instance_valid(current_target):
		return
		
	if not current_target.has_method("take_damage"):
		return
		
	var distance = position.distance_to(current_target.position)
	if distance <= ATTACK_RANGE:
		# Determine damage based on target type
		var damage_amount = OBSTACLE_DAMAGE
		if current_target.is_in_group("flags"):
			damage_amount = FLAG_DAMAGE
		elif current_target.is_in_group("towers"):
			damage_amount *= TOWER_DAMAGE_MULT
		
		current_target.take_damage(damage_amount)
		_play_attack_effects()
		attack_timer = 0.0

func _play_attack_effects():
	sprite.modulate = Color(1.2, 0.8, 0.2)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	sprite.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.2)

func set_stats(new_health: float, new_speed: float, new_gold: int, new_damage: int):
	if health_component:
		health_component.max_health = new_health
		health_component.current_health = new_health
	
	if movement_component:
		movement_component.movement_speed = new_speed
	
	if combat_component:
		combat_component.damage = new_damage
	
	gold_value = new_gold
	_update_health_bar()

func take_damage(amount: float):
	health -= amount
	_update_health_bar()
	
	if health <= 0:
		died.emit(gold_value)
		queue_free()

func _update_health_bar():
	if health_bar:
		health_bar.size.x = (health / max_health) * 32

# Update stuck detection to be more lenient
func is_stuck(current_grid_pos: Vector2) -> bool:
	if position.distance_to(last_position) < 5.0:  # Increased threshold
		stuck_time += get_process_delta_time()
		if stuck_time > MAJOR_STUCK_THRESHOLD:
			# We're seriously stuck, force a complete new path
			_recalculate_path_if_needed(true)
			stuck_time = 0.0
			return false
		elif stuck_time > STUCK_THRESHOLD:
			stuck_time = 0.0
			return true
	else:
		stuck_time = 0.0
		last_position = position
	return false
