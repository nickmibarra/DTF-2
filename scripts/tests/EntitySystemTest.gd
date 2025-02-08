extends Node2D

var test_entity: Entity
var target_entity: Entity

# Track signals for verification
var signals_received = {
	"health_changed": 0,
	"position_changed": 0,
	"attack_completed": 0,
	"effect_applied": 0,
	"state_changed": 0
}

func _ready():
	print("\nStarting Entity System Test")
	run_tests()

func setup():
	print("\nSetting up test...")
	# Reset signal counters
	for key in signals_received:
		signals_received[key] = 0
	
	# Create main test entity
	test_entity = Entity.new()
	test_entity.name = "TestEntity"
	add_child(test_entity)
	print("Created test entity")
	
	# Create target entity (for combat tests)
	target_entity = Entity.new()
	target_entity.name = "TargetEntity"
	target_entity.position = Vector2(50, 0)  # Moved closer to be within attack range
	add_child(target_entity)
	print("Created target entity")
	
	# Wait for initialization
	await get_tree().process_frame
	print("First frame processed")
	await get_tree().process_frame  # Extra frame for good measure
	print("Second frame processed")
	
	# Ensure both entities have initialized components
	print("\nVerifying entity initialization:")
	print("Test entity components:")
	print("- Health: ", test_entity.health_component, " initialized: ", test_entity.health_component._initialized if test_entity.health_component else "N/A")
	print("- Combat: ", test_entity.combat_component)
	print("- State: ", test_entity.state_manager.get_current_state() if test_entity.state_manager else "N/A")
	
	print("\nTarget entity components:")
	print("- Health: ", target_entity.health_component, " initialized: ", target_entity.health_component._initialized if target_entity.health_component else "N/A")
	print("- Position: ", target_entity.position)
	
	# Wait for another frame to ensure all components are fully initialized
	await get_tree().process_frame
	
	# Verify health components are ready
	if test_entity.health_component and not test_entity.health_component._initialized:
		print("Waiting for test entity health initialization...")
		await get_tree().process_frame
	
	if target_entity.health_component and not target_entity.health_component._initialized:
		print("Waiting for target entity health initialization...")
		await get_tree().process_frame
	
	# Final verification
	print("\nFinal component state:")
	print("Test entity health initialized: ", test_entity.health_component._initialized if test_entity.health_component else "N/A")
	print("Target entity health initialized: ", target_entity.health_component._initialized if target_entity.health_component else "N/A")
	
	# Connect signals
	_connect_signals()
	print("Signals connected")
	print("Setup complete")

func _connect_signals():
	if test_entity.health_component:
		test_entity.health_component.health_changed.connect(
			func(current, max_health): 
				print("Health changed: ", current, "/", max_health)
				signals_received["health_changed"] += 1
		)
	
	if test_entity.movement_component:
		test_entity.movement_component.position_changed.connect(
			func(pos): 
				print("Position changed: ", pos)
				signals_received["position_changed"] += 1
		)
	
	if test_entity.combat_component:
		# Connect all combat signals
		test_entity.combat_component.attack_started.connect(
			func(target): 
				print("Attack started on: ", target.name)
		)
		test_entity.combat_component.attack_completed.connect(
			func(target): 
				print("Attack completed on: ", target.name)
				signals_received["attack_completed"] += 1
		)
		test_entity.combat_component.attack_failed.connect(
			func(target, reason): 
				print("Attack failed on: ", target.name, " - Reason: ", reason)
		)
	
	if test_entity.status_component:
		test_entity.status_component.effect_applied.connect(
			func(name, duration): 
				print("Effect applied: ", name, " for ", duration, " seconds")
				signals_received["effect_applied"] += 1
		)
	
	if test_entity.state_manager:
		test_entity.state_manager.state_changed.connect(
			func(from, to): 
				print("State changed: ", from, " -> ", to)
				signals_received["state_changed"] += 1
		)

func teardown():
	test_entity.queue_free()
	target_entity.queue_free()
	test_entity = null
	target_entity = null
	await get_tree().process_frame

func run_tests():
	print("\nStarting test sequence...")
	await test_initialization()
	await test_health_system()
	await test_movement_system()
	await test_status_system()
	await test_state_system()
	await test_combat_system()  # Run combat test last
	print("\nEntity System Tests Complete")
	get_tree().quit()

func test_initialization():
	print("\nTesting Initialization")
	await setup()
	
	# Verify components exist and print details
	print("\nVerifying components:")
	var health = test_entity.health_component
	print("Health component - exists: ", health != null)
	if health:
		print("Current health: ", health.current_health, "/", health.max_health)
	
	var movement = test_entity.movement_component
	print("Movement component - exists: ", movement != null)
	if movement:
		print("Movement speed: ", movement.movement_speed)
	
	var combat = test_entity.combat_component
	print("Combat component - exists: ", combat != null)
	if combat:
		print("Attack range: ", combat.attack_range)
	
	var status = test_entity.status_component
	print("Status component - exists: ", status != null)
	if status:
		print("Active effects: ", status.active_effects)
	
	# Verify managers
	print("\nVerifying managers:")
	print("Visual manager - exists: ", test_entity.visual_manager != null)
	print("State manager - exists: ", test_entity.state_manager != null)
	if test_entity.state_manager:
		print("Current state: ", test_entity.state_manager.get_current_state())
	
	# Run assertions
	assert(health != null, "Health component should exist")
	assert(movement != null, "Movement component should exist")
	assert(combat != null, "Combat component should exist")
	assert(status != null, "Status component should exist")
	assert(test_entity.visual_manager != null, "Visual manager should exist")
	assert(test_entity.state_manager != null, "State manager should exist")
	assert(test_entity.state_manager.get_current_state() == "idle", "Should start in idle state")
	
	await teardown()

func test_health_system():
	print("\nTesting Health System")
	await setup()
	
	var health = test_entity.health_component
	assert(health.current_health == health.max_health, "Should start at max health")
	
	# Test damage
	health.take_damage(20.0)
	assert(health.current_health == health.max_health - 20.0, "Health should decrease")
	assert(signals_received["health_changed"] > 0, "Should emit health_changed signal")
	
	await teardown()

func test_movement_system():
	print("\nTesting Movement System")
	await setup()
	
	var movement = test_entity.movement_component
	var target_pos = Vector2(50, 0)
	
	print("Initial state: ", test_entity.state_manager.get_current_state())
	
	# Test movement
	movement.move_to(target_pos)
	print("Called move_to with target: ", target_pos)
	
	# Process a few frames to allow state change
	for i in range(3):
		movement.process(0.1)  # Process some movement
		await get_tree().process_frame
		print("Processed frame ", i + 1, ", Current state: ", test_entity.state_manager.get_current_state())
	
	print("Final state: ", test_entity.state_manager.get_current_state())
	assert(signals_received["position_changed"] > 0, "Should emit position_changed signal")
	assert(test_entity.state_manager.get_current_state() == "moving", "Should be in moving state")
	
	await teardown()

func test_combat_system():
	print("\nTesting Combat System")
	await setup()
	
	var combat = test_entity.combat_component
	print("\nCombat test setup:")
	print("Combat component exists: ", combat != null)
	print("Combat component attack range: ", combat.attack_range)
	print("Attack cooldown: ", combat._attack_cooldown)
	
	# Verify target entity setup
	print("\nTarget entity setup:")
	print("Target entity exists: ", target_entity != null)
	print("Target position: ", target_entity.position)
	print("Distance to target: ", test_entity.position.distance_to(target_entity.position))
	print("Target health component: ", target_entity.health_component)
	if target_entity.health_component:
		print("Target health: ", target_entity.health_component.current_health, "/", target_entity.health_component.max_health)
		print("Target health initialized: ", target_entity.health_component._initialized)
		print("Target health node path: ", target_entity.health_component.get_path())
	
	# Wait an extra frame to ensure all components are ready
	await get_tree().process_frame
	
	print("\nStarting combat test:")
	print("Initial state: ", test_entity.state_manager.get_current_state())
	
	# Reset attack timer to ensure we can attack immediately
	combat.attack_timer = combat._attack_cooldown
	print("Attack timer reset to: ", combat.attack_timer)
	
	# Test attack
	print("\nAttempting to set target...")
	combat.set_target(target_entity)
	print("Target set, checking attack conditions:")
	print("- Can attack: ", combat.can_attack_target(target_entity))
	print("- Current target: ", combat.current_target.name if combat.current_target else "None")
	print("- Attack timer: ", combat.attack_timer)
	
	# Process one frame to let state changes propagate
	await get_tree().process_frame
	print("\nAfter target set:")
	print("- Current state: ", test_entity.state_manager.get_current_state())
	
	# Process combat
	print("\nProcessing combat...")
	combat.process(0.1)  # Process a small amount to start attack
	await get_tree().process_frame
	print("After first process:")
	print("- Attack timer: ", combat.attack_timer)
	print("- Current state: ", test_entity.state_manager.get_current_state())
	
	# Process multiple frames to ensure attack completes
	for i in range(5):  # Increased to 5 frames
		print("\nProcessing frame ", i + 1)
		combat.process(0.3)  # Process in smaller chunks
		await get_tree().process_frame
		print("- Attack timer: ", combat.attack_timer, "/", combat._attack_cooldown)
		print("- Current target: ", combat.current_target.name if combat.current_target else "None")
		print("- Current state: ", test_entity.state_manager.get_current_state())
		print("- Can attack: ", combat.can_attack_target(target_entity) if target_entity else false)
		print("- Target health: ", target_entity.health_component.current_health if target_entity.health_component else "N/A")
		print("- Attack signals: ", signals_received["attack_completed"])
		
		# Break if we've completed the attack
		if signals_received["attack_completed"] > 0:
			print("Attack completed, breaking loop")
			break
	
	print("\nFinal test state:")
	print("Attack signals received: ", signals_received["attack_completed"])
	print("Current state: ", test_entity.state_manager.get_current_state())
	print("Target health: ", target_entity.health_component.current_health if target_entity.health_component else "N/A")
	
	# Wait one more frame for state changes to complete
	await get_tree().process_frame
	
	# Verify attack was successful
	assert(signals_received["attack_completed"] > 0, "Should emit attack_completed signal")
	assert(target_entity.health_component.current_health < target_entity.health_component.max_health, "Target should have taken damage")
	assert(test_entity.state_manager.get_current_state() == "idle", "Should return to idle state after attack")
	
	await teardown()

func test_status_system():
	print("\nTesting Status System")
	await setup()
	
	var status = test_entity.status_component
	
	# Test effect application
	status.apply_effect("speed_boost", 5.0, {"speed": 0.5})
	
	assert(signals_received["effect_applied"] > 0, "Should emit effect_applied signal")
	assert(status.get_speed_modifier() > 1.0, "Speed modifier should be increased")
	
	await teardown()

func test_state_system():
	print("\nTesting State System")
	await setup()
	
	var state = test_entity.state_manager
	
	# Test state transition
	state.transition_to("moving")
	
	assert(signals_received["state_changed"] > 0, "Should emit state_changed signal")
	assert(state.get_current_state() == "moving", "Should transition to moving state")
	assert(state.get_previous_state() == "idle", "Previous state should be idle")
	
	await teardown() 
