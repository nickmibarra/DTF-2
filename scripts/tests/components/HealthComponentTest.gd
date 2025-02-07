extends Node

var test_entity: Node2D
var health_component: HealthComponent

var signals_received = {
	"health_changed": 0,
	"damage_taken": 0,
	"healed": 0,
	"died": 0
}

func _ready():
	run_tests()

func setup():
	# Reset signal counters
	for key in signals_received:
		signals_received[key] = 0
	
	# Create test entity and component
	test_entity = Node2D.new()
	add_child(test_entity)
	
	health_component = HealthComponent.new()
	
	# Connect signals BEFORE adding to scene
	health_component.health_changed.connect(func(current, maximum): 
		signals_received["health_changed"] += 1
	)
	health_component.damage_taken.connect(func(amount, source): signals_received["damage_taken"] += 1)
	health_component.healed.connect(func(amount): signals_received["healed"] += 1)
	health_component.died.connect(func(): signals_received["died"] += 1)
	
	# Now add component to scene
	test_entity.add_child(health_component)
	
	# Wait for ready
	await get_tree().process_frame

func teardown():
	test_entity.queue_free()
	test_entity = null
	health_component = null

func run_tests():
	print("\nStarting HealthComponent Tests")
	
	# Test initialization
	test_initialization()
	
	# Test damage
	test_basic_damage()
	test_armor_reduction()
	test_invulnerability()
	test_death()
	
	# Test healing
	test_basic_healing()
	test_overheal_clamping()
	
	print("HealthComponent Tests Complete")
	get_tree().quit()

func test_initialization():
	print("\nTesting Initialization")
	setup()
	
	assert(health_component.current_health == health_component.max_health, "Health should be at maximum on initialization")
	assert(signals_received["health_changed"] == 1, "Should emit health_changed signal on initialization")
	
	teardown()

func test_basic_damage():
	print("\nTesting Basic Damage")
	setup()
	
	var damage_amount = 20.0
	var actual_damage = health_component.take_damage(damage_amount)
	
	assert(actual_damage == damage_amount, "Damage dealt should match damage taken")
	assert(health_component.current_health == health_component.max_health - damage_amount, "Health should be reduced by damage amount")
	assert(signals_received["damage_taken"] == 1, "Should emit damage_taken signal")
	assert(signals_received["health_changed"] == 2, "Should emit health_changed signal") # 1 for init, 1 for damage
	
	teardown()

func test_armor_reduction():
	print("\nTesting Armor Reduction")
	setup()
	
	health_component.armor = 0.5  # 50% damage reduction
	var damage_amount = 20.0
	var expected_damage = damage_amount * 0.5
	var actual_damage = health_component.take_damage(damage_amount)
	
	assert(actual_damage == expected_damage, "Damage should be reduced by armor")
	assert(health_component.current_health == health_component.max_health - expected_damage, "Health reduction should account for armor")
	
	teardown()

func test_invulnerability():
	print("\nTesting Invulnerability")
	setup()
	
	health_component.is_invulnerable = true
	var damage_amount = 20.0
	var actual_damage = health_component.take_damage(damage_amount)
	
	assert(actual_damage == 0.0, "No damage should be dealt while invulnerable")
	assert(health_component.current_health == health_component.max_health, "Health should not change while invulnerable")
	assert(signals_received["damage_taken"] == 0, "No damage signals should be emitted while invulnerable")
	
	teardown()

func test_death():
	print("\nTesting Death")
	setup()
	
	health_component.take_damage(health_component.max_health + 10.0)  # Overkill damage
	
	assert(health_component.current_health == 0.0, "Health should be clamped to 0")
	assert(signals_received["died"] == 1, "Should emit died signal")
	assert(not health_component.is_alive(), "Should report as not alive")
	
	teardown()

func test_basic_healing():
	print("\nTesting Basic Healing")
	setup()
	
	var damage_amount = 40.0
	health_component.take_damage(damage_amount)
	
	var heal_amount = 20.0
	var actual_heal = health_component.heal(heal_amount)
	
	assert(actual_heal == heal_amount, "Heal amount should match expected")
	assert(health_component.current_health == health_component.max_health - damage_amount + heal_amount, "Health should increase by heal amount")
	assert(signals_received["healed"] == 1, "Should emit healed signal")
	
	teardown()

func test_overheal_clamping():
	print("\nTesting Overheal Clamping")
	setup()
	
	var damage_amount = 20.0
	health_component.take_damage(damage_amount)
	
	var heal_amount = 40.0  # More than damage taken
	var expected_heal = damage_amount  # Should only heal up to max
	var actual_heal = health_component.heal(heal_amount)
	
	assert(actual_heal == expected_heal, "Heal amount should be clamped to missing health")
	assert(health_component.current_health == health_component.max_health, "Health should be clamped to maximum")
	
	teardown() 
