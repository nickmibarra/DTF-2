class_name VisualComponent
extends EntityComponent

signal animation_started(anim_name: String)
signal animation_finished(anim_name: String)
signal effect_started(effect_name: String)
signal effect_finished(effect_name: String)

@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var effect_container: Node2D

# Visual state
var current_animation: String = ""
var active_effects: Array[Node] = []
var base_color: Color = Color.WHITE
var base_scale: Vector2 = Vector2.ONE

# Effect scenes
var effect_scenes: Dictionary = {}

func _initialize() -> void:
	assert(entity != null, "VisualComponent requires a Node2D parent")
	
	# Create sprite if not provided
	if not sprite:
		sprite = Sprite2D.new()
		entity.add_child(sprite)
	
	# Create animation player if not provided
	if not animation_player:
		animation_player = AnimationPlayer.new()
		entity.add_child(animation_player)
		animation_player.root_node = entity.get_path()
	
	# Create effect container if not provided
	if not effect_container:
		effect_container = Node2D.new()
		effect_container.name = "Effects"
		entity.add_child(effect_container)
	
	# Connect animation signals
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# Store initial state
	base_color = sprite.modulate
	base_scale = sprite.scale

func set_sprite_texture(texture: Texture2D) -> void:
	sprite.texture = texture

func play_animation(anim_name: String, custom_speed: float = 1.0, from_start: bool = true) -> void:
	if not animation_player.has_animation(anim_name):
		push_warning("Animation not found: " + anim_name)
		return
	
	current_animation = anim_name
	if from_start:
		animation_player.stop()
	animation_player.play(anim_name, -1, custom_speed)
	emit_signal("animation_started", anim_name)

func stop_animation() -> void:
	animation_player.stop()
	current_animation = ""

func is_playing() -> bool:
	return animation_player.is_playing()

func register_effect(effect_name: String, effect_scene: PackedScene) -> void:
	effect_scenes[effect_name] = effect_scene

func play_effect(effect_name: String, duration: float = 1.0) -> void:
	if not effect_scenes.has(effect_name):
		push_warning("Effect not found: " + effect_name)
		return
	
	var effect_instance = effect_scenes[effect_name].instantiate()
	effect_container.add_child(effect_instance)
	active_effects.append(effect_instance)
	
	emit_signal("effect_started", effect_name)
	
	# Setup effect cleanup
	if duration > 0:
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func(): _cleanup_effect(effect_instance, effect_name))

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

func _cleanup_effect(effect: Node, effect_name: String) -> void:
	active_effects.erase(effect)
	effect.queue_free()
	emit_signal("effect_finished", effect_name)

func _on_animation_finished(anim_name: String) -> void:
	emit_signal("animation_finished", anim_name)
	if anim_name == current_animation:
		current_animation = "" 