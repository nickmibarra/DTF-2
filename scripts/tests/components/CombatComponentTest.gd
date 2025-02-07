extends Node

var attacker: Node2D
var target: Node2D
var combat_component: CombatComponent

var signals_received = {
	"attack_started": 0,
	"attack_completed": 0,
	"attack_failed": 0
}

func _ready():
	run_tests()

func setup():
	print("\nSetup starting...")
	# Reset signal counters
	for key in signals_received:
		signals_received[key] = 0
	
	# Create attacker entity and component
	attacker = Node2D.new()
	attacker.name = "Attacker"
	add_child(attacker)
	attacker.position = Vector2.ZERO
	print("Attacker created at: ", attacker.position)
	
	combat_component = CombatComponent.new()
	combat_component.name = "CombatComponent"
	attacker.add_child(combat_component)
	print("Combat component added to attacker")
	
	# Connect signals
	combat_component.attack_started.connect(func(t): signals_received["attack_started"] += 1)
	combat_component.attack_completed.connect(func(t): signals_received["attack_completed"] += 1)
	combat_component.attack_failed.connect(func(t, r): 
		print("Attack failed: ", r)
		signals_received["attack_failed"] += 1
	)
	
	# Create target with health component
	target = Node2D.new()
	target.name = "Target"
	add_child(target)
	target.position = Vector2(50, 0)  # Within default range
	print("Target created at: ", target.position)
	
	var health = HealthComponent.new()
	health.name = "HealthComponent"
	target.add_child(health)
	print("Health component added to target at path: ", health.get_path())
	
	# Wait for nodes to be ready
	await get_tree().process_frame
	print("First frame processed")
	
	# Wait for deferred calls
	await get_tree().physics_frame
	print("Physics frame processed")
	
	# Wait for initialization
	await get_tree().process_frame
	print("Second frame processed")
	
	# Debug node tree
	print("\nNode tree after initialization:")
	print_node_tree(self)
	
	# Verify components
	var target_health = target.get_node_or_null("HealthComponent")
	print("\nLooking for HealthComponent in target: ", target.name)
	print("Target path: ", target.get_path())
	print("Target children: ", target.get_children())
	print("Found health component: ", target_health)
	
	if target_health:
		print("Health component state:")
		print("- Initialized: ", target_health._initialized)
		print("- Current health: ", target_health.current_health)
		print("- Max health: ", target_health.max_health)
	else:
		print("ERROR: Health component not found!")
		print("Trying direct search...")
		var health_components = get_tree().get_nodes_in_group("health_components")
		print("Found health components in tree: ", health_components)
	
	assert(target_health != null, "Health component should be added to target")
	assert(target_health.current_health > 0, "Health component should be initialized")

func print_node_tree(node: Node, indent: String = ""):
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		print_node_tree(child, indent + "  ")

func teardown():
	attacker.queue_free()
	target.queue_free()
	attacker = null
	target = null
	combat_component = null

func run_tests():
	print("\nStarting CombatComponent Tests")
	
	await test_initialization()
	await test_target_validation()
	await test_basic_attack()
	await test_attack_range()
	await test_attack_speed()
	await test_combat_state()
	
	print("CombatComponent Tests Complete")
	get_tree().quit()

func test_initialization():
	print("\nTesting Initialization")
	await setup()
	
	assert(combat_component.damage == 10.0, "Default damage should be 10")
	assert(combat_component.attack_range == 100.0, "Default range should be 100")
	assert(combat_component.attack_speed == 1.0, "Default attack speed should be 1")
	assert(combat_component.can_attack, "Should be able to attack by default")
	assert(not combat_component.is_attacking(), "Should not be attacking initially")
	
	teardown()

func test_target_validation():
	print("\nTesting Target Validation")
	await setup()
	
	# Test invalid target (no health component)
	var invalid_target = Node2D.new()
	add_child(invalid_target)
	combat_component.set_target(invalid_target)
	
	assert(signals_received["attack_failed"] == 1, "Should fail when target has no health")
	assert(not combat_component.is_attacking(), "Should not be attacking invalid target")
	
	invalid_target.queue_free()
	teardown()

func test_basic_attack():
	print("\nTesting Basic Attack")
	await setup()
	
	print("Target position: ", target.position)
	print("Attack range: ", combat_component.attack_range)
	print("Distance to target: ", attacker.position.distance_to(target.position))
	
	combat_component.set_target(target)
	print("Is attacking: ", combat_component.is_attacking())
	print("Current target: ", combat_component.current_target)
	print("Can attack target: ", combat_component.can_attack_target(target))
	
	assert(combat_component.is_attacking(), "Should be attacking after setting valid target")
	
	# Process one attack cycle
	combat_component.process(1.1)  # Slightly more than attack cooldown
	
	assert(signals_received["attack_started"] == 1, "Should emit attack_started")
	assert(signals_received["attack_completed"] == 1, "Should emit attack_completed")
	
	var target_health = target.get_node("HealthComponent")
	assert(target_health.current_health < target_health.max_health, "Target should take damage")
	
	teardown()

func test_attack_range():
	print("\nTesting Attack Range")
	await setup()
	
	# Move target just outside range
	target.position = Vector2(combat_component.attack_range + 10, 0)
	combat_component.set_target(target)
	
	assert(signals_received["attack_failed"] == 1, "Should fail when target out of range")
	assert(not combat_component.is_attacking(), "Should not be attacking out-of-range target")
	
	# Move target back in range
	target.position = Vector2(combat_component.attack_range - 10, 0)
	combat_component.set_target(target)
	
	assert(combat_component.is_attacking(), "Should attack when target in range")
	
	teardown()

func test_attack_speed():
	print("\nTesting Attack Speed")
	await setup()
	
	combat_component.attack_speed = 2.0  # 2 attacks per second
	combat_component.set_target(target)
	
	# Process half a second
	combat_component.process(0.5)
	assert(signals_received["attack_completed"] == 1, "Should attack once in 0.5s at 2 attacks/s")
	
	# Process another half second
	combat_component.process(0.5)
	assert(signals_received["attack_completed"] == 2, "Should attack twice in 1.0s at 2 attacks/s")
	
	teardown()

func test_combat_state():
	print("\nTesting Combat State")
	await setup()
	
	combat_component.set_target(target)
	assert(combat_component.is_attacking(), "Should be attacking after setting target")
	
	combat_component.stop_attacking()
	assert(not combat_component.is_attacking(), "Should stop attacking when commanded")
	assert(combat_component.get_attack_progress() == 1.0, "Should be ready to attack after stopping")
	
	combat_component.can_attack = false
	combat_component.set_target(target)
	assert(not combat_component.is_attacking(), "Should not attack when can_attack is false")
	
	teardown() 
