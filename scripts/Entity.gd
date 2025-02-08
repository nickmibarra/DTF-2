class_name Entity
extends Node2D

# Component references
var health_component: HealthComponent
var movement_component: MovementComponent
var combat_component: CombatComponent
var status_component: StatusEffectComponent

# Manager references
var visual_manager: VisualManager
var state_manager: StateManager

# Configuration for this entity
@export var use_health: bool = true
@export var use_movement: bool = true
@export var use_combat: bool = true
@export var use_status: bool = true

var _initialized: bool = false

func _ready() -> void:
	print("Entity _ready called for: ", name)
	_initialize_components()

func _initialize_components() -> void:
	# Get existing components first
	health_component = get_node_or_null("HealthComponent")
	movement_component = get_node_or_null("MovementComponent")
	combat_component = get_node_or_null("CombatComponent")
	status_component = get_node_or_null("StatusEffectComponent")
	visual_manager = get_node_or_null("VisualManager")
	state_manager = get_node_or_null("StateManager")
	
	# Only add components if they don't exist and are enabled
	if use_health and not health_component:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		add_child(health_component)
		print("Health component added to ", name)
	
	if use_movement and not movement_component:
		movement_component = MovementComponent.new()
		movement_component.name = "MovementComponent"
		add_child(movement_component)
		print("Movement component added to ", name)
	
	if use_combat and not combat_component:
		combat_component = CombatComponent.new()
		combat_component.name = "CombatComponent"
		add_child(combat_component)
		print("Combat component added to ", name)
	
	if use_status and not status_component:
		status_component = StatusEffectComponent.new()
		status_component.name = "StatusEffectComponent"
		add_child(status_component)
		print("Status component added to ", name)
	
	if not visual_manager:
		visual_manager = VisualManager.new()
		visual_manager.name = "VisualManager"
		add_child(visual_manager)
		print("Visual manager added to ", name)
	
	if not state_manager:
		state_manager = StateManager.new()
		state_manager.name = "StateManager"
		add_child(state_manager)
		print("State manager added to ", name)
	
	# Wait for components to initialize
	await get_tree().process_frame
	
	# Connect component signals
	_connect_component_signals()
	
	# Setup complete
	_initialized = true
	_on_setup_complete()

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
		
	if movement_component:
		movement_component.process(delta)
	
	if combat_component:
		combat_component.process(delta)
	
	if status_component:
		status_component.process(delta)

func _connect_component_signals() -> void:
	print("Entity: Connecting component signals for ", name)
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)
		print("Entity: Health signals connected")
	
	if movement_component:
		movement_component.position_changed.connect(_on_position_changed)
		movement_component.path_completed.connect(_on_path_completed)
		print("Entity: Movement signals connected")
	
	if combat_component:
		combat_component.attack_started.connect(_on_attack_started)
		combat_component.attack_completed.connect(_on_attack_completed)
		print("Entity: Combat signals connected")
	
	if status_component:
		status_component.effect_applied.connect(_on_effect_applied)
		status_component.effect_removed.connect(_on_effect_removed)
		print("Entity: Status signals connected")

# Virtual methods for derived classes
func _on_setup_complete() -> void:
	pass

func _on_health_changed(current: float, maximum: float) -> void:
	if visual_manager:
		visual_manager.update_health_display(current, maximum)

func _on_died() -> void:
	if visual_manager:
		visual_manager.play_death_effect()
	if state_manager:
		state_manager.transition_to("dead")

func _on_position_changed(new_position: Vector2) -> void:
	if visual_manager:
		visual_manager.update_position(new_position)

func _on_path_completed() -> void:
	if state_manager:
		state_manager.handle_event("path_completed")

func _on_attack_started(target: Node2D) -> void:
	print("Entity: Attack started on ", target.name)
	if visual_manager:
		visual_manager.play_attack_animation()
	if state_manager:
		print("Entity: Transitioning to attacking state")
		state_manager.transition_to("attacking")  # Direct transition to attacking state

func _on_attack_completed(target: Node2D) -> void:
	print("Entity: Attack completed on ", target.name)
	if state_manager:
		print("Entity: Handling attack_completed event")
		state_manager.handle_event("attack_completed")  # Use event to return to idle

func _on_effect_applied(effect_name: String, duration: float) -> void:
	if visual_manager:
		visual_manager.play_effect(effect_name)

func _on_effect_removed(effect_name: String) -> void:
	if visual_manager:
		visual_manager.stop_effect(effect_name) 