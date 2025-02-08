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
	print("CombatComponent initialized for: ", entity.name)

func process(delta: float) -> void:
	if not can_attack or not current_target:
		return
	
	attack_timer += delta
	print("Attack timer: ", attack_timer, " / ", _attack_cooldown)
	
	if attack_timer >= _attack_cooldown:
		print("Attack cooldown complete, checking target...")
		if can_attack_target(current_target):
			print("Target valid, performing attack")
			perform_attack()
			# Ensure we're in attacking state
			if entity and entity.state_manager:
				var current_state = entity.state_manager.get_current_state()
				if current_state != "attacking":
					print("Forcing state to attacking")
					entity.state_manager.transition_to("attacking")
		else:
			print("Attack failed - target invalid after cooldown")
			emit_signal("attack_failed", current_target, "Target invalid or out of range")
			current_target = null

func set_target(new_target: Node2D) -> void:
	print("Setting target: ", new_target.name if new_target else "None")
	if new_target == current_target:
		print("Target already set")
		return
	
	if not can_attack_target(new_target):
		print("Cannot attack target, emitting failure")
		emit_signal("attack_failed", new_target, "Target invalid or out of range")
		current_target = null  # Clear current target on failure
		return
	
	print("Target set successfully")
	current_target = new_target
	# Ensure we're ready to attack
	attack_timer = _attack_cooldown
	
	# Transition to attacking state only on initial target set
	if entity and entity.state_manager:
		print("Transitioning to attack state on target set")
		entity.state_manager.handle_event("attack")  # Use event instead of direct state

func can_attack_target(target: Node2D) -> bool:
	if not can_attack:
		print("Cannot attack: can_attack is false")
		return false
	
	if not is_instance_valid(target):
		print("Cannot attack: target is not valid")
		return false
	
	# Get health component and verify it's properly initialized
	var health = target.get_node_or_null("HealthComponent")
	print("Target health component search result: ", health)
	print("Target node path: ", target.get_path())
	print("Target children: ", target.get_children())
	
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
	
	print("Can attack target - all checks passed")
	return true

func perform_attack() -> void:
	print("\nPerforming attack...")
	if not current_target or not can_attack_target(current_target):
		print("Attack failed - target invalid or out of range")
		return
		
	# Add cooldown check
	if attack_timer < _attack_cooldown:
		print("Attack on cooldown - waiting ", _attack_cooldown - attack_timer, " seconds")
		return
		
	print("Starting attack on target: ", current_target.name)
	emit_signal("attack_started", current_target)
	
	# Wait a frame to ensure state changes propagate
	await entity.get_tree().process_frame
	
	var target_health = current_target.get_node("HealthComponent")
	if target_health and target_health.has_method("take_damage"):
		print("Dealing ", damage, " damage to target")
		target_health.take_damage(damage, entity)
		
		attack_timer = 0.0  # Reset attack timer
		print("Attack completed, emitting signal")
		emit_signal("attack_completed", current_target)
		
		# Don't force state changes after attack completion
		# Let the state manager handle it through events
	else:
		print("Failed to deal damage - no valid health component")
		current_target = null  # Clear invalid target

func stop_attacking() -> void:
	current_target = null
	attack_timer = _attack_cooldown  # Ready for next attack

func is_attacking() -> bool:
	return current_target != null

func get_attack_progress() -> float:
	return attack_timer / _attack_cooldown 