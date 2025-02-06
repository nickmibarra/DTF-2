extends Node2D

@onready var sprite = $Sprite2D
@onready var health_bar = $HealthBar
@onready var attackable = $Attackable

func _ready():
	add_to_group("walls")
	
	# Initialize attackable component
	if not attackable:
		push_error("Wall: Attackable component not found!")
		return
		
	attackable.initialize(5000.0)  # 100 health, no armor
	attackable.health_changed.connect(_on_health_changed)
	attackable.destroyed.connect(_on_wall_destroyed)

func _on_health_changed(current: float, maximum: float):
	if not health_bar:
		return
		
	health_bar.size.x = (current / maximum) * 32
	
	# Update color based on health percentage
	var health_percent = current / maximum
	if health_percent > 0.6:
		health_bar.color = Color(0, 0.8, 0, 1)  # Green
	elif health_percent > 0.3:
		health_bar.color = Color(0.8, 0.8, 0, 1)  # Yellow
	else:
		health_bar.color = Color(0.8, 0, 0, 1)  # Red

func _on_wall_destroyed(pos: Vector2):
	# Tell the grid to remove this wall
	var grid = get_parent()
	if grid and grid.has_method("world_to_grid"):
		var grid_pos = grid.world_to_grid(position)
		grid.set_cell_type(grid_pos, grid.TILE_TYPE.EMPTY)

# Forward take_damage to attackable component
func take_damage(amount: float):
	if attackable:
		attackable.take_damage(amount)
	else:
		push_error("Wall: Cannot take damage, no Attackable component!")
