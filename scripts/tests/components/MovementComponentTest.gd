extends Node

var test_entity: Node2D
var movement_component: MovementComponent

var signals_received = {
	"position_changed": 0,
	"path_completed": 0,
	"movement_blocked": 0
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
	test_entity.position = Vector2(100, 100)  # Starting position
	
	movement_component = MovementComponent.new()
	
	# Connect signals
	movement_component.position_changed.connect(func(pos): signals_received["position_changed"] += 1)
	movement_component.path_completed.connect(func(): signals_received["path_completed"] += 1)
	movement_component.movement_blocked.connect(func(pos): signals_received["movement_blocked"] += 1)
	
	# Add component to scene
	test_entity.add_child(movement_component)
	
	# Wait for ready
	await get_tree().process_frame

func teardown():
	test_entity.queue_free()
	test_entity = null
	movement_component = null

func run_tests():
	print("\nStarting MovementComponent Tests")
	
	await test_initialization()
	await test_basic_movement()
	await test_path_following()
	await test_movement_interruption()
	await test_arrival_threshold()
	
	print("MovementComponent Tests Complete")
	get_tree().quit()

func test_initialization():
	print("\nTesting Initialization")
	await setup()
	
	assert(movement_component.movement_speed == 100.0, "Default speed should be 100")
	assert(not movement_component.is_moving, "Should not be moving initially")
	assert(movement_component.current_path.is_empty(), "Should start with empty path")
	
	teardown()

func test_basic_movement():
	print("\nTesting Basic Movement")
	await setup()
	
	var target = Vector2(200, 200)
	movement_component.move_to(target)
	
	assert(movement_component.is_moving, "Should be moving after move_to call")
	assert(movement_component.target_position == target, "Target position should be set")
	
	# Process a few frames
	for i in range(5):
		movement_component.process(0.1)  # 100ms per frame
		await get_tree().process_frame
	
	assert(signals_received["position_changed"] > 0, "Should emit position_changed signals")
	assert(test_entity.position.distance_to(Vector2(100, 100)) > 0, "Should have moved from start position")
	
	teardown()

func test_path_following():
	print("\nTesting Path Following")
	await setup()
	
	var path = [Vector2(150, 150), Vector2(200, 200)]
	print("Initial path: ", path)
	movement_component.follow_path(path)
	
	print("Path size after follow_path: ", movement_component.current_path.size())
	assert(movement_component.is_moving, "Should be moving after follow_path call")
	assert(movement_component.current_path.size() == 2, "Should have two waypoints")
	
	# Track initial path size
	var initial_path_size = movement_component.current_path.size()
	var reached_first_waypoint = false
	
	# Process until first waypoint
	var max_iterations = 100  # Safety limit
	var iterations = 0
	print("Starting movement loop...")
	while not reached_first_waypoint and iterations < max_iterations:
		var distance = test_entity.position.distance_to(path[0])
		print("Distance to waypoint: ", distance, ", Threshold: ", movement_component.arrival_threshold)
		print("Current position: ", test_entity.position)
		
		# Check if we're about to reach the waypoint
		if distance <= movement_component.arrival_threshold:
			print("About to reach waypoint!")
			movement_component.process(0.1)  # Process the frame where we reach it
			await get_tree().process_frame
			reached_first_waypoint = true
			print("Path size immediately after reaching waypoint: ", movement_component.current_path.size())
			break
		
		movement_component.process(0.1)
		await get_tree().process_frame
		
		iterations += 1
		if iterations % 10 == 0:  # Log every 10 iterations
			print("Iteration: ", iterations, ", Path size: ", movement_component.current_path.size())
	
	print("Loop completed. Iterations: ", iterations)
	print("Final path size: ", movement_component.current_path.size())
	print("Initial path size: ", initial_path_size)
	print("Is moving: ", movement_component.is_moving)
	print("Current position: ", test_entity.position)
	print("Distance to first waypoint: ", test_entity.position.distance_to(path[0]))
	print("Distance to second waypoint: ", test_entity.position.distance_to(path[1]))
	
	assert(reached_first_waypoint, "Should have reached first waypoint")
	assert(movement_component.current_path.size() == initial_path_size - 1, 
		"Should have removed first waypoint (expected %d, got %d)" % [initial_path_size - 1, movement_component.current_path.size()])
	assert(movement_component.is_moving, "Should still be moving to second waypoint")
	
	# Verify we're now moving towards the second waypoint
	if movement_component.current_path.size() > 0:
		var next_target = movement_component.current_path[0]
		assert(next_target == path[1], "Next target should be second waypoint")
	
	teardown()

func test_movement_interruption():
	print("\nTesting Movement Interruption")
	await setup()
	
	movement_component.move_to(Vector2(200, 200))
	assert(movement_component.is_moving, "Should be moving")
	
	movement_component.stop()
	assert(not movement_component.is_moving, "Should not be moving after stop")
	assert(movement_component.current_path.is_empty(), "Path should be cleared after stop")
	assert(movement_component.get_velocity() == Vector2.ZERO, "Velocity should be zero after stop")
	
	teardown()

func test_arrival_threshold():
	print("\nTesting Arrival Threshold")
	await setup()
	
	var target = Vector2(110, 110)  # Just outside arrival threshold
	print("Target position: ", target)
	movement_component.move_to(target)
	
	print("Starting position: ", test_entity.position)
	# Process until very close to target
	var iterations = 0
	while test_entity.position.distance_to(target) > movement_component.arrival_threshold + 1:
		var distance = test_entity.position.distance_to(target)
		print("Distance to target: ", distance, ", Threshold + 1: ", movement_component.arrival_threshold + 1)
		movement_component.process(0.1)
		await get_tree().process_frame
		iterations += 1
		if iterations >= 100:  # Safety break
			print("Hit iteration limit!")
			break
	
	print("Position before final check: ", test_entity.position)
	print("Distance to target: ", test_entity.position.distance_to(target))
	assert(not movement_component.is_at_target(), "Should not be at target yet")
	
	# Process one more frame to arrive
	movement_component.process(0.1)
	await get_tree().process_frame
	
	print("Final position: ", test_entity.position)
	print("Final distance to target: ", test_entity.position.distance_to(target))
	print("Is at target: ", movement_component.is_at_target())
	print("Path completed signals: ", signals_received["path_completed"])
	
	assert(movement_component.is_at_target(), "Should be at target")
	assert(signals_received["path_completed"] > 0, "Should emit path_completed signal")
	
	teardown() 
