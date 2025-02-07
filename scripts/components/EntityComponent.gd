class_name EntityComponent
extends Node

# Reference to the parent entity
var entity: Node2D = null

func _ready() -> void:
	print("EntityComponent _ready called for ", get_class())
	# Get parent entity
	entity = get_parent()
	if not entity is Node2D:
		push_error("EntityComponent must be child of a Node2D")
		return
	
	# Call initialization after we have our entity reference
	call_deferred("_initialize")
	print("EntityComponent _ready completed for ", get_class())

# Virtual method for component-specific initialization
func _initialize() -> void:
	print("EntityComponent _initialize called for ", get_class())
	pass

# Virtual method for component updates
func process(delta: float) -> void:
	pass

# Virtual method for physics updates
func physics_process(delta: float) -> void:
	pass

# Virtual method for component cleanup
func cleanup() -> void:
	pass 