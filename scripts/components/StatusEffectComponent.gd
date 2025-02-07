class_name StatusEffectComponent
extends EntityComponent

signal effect_applied(effect_name: String, duration: float)
signal effect_removed(effect_name: String)
signal effect_updated(effect_name: String, remaining_time: float)

# Dictionary to store active effects
# Format: { "effect_name": { duration: float, modifiers: Dictionary } }
var active_effects: Dictionary = {}

# Effect modifiers
var speed_modifier: float = 1.0
var damage_modifier: float = 1.0
var armor_modifier: float = 0.0

func _initialize() -> void:
	assert(entity != null, "StatusEffectComponent requires a Node2D parent")

func process(delta: float) -> void:
	var effects_to_remove = []
	
	# Update effect durations and check for expired effects
	for effect_name in active_effects:
		var effect = active_effects[effect_name]
		effect.duration -= delta
		
		if effect.duration <= 0:
			effects_to_remove.append(effect_name)
		else:
			emit_signal("effect_updated", effect_name, effect.duration)
	
	# Remove expired effects
	for effect_name in effects_to_remove:
		remove_effect(effect_name)

func apply_effect(effect_name: String, duration: float, modifiers: Dictionary = {}) -> void:
	# If effect already exists, refresh or stack based on type
	if active_effects.has(effect_name):
		var existing = active_effects[effect_name]
		# Default behavior: refresh duration
		existing.duration = max(existing.duration, duration)
		# Stack or update modifiers
		for key in modifiers:
			if key in existing.modifiers:
				existing.modifiers[key] += modifiers[key]  # Stack
			else:
				existing.modifiers[key] = modifiers[key]  # Add new
	else:
		# Add new effect
		active_effects[effect_name] = {
			"duration": duration,
			"modifiers": modifiers.duplicate()
		}
	
	# Apply modifiers
	_update_modifiers()
	
	emit_signal("effect_applied", effect_name, duration)

func remove_effect(effect_name: String) -> void:
	if not active_effects.has(effect_name):
		return
	
	active_effects.erase(effect_name)
	_update_modifiers()  # Recalculate modifiers
	emit_signal("effect_removed", effect_name)

func has_effect(effect_name: String) -> bool:
	return active_effects.has(effect_name)

func get_effect_duration(effect_name: String) -> float:
	if not active_effects.has(effect_name):
		return 0.0
	return active_effects[effect_name].duration

func get_effect_modifier(effect_name: String, modifier_name: String) -> float:
	if not active_effects.has(effect_name):
		return 0.0
	return active_effects[effect_name].modifiers.get(modifier_name, 0.0)

func clear_all_effects() -> void:
	var effects_to_clear = active_effects.keys()  # Create copy of keys
	for effect_name in effects_to_clear:
		remove_effect(effect_name)

func _update_modifiers() -> void:
	# Reset modifiers
	speed_modifier = 1.0
	damage_modifier = 1.0
	armor_modifier = 0.0
	
	# Apply all active effects
	for effect in active_effects.values():
		var mods = effect.modifiers
		speed_modifier *= (1.0 + mods.get("speed", 0.0))
		damage_modifier *= (1.0 + mods.get("damage", 0.0))
		armor_modifier += mods.get("armor", 0.0)  # Armor is additive

# Getter functions for other components to use
func get_speed_modifier() -> float:
	return speed_modifier

func get_damage_modifier() -> float:
	return damage_modifier

func get_armor_modifier() -> float:
	return armor_modifier 