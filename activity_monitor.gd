class_name ActivityMonitor
extends Node

# --- SIGNALS ---
signal user_is_active  # Fired once when user wakes up
signal user_is_bored   # Fired once when user goes idle
signal user_is_working # Fired repeatedly while typing fast

# --- SETTINGS (Editable in Inspector) ---
@export var idle_threshold: float = 30.0 # Seconds of no input to be "Bored"
@export var work_threshold: int = 5      # Keystrokes per second to be "Working"

# --- STATE ---
var is_user_active: bool = true
var last_input_time: float = 0.0
var keystrokes: int = 0
var last_kps_check: float = 0.0

func _ready():
	last_input_time = Time.get_ticks_msec() / 1000.0
	set_process_input(true)

func _input(event):
	# 1. DETECT ACTIVITY
	if event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton:
		last_input_time = Time.get_ticks_msec() / 1000.0
		
		# Transition: Idle -> Active
		if not is_user_active:
			is_user_active = true
			print("Monitor: User Active")
			emit_signal("user_is_active")

		# 2. DETECT TYPING (For "Working" logic)
		if event is InputEventKey and event.pressed and not event.echo:
			keystrokes += 1

func _process(delta):
	var time = Time.get_ticks_msec() / 1000.0
	
	# CHECK 1: IDLE TIMEOUT
	if is_user_active and (time - last_input_time) > idle_threshold:
		is_user_active = false
		print("Monitor: User Bored/Idle")
		emit_signal("user_is_bored")

	# CHECK 2: WORK INTENSITY (Check every 1 second)
	if (time - last_kps_check) > 1.0:
		if keystrokes >= work_threshold:
			emit_signal("user_is_working")
		
		# Reset for next second
		keystrokes = 0
		last_kps_check = time
