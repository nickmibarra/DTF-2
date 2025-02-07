extends Node2D

enum TOWER_TYPE {
	BALLISTA,
	FLAMETHROWER,
	ARCANE
}

var type: TOWER_TYPE = TOWER_TYPE.BALLISTA
var damage: float = 20.0
var attack_range: float = 200.0
var attack_speed: float = 1.0  # Attacks per second
var attack_timer: float = 0.0
var target: Node2D = null
var kills: int = 0
var rank: int = 1
var barrier: Barrier

# Veteran system
const RANK_THRESHOLDS = GameSettings.RANK_THRESHOLDS
const RANK_BONUSES = GameSettings.RANK_BONUSES

# Attack timing
var attack_interval: float = 1.0  # Will be set based on attack_speed

# Add near top with other constants
const UPDATE_FREQUENCY = 0.1  # Update every 100ms
const ATTACK_CHECK_OFFSET = 0.02  # Small offset to stagger checks between towers

# Add near other variables
var update_timer: float = 0.0
var instance_offset: float = 0.0  # Unique offset per tower instance

@onready var sprite = $Sprite2D
@onready var range_indicator = $RangeIndicator
@onready var health_bar = $HealthBar
@onready var attackable = $Attackable

# Preload resources
var tower_textures = {
	TOWER_TYPE.BALLISTA: preload("res://resources/sprites/towers/ballista.tres"),
	TOWER_TYPE.FLAMETHROWER: preload("res://resources/sprites/towers/flamethrower.tres"),
	TOWER_TYPE.ARCANE: preload("res://resources/sprites/towers/arcane.tres")
}

# Preload effects
var projectile_scene = preload("res://scenes/effects/Projectile.tscn")
var flame_scene = preload("res://scenes/effects/FlameEffect.tscn")
var arcane_scene = preload("res://scenes/effects/ArcaneEffect.tscn")

# Add near other variables at top
var _effect_tween: Tween = null
var attack_offset: float = 0.0

func _ready():
	attack_interval = 1.0 / attack_speed  # Initialize interval based on default attack speed
	if range_indicator:
		range_indicator.scale = Vector2.ONE * (attack_range / 100.0)
		range_indicator.visible = false
	
	add_to_group("towers")
	add_to_group("barriers")
	add_to_group("attackable")
	
	# Add barrier component
	barrier = Barrier.new()
	barrier.name = "Barrier"  # Give it a consistent name
	add_child(barrier)
	barrier.setup(self, CollisionSystem.COLLISION_LAYER.TOWER)
	
	# Initialize attackable component
	if attackable:
		attackable.initialize(50.0)  # 200 base health for towers
		attackable.health_changed.connect(_on_health_changed)
		attackable.destroyed.connect(_on_tower_destroyed)
	
	_update_appearance()
	
	# Initialize instance offset based on position to stagger updates
	instance_offset = (position.x + position.y) * ATTACK_CHECK_OFFSET
	update_timer = instance_offset  # Start with offset
	
	# Add to existing _ready function
	attack_offset = randf_range(0, attack_interval * 0.5)  # Random offset between 0 and half the attack interval
	_setup_effect_tween()

func _process(delta):
	update_timer += delta
	
	# Always process attack timer and check for attacks
	if target and is_instance_valid(target):
		var distance = position.distance_to(target.position)
		if distance <= attack_range:
			attack_timer += delta
			if attack_timer >= attack_interval + attack_offset:
				attack_timer = attack_offset
				attack(target)
	
	# Only do expensive operations (target finding) on the update frequency
	if update_timer < UPDATE_FREQUENCY:
		return
	
	update_timer = instance_offset  # Reset to instance offset instead of 0
	
	if not target or not is_instance_valid(target):
		target = find_new_target()
		return
		
	var distance = position.distance_to(target.position)
	if distance > attack_range:
		target = find_new_target()

func _update_appearance():
	if sprite and tower_textures.has(type):
		sprite.texture = tower_textures[type]
		var intensity = 0.5 + (rank * 0.1)
		sprite.modulate.a = intensity

func _play_attack_animation():
	if not _effect_tween or not _effect_tween.is_valid():
		_setup_effect_tween()
	
	# Reset sprite properties
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	
	# Restart the tween
	_effect_tween.stop()  # Stop any current animation
	_effect_tween.play()  # Start from beginning

func _input(event):
	if event is InputEventMouseMotion and range_indicator:
		var mouse_pos = get_global_mouse_position()
		range_indicator.visible = position.distance_to(mouse_pos) < 32

func find_new_target() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = position.distance_to(enemy.position)
			if distance <= attack_range and distance < closest_distance:
				closest_enemy = enemy
				closest_distance = distance
	
	return closest_enemy

func attack(enemy: Node2D):
	if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return
		
	var actual_damage = damage * RANK_BONUSES[rank]
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.init(position, enemy, actual_damage)
	
	if not enemy.is_connected("died", _on_enemy_killed):
		enemy.died.connect(_on_enemy_killed)
	
	# Play attack animation
	_play_attack_animation()

func _spawn_projectile(enemy: Node2D, damage_amount: float):
	var projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.init(position, enemy, damage_amount)

func _spawn_flame_effect(enemy: Node2D, damage_amount: float):
	var flame = flame_scene.instantiate()
	get_parent().add_child(flame)
	flame.init(enemy.position, damage_amount)

func _spawn_arcane_effect(enemy: Node2D, damage_amount: float):
	var arcane = arcane_scene.instantiate()
	get_parent().add_child(arcane)
	arcane.init(enemy.position, damage_amount)

func _on_enemy_killed(_gold_value):
	kills += 1
	check_rank_up()

func check_rank_up():
	for rank_level in range(5, 1, -1):
		if kills >= RANK_THRESHOLDS[rank_level] and rank < rank_level:
			rank = rank_level
			_update_appearance()
			break

func set_type(new_type: TOWER_TYPE):
	type = new_type
	match type:
		TOWER_TYPE.BALLISTA:
			damage = 20.0
			attack_range = 200.0
			attack_speed = 1.0
		TOWER_TYPE.FLAMETHROWER:
			damage = 10.0
			attack_range = 150.0
			attack_speed = 2.0
		TOWER_TYPE.ARCANE:
			damage = 15.0
			attack_range = 180.0
			attack_speed = 1.5
	
	attack_interval = 1.0 / attack_speed  # Update interval based on attacks per second
	if range_indicator:
		range_indicator.scale = Vector2.ONE * (attack_range / 100.0)
	_update_appearance()

func _on_health_changed(current: float, maximum: float):
	if not health_bar:
		return
		
	health_bar.size.x = (current / maximum) * 32
	
	# Update color based on health percentage
	var health_percent = current / maximum
	if health_percent > 0.6:
		health_bar.color = Color(0, 0.8, 0, 1)  # Green
	elif health_percent > 0.3:
		health_bar.color = Color(0.8, 0.8, 0, 1)  # Yellow
	else:
		health_bar.color = Color(0.8, 0, 0, 1)  # Red

func _on_tower_destroyed(pos: Vector2):
	print("Tower destroyed at position: ", pos)
	# Tell the grid to remove this tower
	var grid = get_parent()
	if grid and grid.has_method("world_to_grid"):
		var grid_pos = grid.world_to_grid(position)
		grid.set_cell_type(grid_pos, grid.TILE_TYPE.EMPTY)

# Forward take_damage to attackable component
func take_damage(amount: float):
	if attackable:
		attackable.take_damage(amount)
	else:
		push_error("Tower: Cannot take damage, no Attackable component!")

func _setup_effect_tween():
	if _effect_tween and _effect_tween.is_valid():
		_effect_tween.kill()  # Clean up existing tween
	
	_effect_tween = create_tween()
	_effect_tween.set_parallel(true)
	_effect_tween.pause()
	
	# Set up the flash animation sequence
	_effect_tween.tween_property(sprite, "modulate", Color(1.2, 0.8, 0.2), 0.1)
	_effect_tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	
	# Chain the return to normal
	_effect_tween.chain().tween_property(sprite, "modulate", Color.WHITE, 0.1)
	_effect_tween.chain().tween_property(sprite, "scale", Vector2.ONE, 0.1)
