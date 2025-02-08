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

# Wall placement variables
var is_placing_wall: bool = false
var wall_start_pos: Vector2 = Vector2.ZERO
var wall_preview_cells: Array = []
var wall_preview_nodes: Array = []

# Preload scenes
@onready var tower_scene = preload("res://scenes/Tower.tscn")

func _ready():
	print("\nTestMap: Initializing...")
	# Verify scenes
	print("Checking scenes...")
	print("- Tower scene loaded: ", tower_scene != null)
	
	if not tower_scene:
		push_error("Failed to load Tower scene!")
		return
	
	# Test instantiation
	var test_tower = tower_scene.instantiate()
	if test_tower:
		print("- Tower instantiation test: Success")
		test_tower.queue_free()
	else:
		push_error("Failed to instantiate tower!")
		return
	
	# Ensure grid is in group for CombatManager
	grid.add_to_group("grid")
	
	# Connect combat signals
	CombatManager.attack_performed.connect(_on_attack_performed)
	CombatManager.target_destroyed.connect(_on_target_destroyed)
	
	# Connect other signals
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	
	# Connect to flag's health component for game over
	if flag and flag.health_component:
		flag.health_component.died.connect(_on_flag_destroyed)
	else:
		push_error("Flag or its health component not found!")
	
	# Connect UI signals
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	for type in tower_buttons:
		tower_buttons[type].pressed.connect(func(): select_tower(type))
	
	# Initialize UI
	update_gold_display()
	update_wave_display()
	update_tower_buttons()

	# Create preview container
	var preview_container = Node2D.new()
	preview_container.name = "WallPreview"
	add_child(preview_container)
	
	print("TestMap: Initialization complete")
	print("TestMap: Starting gold: ", gold)
	print("TestMap: Input actions configured:")
	print("- place_tower (Left Click): ", InputMap.has_action("place_tower"))
	print("- place_wall (Right Click): ", InputMap.has_action("place_wall"))
	print("TestMap: Tower scene loaded: ", tower_scene != null)

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					print("\nLeft click detected at: ", event.position)
					attempt_place_tower()
				MOUSE_BUTTON_RIGHT:
					print("\nRight click detected at: ", event.position)
					attempt_place_wall()
	elif event.is_action_pressed("start_wave"):
		print("\nStart wave action detected")
		_on_start_wave_pressed()

func attempt_place_tower():
	var screen_pos = get_viewport().get_mouse_position()
	var world_pos = camera.get_screen_to_canvas(screen_pos)
	var grid_pos = grid.world_to_grid(world_pos)
	
	print("\nAttempting tower placement:")
	print("- Screen pos: ", screen_pos)
	print("- World pos: ", world_pos)
	print("- Grid pos: ", grid_pos)
	print("- Selected tower type: ", selected_tower_type)
	print("- Current gold: ", gold)
	print("- Tower cost: ", GameSettings.TOWER_COSTS[selected_tower_type])
	
	if not grid.is_valid_cell(grid_pos):
		print("Failed: Invalid grid position")
		return
	
	if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
		print("Failed: Cell not empty")
		return
	
	var cost = GameSettings.TOWER_COSTS[selected_tower_type]
	if gold < cost:
		print("Failed: Not enough gold")
		return
	
	print("Placing tower...")
	if grid.place_tower(grid_pos, selected_tower_type):
		gold -= cost
		update_gold_display()
		update_tower_buttons()
		print("Tower placed successfully")
	else:
		print("Failed: Could not place tower")

func attempt_place_wall():
	var screen_pos = get_viewport().get_mouse_position()
	var world_pos = camera.get_screen_to_canvas(screen_pos)
	var grid_pos = grid.world_to_grid(world_pos)
	
	print("\nAttempting wall placement:")
	print("- Screen pos: ", screen_pos)
	print("- World pos: ", world_pos)
	print("- Grid pos: ", grid_pos)
	print("- Current gold: ", gold)
	print("- Wall cost: ", GameSettings.WALL_COST)
	
	if not grid.is_valid_cell(grid_pos):
		print("Failed: Invalid grid position")
		return
	
	if grid.get_cell_type(grid_pos) != grid.TILE_TYPE.EMPTY:
		print("Failed: Cell not empty")
		return
	
	if gold < GameSettings.WALL_COST:
		print("Failed: Not enough gold")
		return
	
	print("Placing wall...")
	if grid.set_cell_type(grid_pos, grid.TILE_TYPE.WALL):
		gold -= GameSettings.WALL_COST
		update_gold_display()
		update_tower_buttons()
		print("Wall placed successfully")
	else:
		print("Failed: set_cell_type returned false")

func _on_start_wave_pressed():
	print("\nAttempting to start wave...")
	print("Wave manager exists: ", wave_manager != null)
	print("Current wave: ", wave_manager.current_wave if wave_manager else "N/A")
	print("Wave in progress: ", wave_manager.wave_in_progress if wave_manager else "N/A")
	
	if wave_manager:
		wave_manager.start_wave()
		start_wave_button.disabled = true
		print("Wave started successfully")
	else:
		push_error("Wave manager not found!")

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
	if target.is_in_group("flags"):
		print("Flag took ", damage, " damage from enemy")

func _on_target_destroyed(pos: Vector2):
	print("Target destroyed at position: ", pos)
	# Additional game logic for destroyed targets can go here
	# For example, updating score, spawning effects, etc.

func update_wall_preview():
	# Clear old preview
	clear_wall_preview()
	
	# Get current mouse position in grid coordinates
	var world_pos = camera.get_screen_to_canvas(get_viewport().get_mouse_position())
	var current_pos = grid.world_to_grid(world_pos)
	
	# Calculate rectangle of cells between start and current
	var min_x = min(wall_start_pos.x, current_pos.x)
	var max_x = max(wall_start_pos.x, current_pos.x)
	var min_y = min(wall_start_pos.y, current_pos.y)
	var max_y = max(wall_start_pos.y, current_pos.y)
	
	# Create preview for each cell
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var pos = Vector2(x, y)
			if grid.is_valid_cell(pos) and grid.get_cell_type(pos) == grid.TILE_TYPE.EMPTY:
				wall_preview_cells.append(pos)
				var preview = ColorRect.new()
				preview.color = Color(0.5, 0.5, 0.5, 0.5)  # Semi-transparent gray
				preview.size = Vector2.ONE * GameSettings.BASE_GRID_SIZE
				preview.position = grid.grid_to_world(pos) - preview.size / 2
				$WallPreview.add_child(preview)
				wall_preview_nodes.append(preview)

func clear_wall_preview():
	for preview in wall_preview_nodes:
		preview.queue_free()
	wall_preview_nodes.clear()
	wall_preview_cells.clear()

func place_walls():
	var total_cost = wall_preview_cells.size() * GameSettings.WALL_COST
	if gold >= total_cost:
		for pos in wall_preview_cells:
			if grid.set_cell_type(pos, grid.TILE_TYPE.WALL):
				gold -= GameSettings.WALL_COST
		update_gold_display()
		update_tower_buttons()
