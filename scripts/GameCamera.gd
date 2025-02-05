extends Camera2D

var min_zoom := 0.5
var max_zoom := 2.0
var zoom_speed := 0.1
var zoom_factor := 1.0

var is_panning := false
var last_mouse_pos := Vector2.ZERO

func _ready():
	# Calculate initial zoom to fit grid in viewport
	var viewport_size = get_viewport_rect().size
	var grid_size = Vector2(40 * 64, 22 * 64)  # GRID_WIDTH * BASE_GRID_SIZE
	
	# Calculate zoom to fit grid with margins
	var zoom_x = (viewport_size.x * 0.95) / grid_size.x
	var zoom_y = (viewport_size.y * 0.85) / grid_size.y
	zoom_factor = min(zoom_x, zoom_y)
	zoom = Vector2.ONE * zoom_factor
	
	# Center the camera on the grid
	position = grid_size / 2

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			# Middle mouse button for panning
			is_panning = event.pressed
			last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			zoom_factor = clamp(zoom_factor + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2.ONE * zoom_factor
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			zoom_factor = clamp(zoom_factor - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2.ONE * zoom_factor
	
	elif event is InputEventMouseMotion and is_panning:
		position -= event.relative / zoom_factor

# Remove all custom coordinate transformation functions
# Let Godot handle coordinate transformations natively 
