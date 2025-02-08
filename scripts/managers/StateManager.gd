class_name StateManager
extends Node

signal state_changed(from_state: String, to_state: String)
signal event_handled(event_name: String)

# State configuration
var states: Dictionary = {
	"idle": {
		"enter": func(): _on_enter_idle(),
		"exit": func(): _on_exit_idle(),
		"transitions": {
			"move": "moving",
			"attack": "attacking",
			"die": "dead"
		}
	},
	"moving": {
		"enter": func(): _on_enter_moving(),
		"exit": func(): _on_exit_moving(),
		"transitions": {
			"stop": "idle",
			"attack": "attacking",
			"path_completed": "idle",
			"die": "dead"
		}
	},
	"attacking": {
		"enter": func(): _on_enter_attacking(),
		"exit": func(): _on_exit_attacking(),
		"transitions": {
			"attack_completed": "idle",
			"move": "moving",
			"die": "dead"
		}
	},
	"dead": {
		"enter": func(): _on_enter_dead(),
		"exit": func(): _on_exit_dead(),
		"transitions": {}  # No transitions out of dead state
	}
}

var current_state: String = "idle"
var previous_state: String = ""

func _ready() -> void:
	print("StateManager ready for: ", get_parent().name)
	# Call enter function for initial state
	var state = states[current_state]
	if "enter" in state:
		state.enter.call()

func transition_to(new_state: String) -> void:
	print("\nAttempting state transition for ", get_parent().name)
	print("From: ", current_state, " To: ", new_state)
	
	if not states.has(new_state):
		push_warning("Invalid state: " + new_state)
		return
	
	if new_state == current_state:
		print("Already in state: ", new_state)
		return
	
	# Check if transition is valid
	var current = states[current_state]
	if not current.transitions.has(new_state) and not current.transitions.values().has(new_state):
		push_warning("Invalid transition from " + current_state + " to " + new_state)
		print("Valid transitions from ", current_state, " are: ", current.transitions)
		return
	
	print("Transition valid, executing...")
	
	# Exit current state
	if "exit" in current:
		current.exit.call()
	
	# Update states
	previous_state = current_state
	current_state = new_state
	
	# Enter new state
	var new = states[new_state]
	if "enter" in new:
		new.enter.call()
	
	print("State transition complete: ", previous_state, " -> ", current_state)
	emit_signal("state_changed", previous_state, current_state)

func handle_event(event_name: String) -> void:
	print("\nHandling event: ", event_name, " in state: ", current_state)
	var current = states[current_state]
	if current.transitions.has(event_name):
		var new_state = current.transitions[event_name]
		print("Event triggers transition to: ", new_state)
		transition_to(new_state)
		emit_signal("event_handled", event_name)
	else:
		print("No transition defined for event: ", event_name, " in state: ", current_state)

func get_current_state() -> String:
	return current_state

func get_previous_state() -> String:
	return previous_state

func can_transition_to(state: String) -> bool:
	if not states.has(state):
		return false
	
	var current = states[current_state]
	return current.transitions.has(state) or current.transitions.values().has(state)

# Virtual state handlers - override in derived classes
func _on_enter_idle() -> void:
	print("Entering idle state")

func _on_exit_idle() -> void:
	print("Exiting idle state")

func _on_enter_moving() -> void:
	print("Entering moving state")

func _on_exit_moving() -> void:
	print("Exiting moving state")

func _on_enter_attacking() -> void:
	print("Entering attacking state")

func _on_exit_attacking() -> void:
	print("Exiting attacking state")

func _on_enter_dead() -> void:
	print("Entering dead state")

func _on_exit_dead() -> void:
	print("Exiting dead state") 