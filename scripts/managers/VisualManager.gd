class_name VisualManager
extends Node

# Node references
@onready var sprite: Sprite2D = $Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var health_bar: ColorRect = $HealthBar
@onready var effect_container: Node2D = $EffectContainer

# Visual state
var base_color: Color = Color.WHITE
var base_scale: Vector2 = Vector2.ONE
var active_effects: Dictionary = {}

func _ready() -> void:
	# Create required nodes if they don't exist
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)
		
	if not animation_player:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)
		
	if not health_bar:
		health_bar = ColorRect.new()
		health_bar.name = "HealthBar"
		health_bar.size = Vector2(32, 4)
		health_bar.position = Vector2(-16, -24)  # Above sprite
		health_bar.color = Color.GREEN
		add_child(health_bar)
		
	if not effect_container:
		effect_container = Node2D.new()
		effect_container.name = "EffectContainer"
		add_child(effect_container)
	
	# Store initial state
	base_color = sprite.modulate
	base_scale = sprite.scale

func set_sprite(texture: Texture2D) -> void:
	sprite.texture = texture

func update_position(new_position: Vector2) -> void:
	# Update visual position (might include interpolation later)
	get_parent().position = new_position

func update_health_display(current: float, maximum: float) -> void:
	var health_percent = current / maximum
	health_bar.size.x = 32 * health_percent
	
	# Update color based on health
	if health_percent > 0.6:
		health_bar.color = Color.GREEN
	elif health_percent > 0.3:
		health_bar.color = Color.YELLOW
	else:
		health_bar.color = Color.RED

func play_attack_animation() -> void:
	if animation_player.has_animation("attack"):
		animation_player.stop()
		animation_player.play("attack")
	else:
		# Fallback visual feedback
		flash(Color(1.5, 1.0, 1.0))  # Reddish flash
		pulse(1.2, 0.2)  # Quick pulse

func play_death_effect() -> void:
	if animation_player.has_animation("death"):
		animation_player.play("death")
	else:
		# Fallback death effect
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(get_parent().queue_free)

func play_effect(effect_name: String) -> void:
	# Create effect instance
	var effect = ColorRect.new()  # Simple colored rectangle as fallback
	effect.size = Vector2(32, 32)
	effect.position = Vector2(-16, -16)
	
	# Configure based on effect type
	match effect_name:
		"speed_boost":
			effect.color = Color(0.0, 1.0, 1.0, 0.3)  # Cyan
		"damage_boost":
			effect.color = Color(1.0, 0.0, 0.0, 0.3)  # Red
		"armor_boost":
			effect.color = Color(0.0, 0.0, 1.0, 0.3)  # Blue
		_:
			effect.color = Color(1.0, 1.0, 1.0, 0.3)  # White
	
	effect_container.add_child(effect)
	active_effects[effect_name] = effect

func stop_effect(effect_name: String) -> void:
	if effect_name in active_effects:
		var effect = active_effects[effect_name]
		var tween = create_tween()
		tween.tween_property(effect, "modulate:a", 0.0, 0.2)
		tween.tween_callback(effect.queue_free)
		active_effects.erase(effect_name)

func flash(color: Color = Color.WHITE, duration: float = 0.1) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", color, duration * 0.5)
	tween.tween_property(sprite, "modulate", base_color, duration * 0.5)

func pulse(scale_amount: float = 1.2, duration: float = 0.2) -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "scale", base_scale * scale_amount, duration * 0.5)
	tween.tween_property(sprite, "scale", base_scale, duration * 0.5)

func shake(intensity: float = 5.0, duration: float = 0.2) -> void:
	var start_pos = sprite.position
	var tween = create_tween()
	
	for i in range(4):  # 4 shakes
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(sprite, "position", start_pos + offset, duration * 0.125)
	
	tween.tween_property(sprite, "position", start_pos, duration * 0.125) 