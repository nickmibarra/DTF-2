class_name MovementComponent
extends EntityComponent

signal position_changed(new_position: Vector2)
signal path_completed
signal movement_blocked(position: Vector2)

@export var movement_speed: float = 100.0
@export var rotation_speed: float = PI  # Radians per second
@export var arrival_threshold: float = 5.0  # Distance to consider arrived at target

var current_path: Array[Vector2] = []
var target_position: Vector2
var is_moving: bool = false
var _velocity: Vector2 = Vector2.ZERO

func _initialize() -> void:
	# Ensure we have a valid entity reference
	assert(entity != null, "MovementComponent requires a Node2D parent")

func process(delta: float) -> void:
	if not is_moving or current_path.is_empty():
		return
	
	var next_point = current_path[0]
	var direction = (next_point - entity.position).normalized()
	var distance = entity.position.distance_to(next_point)
	
	# Move towards next point
	if distance > arrival_threshold:
		_velocity = direction * movement_speed
		entity.position += _velocity * delta
		emit_signal("position_changed", entity.position)
	else:
		# Reached waypoint
		current_path.pop_front()
		emit_signal("position_changed", entity.position)  # Emit on waypoint reach
		if current_path.is_empty():
			is_moving = false
			_velocity = Vector2.ZERO
			emit_signal("path_completed")

func move_to(target: Vector2) -> void:
	target_position = target
	is_moving = true
	current_path = [target]  # Direct movement
	_velocity = Vector2.ZERO  # Reset velocity on new movement
	
func follow_path(path: Array) -> void:
	if path.is_empty():
		return
	
	# Convert input array to typed array
	current_path.clear()
	for point in path:
		if point is Vector2:
			current_path.push_back(point)
	
	if not current_path.is_empty():
		target_position = current_path[-1]
		is_moving = true
		_velocity = Vector2.ZERO  # Reset velocity on new path

func stop() -> void:
	is_moving = false
	current_path.clear()
	_velocity = Vector2.ZERO

func get_velocity() -> Vector2:
	return _velocity

func is_at_target() -> bool:
	return not is_moving or (current_path.is_empty() and entity.position.distance_to(target_position) <= arrival_threshold) 