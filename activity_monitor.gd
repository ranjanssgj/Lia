extends Node

# SIGNALS
signal user_is_working # High APM/Typing
signal user_is_bored   # No input for X seconds
signal user_is_active  # Input detected

# PROPERTIES (This fixes your error)
var is_user_active = false
var last_input_time = 0.0
var time_since_input = 0.0

# THRESHOLDS
var idle_threshold = 5.0 # Seconds before considered "Idle"

func _input(event):
	# Detect any mouse or key press
	if event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton:
		last_input_time = Time.get_ticks_msec() / 1000.0
		
		# If we were previously idle, signal that we are active now
		if not is_user_active:
			is_user_active = true
			emit_signal("user_is_active")

func _process(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	time_since_input = current_time - last_input_time
	
	# Check if user has gone idle
	if time_since_input > idle_threshold and is_user_active:
		is_user_active = false
		emit_signal("user_is_bored")
