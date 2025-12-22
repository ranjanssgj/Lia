extends Node

signal user_is_working
signal user_is_bored
signal user_is_active

var last_mouse_pos = Vector2()
var idle_time = 0.0

# Thresholds
const WORK_THRESHOLD = 5.0 
const BORED_THRESHOLD = 30.0 

# Track current state to prevent spamming signals
enum ActivityState { ACTIVE, WORKING, BORED }
var current_state = ActivityState.ACTIVE

func _process(delta):
	var current_mouse_pos = DisplayServer.mouse_get_position()
	var distance = current_mouse_pos.distance_to(last_mouse_pos)
	
	if distance < 5.0:
		idle_time += delta
	else:
		idle_time = 0.0 # Reset immediately on movement
		if current_state != ActivityState.ACTIVE:
			_set_state(ActivityState.ACTIVE)

	last_mouse_pos = current_mouse_pos
	
	# Logic: Deduce User State
	if idle_time > BORED_THRESHOLD:
		if current_state != ActivityState.BORED:
			_set_state(ActivityState.BORED)
			
	elif idle_time > WORK_THRESHOLD:
		if current_state != ActivityState.WORKING:
			_set_state(ActivityState.WORKING)

func _set_state(new_state):
	current_state = new_state
	match new_state:
		ActivityState.ACTIVE: emit_signal("user_is_active")
		ActivityState.WORKING: emit_signal("user_is_working")
		ActivityState.BORED: emit_signal("user_is_bored")
