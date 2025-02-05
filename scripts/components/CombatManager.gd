extends Node

signal attack_performed(attacker, target, damage)
signal target_destroyed(target_position)

# Combat configuration
const DEFAULT_CONFIG = {
	"ATTACK_RANGE": 80.0,
	"RANGE_BUFFER": 10.0,
	"PERSONAL_SPACE": 32.0
}

var config: Dictionary = DEFAULT_CONFIG.duplicate()
var grid: Node  # Reference to the game grid

func _ready():
	# Wait a frame for other nodes to be ready
	await get_tree().process_frame
	grid = get_tree().get_first_node_in_group("grid")
	if not grid:
		push_error("CombatManager: No grid found in scene")

func initialize(custom_config: Dictionary = {}):
	config.merge(custom_config)

func can_attack(attacker: Node2D, target: Node2D) -> bool:
	if not is_valid_combat_pair(attacker, target):
		print("Invalid combat pair")  # Debug log
		return false
	
	var distance = attacker.position.distance_to(target.position)
	if not is_in_attack_range(distance):
		print("Target out of range")  # Debug log
		return false
		
	print("Attack check passed - Distance: ", distance)  # Debug log
	return true  # Removed path check since we're already at attack position

func has_clear_path(attacker: Node2D, target: Node2D) -> bool:
	if not grid:
		return true  # Fallback if no grid
		
	var start_pos = grid.world_to_grid(attacker.position)
	var end_pos = grid.world_to_grid(target.position)
	
	var path = grid.find_path(start_pos, end_pos)
	return not path.is_empty()

func is_valid_attack_position(pos: Vector2, target: Node2D) -> bool:
	if not grid:
		return true  # Fallback if no grid
		
	# Check grid position
	var grid_pos = grid.world_to_grid(pos)
	if not grid.is_valid_cell(grid_pos):
		return false
		
	if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
		return false
		
	# Check collision
	if not CollisionSystem.is_position_valid(pos, CollisionSystem.COLLISION_LAYER.ENEMY, config.PERSONAL_SPACE):
		return false
		
	# Check if we can attack target from here
	var distance = pos.distance_to(target.position)
	if not is_in_attack_range(distance):
		return false
		
	return true

func get_best_attack_position(attacker: Node2D, target: Node2D) -> Vector2:
	if not is_valid_combat_pair(attacker, target):
		return attacker.position
	
	# Try current position first if valid
	if can_attack(attacker, target):
		return attacker.position
	
	# Find best position around target
	var angles = range(0, 360, 45)
	angles.shuffle()
	
	var best_position = attacker.position
	var best_distance = INF
	
	for angle in angles:
		var rad = deg_to_rad(angle)
		var offset = Vector2(cos(rad), sin(rad)) * config.ATTACK_RANGE
		var test_pos = target.position + offset
		
		if is_valid_attack_position(test_pos, target):
			var dist = test_pos.distance_to(attacker.position)
			if dist < best_distance:
				best_position = test_pos
				best_distance = dist
	
	return best_position

func perform_attack(attacker: Node2D, target: Node2D, damage: float) -> bool:
	if not can_attack(attacker, target):
		return false
	
	var attackable = target.get_node_or_null("Attackable")
	if not attackable:
		return false
	
	var actual_damage = attackable.take_damage(damage, attacker)
	emit_signal("attack_performed", attacker, target, actual_damage)
	
	if attackable.current_health <= 0:
		emit_signal("target_destroyed", target.position)
	
	return true

func is_valid_combat_pair(attacker: Node2D, target: Node2D) -> bool:
	if not attacker or not target or not target.is_inside_tree():
		return false
	
	if not target.has_node("Attackable"):
		return false
	
	return true

func is_in_attack_range(distance: float) -> bool:
	var max_range = config.ATTACK_RANGE + config.RANGE_BUFFER
	print("CombatManager range check - Distance: ", distance, " Max range: ", max_range)  # Debug log
	return distance <= max_range  # Only check maximum range

func find_attackable_targets(from_position: Vector2, max_range: float, group: String = "") -> Array:
	var targets = []
	var potential_targets = get_tree().get_nodes_in_group("attackable")
	
	for target in potential_targets:
		if not target.is_inside_tree():
			continue
			
		if group and not target.is_in_group(group):
			continue
			
		var parent = target.get_parent()
		if not parent is Node2D:
			continue
			
		var distance = from_position.distance_to(parent.position)
		if distance <= max_range:
			targets.append(parent)
	
	return targets
