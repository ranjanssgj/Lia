extends Node

# Signals to tell Main what to do
signal user_is_working
signal user_is_bored
signal user_is_active

var last_mouse_pos = Vector2()
var idle_time = 0.0
var mouse_speed = 0.0

# Thresholds
const WORK_THRESHOLD = 5.0 # Seconds of low movement (Reading/Thinking)
const BORED_THRESHOLD = 30.0 # Seconds of NO movement
const ACTIVE_THRESHOLD = 100.0 # Mouse pixels per frame (High activity)

func _process(delta):
	var current_mouse_pos = DisplayServer.mouse_get_position()
	var distance = current_mouse_pos.distance_to(last_mouse_pos)
	mouse_speed = distance / delta
	
	if distance < 5.0:
		idle_time += delta
	else:
		idle_time = 0.0 # Reset if mouse moves
		emit_signal("user_is_active")

	last_mouse_pos = current_mouse_pos
	
	# Logic: Deduce User State
	if idle_time > BORED_THRESHOLD:
		# User is AFK
		emit_signal("user_is_bored")
	elif idle_time > WORK_THRESHOLD and idle_time < BORED_THRESHOLD:
		# User is moving mouse very little (likely reading or typing)
		emit_signal("user_is_working")
