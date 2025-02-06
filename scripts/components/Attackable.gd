class_name Attackable
extends Node

signal health_changed(current, max_health)
signal destroyed(position)
signal damage_taken(amount, source)

# Combat properties
var max_health: float = 100.0
var current_health: float
var armor: float = 0.0
var is_invulnerable: bool = false

# Visual feedback
var flash_on_hit: bool = true
var destruction_effect: bool = true

func _ready():
	add_to_group("attackable")

func initialize(initial_health: float, initial_armor: float = 0.0):
	max_health = initial_health
	current_health = initial_health
	armor = initial_armor
	emit_signal("health_changed", current_health, max_health)

func take_damage(amount: float, source: Node = null) -> float:
	if is_invulnerable:
		return 0.0
		
	var actual_damage = amount * (1.0 - armor)
	current_health -= actual_damage
	
	emit_signal("damage_taken", actual_damage, source)
	emit_signal("health_changed", current_health, max_health)
	
	if flash_on_hit:
		_play_damage_effect()
	
	if current_health <= 0:
		_handle_destruction()
	
	return actual_damage

func heal(amount: float):
	var old_health = current_health
	current_health = min(current_health + amount, max_health)
	
	if current_health != old_health:
		emit_signal("health_changed", current_health, max_health)
		_play_heal_effect()

func _handle_destruction():
	if destruction_effect:
		_play_destruction_effect()
	
	emit_signal("destroyed", get_parent().position)
	get_parent().queue_free()

func _play_damage_effect():
	if not get_parent() is Node2D:
		return
		
	var sprite = get_parent().get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.5, 0.3, 0.3)  # Bright red
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.05)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.05)

func _play_heal_effect():
	if not get_parent() is Node2D:
		return
		
	var sprite = get_parent().get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(0.3, 1.5, 0.3)  # Bright green
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _play_destruction_effect():
	if not get_parent() is Node2D:
		return
		
	var sprite = get_parent().get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.0, 0, 0)  # Pure red
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.1) 