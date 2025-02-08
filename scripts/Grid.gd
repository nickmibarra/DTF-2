extends Node2D

# Base grid configuration
const BASE_GRID_SIZE = GameSettings.BASE_GRID_SIZE
const GRID_WIDTH = GameSettings.GRID_WIDTH
const GRID_HEIGHT = GameSettings.GRID_HEIGHT

var grid = []  # 2D array to store grid data
var spawn_points = []  # List of possible enemy spawn points
var flag_position = Vector2(GRID_WIDTH - 3, GRID_HEIGHT / 2)
var wall_scene = preload("res://scenes/Wall.tscn")
var walls = {}  # Dictionary to store wall instances
var towers = {}  # Dictionary to store tower instances

# Cache for attackable objects
var attackable_objects = {}  # Dictionary of attackable objects by position
var spatial_grid = {}  # Spatial partitioning for quick neighbor lookups
const SPATIAL_CELL_SIZE = 128  # Size of spatial partitioning cells

# Add path caching
var path_cache = {}
const PATH_CACHE_TIME = 0.5  # Reduced to 0.5 seconds
const MAX_CACHE_SIZE = 1000   # Keep this the same
const CACHE_REGION_SIZE = 1   # Reduced to 1 for exact position matching

# Add range check caching
var _range_cache = {}

# Add near other cache variables
var _breakthrough_cache = {}
const BREAKTHROUGH_CACHE_TIME = 1.0  # 1 second cache for breakthrough paths

# Add cache cleanup timer
var _range_cleanup_timer: float = 0.0
const RANGE_CLEANUP_INTERVAL: float = 0.5  # Clean every 0.5 seconds

# Add near other cache variables
var _flag_access_cache = {
	"is_blocked": false,
	"blocking_walls": [],
	"time": 0.0
}
const FLAG_ACCESS_CACHE_TIME = 0.2  # 200ms, shorter than other caches since it's critical

enum TILE_TYPE {
	EMPTY,
	WALL,
	TOWER,
	PATH,
	FLAG
}

class PathResult:
	var path: Array
	var obstacle_target: Vector2  # Renamed from wall_target
	var blocked_by_obstacle: bool  # Renamed from is_wall_path
	
	func _init(p: Array, obstacle: Vector2 = Vector2.ZERO, is_blocked: bool = false):
		path = p
		obstacle_target = obstacle
		blocked_by_obstacle = is_blocked

signal obstacle_changed(position)  # Emitted when wall placed/destroyed
signal attackable_added(object, position)
signal attackable_removed(object, position)
signal tower_placed(tower, position)

func _ready():
	initialize_grid()
	initialize_spawn_points()
	setup_grid_transform()
	get_tree().get_root().size_changed.connect(_on_viewport_size_changed)
	
	# Initialize spatial grid
	_initialize_spatial_grid()
	
	# Clear any existing entities
	for child in get_children():
		if child is Timer:  # Keep timers
			continue
		if child.is_in_group("attackable"):
			child.queue_free()
	
	# Start cache cleanup timers
	var path_timer = Timer.new()
	path_timer.wait_time = PATH_CACHE_TIME
	path_timer.timeout.connect(_cleanup_path_cache)
	add_child(path_timer)
	path_timer.start()
	
	var breakthrough_timer = Timer.new()
	breakthrough_timer.wait_time = BREAKTHROUGH_CACHE_TIME
	breakthrough_timer.timeout.connect(_cleanup_breakthrough_cache)
	add_child(breakthrough_timer)
	breakthrough_timer.start()
	
	# Initialize caches after cleanup
	call_deferred("_cache_existing_attackables")

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
	
	# Remove existing wall/tower if any
	if grid[pos.x][pos.y] == TILE_TYPE.WALL and walls.has(str(pos)):
		var wall = walls[str(pos)]
		_remove_from_spatial_cache(wall)
		wall.queue_free()
		walls.erase(str(pos))
	elif grid[pos.x][pos.y] == TILE_TYPE.TOWER and towers.has(str(pos)):
		var tower = towers[str(pos)]
		_remove_from_spatial_cache(tower)
		tower.queue_free()
		towers.erase(str(pos))
	
	grid[pos.x][pos.y] = type
	
	# Create wall instance if needed
	if type == TILE_TYPE.WALL:
		var wall = wall_scene.instantiate()
		var final_pos = grid_to_world(pos)
		wall.position = final_pos
		add_child(wall)
		walls[str(pos)] = wall
		_add_to_spatial_cache(wall)
	
	# Notify if obstacle state changed
	if (old_type == TILE_TYPE.WALL or old_type == TILE_TYPE.TOWER or 
		type == TILE_TYPE.WALL or type == TILE_TYPE.TOWER):
		# Invalidate flag access cache if change is near flag
		if pos.distance_to(flag_position) <= 2:
			_flag_access_cache.time = 0.0  # Invalidate cache
		obstacle_changed.emit(pos)
	
	queue_redraw()
	return true

# Add new function to place tower
func place_tower(pos: Vector2, tower_type: int) -> bool:
	print("\nGrid: Attempting to place tower...")
	print("Grid position: ", pos)
	
	if not is_valid_cell(pos):
		print("Grid: Failed - Invalid grid position")
		return false
		
	if grid[pos.x][pos.y] != TILE_TYPE.EMPTY:
		print("Grid: Failed - Cell not empty")
		return false
		
	var tower_scene = preload("res://scenes/Tower.tscn")
	if not tower_scene:
		push_error("Grid: Failed - Could not load tower scene!")
		return false
	
	print("Grid: Creating tower instance...")
	var tower = tower_scene.instantiate()
	if not tower:
		push_error("Grid: Failed - Could not instantiate tower!")
		return false
	
	var final_pos = grid_to_world(pos)
	print("Grid: Setting tower position to: ", final_pos)
	tower.position = final_pos
	
	print("Grid: Setting tower type to: ", tower_type)
	if not tower.has_method("set_type"):
		push_error("Grid: Failed - Tower does not have set_type method!")
		return false
	
	tower.set_type(tower_type)
	
	print("Grid: Adding tower to scene...")
	add_child(tower)
	
	print("Grid: Updating grid and registering tower...")
	grid[pos.x][pos.y] = TILE_TYPE.TOWER
	towers[str(pos)] = tower
	_add_to_spatial_cache(tower)
	
	if pos.distance_to(flag_position) <= 2:
		_flag_access_cache.time = 0.0
	obstacle_changed.emit(pos)
	tower_placed.emit(tower, pos)
	
	queue_redraw()
	print("Grid: Tower placed successfully")
	return true

func world_to_grid(world_pos: Vector2) -> Vector2:
	# Convert world position to grid coordinates with proper rounding
	var grid_x = int(round(world_pos.x / BASE_GRID_SIZE))
	var grid_y = int(round(world_pos.y / BASE_GRID_SIZE))
	
	return Vector2(
		clamp(grid_x, 0, GRID_WIDTH - 1),
		clamp(grid_y, 0, GRID_HEIGHT - 1)
	)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	# Convert grid coordinates to world position (center of cell)
	return Vector2(
		grid_pos.x * BASE_GRID_SIZE + BASE_GRID_SIZE/2,
		grid_pos.y * BASE_GRID_SIZE + BASE_GRID_SIZE/2
	)

# Add helper function near the top
func is_blocking_obstacle(cell_type: int) -> bool:
	return cell_type == TILE_TYPE.WALL or cell_type == TILE_TYPE.TOWER

# Modify get_neighbors to use the helper
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
			var cell_type = grid[neighbor.x][neighbor.y]
			if not is_blocking_obstacle(cell_type):
				# Add movement cost for diagonal
				var cost = 1.0 if dir.x == 0 or dir.y == 0 else 1.414
				neighbors.append({"pos": neighbor, "cost": cost})
	
	return neighbors

# Modify find_path_to_position to use the helper
func find_path_to_position(start: Vector2, end: Vector2) -> Array:
	# Simple direct path check instead of full pathfinding
	var cells = get_cells_in_line(start, end)
	
	# Check if direct path is clear
	for cell in cells:
		if not is_valid_cell(cell):
			return []
		if is_blocking_obstacle(get_cell_type(cell)):
			return []
	
	return cells

# Update find_path cache verification
func find_path(start: Vector2, end: Vector2) -> PathResult:
	# Check cache first
	var cache_key = _get_path_cache_key(start, end)
	if path_cache.has(cache_key):
		var cache_entry = path_cache[cache_key]
		if (Time.get_ticks_msec() / 1000.0) - cache_entry.time <= PATH_CACHE_TIME:
			# Only verify the next step, not multiple steps
			if not cache_entry.result.path.is_empty():
				if not is_blocking_obstacle(get_cell_type(cache_entry.result.path[0])):
					return cache_entry.result
			path_cache.erase(cache_key)
	
	# Calculate new path
	var result = _calculate_path(start, end)
	
	# Cache the result
	path_cache[cache_key] = {
		"result": result,
		"time": Time.get_ticks_msec() / 1000.0
	}
	
	return result

# Update is_flag_accessible to use the helper
func is_flag_accessible(from_pos: Vector2) -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check if cache is valid
	if current_time - _flag_access_cache.time <= FLAG_ACCESS_CACHE_TIME:
		return _flag_access_cache
	
	# Calculate new flag accessibility
	var path_result = _calculate_path(from_pos, flag_position)
	var blocking_walls = []
	
	if path_result.path.is_empty():
		# Flag is blocked, find all walls and towers around flag
		for offset in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var check_pos = flag_position + offset
			if is_valid_cell(check_pos):
				var cell_type = get_cell_type(check_pos)
				if is_blocking_obstacle(cell_type):
					blocking_walls.append(check_pos)
	
	_flag_access_cache = {
		"is_blocked": path_result.path.is_empty(),
		"blocking_walls": blocking_walls,
		"time": current_time
	}
	
	return _flag_access_cache

# A* pathfinding implementation
func _calculate_path(start: Vector2, end: Vector2) -> PathResult:
	# Check if we're trying to path to flag and it's blocked
	if end == flag_position:
		var flag_state = is_flag_accessible(start)
		if flag_state.is_blocked and not flag_state.blocking_walls.is_empty():
			# Return path to closest blocking obstacle
			var closest_obstacle = null
			var closest_dist = INF
			var best_path = []
			
			for obstacle_pos in flag_state.blocking_walls:
				var dist = start.distance_to(obstacle_pos)
				if dist < closest_dist:
					# Try to find path to adjacent position
					for adj_pos in get_adjacent_positions(obstacle_pos):
						if is_valid_cell(adj_pos) and not is_blocking_obstacle(get_cell_type(adj_pos)):
							var path = get_cells_in_line(start, adj_pos)
							if not path.is_empty():
								closest_obstacle = obstacle_pos
								closest_dist = dist
								best_path = path
								break
			
			if closest_obstacle != null:
				return PathResult.new(best_path, closest_obstacle, true)
	
	# Regular A* pathfinding
	var open_set = []
	var closed_set = {}
	var came_from = {}
	
	var g_score = {str(start): 0.0}
	var f_score = {str(start): heuristic(start, end)}
	
	open_set.append(start)
	var found_obstacle = null
	var obstacle_adjacent = null
	var best_obstacle_dist = INF
	
	while open_set.size() > 0:
		var current = get_lowest_f_score_node(open_set, f_score)
		if current == end:
			return PathResult.new(reconstruct_path(came_from, current))
		
		open_set.erase(current)
		closed_set[str(current)] = true
		
		# Check for obstacles during normal pathfinding
		for neighbor in get_adjacent_positions(current):
			if is_valid_cell(neighbor):
				var cell_type = get_cell_type(neighbor)
				if is_blocking_obstacle(cell_type):
					var dist = start.distance_to(neighbor)
					if dist < best_obstacle_dist:
						found_obstacle = neighbor
						best_obstacle_dist = dist
						# Find best adjacent position
						for adj in get_adjacent_positions(neighbor):
							if is_valid_cell(adj) and not closed_set.has(str(adj)):
								if not is_blocking_obstacle(get_cell_type(adj)):
									obstacle_adjacent = adj
									break
		
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
	
	# If we found an obstacle during pathfinding, use it
	if found_obstacle != null and obstacle_adjacent != null:
		var path_to_obstacle = get_cells_in_line(start, obstacle_adjacent)
		if not path_to_obstacle.is_empty():
			return PathResult.new(path_to_obstacle, found_obstacle, true)
	
	return PathResult.new([])

func find_wall_breakthrough_path(start: Vector2, end: Vector2, explored_cells: Dictionary) -> PathResult:
	# Check cache first
	var cache_key = "%d,%d-%d,%d" % [start.x, start.y, end.x, end.y]
	if _breakthrough_cache.has(cache_key):
		var cache_entry = _breakthrough_cache[cache_key]
		if (Time.get_ticks_msec() / 1000.0) - cache_entry.time <= BREAKTHROUGH_CACHE_TIME:
			return cache_entry.result
	
	# Get direct line to target first
	var direct_cells = get_cells_in_line(start, end)
	var first_obstacle_pos = null
	
	# Find first wall/tower in direct path
	for cell in direct_cells:
		if not is_valid_cell(cell):
			continue
		var cell_type = get_cell_type(cell)
		if is_blocking_obstacle(cell_type):
			first_obstacle_pos = cell
			break
	
	# If we found an obstacle in direct path, find closest clear position
	if first_obstacle_pos != null:
		var adjacent_positions = get_adjacent_positions(first_obstacle_pos)
		var best_pos = null
		var best_dist = INF
		
		for adj_pos in adjacent_positions:
			if is_valid_cell(adj_pos) and not is_blocking_obstacle(get_cell_type(adj_pos)):
				var dist = start.distance_to(adj_pos)
				if dist < best_dist:
					best_dist = dist
					best_pos = adj_pos
		
		if best_pos != null:
			var path = get_cells_in_line(start, best_pos)
			if not path.is_empty():
				var result = PathResult.new(path, first_obstacle_pos, true)
				_breakthrough_cache[cache_key] = {
					"result": result,
					"time": Time.get_ticks_msec() / 1000.0
				}
				return result
	
	return PathResult.new([])

# Helper function to get cells in a line
func get_cells_in_line(start: Vector2, end: Vector2) -> Array:
	var cells = []
	var dx = abs(end.x - start.x)
	var dy = abs(end.y - start.y)
	var x = int(start.x)
	var y = int(start.y)
	var n = 1 + dx + dy
	var x_inc = 1 if end.x > start.x else -1
	var y_inc = 1 if end.y > start.y else -1
	var error = dx - dy
	dx *= 2
	dy *= 2
	
	for _i in range(n):
		cells.append(Vector2(x, y))
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx
	
	return cells

func get_adjacent_positions(pos: Vector2) -> Array:
	return [
		pos + Vector2(1, 0),
		pos + Vector2(-1, 0),
		pos + Vector2(0, 1),
		pos + Vector2(0, -1)
	]

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

func _initialize_spatial_grid():
	spatial_grid.clear()
	# Pre-allocate grid cells
	var cells_x = ceil(GRID_WIDTH * BASE_GRID_SIZE / float(SPATIAL_CELL_SIZE))
	var cells_y = ceil(GRID_HEIGHT * BASE_GRID_SIZE / float(SPATIAL_CELL_SIZE))
	for x in range(cells_x):
		for y in range(cells_y):
			spatial_grid["%d,%d" % [x, y]] = []

func _get_spatial_key(pos: Vector2) -> String:
	var cell_x = floor(pos.x / SPATIAL_CELL_SIZE)
	var cell_y = floor(pos.y / SPATIAL_CELL_SIZE)
	return "%d,%d" % [cell_x, cell_y]

func _cache_existing_attackables():
	for obj in get_tree().get_nodes_in_group("attackable"):
		if obj is Node2D and obj.get_parent() == self:  # Only cache objects that are children of grid
			_add_to_spatial_cache(obj)

func _add_to_spatial_cache(obj: Node2D):
	var key = _get_spatial_key(obj.position)
	if not spatial_grid.has(key):
		spatial_grid[key] = []
	spatial_grid[key].append(obj)
	attackable_objects[obj.get_instance_id()] = obj
	attackable_added.emit(obj, obj.position)

func _remove_from_spatial_cache(obj: Node2D):
	var key = _get_spatial_key(obj.position)
	if spatial_grid.has(key):
		spatial_grid[key].erase(obj)
	attackable_objects.erase(obj.get_instance_id())
	attackable_removed.emit(obj, obj.position)

# Get attackable objects within range of a position
func get_attackables_in_range(pos: Vector2, range: float) -> Array:
	var result = []
	var center_key = _get_spatial_key(pos)
	var cells_to_check = 1 + int(range / SPATIAL_CELL_SIZE)
	
	# Get cell coordinates
	var cell_x = floor(pos.x / SPATIAL_CELL_SIZE)
	var cell_y = floor(pos.y / SPATIAL_CELL_SIZE)
	
	# Cache nearby results for 0.5 seconds
	var cache_key = "%d,%d-%d" % [cell_x, cell_y, int(range)]
	if _range_cache.has(cache_key):
		var cache = _range_cache[cache_key]
		if Time.get_ticks_msec() - cache.time < 500:  # 0.5 second cache
			return cache.results.filter(func(obj): return is_instance_valid(obj))
	
	# Use squared distance for faster checks
	var range_squared = range * range
	
	# Check cells in range
	for x in range(cell_x - cells_to_check, cell_x + cells_to_check + 1):
		for y in range(cell_y - cells_to_check, cell_y + cells_to_check + 1):
			var key = "%d,%d" % [x, y]
			if spatial_grid.has(key):
				for obj in spatial_grid[key]:
					if is_instance_valid(obj):
						var dx = obj.position.x - pos.x
						var dy = obj.position.y - pos.y
						if dx * dx + dy * dy <= range_squared:
							result.append(obj)
	
	# Cache results
	_range_cache[cache_key] = {
		"time": Time.get_ticks_msec(),
		"results": result.duplicate()
	}
	
	return result

func _cleanup_path_cache():
	var current_time = Time.get_ticks_msec() / 1000.0
	var keys_to_remove = []
	
	for key in path_cache:
		if current_time - path_cache[key].time > PATH_CACHE_TIME:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		path_cache.erase(key)

func _get_path_cache_key(start: Vector2, end: Vector2) -> String:
	# Faster hash-based key
	return str(int(start.x + start.y * GRID_WIDTH) + int(end.x + end.y * GRID_WIDTH) * GRID_WIDTH * GRID_HEIGHT)

func _cleanup_breakthrough_cache():
	var current_time = Time.get_ticks_msec() / 1000.0
	var keys_to_remove = []
	
	for key in _breakthrough_cache:
		if current_time - _breakthrough_cache[key].time > BREAKTHROUGH_CACHE_TIME:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_breakthrough_cache.erase(key)

# Remove _physics_process cache cleanup
func _physics_process(_delta):
	pass

# Add helper function to get any blocking object at position
func get_blocking_object_at(pos: Vector2) -> Node2D:
	var pos_str = str(pos)
	if walls.has(pos_str):
		return walls[pos_str]
	if towers.has(pos_str):
		return towers[pos_str]
	return null

# Add new function to register tower
func register_tower(tower: Node2D) -> void:
	var pos = world_to_grid(tower.position)
	if is_valid_cell(pos):
		grid[pos.x][pos.y] = TILE_TYPE.TOWER
		towers[str(pos)] = tower
		_add_to_spatial_cache(tower)
		tower_placed.emit(tower, pos)
		# Invalidate flag access cache if near flag
		if pos.distance_to(flag_position) <= 2:
			_flag_access_cache.time = 0.0
