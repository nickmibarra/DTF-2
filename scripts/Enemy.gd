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

# Base stats
var base_speed: float = 100.0
var health: float = 100.0
var max_health: float = 100.0
var gold_value: int = 10

@onready var health_bar = $HealthBar
@onready var sprite = $Sprite2D

func _ready():
	add_to_group("enemies")
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
		current_target = target
		current_state = AI_STATE.ATTACKING
	else:
		_move_towards(target.position, delta)

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
	
	# If we found a wall within range, target it
	if closest_wall and closest_dist <= ATTACK_RANGE * 1.5:
		return closest_wall
	
	# Otherwise target flag
	return get_parent().flag

func _process_combat(delta):
	if not current_target or not is_instance_valid(current_target):
		current_state = AI_STATE.MOVING
		current_target = null
		return
		
	var dist = position.distance_to(current_target.position)
	if dist > ATTACK_RANGE:
		current_state = AI_STATE.MOVING
		current_target = null
		return
		
	attack_timer += delta
	if attack_timer >= ATTACK_INTERVAL:
		attack_timer = 0.0
		_perform_attack()

func _perform_attack():
	if not current_target or not is_instance_valid(current_target):
		return
		
	var damage = WALL_DAMAGE if current_target.is_in_group("walls") else FLAG_DAMAGE
	print("Enemy: Performing attack - Target: ", current_target.name, " Damage: ", damage)
	
	if current_target.has_method("take_damage"):
		current_target.take_damage(damage)
		_play_attack_effects()
		
		if current_target.is_in_group("flags"):
			print("Enemy: Flag hit - Emitting reached_flag signal")
			reached_flag.emit(damage)
	else:
		print("Enemy: Target has no take_damage method!")

func _move_towards(target_pos: Vector2, delta: float):
	var direction = (target_pos - position).normalized()
	position += direction * base_speed * delta

func _play_attack_effects():
	sprite.modulate = Color(1.2, 0.8, 0.2)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	sprite.scale = Vector2(1.2, 1.2)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.2)

func set_stats(new_health: float, new_speed: float, new_gold: int, _new_damage: int):
	max_health = new_health
	health = new_health
	base_speed = new_speed
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
