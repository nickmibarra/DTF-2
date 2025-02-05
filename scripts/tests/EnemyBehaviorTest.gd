extends Node2D

# Test cases
@onready var direct_path_test = $TestCases/DirectPath
@onready var wall_choice_test = $TestCases/WallChoice
@onready var grid = $Grid

# UI
@onready var run_button = $UI/TestControls/RunTestButton
@onready var reset_button = $UI/TestControls/ResetButton
@onready var status_label = $UI/TestControls/StatusLabel

var test_results = {}
var current_test = ""

func _ready():
	run_button.pressed.connect(run_tests)
	reset_button.pressed.connect(reset_tests)
	
	# Add status label if it doesn't exist
	if not status_label:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		$UI/TestControls.add_child(status_label)
	
	# Initialize grid with walls
	_setup_grid()
	
	# Disable debug mode for all enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var behavior = enemy.get_node("EnemyBehavior")
		behavior.debug_mode = false
		# Make enemies visible but inactive initially
		enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _setup_grid():
	# Register wall in grid for wall choice test
	var wall = wall_choice_test.get_node("Wall")
	if wall:
		print("Test: Setting up wall in grid")
		# Convert wall's position to grid coordinates
		var wall_pos = grid.world_to_grid(wall.position + wall_choice_test.position)
		print("Test: Wall grid position: ", wall_pos)
		# Set wall in grid
		grid.set_cell_type(wall_pos, grid.TILE_TYPE.WALL)
		grid.walls[str(wall_pos)] = wall
		print("Test: Wall registered in grid at position: ", wall_pos)

func run_tests():
	status_label.text = "=== Starting Enemy Behavior Tests ==="
	test_results.clear()
	
	# Test 1: Direct Path to Flag
	current_test = "direct_path"
	var direct_enemy = direct_path_test.get_node("Enemy")
	var direct_flag = direct_path_test.get_node("Flag")
	
	# Configure enemy for direct path test
	direct_enemy.process_mode = Node.PROCESS_MODE_INHERIT
	var direct_behavior = direct_enemy.get_node("EnemyBehavior")
	direct_behavior.attack_weight = 1.0
	direct_behavior.path_weight = 1.0
	print("\nTest: Direct Path Test Setup")
	print("- Enemy Position: ", direct_enemy.position)
	print("- Flag Position: ", direct_flag.position)
	
	# Force initial path calculation
	direct_enemy.current_path.clear()
	
	status_label.text += "\n\nTest 1: Direct Path"
	status_label.text += "\n- Enemy should move directly to flag"
	
	# Test 2: Wall Choice
	current_test = "wall_choice"
	var wall_enemy = wall_choice_test.get_node("Enemy")
	var wall = wall_choice_test.get_node("Wall")
	var wall_flag = wall_choice_test.get_node("Flag")
	
	# Configure enemy for wall test
	wall_enemy.process_mode = Node.PROCESS_MODE_INHERIT
	var behavior = wall_enemy.get_node("EnemyBehavior")
	behavior.attack_weight = 0.5  # Lower means MORE likely to attack (inverted in should_attack_target)
	behavior.path_weight = 2.0    # Higher means LESS likely to take long paths
	print("\nTest: Wall Choice Test Setup")
	print("- Enemy Position: ", wall_enemy.position)
	print("- Wall Position: ", wall.position)
	print("- Flag Position: ", wall_flag.position)
	print("- Attack Weight: ", behavior.attack_weight)
	print("- Path Weight: ", behavior.path_weight)
	
	# Force initial path calculation
	wall_enemy.current_path.clear()
	
	status_label.text += "\n\nTest 2: Wall Choice"
	status_label.text += "\n- Enemy should prefer attacking wall"
	status_label.text += "\n- Attack Weight: " + str(behavior.attack_weight)
	status_label.text += "\n- Path Weight: " + str(behavior.path_weight)

func _process(_delta):
	if current_test != "":
		match current_test:
			"direct_path":
				_check_direct_path()
			"wall_choice":
				_check_wall_choice()

func _check_direct_path():
	var enemy = direct_path_test.get_node("Enemy")
	var flag = direct_path_test.get_node("Flag")
	
	if not is_instance_valid(enemy):
		return
		
	var dist = enemy.position.distance_to(flag.position)
	if dist <= enemy.ATTACK_RANGE:
		status_label.text += "\nDirect Path Test: Enemy reached flag"
		current_test = ""

func _check_wall_choice():
	var enemy = wall_choice_test.get_node("Enemy")
	var wall = wall_choice_test.get_node("Wall")
	
	if not is_instance_valid(enemy) or not is_instance_valid(wall):
		return
		
	var dist_to_wall = enemy.position.distance_to(wall.position)
	if not test_results.has("initial_wall_decision") and dist_to_wall <= enemy.ATTACK_RANGE * 1.5:
		var behavior = enemy.get_node("EnemyBehavior")
		var should_attack = behavior.should_attack_target(100.0, dist_to_wall)
		test_results["initial_wall_decision"] = should_attack
		status_label.text += "\nWall Choice Test: Enemy decision - Attack Wall: " + str(should_attack)
		
		# Draw decision visualization
		queue_redraw()
		current_test = ""

func _draw():
	if test_results.has("initial_wall_decision"):
		var enemy = wall_choice_test.get_node("Enemy")
		var wall = wall_choice_test.get_node("Wall")
		var flag = wall_choice_test.get_node("Flag")
		
		if is_instance_valid(enemy) and is_instance_valid(wall) and is_instance_valid(flag):
			# Draw path options
			var attack_color = Color(1, 0, 0, 0.5) if test_results["initial_wall_decision"] else Color(0.5, 0.5, 0.5, 0.5)
			var path_color = Color(0, 1, 0, 0.5) if not test_results["initial_wall_decision"] else Color(0.5, 0.5, 0.5, 0.5)
			
			# Draw attack path
			draw_line(enemy.position + wall_choice_test.position, wall.position + wall_choice_test.position, attack_color, 2.0)
			# Draw movement path
			draw_line(enemy.position + wall_choice_test.position, enemy.position + wall_choice_test.position + Vector2(0, -50), path_color, 2.0)
			draw_line(enemy.position + wall_choice_test.position + Vector2(0, -50), flag.position + wall_choice_test.position, path_color, 2.0)

func reset_tests():
	status_label.text = "=== Tests Reset ==="
	get_tree().reload_current_scene()
	current_test = ""
	test_results.clear()
	queue_redraw() 
