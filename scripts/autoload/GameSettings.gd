extends Node

# Game balance settings
const STARTING_GOLD = 1000
const WALL_COST = 20

const TOWER_COSTS = {
	0: 50,  # Ballista
	1: 75,  # Flamethrower
	2: 100  # Arcane
}

# Game speed settings
var game_speed: float = 1.0
const FAST_GAME_SPEED: float = 3.0
signal game_speed_changed(new_speed)

# Wave settings
const BASE_ENEMIES_PER_WAVE = 10
const WAVE_ENEMY_INCREASE = 5
const SPAWN_INTERVAL = 1.0
const CAMPAIGN_WAVES = 10

# Enemy scaling
const HEALTH_SCALE = 1.2
const SPEED_SCALE = 1.1
const GOLD_SCALE = 1.15
const DAMAGE_SCALE = 1.1

# Tower veteran system
const RANK_THRESHOLDS = {
	2: 10,  # 10 kills for rank 2
	3: 25,  # 25 kills for rank 3
	4: 50,  # 50 kills for rank 4
	5: 100  # 100 kills for rank 5
}

const RANK_BONUSES = {
	1: 1.0,    # Base damage
	2: 1.05,   # +5% damage
	3: 1.12,   # +12% damage
	4: 1.22,   # +22% damage
	5: 1.37    # +37% damage
}

# Save data
var high_scores = {}
var unlocked_features = []

func _ready():
	load_settings()
	# Set up speed toggle input
	if not InputMap.has_action("toggle_game_speed"):
		InputMap.add_action("toggle_game_speed")
		var event = InputEventKey.new()
		event.keycode = KEY_TAB
		InputMap.action_add_event("toggle_game_speed", event)

func _input(event):
	if event.is_action_pressed("toggle_game_speed"):
		toggle_game_speed()

func toggle_game_speed():
	if game_speed == 1.0:
		set_game_speed(FAST_GAME_SPEED)
	else:
		set_game_speed(1.0)

func set_game_speed(speed: float):
	game_speed = speed
	Engine.time_scale = speed
	game_speed_changed.emit(speed)

func load_settings():
	# TODO: Implement save/load system
	pass

func save_settings():
	# TODO: Implement save/load system
	pass

func update_high_score(mode: String, score: int) -> bool:
	if not high_scores.has(mode) or score > high_scores[mode]:
		high_scores[mode] = score
		save_settings()
		return true
	return false 
