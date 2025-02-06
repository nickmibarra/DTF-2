extends Node

signal wave_started(wave_number)
signal wave_completed
signal all_waves_completed

@export var enemy_scene: PackedScene
var current_wave: int = 0
var enemies_remaining: int = 0
var wave_in_progress: bool = false
var endless_mode: bool = false

# Wave configuration
var base_enemies_per_wave: int = 10
var wave_enemy_increase: int = 5
var spawn_interval: float = 1.0
var spawn_timer: float = 0.0

# Enemy scaling
var base_health: float = 100.0
var base_speed: float = 100.0
var base_gold: int = 10
var base_damage: int = 1

var health_scale: float = 1.2
var speed_scale: float = 1.1
var gold_scale: float = 1.15
var damage_scale: float = 1.1

# Track active enemies
var active_enemies: Array = []

func _ready():
	set_process(false)
	randomize()  # Initialize random number generator

func _process(delta):
	if wave_in_progress and enemies_remaining > 0:
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_enemy()
			spawn_timer = 0.0
	
	# Clean up invalid enemies
	active_enemies = active_enemies.filter(func(enemy): return is_instance_valid(enemy))
	
	# Check if wave is complete
	if wave_in_progress and enemies_remaining <= 0 and active_enemies.is_empty():
		_on_wave_complete()

func start_wave():
	if wave_in_progress:
		return
	
	current_wave += 1
	enemies_remaining = calculate_enemies_for_wave()
	wave_in_progress = true
	spawn_timer = 0.0
	set_process(true)
	wave_started.emit(current_wave)

func start_endless_mode():
	endless_mode = true
	start_wave()

func calculate_enemies_for_wave() -> int:
	return base_enemies_per_wave + (current_wave - 1) * wave_enemy_increase

func spawn_enemy():
	if not enemy_scene:
		push_error("Enemy scene not set in WaveManager")
		return
	
	var grid = get_parent().grid
	if not grid:
		push_error("Grid not found in parent")
		return
	
	var enemy = enemy_scene.instantiate()
	grid.add_child(enemy)  # Add to grid instead of parent
	active_enemies.append(enemy)
	
	# Calculate scaled stats
	var health = base_health * pow(health_scale, current_wave - 1)
	var speed = base_speed * pow(speed_scale, current_wave - 1)
	var gold = int(base_gold * pow(gold_scale, current_wave - 1))
	var damage = int(base_damage * pow(damage_scale, current_wave - 1))
	
	enemy.set_stats(health, speed, gold, damage)
	
	# Get spawn position
	var spawn_pos = grid.get_random_spawn_point()
	enemy.position = spawn_pos
	
	# Connect signals
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.reached_flag.connect(_on_enemy_reached_flag)
	
	enemies_remaining -= 1

func _on_enemy_died(gold_value: int, enemy: Node2D):
	active_enemies.erase(enemy)
	get_parent()._on_enemy_died(gold_value)
	
	if enemies_remaining <= 0 and active_enemies.is_empty():
		_on_wave_complete()

func _on_enemy_reached_flag(damage: int):
	get_parent().flag.take_damage(damage)

func _on_wave_complete():
	wave_in_progress = false
	set_process(false)
	wave_completed.emit()
	
	if not endless_mode and current_wave >= GameSettings.CAMPAIGN_WAVES:
		all_waves_completed.emit()
