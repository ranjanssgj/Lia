extends Node

@onready var chat_controller = $"../Lia/Node/Armature/Skeleton3D/Face/ChatBubble" # Update path if needed
@onready var activity_monitor = $"../ActivityMonitor"

# --- SETTINGS ---
var check_interval = 5.0 # Check "Vibe" every 5 seconds (Fast reaction)
var speech_cooldown = 0.0 # Timer to prevent spamming
var silence_timer = 0.0 # How long since LIA last spoke

# --- STATE ---
var has_greeted = false

func _ready():
	# 1. STARTUP GREETING (Immediate)
	await get_tree().create_timer(2.0).timeout # Wait for model to load
	trigger_speech("You just booted up. Give a warm, cute welcome based on the time of day.")
	has_greeted = true

	# 2. THE "VIBE CHECK" LOOP
	var timer = Timer.new()
	timer.wait_time = check_interval
	timer.autostart = true
	timer.timeout.connect(_check_vibe)
	add_child(timer)

func _process(delta):
	if speech_cooldown > 0: speech_cooldown -= delta
	silence_timer += delta

func _check_vibe():
	if speech_cooldown > 0: return
	
	# Don't interrupt if user is already typing or she is speaking
	# (Assuming chat_controller has a boolean 'is_speaking' or we check UI visibility)
	if chat_controller.input_field.text != "": return 

	var time = Time.get_time_dict_from_system()
	
	# --- TRIGGER 1: The "Silence Breaker" (Friend Logic) ---
	# If nobody has spoken for 5 minutes, say something random.
	if silence_timer > 300.0:
		trigger_speech("It has been quiet for a while. Say a random thought, a joke, or ask the user a random question to break the silence.")
		return

	# --- TRIGGER 2: Late Night Company ---
	if time.hour >= 1 and time.hour < 5 and randf() < 0.05: # Low chance per check
		trigger_speech("It is very late (past 1 AM). Softly ask the user why they are still awake.")
		return

	# --- TRIGGER 3: Activity Reaction (You are ignoring her) ---
	# If user is working (active) but hasn't talked to Lia for 15 mins
	if activity_monitor.is_user_active and silence_timer > 900.0:
		trigger_speech("The user is working hard and ignoring you. Pout playfully or ask for attention.")
		return

	# --- TRIGGER 4: Random "Alive" Moments ---
	# 1% chance every 5 seconds to just do something cute
	if randf() < 0.01: 
		trigger_speech("You are bored. Hum a tune, talk about the weather, or compliment the user out of nowhere.")
		return

func trigger_speech(system_instruction: String):
	print("PROACTIVE EVENT: ", system_instruction)
	
	# Reset timers
	speech_cooldown = 120.0 # Wait at least 2 mins before auto-speaking again
	silence_timer = 0.0 
	
	# Send to Voice
	if chat_controller:
		chat_controller.generate_proactive_response(system_instruction)
