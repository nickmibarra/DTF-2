extends Node2D

var max_health: float = 100.0
var health: float = max_health

@onready var sprite = $Sprite2D
@onready var health_bar = $HealthBar

func _ready():
    add_to_group("walls")
    _update_health_bar()

func take_damage(amount: float):
    health -= amount
    _update_health_bar()
    
    # Visual feedback
    sprite.modulate = Color(1, 0.3, 0.3)  # Flash red
    create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
    
    # Update appearance based on health
    var health_percent = health / max_health
    sprite.modulate.a = 0.5 + (health_percent * 0.5)  # Fade out as health decreases
    
    if health <= 0:
        # Tell the grid to remove this wall
        var grid_pos = get_parent().world_to_grid(position)
        get_parent().set_cell_type(grid_pos, get_parent().TILE_TYPE.EMPTY)
        queue_free()

func _update_health_bar():
    if health_bar:
        health_bar.size.x = (health / max_health) * 32
        
        # Change color based on health percentage
        var health_percent = health / max_health
        if health_percent > 0.6:
            health_bar.color = Color(0, 0.8, 0, 1)  # Green
        elif health_percent > 0.3:
            health_bar.color = Color(0.8, 0.8, 0, 1)  # Yellow
        else:
            health_bar.color = Color(0.8, 0, 0, 1)  # Red 