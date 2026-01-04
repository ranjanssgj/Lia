extends Control

# --- SIGNALS ---
signal chat_started # Tells Main to lock the body
signal chat_ended   # Tells Main to unlock (on errors)

const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
const MODEL_NAME = "lia-v3"

@onready var output_label = $PanelContainer/VBoxContainer/RichTextLabel
@onready var input_field = $PanelContainer/VBoxContainer/LineEdit
@onready var http = $OllamaRequest

# --- DEPENDENCY INJECTION (Assigned by main.gd) ---
var animator: AnimationPlayer 
var main_node: Node 
var is_setup_mode = false 
var conversation_history: Array = [] 
const MAX_HISTORY_LIMIT = 10
var udp_sender = PacketPeerUDP.new()
const PYTHON_TTS_PORT = 4243
const PYTHON_IP = "127.0.0.1"
const CORE_SYSTEM_PROMPT = """You are Lia, a cheerful loving partner.
    
    INSTRUCTIONS:
    1. Analyze the EMOTION of your reply.
    2. Start the response with the matching tag from this list:
    
    -- HAPPY / EXCITED --
    [JUMP] - Success, big news, excitement.
    [DANCE_HIP] - Celebration, partying, winning.
    [DANCE_JAZZ] - Playful, music, fun.
    [DANCE_RUMBA] - Elegant, sweet, charming.
    
    -- AFFECTIONATE --
    [KISS] - Love, gratitude, comforting the user.
    [WAVE] - Hello, goodbye, welcoming.
    
    -- RELAXED / PASSIVE --
    [LAY] - Tired, watching movies, chilling.
    [SIT_CHILL] - Casual chat, listening, waiting.
    [YAWN] - Sleepy, late night, bored.
    [HANG] - Idling, waiting for download.
    
    -- WORK / SERIOUS --
    [SIT_FOCUS] - Working, studying, deep thought.
	[SALUTE] - Acknowledging orders, "Yes Commander", starting tasks.
    [PRAY] - Hoping, wishing for luck, nervous.
    
    -- NEGATIVE --
    [ANGRY] - Scolding, annoyed, defending yourself.
    [SHOCK] - Surprised, confused, sudden news.
    [CRYING] - Sad news, heartbreak, grief.
    [SADIDLE] - Gloomy, bad day, low energy.
    [SADWALK] - Leaving, wanting space, depression.
    
    -- ACTION --
    [RUN] - Late, hurry, emergency.
    [WORKOUT_ABS] - Gym, exercise, motivation.
    [HIDE] - Scared, user needs privacy.
	[QUESTION] - You are asking a question from user.
    
    Example: [WAVE] Hello!
    Example: [SIT_FOCUS] I am listening.
	"""
	
var anim_map = {
	"[JUMP]":              "JoyfulJump",
	"[WAVE]":              "Waving",
	"[KISS]":              "Kiss",
	"[DANCE_HIP]":         "HipHopDancing",
	"[DANCE_JAZZ]":        "JazzDancing",
	"[DANCE_RUMBA]":       "RumbaDancing",
	"[RUMBA]":             "RumbaDancing", 
	"[HIPHOP]":            "HipHopDancing", # Safety alias
	"[JAZZ]":              "JazzDancing",   # Safety alias
	"[LAY]":               "FemaleLayingPose",
	"[SIT_CHILL]":         "SittingIdle",
	"[SIT_FOCUS]":         "Sitting1",
	"[PRAY]":              "Praying",
	"[SALUTE]":            "Salute",
	"[SHOCK]":             "Surprised",
	"[ANGRY]":             "Angry",
	"[RUN]":               "TreadmillRunning",
	"[WORKOUT_ABS]":       "Situps",
	"[HANG]":              "HangingIdle",
	"[HIDE]":              "Hide", 
	"[YAWN]":              "Yawn",
	"[TALK]":              "Talking",
	"[QUESTION]":          "AskingQuestion",
	"[CRYING]":            "anime_essential_2/mixamo_com", 
	"[SADIDLE]":           "anime_essential_2/SadIdle",
	"[SADWALK]":           "anime_essential_2/SadWalk"
}

func _ready():
	input_field.text_submitted.connect(_on_text_submitted)
	http.request_completed.connect(_on_request_completed)
	
	if Memory.context_data["user_name"] == "User":
		start_setup_mode()
	else:
		output_label.text = "Lia: Welcome back, " + Memory.context_data["user_name"] + "!"
	if "chat_log" in Memory.context_data:
		conversation_history = Memory.context_data["chat_log"]
	udp_sender.set_dest_address(PYTHON_IP, PYTHON_TTS_PORT)

func start_setup_mode():
	is_setup_mode = true
	output_label.text = "Lia: Hello! I don't know your name yet.\nWhat should I call you?"

func _on_text_submitted(new_text: String):
	if new_text.strip_edges() == "": return
	input_field.clear()
	
	if is_setup_mode:
		Memory.context_data["user_name"] = new_text.strip_edges()
		Memory.save_memory()
		output_label.text = "Lia: Nice to meet you, " + new_text + "!"
		is_setup_mode = false
		return
		
	emit_signal("chat_started")

	if animator and animator.has_animation("Talking"): 
		animator.play("Talking") # Default loop while thinking
	
	output_label.text = "You: " + new_text + "\n..."
	input_field.editable = false
	
	conversation_history.append({"role": "User", "text": new_text})
	var full_prompt = "PREVIOUS CONVERSATION:\n" + get_history_string() + "\nUser: " + new_text
	
	var data = {
		"model": MODEL_NAME,
		"prompt": full_prompt,
		"system": CORE_SYSTEM_PROMPT,
		"stream": false 
	}
	
	var headers = ["Content-Type: application/json"]
	http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	
# --- PROACTIVE MODE ---
func request_proactive_speech(system_instruction: String):
	# If the user is currently typing, ABORT. Don't be annoying.
	if input_field.has_focus() or input_field.text != "":
		return

	emit_signal("chat_started")
	
	# Contextual Prompt
	var pro_prompt = """
	[SYSTEM EVENT]: %s
	
	INSTRUCTIONS:
	- This is a System event, meaning messages were based on system data
	- Respond to the User immediately.
	- Be warm and natural.
	- START with a valid tag from this list - ['[JUMP]', '[WAVE]', '[KISS]', '[DANCE_HIP]', '[DANCE_JAZZ]', '[DANCE_RUMBA]', '[RUMBA]', '[HIPHOP]', '[JAZZ]', '[LAY]', '[SIT_CHILL]', '[SIT_FOCUS]', '[PRAY]', '[SALUTE]', '[SHOCK]', '[ANGRY]', '[RUN]', '[WORKOUT_ABS]', '[HANG]', '[HIDE]', '[YAWN]', '[TALK]', '[QUESTION]', '[CRYING]', '[SADIDLE]', '[SADWALK]'].
	- Keep it short (under 15 words).
	""" % system_instruction
	
	
	var data = {
		"model": MODEL_NAME,
		"prompt": "...",
		"system": pro_prompt,
		"stream": false
	}
	var headers = ["Content-Type: application/json"]
	http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _on_request_completed(result, response_code, headers, body):
	input_field.editable = true
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		var raw_response = json["response"]
		parse_and_animate(raw_response)
	else:
		output_label.text = "Lia: Brain Disconnected (Ollama Error)."
		emit_signal("chat_ended")

func parse_and_animate(full_response: String):
	print("AI RAW: ", full_response)
	var clean_text = full_response
	var found_animations = [] # List to store the sequence of animations
	var regex = RegEx.new()
	regex.compile("\\[(.*?)\\]") 
	var results = regex.search_all(full_response)
	for result in results:
		var tag = result.get_string()
		
		# Add to animation list if valid
		if tag in anim_map:
			found_animations.append(anim_map[tag])
			
		# Remove tag from the visible text
		clean_text = clean_text.replace(tag, "")

	# 2. UPDATE UI & MEMORY
	clean_text = clean_text.strip_edges()
	if clean_text == "": clean_text = "..." # Fallback if message was only tags
	output_label.text = "Lia: " + clean_text
	var packet = clean_text.to_utf8_buffer()
	udp_sender.put_packet(packet)
	conversation_history.append({"role": "Lia", "text": clean_text}) # Save clean text to memory
	if conversation_history.size() > MAX_HISTORY_LIMIT:
		conversation_history.pop_front()
	Memory.context_data["chat_log"] = conversation_history
	Memory.save_memory()
	
	# 3. PLAY ANIMATION QUEUE
	if animator:
		_play_smooth_sequence(found_animations)

# Helper to handle the specific "Hide" logic vs normal animations
func _play_or_hide(anim_name: String):
	if anim_name == "Hide":
		if main_node and main_node.has_method("force_hide"): 
			main_node.force_hide()
	elif animator.has_animation(anim_name):
		animator.play(anim_name)
	else:
		print("Lia Error: Animation missing -> ", anim_name)
		animator.play("Talking")
		
func get_history_string() -> String:
	var history_str = ""
	for msg in conversation_history:
		history_str += msg["role"] + ": " + msg["text"] + "\n"
	return history_str
	
func _play_smooth_sequence(anim_list: Array):
	if anim_list.is_empty():
		animator.play("Talking", 0.2)
		return

	# Loop through animations and blend them manually
	for anim_name in anim_list:
		if anim_name == "Hide":
			if main_node and main_node.has_method("force_hide"): main_node.force_hide()
		elif animator.has_animation(anim_name):
			animator.play(anim_name, 0.2)
			var length = animator.get_animation(anim_name).length
			var wait_time = max(0.1, length - 0.2) # Don't wait negative time
			await get_tree().create_timer(wait_time).timeout
		else:
			animator.play("Talking", 0.2)
	emit_signal("chat_ended")
