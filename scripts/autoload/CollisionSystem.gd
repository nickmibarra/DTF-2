extends Node

# Collision layers for different types of entities
enum COLLISION_LAYER {
	NONE = 0,
	ENEMY = 1,
	WALL = 2,
	TOWER = 4,
	FLAG = 8
}

# Collision masks (what each type collides with)
const COLLISION_MASKS = {
	COLLISION_LAYER.ENEMY: COLLISION_LAYER.WALL | COLLISION_LAYER.TOWER,  # Enemies collide with walls and towers
	COLLISION_LAYER.WALL: COLLISION_LAYER.ENEMY,  # Walls collide with enemies
	COLLISION_LAYER.TOWER: COLLISION_LAYER.ENEMY,  # Towers collide with enemies
	COLLISION_LAYER.FLAG: COLLISION_LAYER.NONE  # Flag doesn't collide (for pathfinding purposes)
}

# Helper function to check if a position is valid considering all barriers
func is_position_valid(pos: Vector2, layer: int, radius: float = 32.0) -> bool:
	var barrier_objects = get_tree().get_nodes_in_group("barriers")
	for barrier_obj in barrier_objects:
		# Get the Barrier component
		var barrier_component = barrier_obj.get_node_or_null("Barrier")
		if barrier_component and barrier_component.collision_mask & layer != 0:
			if pos.distance_to(barrier_obj.position) < radius:
				return false
	return true 
