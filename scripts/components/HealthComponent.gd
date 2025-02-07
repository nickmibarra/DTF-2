class_name HealthComponent
extends EntityComponent

signal health_changed(current: float, maximum: float)
signal damage_taken(amount: float, source: Node)
signal healed(amount: float)
signal died()

@export var max_health: float = 100.0
@export var armor: float = 0.0
@export var is_invulnerable: bool = false

var current_health: float = -1  # Initialize to invalid value to detect initialization issues
var _initialized: bool = false

func _ready() -> void:
	print("HealthComponent _ready called on: ", get_path())
	add_to_group("health_components")  # Add to group for easier tracking
	super._ready()
	print("HealthComponent _ready completed on: ", get_path())

func _initialize() -> void:
	print("HealthComponent _initialize called on: ", get_path())
	if not _initialized:  # Only initialize once
		current_health = max_health
		_initialized = true
		print("Health initialized to: ", current_health, " on: ", get_path())
		# Emit signal immediately since we're already in _initialize
		emit_signal("health_changed", current_health, max_health)
	print("HealthComponent _initialize completed with health: ", current_health, " on: ", get_path())

func take_damage(amount: float, source: Node = null) -> float:
	if not _initialized:
		push_error("HealthComponent not properly initialized!")
		return 0.0
		
	if is_invulnerable:
		return 0.0
	
	var actual_damage = amount * (1.0 - armor)
	current_health = max(0.0, current_health - actual_damage)
	
	emit_signal("damage_taken", actual_damage, source)
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		emit_signal("died")
	
	return actual_damage

func heal(amount: float) -> float:
	if not _initialized:
		push_error("HealthComponent not properly initialized!")
		return 0.0
		
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	
	var healed_amount = current_health - old_health
	if healed_amount > 0:
		emit_signal("healed", healed_amount)
		emit_signal("health_changed", current_health, max_health)
	
	return healed_amount

func get_health_percent() -> float:
	return current_health / max_health if _initialized else 0.0

func is_alive() -> bool:
	return _initialized and current_health > 0 