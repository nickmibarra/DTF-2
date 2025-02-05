extends Node2D

signal died(gold_value)
signal reached_flag(damage)

enum AI_STATE {
	MOVING,      # Moving towards target (flag or wall)
	ATTACKING    # Attacking current target (flag or wall)
}

var current_state: AI_STATE = AI_STATE.MOVING
var target_position: Vector2  # Flag position
var current_target = null     # Current attack target (flag or wall)
const MELEE_RANGE: float = 80.0
const MIN_ENEMY_SPACING: float = 40.0

# Movement and stats
var base_speed: float = 100.0
var speed: float = base_speed
var health: float = 100.0
var max_health: float = 100.0
var gold_value: int = 10
var damage_to_flag: int = 1
var damage_to_wall: int = 5
var attack_interval: float = 1.0
var attack_timer: float = 0.0

# Slow effect
var slow_factor: float = 1.0
var slow_duration: float = 0.0

@onready var health_bar = $HealthBar
@onready var sprite = $Sprite2D

func _ready():
	add_to_group("enemies")
	_update_health_bar()
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta):
	if slow_duration > 0:
		slow_duration -= delta
		if slow_duration <= 0:
			slow_factor = 1.0
			_update_appearance()
	
	match current_state:
		AI_STATE.MOVING:
			_process_movement(delta)
		AI_STATE.ATTACKING:
			_process_attacking(delta)

func _process_movement(delta):
	var flag = get_parent().flag
	if not flag:
		return
		
	# First, check if we can attack the flag directly
	if position.distance_to(flag.position) <= MELEE_RANGE and _can_attack_position(position):
		current_target = flag
		current_state = AI_STATE.ATTACKING
		return
		
	# Check for walls blocking direct path to flag
	var blocking_wall = _find_blocking_wall()
	if blocking_wall:
		current_target = blocking_wall
		current_state = AI_STATE.ATTACKING
		return
	
	# Move towards flag while avoiding other enemies
	var move_direction = _get_move_direction(flag.position)
	position += move_direction * base_speed * slow_factor * delta

func _process_attacking(delta):
	if not current_target or not is_instance_valid(current_target):
		current_state = AI_STATE.MOVING
		return
	
	# Check if still in range and position valid
	var target_pos = current_target.position
	if position.distance_to(target_pos) > MELEE_RANGE or not _can_attack_position(position):
		current_state = AI_STATE.MOVING
		return
	
	# Attack
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		if current_target.has_method("take_damage"):
			# Check if target is a wall by checking its script path
			var is_wall = current_target.get_script().resource_path.ends_with("Wall.gd")
			var damage = damage_to_wall if is_wall else damage_to_flag
			current_target.take_damage(damage)
			# Check if target is the flag by checking its script path
			if current_target.get_script().resource_path.ends_with("Flag.gd"):
				reached_flag.emit(damage)

func _get_move_direction(target_pos: Vector2) -> Vector2:
	var base_direction = (target_pos - position).normalized()
	
	# Add avoidance vector from nearby enemies
	var avoidance = Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy):
			var to_enemy = position - enemy.position
			var distance = to_enemy.length()
			if distance < MIN_ENEMY_SPACING:
				avoidance += to_enemy.normalized() * (1.0 - distance / MIN_ENEMY_SPACING)
	
	# Combine base direction with avoidance
	var final_direction = (base_direction + avoidance * 0.5).normalized()
	return final_direction

func _find_blocking_wall() -> Node2D:
	var grid = get_parent().grid
	var current_pos = grid.world_to_grid(position)
	var flag_pos = target_position
	
	# Check cells between current position and flag
	var direction = (flag_pos - current_pos).normalized()
	var check_pos = current_pos
	for _i in range(5):  # Check up to 5 cells ahead
		check_pos += direction.round()
		if not grid.is_valid_cell(check_pos):
			break
			
		if grid.get_cell_type(check_pos) == grid.TILE_TYPE.WALL:
			return grid.walls.get(str(check_pos))
	
	return null

func _can_attack_position(pos: Vector2) -> bool:
	# Check spacing with other enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and is_instance_valid(enemy):
			if pos.distance_to(enemy.position) < MIN_ENEMY_SPACING:
				return false
	
	# Check if position is on valid ground
	var grid = get_parent().grid
	var grid_pos = grid.world_to_grid(pos)
	if not grid.is_valid_cell(grid_pos):
		return false
	
	var cell_type = grid.get_cell_type(grid_pos)
	return cell_type != grid.TILE_TYPE.WALL and cell_type != grid.TILE_TYPE.TOWER

func set_target(grid_pos: Vector2):
	target_position = grid_pos

func set_stats(new_health: float, new_speed: float, new_gold: int, new_damage: int):
	max_health = new_health
	health = new_health
	base_speed = new_speed
	speed = new_speed
	gold_value = new_gold
	damage_to_flag = new_damage
	damage_to_wall = max(1, new_damage / 2)
	_update_health_bar()

func take_damage(amount: float):
	health -= amount
	_update_health_bar()
	
	sprite.modulate = Color(1, 0.3, 0.3)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	if health <= 0:
		died.emit(gold_value)
		queue_free()

func apply_slow(factor: float, duration: float):
	if factor < slow_factor:
		slow_factor = factor
		slow_duration = max(duration, slow_duration)
		_update_appearance()

func _update_health_bar():
	if health_bar:
		health_bar.size.x = (health / max_health) * 32

func _update_appearance():
	if slow_factor < 1.0:
		sprite.modulate = Color(0.7, 0.7, 1.0)
	else:
		sprite.modulate = Color.WHITE
