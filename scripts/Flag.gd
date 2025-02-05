extends Node2D

signal health_changed(current_health, max_health)
signal flag_destroyed

var max_health: float = 100.0
var current_health: float = max_health

func _ready():
    # Initialize flag appearance
    var flag_shape = ColorRect.new()
    flag_shape.size = Vector2(48, 48)  # 75% of grid size
    flag_shape.position = -flag_shape.size / 2  # Center the shape
    flag_shape.color = Color(0.8, 0.2, 0.2)  # Red color
    add_child(flag_shape)
    
    # Add health bar
    var health_bar_bg = ColorRect.new()
    health_bar_bg.size = Vector2(64, 8)
    health_bar_bg.position = Vector2(-32, -40)
    health_bar_bg.color = Color.DARK_RED
    add_child(health_bar_bg)
    
    var health_bar = ColorRect.new()
    health_bar.size = Vector2(64, 8)
    health_bar.position = Vector2(-32, -40)
    health_bar.color = Color.GREEN
    health_bar.name = "health_bar"
    add_child(health_bar)
    
    # Make sure we process even when paused
    process_mode = Node.PROCESS_MODE_PAUSABLE

func take_damage(amount: float):
    current_health = max(0, current_health - amount)
    update_health_bar()
    health_changed.emit(current_health, max_health)
    
    if current_health <= 0:
        # Visual feedback before game over
        modulate = Color(1, 0, 0)  # Turn bright red
        flag_destroyed.emit()

func heal(amount: float):
    current_health = min(max_health, current_health + amount)
    update_health_bar()
    health_changed.emit(current_health, max_health)

func update_health_bar():
    var health_bar = get_node("health_bar")
    if health_bar:
        health_bar.size.x = (current_health / max_health) * 64
        
        # Update color based on health percentage
        var health_percent = current_health / max_health
        if health_percent > 0.6:
            health_bar.color = Color.GREEN
        elif health_percent > 0.3:
            health_bar.color = Color(1, 1, 0)  # Yellow
        else:
            health_bar.color = Color(1, 0, 0)  # Red

func get_health_percentage() -> float:
    return current_health / max_health
