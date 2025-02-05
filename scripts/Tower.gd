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

# Veteran system
const RANK_THRESHOLDS = GameSettings.RANK_THRESHOLDS
const RANK_BONUSES = GameSettings.RANK_BONUSES

@onready var sprite = $Sprite2D
@onready var range_indicator = $RangeIndicator

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

func _ready():
	if range_indicator:
		range_indicator.scale = Vector2.ONE * (attack_range / 100.0)
		range_indicator.visible = false
	
	_update_appearance()

func _process(delta):
	attack_timer += delta
	
	if attack_timer >= 1.0 / attack_speed:
		if target and is_instance_valid(target) and target.is_inside_tree():
			var distance = position.distance_to(target.position)
			if distance <= attack_range:
				attack(target)
				attack_timer = 0.0
				_play_attack_animation()
			else:
				target = null
		else:
			target = find_new_target()

func _update_appearance():
	if sprite and tower_textures.has(type):
		sprite.texture = tower_textures[type]
		var intensity = 0.5 + (rank * 0.1)
		sprite.modulate.a = intensity

func _play_attack_animation():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)

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
	enemy.take_damage(actual_damage)
	
	if not enemy.is_connected("died", _on_enemy_killed):
		enemy.died.connect(_on_enemy_killed)

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
	
	if range_indicator:
		range_indicator.scale = Vector2.ONE * (attack_range / 100.0)
	_update_appearance()
