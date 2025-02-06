extends Node2D

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
const WALL_DAMAGE = 20
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

func _ready():
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
	var flag = _find_target()
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
				# Force a new path if we haven't made progress
				_recalculate_path_if_needed(true)  # Force recalculation
				same_path_time = 0.0
		else:
			same_path_time = 0.0
			last_path_length = current_path.size()
	
	# If we can't attack flag, handle movement
	if current_path.is_empty() and target_position == Vector2.ZERO:
		if flag and should_update:  # Only update path on update tick
			# Instead of pathing to flag position, path directly to flag
			target_position = flag.position  # Path directly to flag
			target_grid_pos = grid.world_to_grid(target_position)
			_recalculate_path_if_needed()
			return
	
	# Check for walls only if we're stuck or don't have a path
	if (current_path.is_empty() or is_stuck(grid.world_to_grid(position))) and should_update:
		var wall_target = _find_wall_to_attack()
		if wall_target:
			_transition_to_attack(wall_target)
			return
		_recalculate_path_if_needed()
	
	# Follow current path
	if not current_path.is_empty():
		_follow_path(delta)

func _find_wall_to_attack() -> Node2D:
	var flag = _find_target()
	if not flag:
		return null
	
	# First check if we have a clear path to flag
	var current_grid_pos = grid.world_to_grid(position)
	var flag_grid_pos = grid.world_to_grid(flag.position)
	var path_to_flag = grid.find_path(current_grid_pos, flag_grid_pos)
	
	# If we have a valid path that doesn't require wall breaking, don't attack walls
	if not path_to_flag.path.is_empty() and not path_to_flag.is_wall_path:
		return null
	
	var nearby_attackables = grid.get_attackables_in_range(position, ATTACK_RANGE * 1.5)
	var best_target = null
	var best_score = INF
	
	var to_flag_dir = (flag.position - position).normalized()
	
	for potential_target in nearby_attackables:
		# Skip if it's the enemy itself or not a wall
		if potential_target == self or not potential_target.is_in_group("walls"):
			continue
			
		var attackable_component = potential_target.get_node_or_null("Attackable")
		if not attackable_component:
			continue
			
		var wall_pos = potential_target.position
		var dist = position.distance_to(wall_pos)
		
		# Check if wall is in the general direction of the flag
		var to_wall_dir = (wall_pos - position).normalized()
		var dot_product = to_flag_dir.dot(to_wall_dir)
		
		# Calculate a score based on multiple factors
		if dot_product > 0.0:  # Wall is roughly in the direction we want to go
			var wall_grid_pos = grid.world_to_grid(wall_pos)
			
			# Check if there's a path around this wall
			var temp_grid_state = grid.get_cell_type(wall_grid_pos)
			grid.set_cell_type(wall_grid_pos, grid.TILE_TYPE.EMPTY)  # Temporarily remove wall
			var alternate_path = grid.find_path(current_grid_pos, flag_grid_pos)
			grid.set_cell_type(wall_grid_pos, temp_grid_state)  # Restore wall
			
			# If there's a good path around, skip this wall
			if not alternate_path.path.is_empty() and alternate_path.path.size() < path_to_flag.path.size() + 5:
				continue
			
			# Score based on distance and direction
			var score = dist * (2.0 - dot_product)  # Lower score is better
			
			if behavior.should_attack_target(attackable_component.current_health, dist):
				if score < best_score:
					best_target = potential_target
					best_score = score
	
	return best_target

func _find_target() -> Node2D:
	if not _flag:
		_flag = get_tree().get_first_node_in_group("flags")
		if not _flag:
			push_error("Enemy: No flag found in scene!")
			return null
	
	return _flag

func _move_towards(target_pos: Vector2, delta: float):
	var direction = (target_pos - position).normalized()
	var move_speed = behavior.get_effective_speed() * delta
	var proposed_position = position + direction * move_speed
	
	# Check if we're moving towards the flag
	var flag = _find_target()
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
	
	# Fast path: If proposed position is clear, take it
	if cell_type != grid.TILE_TYPE.WALL:
		position = proposed_position
		stuck_time = 0.0
		last_position = position
		return
	
	# Only do detailed collision checks if we hit a wall
	var wall_clearance = GameSettings.BASE_GRID_SIZE * 0.3
	
	# Try diagonal movements first
	var diagonal_directions = [
		direction.rotated(PI/4),
		direction.rotated(-PI/4)
	]
	
	for slide_dir in diagonal_directions:
		var slide_position = position + slide_dir * move_speed
		var slide_grid_pos = grid.world_to_grid(slide_position)
		if grid.get_cell_type(slide_grid_pos) != grid.TILE_TYPE.WALL:
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
		if grid.get_cell_type(slide_grid_pos) != grid.TILE_TYPE.WALL:
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
	
	# If we're forced to recalc, try a simple offset pattern
	var path_result
	if force:
		# Try a few simple offsets from the target
		var offsets = [
			Vector2.ZERO,  # Direct path first
			Vector2(-1, 0),
			Vector2(1, 0),
			Vector2(0, -1),
			Vector2(0, 1)
		]
		
		var best_path = []
		var best_score = INF
		
		for offset in offsets:
			var try_target = target_grid_pos + offset
			if grid.is_valid_cell(try_target) and grid.get_cell_type(try_target) == grid.TILE_TYPE.EMPTY:
				var try_result = grid.find_path(current_grid_pos, try_target)
				if not try_result.path.is_empty():
					var score = _evaluate_path(try_result.path)
					if score < best_score:
						best_path = try_result.path
						best_score = score
						path_result = try_result
		
		if not best_path.is_empty():
			current_path = best_path
			return
	
	# Fall back to normal pathfinding if forced recalc failed or wasn't requested
	path_result = grid.find_path(current_grid_pos, target_grid_pos)
	
	if path_result.is_wall_path:
		var wall = grid.walls.get(str(path_result.wall_target))
		if wall:
			_transition_to_attack(wall)
			return
	
	current_path = path_result.path

# Helper function to evaluate path quality
func _evaluate_path(path: Array) -> float:
	if path.is_empty():
		return INF
		
	var score = path.size() * 1.0  # Base score is path length
	
	# Only penalize paths that run along walls
	for i in range(1, path.size()):
		var pos = path[i]
		# Check adjacent cells for walls
		var adjacent_walls = 0
		for offset in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var check_pos = pos + offset
			if grid.is_valid_cell(check_pos) and grid.get_cell_type(check_pos) == grid.TILE_TYPE.WALL:
				adjacent_walls += 1
		score += adjacent_walls * 1.0  # Wall penalty
	
	return score

func _follow_path(delta: float):
	if current_path.is_empty():
		return
	
	# Check attack range before moving
	var flag = _find_target()
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

func _find_wall_to_break(target_pos: Vector2) -> Node2D:
	var start_grid = grid.world_to_grid(position)
	var end_grid = grid.world_to_grid(target_pos)
	
	# Get direction to target
	var dx = end_grid.x - start_grid.x
	var dy = end_grid.y - start_grid.y
	var direction = Vector2(
		1 if dx > 0 else -1 if dx < 0 else 0,
		1 if dy > 0 else -1 if dy < 0 else 0
	)
	
	# Check cells in direction of target
	var check_pos = start_grid
	for _i in range(3):  # Check up to 3 cells ahead
		check_pos += direction
		if not grid.is_valid_cell(check_pos):
			break
			
		if grid.get_cell_type(check_pos) == grid.TILE_TYPE.WALL:
			var wall = grid.walls.get(str(check_pos))
			if wall:
				var wall_attackable = wall.get_node("Attackable")
				if wall_attackable:
					var dist = position.distance_to(wall.position)
					if dist <= ATTACK_RANGE * 1.5:
						if behavior.should_attack_target(wall_attackable.current_health, dist):
							return wall
						else:
							return null
	
	return null

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
		
		# Check if proposed position would be in a wall (that's not our target)
		var proposed_grid_pos = grid.world_to_grid(proposed_position)
		var cell_type = grid.get_cell_type(proposed_grid_pos)
		var can_move = true
		
		if cell_type == grid.TILE_TYPE.WALL:
			var wall = grid.walls.get(str(proposed_grid_pos))
			if wall != current_target:
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
		var damage_amount = WALL_DAMAGE
		if current_target.is_in_group("towers"):
			damage_amount *= 0.8  # Towers take slightly less damage than walls
		
		current_target.take_damage(damage_amount)
		_play_attack_effects()
		attack_timer = 0.0

func _play_attack_effects():
	sprite.modulate = Color(1.2, 0.8, 0.2)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	sprite.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.2)

func set_stats(new_health: float, new_speed: float, new_gold: int, new_damage: int):
	max_health = new_health
	health = new_health
	behavior.movement_speed = new_speed
	behavior.attack_damage = new_damage
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

func _attack_target():
	if not current_target or not is_instance_valid(current_target):
		return
		
	if not current_target.has_method("take_damage"):
		return
		
	var distance = position.distance_to(current_target.position)
	if distance <= ATTACK_RANGE:
		current_target.take_damage(WALL_DAMAGE if current_target.is_in_group("walls") else FLAG_DAMAGE)
		_play_attack_effects()
		attack_timer = 0.0
