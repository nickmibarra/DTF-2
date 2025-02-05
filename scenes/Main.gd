extends Node2D

@onready var grid = $Grid
@onready var wave_manager = $WaveManager
@onready var flag = $Flag

# UI references
@onready var gold_label = $UI/TopBar/GoldLabel
@onready var wave_label = $UI/TopBar/WaveLabel
@onready var start_wave_button = $UI/TopBar/StartWaveButton
@onready var tower_buttons = {
	0: $UI/TowerPanel/HBoxContainer/BallistaButton,
	1: $UI/TowerPanel/HBoxContainer/FlamethrowerButton,
	2: $UI/TowerPanel/HBoxContainer/ArcaneButton
}

var gold: int = 100
var selected_tower_type = 0  # Index of the currently selected tower type
var game_over: bool = false

# Costs
const TOWER_COSTS = {
	0: 50,  # Ballista
	1: 75,  # Flamethrower
	2: 100  # Arcane
}

const WALL_COST = 20

func _ready():
	# Connect signals
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	flag.flag_destroyed.connect(_on_flag_destroyed)
	
	# Connect UI signals
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	for type in tower_buttons:
		tower_buttons[type].pressed.connect(func(): select_tower(type))
	
	# Initialize UI
	update_gold_display()
	update_wave_display()
	update_tower_buttons()

func _unhandled_input(event):
	if game_over:
		return
	
	if event.is_action_pressed("start_wave"):
		_on_start_wave_pressed()
	
	if event.is_action_pressed("place_tower"):
		attempt_place_tower()
	
	if event.is_action_pressed("place_wall"):
		attempt_place_wall()

func attempt_place_tower():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = grid.world_to_grid(mouse_pos)
	
	if not grid.is_valid_cell(grid_pos):
		return
	
	if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
		return
	
	var cost = TOWER_COSTS[selected_tower_type]
	if gold < cost:
		return
	
	# Place tower
	var tower = preload("res://scenes/Tower.tscn").instantiate()
	tower.position = grid.grid_to_world(grid_pos)
	tower.set_type(selected_tower_type)
	add_child(tower)
	
	# Update grid and gold
	grid.set_cell_type(grid_pos, grid.TILE_TYPE.TOWER)
	gold -= cost
	update_gold_display()
	update_tower_buttons()

func attempt_place_wall():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = grid.world_to_grid(mouse_pos)
	
	if not grid.is_valid_cell(grid_pos):
		return
	
	if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
		return
	
	if gold < WALL_COST:
		return
	
	# Place wall
	grid.set_cell_type(grid_pos, grid.TILE_TYPE.WALL)
	gold -= WALL_COST
	update_gold_display()
	update_tower_buttons()

func _on_start_wave_pressed():
	wave_manager.start_wave()
	start_wave_button.disabled = true

func _on_wave_started(wave_number):
	update_wave_display()

func _on_wave_completed():
	update_wave_display()
	start_wave_button.disabled = false

func _on_all_waves_completed():
	show_victory_screen()

func _on_flag_destroyed():
	game_over = true
	show_game_over_screen()

func _on_enemy_died(gold_value):
	gold += gold_value
	update_gold_display()
	update_tower_buttons()

func update_gold_display():
	gold_label.text = "Gold: %d" % gold

func update_wave_display():
	wave_label.text = "Wave: %d" % wave_manager.current_wave

func update_tower_buttons():
	for type in tower_buttons:
		tower_buttons[type].disabled = gold < TOWER_COSTS[type]

func show_victory_screen():
	# Create victory screen
	var victory_panel = Panel.new()
	victory_panel.anchor_right = 1.0
	victory_panel.anchor_bottom = 1.0
	
	var victory_label = Label.new()
	victory_label.text = "Victory!"
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_label.anchor_right = 1.0
	victory_label.anchor_bottom = 1.0
	
	victory_panel.add_child(victory_label)
	$UI.add_child(victory_panel)

func show_game_over_screen():
	# Create game over screen
	var game_over_panel = Panel.new()
	game_over_panel.anchor_right = 1.0
	game_over_panel.anchor_bottom = 1.0
	
	var game_over_label = Label.new()
	game_over_label.text = "Game Over!"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.anchor_right = 1.0
	game_over_label.anchor_bottom = 1.0
	
	game_over_panel.add_child(game_over_label)
	$UI.add_child(game_over_panel)

func select_tower(type: int):
	selected_tower_type = type
	
	# Update button visuals
	for t in tower_buttons:
		var button = tower_buttons[t]
		button.modulate = Color(1, 1, 1, 1) if t != type else Color(0.7, 1.0, 0.7) 
