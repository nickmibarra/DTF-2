extends Node2D

# Test configuration
var test_cases = [
	{"enemies": 10, "duration": 3, "warmup": 1},
	{"enemies": 50, "duration": 3, "warmup": 1},
	{"enemies": 100, "duration": 3, "warmup": 1},
	{"enemies": 500, "duration": 3, "warmup": 1},
	{"enemies": 1000, "duration": 3, "warmup": 1}
]

# Performance metrics
var metrics = {
	"frame_times": [],
	"path_calculations": 0,
	"cache_hits": 0,
	"cache_misses": 0,
	"spatial_queries": 0,
	"memory_usage": 0
}

# Test state
var current_test = -1
var test_timer = 0.0
var warmup_timer = 0.0
var is_running = false
var enemy_scene = preload("res://scenes/Enemy.tscn")
var spawn_timer = 0.0
var enemies_to_spawn = 0

# UI elements
@onready var results_display = $UI/Results
@onready var current_test_label = $UI/CurrentTest
@onready var start_button = $UI/StartButton
@onready var grid = $Grid

func _ready():
	setup_ui()
	grid.setup_metrics(metrics)

func setup_ui():
	start_button.pressed.connect(start_tests)
	results_display.text = "Click Start to begin performance tests"

func start_tests():
	if is_running:
		return
		
	# Reset all metrics
	current_test = -1
	metrics.frame_times.clear()
	metrics.path_calculations = 0
	metrics.cache_hits = 0
	metrics.cache_misses = 0
	metrics.spatial_queries = 0
	metrics.memory_usage = 0
	results_display.text = ""
	
	is_running = true
	start_next_test()

func start_next_test():
	# Clean up previous test
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	current_test += 1
	if current_test >= test_cases.size():
		show_final_results()
		return
	
	var test = test_cases[current_test]
	test_timer = 0.0
	warmup_timer = 0.0
	enemies_to_spawn = test.enemies
	spawn_timer = 0.0
	
	current_test_label.text = "Running test %d/%d: %d enemies (warmup)" % [
		current_test + 1,
		test_cases.size(),
		test.enemies
	]

func _process(delta):
	if not is_running:
		return
	
	var test = test_cases[current_test]
	
	# Handle enemy spawning
	if enemies_to_spawn > 0:
		spawn_timer += delta
		if spawn_timer >= 0.05:  # Spawn every 50ms
			spawn_timer = 0.0
			var enemy = enemy_scene.instantiate()
			enemy.position = get_random_spawn_position()
			add_child(enemy)
			enemies_to_spawn -= 1
	
	# Handle warmup period
	if warmup_timer < test.warmup:
		warmup_timer += delta
		if warmup_timer >= test.warmup:
			# Clear metrics after warmup
			metrics.frame_times.clear()
			metrics.path_calculations = 0
			metrics.cache_hits = 0
			metrics.cache_misses = 0
			metrics.spatial_queries = 0
			current_test_label.text = "Running test %d/%d: %d enemies (measuring)" % [
				current_test + 1,
				test_cases.size(),
				test.enemies
			]
		return
	
	# Record frame time and memory usage
	metrics.frame_times.append(Performance.get_monitor(Performance.TIME_PROCESS))
	metrics.memory_usage = Performance.get_monitor(Performance.MEMORY_STATIC)
	
	# Update test timer
	test_timer += delta
	if test_timer >= test.duration:
		record_test_results()
		start_next_test()

func record_test_results():
	if metrics.frame_times.is_empty():
		return
		
	var test = test_cases[current_test]
	
	# Calculate average frame time (excluding worst 5% of frames)
	var sorted_times = metrics.frame_times.duplicate()
	sorted_times.sort()
	var trim_count = int(sorted_times.size() * 0.05)  # 5% of frames
	sorted_times = sorted_times.slice(0, sorted_times.size() - trim_count)
	
	var avg_frame_time = 0.0
	for t in sorted_times:
		avg_frame_time += t
	avg_frame_time /= sorted_times.size()
	
	var result = "Test %d (%d enemies):\n" % [current_test + 1, test.enemies]
	result += "- Average frame time: %.2f ms\n" % [avg_frame_time * 1000.0]
	result += "- FPS: %.1f\n" % [1.0 / avg_frame_time]
	result += "- Path calculations: %d\n" % metrics.path_calculations
	result += "- Cache hit rate: %.1f%%\n" % [
		(metrics.cache_hits / float(metrics.path_calculations)) * 100.0 if metrics.path_calculations > 0 else 0.0
	]
	result += "- Spatial queries: %d\n" % metrics.spatial_queries
	result += "- Memory usage: %.1f MB\n" % [metrics.memory_usage / 1024.0 / 1024.0]
	
	# Add to UI and log
	results_display.text += "\n\n" + result
	print("\n=== Performance Test Results ===")
	print(result)
	
	# Reset metrics for next test
	metrics.frame_times.clear()
	metrics.path_calculations = 0
	metrics.cache_hits = 0
	metrics.cache_misses = 0
	metrics.spatial_queries = 0

func show_final_results():
	is_running = false
	current_test_label.text = "Tests completed!"
	start_button.text = "Run Again"
	print("\n=== All Performance Tests Completed ===\n")

func get_random_spawn_position() -> Vector2:
	return grid.get_random_spawn_point()

func _exit_tree():
	is_running = false
