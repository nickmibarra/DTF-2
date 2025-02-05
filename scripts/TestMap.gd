extends Node2D

@onready var grid = $Grid
@onready var wave_manager = $WaveManager
@onready var flag = $Flag
@onready var camera = $GameCamera

# UI references
@onready var gold_label = $CanvasLayer/UI/TopBar/GoldLabel
@onready var wave_label = $CanvasLayer/UI/TopBar/WaveLabel
@onready var start_wave_button = $CanvasLayer/UI/TopBar/StartWaveButton
@onready var tower_buttons = {
	0: $CanvasLayer/UI/TowerPanel/HBoxContainer/BallistaButton,
	1: $CanvasLayer/UI/TowerPanel/HBoxContainer/FlamethrowerButton,
	2: $CanvasLayer/UI/TowerPanel/HBoxContainer/ArcaneButton
}

var gold: int = GameSettings.STARTING_GOLD
var selected_tower_type = 0
var game_over: bool = false

# Preload scenes
var tower_scene = preload("res://scenes/Tower.tscn")

func _ready():
	print("TestMap: Ready called")
	
	# Ensure grid is in group for CombatManager
	grid.add_to_group("grid")
	
	# Connect combat signals
	CombatManager.attack_performed.connect(_on_attack_performed)
	CombatManager.target_destroyed.connect(_on_target_destroyed)
	
	# Connect other signals
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

func _input(event):
	if not event is InputEventMouseMotion:  # Don't log mouse motion
		print("TestMap: Input event received: ", event)

func _unhandled_input(event):
	if not event is InputEventMouseMotion:  # Don't log mouse motion
		print("TestMap: Unhandled input event: ", event)
	
	if game_over:
		return
	
	if event.is_action_pressed("place_tower"):
		print("TestMap: Attempting to place tower")
		attempt_place_tower()
	elif event.is_action_pressed("place_wall"):
		print("TestMap: Attempting to place wall")
		attempt_place_wall()

func attempt_place_tower():
	var mouse_pos = get_viewport().get_mouse_position()
	var grid_pos = grid.world_to_grid(mouse_pos)
	print("TestMap: Tower placement - Mouse pos: ", mouse_pos, " Grid pos: ", grid_pos)
	
	if not grid.is_valid_cell(grid_pos):
		print("TestMap: Invalid grid cell")
		return
	
	if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
		print("TestMap: Cell not empty")
		return
	
	var cost = GameSettings.TOWER_COSTS[selected_tower_type]
	if gold < cost:
		print("TestMap: Not enough gold")
		return
	
	print("TestMap: Placing tower")
	# Place tower
	var tower = tower_scene.instantiate()
	tower.position = grid.grid_to_world(grid_pos)
	tower.set_type(selected_tower_type)
	grid.add_child(tower)
	
	# Update grid and gold
	grid.set_cell_type(grid_pos, grid.TILE_TYPE.TOWER)
	gold -= cost
	update_gold_display()
	update_tower_buttons()

func attempt_place_wall():
	var mouse_pos = get_viewport().get_mouse_position()
	var grid_pos = grid.world_to_grid(mouse_pos)
	print("TestMap: Wall placement - Mouse pos: ", mouse_pos, " Grid pos: ", grid_pos)
	
	if not grid.is_valid_cell(grid_pos):
		print("TestMap: Invalid grid cell")
		return
	
	if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
		print("TestMap: Cell not empty")
		return
	
	if gold < GameSettings.WALL_COST:
		print("TestMap: Not enough gold")
		return
	
	print("TestMap: Placing wall")
	# Place wall
	if grid.set_cell_type(grid_pos, grid.TILE_TYPE.WALL):
		gold -= GameSettings.WALL_COST
		update_gold_display()
	else:
		print("TestMap: Wall placement failed")

func _on_start_wave_pressed():
	wave_manager.start_wave()
	start_wave_button.disabled = true

func _on_wave_started(wave_number):
	update_wave_display()

func _on_wave_completed():
	update_wave_display()
	start_wave_button.disabled = false

func _on_all_waves_completed():
	game_over = true
	# TODO: Show victory screen

func _on_flag_destroyed():
	game_over = true
	show_game_over_screen()

func show_game_over_screen():
	# Create game over screen
	var game_over_panel = Panel.new()
	game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill entire viewport
	game_over_panel.modulate = Color(0.1, 0.1, 0.1, 0.9)  # Dark semi-transparent background
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)  # Center in parent
	vbox.position = Vector2(-200, -100)  # Offset for centering
	vbox.custom_minimum_size = Vector2(400, 200)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	
	var game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 48)
	
	var wave_summary = Label.new()
	wave_summary.text = "Waves Survived: %d" % wave_manager.current_wave
	wave_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.custom_minimum_size = Vector2(200, 50)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Make sure button stays interactive when game is paused
	restart_button.process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)
	
	vbox.add_child(game_over_label)
	vbox.add_child(wave_summary)
	vbox.add_child(restart_button)
	
	game_over_panel.add_child(vbox)
	$CanvasLayer/UI.add_child(game_over_panel)
	
	print("Game Over screen shown")
	# Pause all game processes
	get_tree().paused = true

func _on_restart_pressed():
	print("Restart button pressed")
	# Unpause before reloading
	get_tree().paused = false
	# Reload the current scene
	get_tree().reload_current_scene()

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
		tower_buttons[type].disabled = gold < GameSettings.TOWER_COSTS[type]

func select_tower(type: int):
	selected_tower_type = type
	
	# Update button visuals
	for t in tower_buttons:
		var button = tower_buttons[t]
		button.modulate = Color(1, 1, 1, 1) if t != type else Color(0.7, 1.0, 0.7) 

func _on_attack_performed(attacker: Node2D, target: Node2D, damage: float):
	if target.is_in_group("walls"):
		print("Wall at ", target.position, " took ", damage, " damage from enemy")
	elif target.is_in_group("flags"):
		print("Flag took ", damage, " damage from enemy")

func _on_target_destroyed(pos: Vector2):
	print("Target destroyed at position: ", pos)
	# Additional game logic for destroyed targets can go here
	# For example, updating score, spawning effects, etc.
