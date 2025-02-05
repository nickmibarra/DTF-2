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

func _ready():
	add_to_group("enemies")
	assert(behavior != null, "Enemy must have EnemyBehavior component")
	assert(grid != null, "Enemy needs Grid node for pathfinding")
	_update_health_bar()
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta):
	match current_state:
		AI_STATE.MOVING:
			_process_movement(delta)
		AI_STATE.ATTACKING:
			_process_combat(delta)

func _process_movement(delta):
	var target = _find_target()
	if not target:
		return
		
	var dist = position.distance_to(target.position)
	if dist <= ATTACK_RANGE:
		_transition_to_attack(target)
		return
		
	# If we're already attacking a wall, keep at it unless conditions change
	if current_state == AI_STATE.ATTACKING and current_target and current_target.is_in_group("walls"):
		var attack_dist = position.distance_to(current_target.position)
		if attack_dist <= ATTACK_RANGE * 1.5:
			return
	
	# If we're not attacking, handle movement
	var current_grid_pos = grid.world_to_grid(position)
	var target_grid_pos = grid.world_to_grid(target.position)
	
	# Recalculate path if needed
	var should_recalculate = current_path.is_empty() or \
						   (current_path.size() > 0 and current_path[-1] != target_grid_pos) or \
						   is_stuck(current_grid_pos)
	
	if should_recalculate:
		print("Enemy: Recalculating path from ", current_grid_pos, " to ", target_grid_pos)
		var path_result = grid.find_path(current_grid_pos, target_grid_pos)
		
		if path_result.is_wall_path:
			print("Enemy: Found wall-breaking path, transitioning to attack wall at ", path_result.wall_target)
			var wall = grid.walls.get(str(path_result.wall_target))
			if wall:
				_transition_to_attack(wall)
				return
		
		current_path = path_result.path
		if not current_path.is_empty():
			print("Enemy: Found path with ", current_path.size(), " steps")
	
	if not current_path.is_empty():
		_follow_path(delta)

func _find_target() -> Node2D:
	# First check for nearby walls
	var walls = get_tree().get_nodes_in_group("walls")
	var closest_wall = null
	var closest_dist = INF
	
	for wall in walls:
		var dist = position.distance_to(wall.position)
		if dist < closest_dist:
			closest_wall = wall
			closest_dist = dist
	
	# If we found a wall within range and should attack it, target it
	if closest_wall and closest_dist <= ATTACK_RANGE * 1.5:
		var wall_attackable = closest_wall.get_node("Attackable")
		if wall_attackable:
			if behavior.should_attack_target(wall_attackable.current_health, closest_dist):
				return closest_wall
	
	# Find flag in our test case or parent
	var parent = get_parent()
	var flag = parent.get_node_or_null("Flag")  # Check for sibling flag first
	if not flag:
		flag = get_tree().get_first_node_in_group("flags")  # Fallback to any flag
	
	if not flag:
		push_error("Enemy: No flag found in scene!")
		return null
		
	return flag

func _move_towards(target_pos: Vector2, delta: float):
	var direction = (target_pos - position).normalized()
	var proposed_position = position + direction * behavior.get_effective_speed() * delta
	
	# Check if proposed position would be in a wall
	var current_grid_pos = grid.world_to_grid(position)
	var proposed_grid_pos = grid.world_to_grid(proposed_position)
	
	# Only move if we're not trying to enter a wall cell
	if grid.get_cell_type(proposed_grid_pos) != grid.TILE_TYPE.WALL:
		position = proposed_position
		# Reset stuck timer when we successfully move
		stuck_time = 0.0
		last_position = position
	else:
		# Force path recalculation
		current_path.clear()

func _transition_to_attack(new_target: Node2D):
	print("Enemy: Transitioning to attack state, target: ", new_target.name)
	print("Enemy: Distance to target: ", position.distance_to(new_target.position))
	current_target = new_target
	current_state = AI_STATE.ATTACKING
	attack_timer = ATTACK_INTERVAL  # Reset timer to allow immediate first attack
	current_path.clear()

func _recalculate_path(target: Node2D):
	print("Enemy: Recalculating path to target")
	var start_pos = grid.world_to_grid(position)
	var end_pos = grid.world_to_grid(target.position)
	
	# Add small random offset to encourage unique paths
	var random_offset = Vector2(
		randf_range(-0.45, 0.45),
		randf_range(-0.45, 0.45)
	)
	start_pos += random_offset
	
	# Ensure grid positions are valid integers
	start_pos = Vector2(int(start_pos.x), int(start_pos.y))
	end_pos = Vector2(int(end_pos.x), int(end_pos.y))
	
	print("Enemy: Grid positions - Start: ", start_pos, " End: ", end_pos)
	
	# Validate positions are within grid bounds
	if not grid.is_valid_cell(start_pos) or not grid.is_valid_cell(end_pos):
		print("Enemy: Invalid grid positions!")
		return
	
	# Get multiple possible paths and choose one based on individual preference
	var possible_paths = []
	
	# Try a few different slight variations
	for _i in range(3):
		var path = grid.find_path(start_pos, end_pos)
		if not path.is_empty():
			possible_paths.append(path)
		start_pos += Vector2(randf_range(-0.45, 0.45), randf_range(-0.45, 0.45))
		start_pos = Vector2(int(start_pos.x), int(start_pos.y))
	
	if possible_paths.is_empty():
		print("Enemy: No path found, checking for walls to break")
		var wall = _find_wall_to_break(target.position)
		if wall:
			_transition_to_attack(wall)
	else:
		# Choose a random path from the valid ones
		current_path = possible_paths[randi() % possible_paths.size()]
		print("Enemy: Chose path with ", current_path.size(), " steps")
		print("Enemy: Path: ", current_path)

func _follow_path(delta: float):
	if current_path.is_empty():
		return
		
	var next_point = grid.grid_to_world(current_path[0])
	var dist_to_next = position.distance_to(next_point)
	
	print("Enemy: Following path - Current pos: ", position, " Next point: ", next_point, " Distance: ", dist_to_next)
	
	# Check if we've reached the current waypoint
	if dist_to_next < 10:
		current_path.pop_front()
		if not current_path.is_empty():
			next_point = grid.grid_to_world(current_path[0])
	
	if not current_path.is_empty():
		_move_towards(next_point, delta)
		
	# If we're stuck, clear path to force recalculation
	if is_stuck(grid.world_to_grid(position)):
		current_path.clear()

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
						print("Enemy: Found wall at ", check_pos, ", evaluating attack...")
						if behavior.should_attack_target(wall_attackable.current_health, dist):
							print("Enemy: Decided to attack wall at distance: ", dist)
							return wall
						else:
							print("Enemy: Decided not to attack wall, will try to path around")
	
	return null

func _process_combat(delta):
	if not current_target or not is_instance_valid(current_target):
		print("Enemy: Combat - Invalid target, returning to movement")
		current_state = AI_STATE.MOVING
		current_target = null
		return
		
	var dist = position.distance_to(current_target.position)
	print("Enemy: Combat - Distance to target: ", dist, ", Attack Range: ", ATTACK_RANGE)
	
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
			print("Enemy: Combat - Moving closer to target")
	else:
		# We're in range, perform attack
		attack_timer += delta
		if attack_timer >= ATTACK_INTERVAL:
			attack_timer = 0.0
			_perform_attack()

func _perform_attack():
	if not current_target or not is_instance_valid(current_target):
		print("Enemy: Attack - Invalid target")
		return
		
	print("Enemy: Performing attack on: ", current_target.name)
	var damage = WALL_DAMAGE if current_target.is_in_group("walls") else FLAG_DAMAGE
	
	if current_target.has_method("take_damage"):
		print("Enemy: Dealing ", damage, " damage to target")
		current_target.take_damage(damage)
		_play_attack_effects()
		
		if current_target.is_in_group("flags"):
			reached_flag.emit(damage)

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
		if stuck_time > STUCK_THRESHOLD:
			print("Enemy: Detected stuck at position ", current_grid_pos)
			# Reset stuck timer to prevent rapid recalculation
			stuck_time = 0.0
			return true
	else:
		stuck_time = 0.0
		last_position = position
	return false
