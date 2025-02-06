extends Node2D

# Base grid configuration
const BASE_GRID_SIZE = 64  # Base size of each grid cell in pixels
const GRID_WIDTH = 40  # Number of cells horizontally
const GRID_HEIGHT = 22  # Number of cells vertically

var grid = []  # 2D array to store grid data
var spawn_points = []  # List of possible enemy spawn points
var flag_position = Vector2(GRID_WIDTH - 3, GRID_HEIGHT / 2)
var wall_scene = preload("res://scenes/Wall.tscn")
var walls = {}  # Dictionary to store wall instances

enum TILE_TYPE {
	EMPTY,
	WALL,
	TOWER,
	PATH,
	FLAG
}

class PathResult:
	var path: Array
	var wall_target: Vector2
	var is_wall_path: bool
	
	func _init(p: Array, wall: Vector2 = Vector2.ZERO, is_wall: bool = false):
		path = p
		wall_target = wall
		is_wall_path = is_wall

signal obstacle_changed(position)  # Emitted when wall placed/destroyed

func _ready():
	print("Grid: Ready called")
	initialize_grid()
	initialize_spawn_points()
	setup_grid_transform()
	get_tree().get_root().size_changed.connect(_on_viewport_size_changed)

func setup_grid_transform():
	# Grid should be at origin with no transform
	position = Vector2.ZERO
	scale = Vector2.ONE

func _on_viewport_size_changed():
	setup_grid_transform()
	queue_redraw()

func initialize_spawn_points():
	# Clear existing spawn points
	spawn_points.clear()
	
	# Add spawn points along the left edge with proper spacing
	for y in range(2, GRID_HEIGHT - 2):  # Leave some margin at top/bottom
		var spawn_point = Vector2(0, y)
		spawn_points.append(spawn_point)

func initialize_grid():
	# Initialize the grid with empty cells
	grid = []
	for x in range(GRID_WIDTH):
		var column = []
		for y in range(GRID_HEIGHT):
			column.append(TILE_TYPE.EMPTY)
		grid.append(column)
	
	# Set the flag position
	grid[flag_position.x][flag_position.y] = TILE_TYPE.FLAG

func _draw():
	# Draw background for entire grid
	var bg_color = Color(0.2, 0.3, 0.2, 0.2)  # Subtle dark green
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(GRID_WIDTH * BASE_GRID_SIZE, GRID_HEIGHT * BASE_GRID_SIZE)),
		bg_color
	)
	
	# Draw grid lines
	var line_color = Color(0.3, 0.3, 0.3, 0.5)  # Subtle grid lines
	for x in range(GRID_WIDTH + 1):
		draw_line(
			Vector2(x * BASE_GRID_SIZE, 0),
			Vector2(x * BASE_GRID_SIZE, GRID_HEIGHT * BASE_GRID_SIZE),
			line_color
		)
	for y in range(GRID_HEIGHT + 1):
		draw_line(
			Vector2(0, y * BASE_GRID_SIZE),
			Vector2(GRID_WIDTH * BASE_GRID_SIZE, y * BASE_GRID_SIZE),
			line_color
		)
	
	# Draw tiles (except walls and flag, which are Node2D instances)
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2(x * BASE_GRID_SIZE, y * BASE_GRID_SIZE)
			match grid[x][y]:
				TILE_TYPE.TOWER:
					draw_rect(Rect2(pos, Vector2(BASE_GRID_SIZE, BASE_GRID_SIZE)), Color(0.2, 0.4, 0.8, 0.3))
				TILE_TYPE.PATH:
					draw_rect(Rect2(pos, Vector2(BASE_GRID_SIZE, BASE_GRID_SIZE)), Color(0.2, 0.8, 0.2, 0.3))

func is_valid_cell(pos: Vector2) -> bool:
	var x = int(pos.x)
	var y = int(pos.y)
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

func get_cell_type(pos: Vector2) -> int:
	if not is_valid_cell(pos):
		return -1
	return grid[pos.x][pos.y]

func set_cell_type(pos: Vector2, type: int) -> bool:
	if not is_valid_cell(pos):
		return false
	
	if type != TILE_TYPE.EMPTY and (pos in spawn_points or pos == flag_position):
		return false
	
	var old_type = grid[pos.x][pos.y]
	
	# Remove existing wall if any
	if grid[pos.x][pos.y] == TILE_TYPE.WALL and walls.has(str(pos)):
		walls[str(pos)].queue_free()
		walls.erase(str(pos))
	
	grid[pos.x][pos.y] = type
	
	# Create wall instance if needed
	if type == TILE_TYPE.WALL:
		var wall = wall_scene.instantiate()
		var final_pos = grid_to_world(pos)
		wall.position = final_pos
		add_child(wall)
		walls[str(pos)] = wall
	
	# Notify if obstacle state changed
	if (old_type == TILE_TYPE.WALL or type == TILE_TYPE.WALL):
		obstacle_changed.emit(pos)
	
	queue_redraw()
	return true

func world_to_grid(world_pos: Vector2) -> Vector2:
	# Direct conversion from world position to grid coordinates
	var grid_x = int(world_pos.x / BASE_GRID_SIZE)
	var grid_y = int(world_pos.y / BASE_GRID_SIZE)
	
	return Vector2(
		clamp(grid_x, 0, GRID_WIDTH - 1),
		clamp(grid_y, 0, GRID_HEIGHT - 1)
	)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	# Convert grid coordinates to world position (center of cell)
	var world_pos = Vector2(
		grid_pos.x * BASE_GRID_SIZE + BASE_GRID_SIZE/2,
		grid_pos.y * BASE_GRID_SIZE + BASE_GRID_SIZE/2
	)
	return world_pos

# A* pathfinding implementation
func find_path(start: Vector2, end: Vector2) -> PathResult:
	var open_set = []
	var closed_set = {}
	var came_from = {}
	
	var g_score = {str(start): 0.0}
	var f_score = {str(start): heuristic(start, end)}
	
	open_set.append(start)
	
	while open_set.size() > 0:
		var current = get_lowest_f_score_node(open_set, f_score)
		if current == end:
			return PathResult.new(reconstruct_path(came_from, current))
		
		open_set.erase(current)
		closed_set[str(current)] = true
		
		for neighbor_data in get_neighbors(current):
			var neighbor = neighbor_data.pos
			var move_cost = neighbor_data.cost
			
			if closed_set.has(str(neighbor)):
				continue
			
			var tentative_g_score = g_score[str(current)] + move_cost
			
			if not open_set.has(neighbor):
				open_set.append(neighbor)
			elif tentative_g_score >= g_score[str(neighbor)]:
				continue
			
			came_from[str(neighbor)] = current
			g_score[str(neighbor)] = tentative_g_score
			f_score[str(neighbor)] = g_score[str(neighbor)] + heuristic(neighbor, end)
	
	# If no path found, find wall to break
	var wall_result = find_wall_breakthrough_path(start, end, closed_set)
	if not wall_result.path.is_empty():
		print("Grid: Found wall-breaking path to wall at ", wall_result.wall_target)
		return wall_result
	return PathResult.new([])

func find_wall_breakthrough_path(start: Vector2, end: Vector2, explored_cells: Dictionary) -> PathResult:
	# Calculate direction to target
	var dir = (end - start).normalized()
	var best_wall_pos = null
	var best_score = INF
	var best_path = []
	
	# Only check walls in the general direction of the target
	var check_radius = 3  # Check 3 cells in each direction from the direct path
	var step_count = int(start.distance_to(end))
	var current = start
	
	for _i in range(step_count):
		current += dir
		var check_pos = Vector2(int(current.x), int(current.y))
		
		# Check cells around the direct path
		for x_offset in range(-check_radius, check_radius + 1):
			for y_offset in range(-check_radius, check_radius + 1):
				var wall_pos = check_pos + Vector2(x_offset, y_offset)
				if not is_valid_cell(wall_pos):
					continue
					
				if get_cell_type(wall_pos) == TILE_TYPE.WALL:
					var dist_to_start = wall_pos.distance_to(start)
					var dist_to_end = wall_pos.distance_to(end)
					var score = dist_to_start + dist_to_end
					
					if score < best_score:
						# Try to find path to a position adjacent to wall
						var adjacent_positions = get_adjacent_positions(wall_pos)
						for adj_pos in adjacent_positions:
							if is_valid_cell(adj_pos) and get_cell_type(adj_pos) != TILE_TYPE.WALL:
								var path_to_wall = find_path_to_position(start, adj_pos)
								if not path_to_wall.is_empty():
									best_score = score
									best_wall_pos = wall_pos
									best_path = path_to_wall
									break
	
	if best_wall_pos != null:
		return PathResult.new(best_path, best_wall_pos, true)
	
	return PathResult.new([])

func get_adjacent_positions(pos: Vector2) -> Array:
	return [
		pos + Vector2(1, 0),
		pos + Vector2(-1, 0),
		pos + Vector2(0, 1),
		pos + Vector2(0, -1)
	]

func find_path_to_position(start: Vector2, end: Vector2) -> Array:
	var open_set = []
	var closed_set = {}
	var came_from = {}
	
	var g_score = {str(start): 0.0}
	var f_score = {str(start): heuristic(start, end)}
	
	open_set.append(start)
	
	while open_set.size() > 0:
		var current = get_lowest_f_score_node(open_set, f_score)
		if current == end:
			return reconstruct_path(came_from, current)
		
		open_set.erase(current)
		closed_set[str(current)] = true
		
		for neighbor_data in get_neighbors(current):
			var neighbor = neighbor_data.pos
			var move_cost = neighbor_data.cost
			
			if closed_set.has(str(neighbor)):
				continue
			
			var tentative_g_score = g_score[str(current)] + move_cost
			
			if not open_set.has(neighbor):
				open_set.append(neighbor)
			elif tentative_g_score >= g_score[str(neighbor)]:
				continue
			
			came_from[str(neighbor)] = current
			g_score[str(neighbor)] = tentative_g_score
			f_score[str(neighbor)] = g_score[str(neighbor)] + heuristic(neighbor, end)
	
	return []

func heuristic(start: Vector2, end: Vector2) -> float:
	# Use Euclidean distance for more natural diagonal paths
	return start.distance_to(end)

func get_lowest_f_score_node(nodes: Array, f_score: Dictionary) -> Vector2:
	var lowest_node = nodes[0]
	var lowest_score = f_score[str(lowest_node)]
	
	for node in nodes:
		var score = f_score[str(node)]
		if score < lowest_score:
			lowest_node = node
			lowest_score = score
	
	return lowest_node

func get_neighbors(pos: Vector2) -> Array:
	var neighbors = []
	var directions = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),  # Cardinals
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)  # Diagonals
	]
	
	for dir in directions:
		var neighbor = pos + dir
		if is_valid_cell(neighbor):
			# Check if we can move to this cell
			if grid[neighbor.x][neighbor.y] != TILE_TYPE.WALL and grid[neighbor.x][neighbor.y] != TILE_TYPE.TOWER:
				# Add movement cost for diagonal
				var cost = 1.0 if dir.x == 0 or dir.y == 0 else 1.414
				neighbors.append({"pos": neighbor, "cost": cost})
	
	return neighbors

func reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while came_from.has(str(current)):
		current = came_from[str(current)]
		path.push_front(current)
	return path

func get_random_spawn_point() -> Vector2:
	if spawn_points.is_empty():
		push_error("No spawn points defined")
		return Vector2.ZERO
	
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	return grid_to_world(spawn_point)
