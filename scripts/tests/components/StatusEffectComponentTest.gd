extends Node

var test_entity: Node2D
var status_component: StatusEffectComponent

var signals_received = {
	"effect_applied": 0,
	"effect_removed": 0,
	"effect_updated": 0
}

func _ready():
	run_tests()

func setup():
	# Reset signal counters
	for key in signals_received:
		signals_received[key] = 0
	
	# Create test entity and component
	test_entity = Node2D.new()
	test_entity.name = "TestEntity"
	add_child(test_entity)
	
	status_component = StatusEffectComponent.new()
	status_component.name = "StatusEffectComponent"
	
	# Connect signals
	status_component.effect_applied.connect(func(name, duration): signals_received["effect_applied"] += 1)
	status_component.effect_removed.connect(func(name): signals_received["effect_removed"] += 1)
	status_component.effect_updated.connect(func(name, time): signals_received["effect_updated"] += 1)
	
	test_entity.add_child(status_component)
	
	# Wait for initialization
	await get_tree().process_frame

func teardown():
	test_entity.queue_free()
	test_entity = null
	status_component = null

func run_tests():
	print("\nStarting StatusEffectComponent Tests")
	
	await test_initialization()
	await test_basic_effect()
	await test_effect_stacking()
	await test_effect_duration()
	await test_modifiers()
	await test_effect_removal()
	
	print("StatusEffectComponent Tests Complete")
	get_tree().quit()

func test_initialization():
	print("\nTesting Initialization")
	await setup()
	
	assert(status_component.active_effects.is_empty(), "Should start with no effects")
	assert(status_component.speed_modifier == 1.0, "Speed modifier should start at 1.0")
	assert(status_component.damage_modifier == 1.0, "Damage modifier should start at 1.0")
	assert(status_component.armor_modifier == 0.0, "Armor modifier should start at 0.0")
	
	teardown()

func test_basic_effect():
	print("\nTesting Basic Effect")
	await setup()
	
	status_component.apply_effect("speed_boost", 5.0, {"speed": 0.5})  # 50% speed boost
	
	assert(status_component.has_effect("speed_boost"), "Effect should be active")
	assert(status_component.get_effect_duration("speed_boost") == 5.0, "Duration should be set")
	assert(status_component.get_speed_modifier() == 1.5, "Speed should be increased by 50%")
	assert(signals_received["effect_applied"] == 1, "Should emit effect_applied signal")
	
	teardown()

func test_effect_stacking():
	print("\nTesting Effect Stacking")
	await setup()
	
	# Apply two damage boosts
	status_component.apply_effect("damage_boost", 5.0, {"damage": 0.2})  # +20% damage
	status_component.apply_effect("damage_boost", 5.0, {"damage": 0.2})  # Stack another +20%
	
	assert(status_component.get_damage_modifier() == 1.4, "Damage modifiers should stack")
	assert(signals_received["effect_applied"] == 2, "Should emit effect_applied signal twice")
	
	teardown()

func test_effect_duration():
	print("\nTesting Effect Duration")
	await setup()
	
	status_component.apply_effect("test_effect", 2.0, {"speed": 0.1})
	
	# Process some time
	status_component.process(1.0)  # 1 second
	assert(status_component.get_effect_duration("test_effect") == 1.0, "Duration should decrease")
	assert(signals_received["effect_updated"] > 0, "Should emit effect_updated signal")
	
	# Process remaining time
	status_component.process(1.0)  # Another second
	assert(not status_component.has_effect("test_effect"), "Effect should be removed")
	assert(signals_received["effect_removed"] == 1, "Should emit effect_removed signal")
	
	teardown()

func test_modifiers():
	print("\nTesting Modifiers")
	await setup()
	
	# Apply multiple effect types
	status_component.apply_effect("boost", 5.0, {
		"speed": 0.2,   # +20% speed
		"damage": 0.3,  # +30% damage
		"armor": 10.0   # +10 armor
	})
	
	assert(status_component.get_speed_modifier() == 1.2, "Speed should be increased by 20%")
	assert(status_component.get_damage_modifier() == 1.3, "Damage should be increased by 30%")
	assert(status_component.get_armor_modifier() == 10.0, "Armor should be increased by 10")
	
	teardown()

func test_effect_removal():
	print("\nTesting Effect Removal")
	await setup()
	
	# Apply multiple effects
	status_component.apply_effect("effect1", 5.0, {"speed": 0.1})
	status_component.apply_effect("effect2", 5.0, {"damage": 0.1})
	
	# Remove one effect
	status_component.remove_effect("effect1")
	assert(not status_component.has_effect("effect1"), "Effect1 should be removed")
	assert(status_component.has_effect("effect2"), "Effect2 should remain")
	assert(status_component.get_speed_modifier() == 1.0, "Speed modifier should be reset")
	assert(status_component.get_damage_modifier() == 1.1, "Damage modifier should remain")
	
	# Clear all effects
	status_component.clear_all_effects()
	assert(status_component.active_effects.is_empty(), "All effects should be cleared")
	
	teardown() 
