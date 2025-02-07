class_name CombatComponent
extends EntityComponent

signal attack_started(target: Node2D)
signal attack_completed(target: Node2D)
signal attack_failed(target: Node2D, reason: String)

@export var damage: float = 10.0
@export var attack_range: float = 100.0
@export var attack_speed: float = 1.0  # Attacks per second
@export var can_attack: bool = true

var current_target: Node2D = null
var attack_timer: float = 0.0
var _attack_cooldown: float:
	get:
		return 1.0 / attack_speed if attack_speed > 0 else INF

func _initialize() -> void:
	assert(entity != null, "CombatComponent requires a Node2D parent")
	attack_timer = _attack_cooldown  # Start ready to attack

func process(delta: float) -> void:
	if not can_attack or not current_target:
		return
	
	attack_timer += delta
	if attack_timer >= _attack_cooldown:
		if can_attack_target(current_target):
			perform_attack()
		else:
			emit_signal("attack_failed", current_target, "Target out of range")
			current_target = null

func set_target(new_target: Node2D) -> void:
	if new_target == current_target:
		return
	
	if not can_attack_target(new_target):
		emit_signal("attack_failed", new_target, "Target invalid or out of range")
		current_target = null  # Clear current target on failure
		return
	
	current_target = new_target

func can_attack_target(target: Node2D) -> bool:
	if not can_attack:
		print("Cannot attack: can_attack is false")
		return false
	
	if not is_instance_valid(target):
		print("Cannot attack: target is not valid")
		return false
	
	# Get health component and verify it's properly initialized
	var health = target.get_node_or_null("HealthComponent")
	if not health:
		print("Cannot attack: target has no HealthComponent")
		return false
	
	if not health is HealthComponent:
		print("Cannot attack: target's HealthComponent is wrong type")
		return false
	
	if not health._initialized:
		print("Cannot attack: target's HealthComponent not initialized")
		return false
	
	if not health.is_alive():
		print("Cannot attack: target is not alive")
		return false
	
	var distance = entity.position.distance_to(target.position)
	if distance > attack_range:
		print("Cannot attack: target out of range (distance: ", distance, ", range: ", attack_range, ")")
		return false
	
	return true

func perform_attack() -> void:
	if not current_target or not can_attack_target(current_target):
		return
	
	emit_signal("attack_started", current_target)
	
	var target_health = current_target.get_node("HealthComponent")
	if target_health and target_health.has_method("take_damage"):
		target_health.take_damage(damage, entity)
	
	attack_timer = 0.0  # Reset attack timer
	emit_signal("attack_completed", current_target)

func stop_attacking() -> void:
	current_target = null
	attack_timer = _attack_cooldown  # Ready for next attack

func is_attacking() -> bool:
	return current_target != null

func get_attack_progress() -> float:
	return attack_timer / _attack_cooldown 