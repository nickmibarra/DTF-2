extends Entity

signal flag_destroyed

@onready var attackable = $Attackable
@onready var health_bar = $HealthBarBG/HealthBar  # Updated path since HealthBar is now child of HealthBarBG
@onready var health_bar_bg = $HealthBarBG

func _ready():
	super._ready()
	add_to_group("flags")
	
	# Initialize appearance first
	var flag_shape = $FlagShape
	if not flag_shape:
		flag_shape = ColorRect.new()
		flag_shape.name = "FlagShape"
		flag_shape.size = Vector2(48, 48)  # 75% of grid size
		flag_shape.position = -flag_shape.size / 2  # Center the shape
		flag_shape.color = Color(0.8, 0.2, 0.2)  # Red color
		add_child(flag_shape)
	
	# Make sure we process even when paused
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Initialize attackable component
	if not attackable:
		push_error("Flag: Attackable component not found!")
		return
		
	attackable.initialize(100.0)  # 100 base health
	attackable.health_changed.connect(_on_health_changed)
	attackable.destroyed.connect(_on_flag_destroyed)
	attackable.damage_taken.connect(_on_damage_taken)
	
	# Initialize health bar
	if health_bar and health_bar_bg:
		# Ensure health bars are visible
		health_bar.show()
		health_bar_bg.show()
		# Force initial health bar update
		_on_health_changed(attackable.current_health, attackable.max_health)
	else:
		push_error("Flag: Health bar nodes not found! HealthBar: ", health_bar != null, " BG: ", health_bar_bg != null)

func _on_health_changed(current: float, maximum: float):
	if not health_bar:
		push_error("Flag: Cannot update health bar - node not found!")
		return
		
	# Update health bar size
	var new_width = (current / maximum) * health_bar_bg.size.x  # Use background width as reference
	health_bar.size.x = new_width
	
	# Update color based on health percentage
	var health_percent = current / maximum
	if health_percent > 0.6:
		health_bar.color = Color.GREEN
	elif health_percent > 0.3:
		health_bar.color = Color(1, 1, 0)  # Yellow
	else:
		health_bar.color = Color(1, 0, 0)  # Red

func _on_damage_taken(amount: float, _source: Node = null):
	pass  # Remove logging

func _on_flag_destroyed(_pos: Vector2):
	# Visual feedback before game over
	modulate = Color(1, 0, 0)  # Turn bright red
	flag_destroyed.emit()

# Forward take_damage to attackable component - same pattern as Wall
func take_damage(amount: float):
	if attackable:
		attackable.take_damage(amount)
	else:
		push_error("Flag: Cannot take damage, no Attackable component!")

func get_health_percentage() -> float:
	if not attackable:
		return 0.0
	return attackable.current_health / attackable.max_health
