class_name ProactiveModule
extends Node

@onready var chat_controller = $"../Lia/Node/Armature/Skeleton3D/Face/ChatBubble"
@onready var activity_monitor = $"../ActivityMonitor"

var vibe_check_interval = 10.0 
# Minimum seconds between Lia speaking (prevent spam)
var speech_cooldown = 0.0 
# Chance (0.0 to 1.0) to speak when checking vibe
var random_talk_chance = 0.15 # 15% chance every 10s (Much higher!)

# --- STATE TRACKING ---
var silence_duration = 0.0 # Time since LIA last spoke
var user_idle_duration = 0.0 # Time since USER last moved
var has_greeted_morning = false
var has_greeted_night = false
var is_waiting_for_response = false

func _ready():
	# 1. WAIT FOR SYSTEMS TO BOOT
	await get_tree().create_timer(2.0).timeout
	if chat_controller:
		if not chat_controller.is_connected("chat_ended", _on_chat_ended):
			chat_controller.chat_ended.connect(_on_chat_ended)
	# 2. CONNECT TO SENSES (Event-Driven!)
	if activity_monitor:
		if not activity_monitor.is_connected("user_is_working", _on_user_working_hard):
			activity_monitor.user_is_working.connect(_on_user_working_hard)
		if not activity_monitor.is_connected("user_is_active", _on_user_returned):
			activity_monitor.user_is_active.connect(_on_user_returned)
	
	# 3. START THE "INTERNAL CLOCK"
	var timer = Timer.new()
	timer.wait_time = vibe_check_interval
	timer.autostart = true
	timer.timeout.connect(_on_vibe_check)
	add_child(timer)
	
	# 4. IMMEDIATE WELCOME
	_trigger("System startup. Give a warm welcome.")

func _process(delta):
	if speech_cooldown > 0: speech_cooldown -= delta
	silence_duration += delta
	
	# Track user idle time separately
	if activity_monitor and not activity_monitor.is_user_active:
		user_idle_duration += delta
	else:
		user_idle_duration = 0.0

func _on_chat_ended():
	is_waiting_for_response = false
	silence_duration = 0.0

# 1. EVENT: User is typing furiously
func _on_user_working_hard():
	if speech_cooldown > 0: return
	# Only interrupt if we haven't spoken in a minute
	if silence_duration > 60.0:
		_trigger("User is typing really fast. Cheer them on or tell them to breathe!")

# 2. EVENT: User came back after being gone
func _on_user_returned():
	# If they were gone for more than 5 mins
	if user_idle_duration > 300.0 and speech_cooldown <= 0:
		_trigger("User just came back to the computer. Welcome them back!")

# 3. TIMER: The "Vibe Check" (Runs every 10 seconds)
func _on_vibe_check():
	if speech_cooldown > 0: return
	
	# Don't speak if user is typing a message to you right now
	if chat_controller and chat_controller.input_field.text != "": return

	var time = Time.get_time_dict_from_system()
	var roll = randf() # 0.0 to 1.0

	# A. SILENCE BREAKER (If quiet for 90 seconds)
	if silence_duration > 90.0 and roll < 0.2:
		var prompts = [
			"Ask the user what they are thinking about.",
			"Hum a random tune or make a cute noise.",
			"Comment on how quiet it is.",
            "Ask if the user wants to see a dance."
		]
		_trigger(prompts.pick_random())
		return

	# B. WATCHING YOU (User active but silent for 3 mins)
	if activity_monitor.is_user_active and silence_duration > 180.0 and roll < 0.3:
		_trigger("User is staring at the screen silently. Ask what they are looking at.")
		return

	# C. TIME AWARENESS (Morning/Night)
	if time.hour >= 6 and time.hour < 10 and not has_greeted_morning:
		_trigger("It is morning time. Wish the user a great day ahead!")
		has_greeted_morning = true
		return
		
	if time.hour >= 23 and not has_greeted_night:
		_trigger("It is getting very late. Concernedly tell the user to get some sleep.")
		has_greeted_night = true
		return

	# D. PURE RANDOMNESS (Just because!)
	if roll < random_talk_chance:
		_trigger("Say something random, funny, or affectionate to your best friend.")

# --- HELPER ---
func _trigger(instruction: String):
	print("PROACTIVE TRIGGER: ", instruction)
	is_waiting_for_response = true
	silence_duration = 0.0
	# Don't speak again for 45 seconds to let the user breathe
	speech_cooldown = 45.0 
	
	if chat_controller:
		chat_controller.request_proactive_speech(instruction)
