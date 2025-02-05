class_name Barrier
extends Node

var collision_layer: int = 0
var collision_mask: int = 0

func setup(parent_node: Node2D, layer: int):
	collision_layer = layer
	collision_mask = CollisionSystem.COLLISION_MASKS[layer]

# Check if this barrier collides with another entity
func collides_with(other_layer: int) -> bool:
	return (collision_mask & other_layer) != 0

# Check if a position would result in collision
func check_collision(pos: Vector2, radius: float = 32.0) -> bool:
	if not get_parent() or not is_instance_valid(get_parent()):
		return false
	return pos.distance_to(get_parent().position) < radius 