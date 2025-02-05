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

func _ready():
	print("Grid: Ready called")
	set_process_input(true)  # Enable input processing
	initialize_grid()
	initialize_spawn_points()
	setup_grid_transform()
	get_tree().get_root().size_changed.connect(_on_viewport_size_changed)

func _input(event):
	if not event is InputEventMouseMotion:  # Don't log mouse motion
		print("Grid: Input event received: ", event)

func setup_grid_transform():
	# Center the grid at (0,0) - camera will handle viewport positioning
	position = Vector2.ZERO
	
	# No scaling at grid level - camera will handle viewport scaling
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
		print("Added spawn point at grid position: ", spawn_point)  # Debug log

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
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT

func get_cell_type(pos: Vector2) -> int:
	if not is_valid_cell(pos):
		return -1
	return grid[pos.x][pos.y]

func set_cell_type(pos: Vector2, type: int) -> bool:
	if not is_valid_cell(pos):
		print("Invalid cell position: ", pos)
		return false
	
	if type != TILE_TYPE.EMPTY and (pos in spawn_points or pos == flag_position):
		print("Cannot build on spawn point or flag")
		return false
	
	# Remove existing wall if any
	if grid[pos.x][pos.y] == TILE_TYPE.WALL and walls.has(str(pos)):
		walls[str(pos)].queue_free()
		walls.erase(str(pos))
	
	grid[pos.x][pos.y] = type
	
	# Create wall instance if needed
	if type == TILE_TYPE.WALL:
		var wall = wall_scene.instantiate()
		wall.position = grid_to_world(pos)
		add_child(wall)
		walls[str(pos)] = wall
	
	queue_redraw()
	return true

func world_to_grid(screen_pos: Vector2) -> Vector2:
	# Convert screen position to local position using Godot's built-in functionality
	var local_pos = to_local(get_global_mouse_position())
	
	# Convert to grid coordinates
	var grid_x = floor(local_pos.x / BASE_GRID_SIZE)
	var grid_y = floor(local_pos.y / BASE_GRID_SIZE)
	
	return Vector2(
		clamp(grid_x, 0, GRID_WIDTH - 1),
		clamp(grid_y, 0, GRID_HEIGHT - 1)
	)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	# Convert grid coordinates to local position
	var local_pos = Vector2(
		grid_pos.x * BASE_GRID_SIZE + BASE_GRID_SIZE / 2,
		grid_pos.y * BASE_GRID_SIZE + BASE_GRID_SIZE / 2
	)
	
	# Convert to global position using to_global
	return to_global(local_pos)

# A* pathfinding implementation
func find_path(start: Vector2, end: Vector2) -> Array:
	var open_set = []
	var closed_set = {}
	var came_from = {}
	
	var g_score = {str(start): 0}
	var f_score = {str(start): heuristic(start, end)}
	
	open_set.append(start)
	
	while open_set.size() > 0:
		var current = get_lowest_f_score_node(open_set, f_score)
		if current == end:
			return reconstruct_path(came_from, current)
		
		open_set.erase(current)
		closed_set[str(current)] = true
		
		for neighbor in get_neighbors(current):
			if closed_set.has(str(neighbor)):
				continue
			
			var tentative_g_score = g_score[str(current)] + 1
			
			if not open_set.has(neighbor):
				open_set.append(neighbor)
			elif tentative_g_score >= g_score[str(neighbor)]:
				continue
			
			came_from[str(neighbor)] = current
			g_score[str(neighbor)] = tentative_g_score
			f_score[str(neighbor)] = g_score[str(neighbor)] + heuristic(neighbor, end)
	
	return []

func heuristic(start: Vector2, end: Vector2) -> float:
	return abs(start.x - end.x) + abs(start.y - end.y)

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
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)  # Add diagonals
	]
	
	for dir in directions:
		var neighbor = pos + dir
		if is_valid_cell(neighbor):
			# Enemies can't walk through walls or towers
			if grid[neighbor.x][neighbor.y] != TILE_TYPE.WALL and grid[neighbor.x][neighbor.y] != TILE_TYPE.TOWER:
				neighbors.append(neighbor)
	
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
	# Convert grid position to world position
	var world_pos = grid_to_world(spawn_point)
	print("Selected spawn point: grid=", spawn_point, " world=", world_pos)  # Debug log
	return world_pos
