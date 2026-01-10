class_name ChatController
extends Control

signal chat_started
signal chat_ended

# Set to TRUE to use Groq (Online, Fast), FALSE for Ollama (Offline)
const USE_GROQ = true 
var groq_api_key = ""

var main_node: Node 
# --- URLS ---
const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
const OLLAMA_MODEL = "lia-v3"
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
# Models: "llama-3.3-70b-versatile" (Smart) or "llama-3.1-8b-instant" (Fastest)
const MODEL_PRIMARY = "llama-3.3-70b-versatile" # Smart, but restricted
const MODEL_FALLBACK = "llama-3.1-8b-instant"   # Fast, generous limits

# --- NODES & VARIABLES ---
@onready var output_label = $PanelContainer/VBoxContainer/RichTextLabel
@onready var input_field = $PanelContainer/VBoxContainer/LineEdit
@onready var mode_toggle = $PanelContainer/VBoxContainer/ModeToggle
@onready var http = $OllamaRequest

var animator: AnimationPlayer
var udp_sender = PacketPeerUDP.new()
const PYTHON_TTS_PORT = 4243
const PYTHON_IP = "127.0.0.1"
var waiting_for_audio = false
var is_setup_mode = false
var conversation_history: Array = []
const MAX_HISTORY_LIMIT = 15
const TTS_CHAR_SPEED = 16.0

# --- SYSTEM PROMPT ---
const CORE_SYSTEM_PROMPT = """You are Lia, a smart, energetic, and teasing desktop companion. You are NOT a generic assistant.

    --- RULES FOR OUTPUT ---
    1. VARIETY: Use a variety of tags based on the context.
    
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
	"[JUMP]": "JoyfulJump", "[WAVE]": "Waving", "[KISS]": "Kiss",
	"[DANCE_HIP]": "HipHopDancing", "[DANCE_JAZZ]": "JazzDancing", 
	"[DANCE_RUMBA]": "RumbaDancing", "[RUMBA]": "RumbaDancing",
	"[LAY]": "FemaleLayingPose", "[SIT_CHILL]": "SittingIdle", 
	"[SIT_FOCUS]": "Sitting1", "[PRAY]": "Praying", "[SALUTE]": "Salute",
	"[SHOCK]": "Surprised", "[ANGRY]": "Angry", "[RUN]": "TreadmillRunning",
	"[WORKOUT_ABS]": "Situps", "[HANG]": "HangingIdle", "[HIDE]": "Hide",
	"[YAWN]": "Yawn", "[TALK]": "Talking", "[QUESTION]": "AskingQuestion",
	"[CRYING]": "anime_essential_2/mixamo_com",
	"[SADIDLE]": "anime_essential_2/SadIdle",
	"[SADWALK]": "anime_essential_2/SadWalk"
}

func _ready():
	_load_env()
	if not animator:
		if owner: animator = owner.find_child("AnimationPlayer", true, false)
		if not animator: animator = get_tree().root.find_child("AnimationPlayer", true, false)
	
	input_field.text_submitted.connect(_on_text_submitted)
	http.request_completed.connect(_on_request_completed)

	input_field.focus_entered.connect(_on_input_focus)
	input_field.focus_exited.connect(_on_input_unfocus)
	
	udp_sender.set_dest_address(PYTHON_IP, PYTHON_TTS_PORT)
	
	if "chat_log" in Memory.context_data:
		conversation_history = Memory.context_data["chat_log"]
		
	if Memory.context_data["user_name"] == "User":
		start_setup_mode()
	else:
		output_label.text = "Lia: Welcome back, " + Memory.context_data["user_name"] + "!"

func _send_sys_command(cmd: String):
	udp_sender.put_packet(cmd.to_utf8_buffer())

func _on_input_focus():
	_send_sys_command("__SYS__PAUSE_MIC")

func _on_input_unfocus():
	if input_field.text == "":
		_send_sys_command("__SYS__RESUME_MIC")

func _load_env():
	var env_path = "res://.env"
	if not OS.has_feature("editor"):
		env_path = OS.get_executable_path().get_base_dir() + "/.env"
		
	if FileAccess.file_exists(env_path):
		var file = FileAccess.open(env_path, FileAccess.READ)
		while not file.eof_reached():
			var line = file.get_line()
			if line.begins_with("GROQ_API_KEY="):
				groq_api_key = line.replace("GROQ_API_KEY=", "").strip_edges()
				print("Lia System: API Key loaded securely.")
				return
	
	print("Lia Error: Could not find .env file at ", env_path)


func start_setup_mode():
	is_setup_mode = true
	output_label.text = "Lia: Hello! I don't know your name yet.\nWhat should I call you?"

func get_history_string() -> String:
	var history_str = ""
	for msg in conversation_history:
		history_str += msg["role"] + ": " + msg["text"] + "\n"
	return history_str

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
	if animator and animator.has_animation("Talking"): animator.play("Talking")
	output_label.text = "You: " + new_text + "\n..."
	
	conversation_history.append({"role": "User", "text": new_text})
	input_field.release_focus()
	_send_sys_command("__SYS__RESUME_MIC")
	if USE_GROQ:
		_send_request_to_groq(new_text)
	else:
		_send_request_to_ollama(new_text)

func request_proactive_speech(system_instruction: String):
	if input_field.has_focus() or input_field.text != "": return
	emit_signal("chat_started")
	if animator: animator.play("Talking")
	
	if USE_GROQ:
		_send_request_to_groq(system_instruction, true)
	else:
		_send_request_to_ollama(system_instruction, true)

func _send_request_to_groq(input_text: String, is_proactive: bool = false, use_fallback: bool = false):
	if groq_api_key == "":
		output_label.text = "Lia: Error. No API Key."
		return
	var user_name = Memory.context_data["user_name"]
	var messages = []
	var event_prompt = "[SYSTEM EVENT: %s]\n(React naturally to this event. Do not mention you are an AI.)" % input_text
	var sys_content = CORE_SYSTEM_PROMPT + "\nUser Name: " + user_name
	messages.append({ "role": "system", "content": sys_content })
	
	for msg in conversation_history:
		var role = "user"
		if msg["role"] == "Lia": role = "assistant"
		messages.append({ "role": role, "content": msg["text"] })
		

	if is_proactive:
		messages.append({ "role": "user", "content": event_prompt })
	else:
		messages.append({ "role": "user", "content": input_text })
	var selected_model = MODEL_PRIMARY
	if use_fallback:
		selected_model = MODEL_FALLBACK
		print("Lia: Primary model exhausted. Switching to Fallback (8b).")

	var data = {
		"model": selected_model,
		"messages": messages,
		"temperature": 0.7,
		"max_tokens": 150 # Keep replies concise
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + groq_api_key
	]
	http.set_meta("fallback_active", use_fallback)
	http.set_meta("last_input", input_text)
	http.set_meta("is_proactive", is_proactive)
	http.request(GROQ_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(data))

# --- OLLAMA FUNCTION (OFFLINE) ---
func _send_request_to_ollama(input_text: String, is_proactive: bool = false):
	var full_prompt = ""
	if is_proactive:
		full_prompt = "PREVIOUS CONVERSATION:\n" + get_history_string() + "\n\n[SYSTEM EVENT]: " + input_text + "\nTASK: Respond naturally."
	else:
		full_prompt = "PREVIOUS CONVERSATION:\n" + get_history_string() + "\nUser: " + input_text

	var data = { 
		"model": OLLAMA_MODEL, 
		"prompt": full_prompt, 
		"system": CORE_SYSTEM_PROMPT + "\nUser Name: " + Memory.context_data["user_name"], 
		"stream": false 
	}
	var headers = ["Content-Type: application/json"]
	http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _on_request_completed(result, response_code, headers, body):
	input_field.editable = true
	if response_code == 429:
		var was_fallback = http.get_meta("fallback_active")
		if not was_fallback:
			# RETRY WITH FALLBACK MODEL
			var input = http.get_meta("last_input")
			var pro = http.get_meta("is_proactive")
			_send_request_to_groq(input, pro, true)
			return
		else:
			output_label.text = "Lia: Brain Overloaded (Both models busy)."
			emit_signal("chat_ended")
			return
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		var reply = ""
		
		# 1. PARSE GROQ (OpenAI Format)
		if USE_GROQ:
			if "choices" in json and json["choices"].size() > 0:
				reply = json["choices"][0]["message"]["content"]
		
		# 2. PARSE OLLAMA
		else:
			if "response" in json:
				reply = json["response"]
		
		if reply != "":
			parse_and_animate(reply)
		else:
			emit_signal("chat_ended")
	else:
		print("Lia Error: API Failed (Code %s)" % response_code)
		print("Body: ", body.get_string_from_utf8())
		output_label.text = "Lia: Brain Disconnected."
		emit_signal("chat_ended")

func parse_and_animate(full_response: String):
	print("AI RAW: ", full_response)
	
	var clean_text = ""
	var anim_schedule = [] # Stores: { "anim": "Wave", "delay": 2.5 }
	
	# 1. PARSE & CALCULATE TIMING
	# We iterate through the raw string to find tags AND build clean text simultaneously.
	var regex = RegEx.new()
	regex.compile("\\[(.*?)\\]")
	
	var results = regex.search_all(full_response)
	var current_raw_pos = 0
	
	for result in results:
		# A. Append text BEFORE this tag to clean_text
		var match_start = result.get_start()
		var pre_tag_text = full_response.substr(current_raw_pos, match_start - current_raw_pos)
		clean_text += pre_tag_text
		
		# B. Calculate Delay based on text length SO FAR
		var char_count = clean_text.length()
		var estimated_delay = char_count / TTS_CHAR_SPEED
		
		# C. Add to Schedule
		var tag_string = result.get_string()
		if tag_string in anim_map:
			anim_schedule.append({ 
				"name": anim_map[tag_string], 
				"delay": estimated_delay 
			})
			
		current_raw_pos = result.get_end()
	
	# Append any remaining text after the last tag
	clean_text += full_response.substr(current_raw_pos)
	clean_text = clean_text.strip_edges()
	
	if clean_text == "": clean_text = "..."
	
	# 2. UPDATE UI & SEND TO PYTHON (Full Sentence)
	output_label.text = "Lia: " + clean_text
	
	# Send FULL text to TTS (Natural Flow)
	var packet = clean_text.to_utf8_buffer()
	udp_sender.put_packet(packet)
	
	# 3. MEMORY UPDATE
	conversation_history.append({"role": "Lia", "text": clean_text})
	if conversation_history.size() > MAX_HISTORY_LIMIT: conversation_history.pop_front()
	Memory.context_data["chat_log"] = conversation_history
	Memory.save_memory()
	
	# 4. START ANIMATION SCHEDULER
	_execute_anim_schedule(anim_schedule)

# --- NEW SCHEDULER FUNCTION ---
func _execute_anim_schedule(schedule: Array):
	# Always start with talking/idle
	if animator: animator.play("Talking", 0.3)
	
	var current_time = 0.0
	
	for item in schedule:
		var target_time = item["delay"]
		var anim_name = item["name"]
		
		# How long to wait from NOW until this animation should play
		var wait_time = target_time - current_time
		
		if wait_time > 0:
			await get_tree().create_timer(wait_time).timeout
			current_time += wait_time
		
		# Play the scheduled animation
		if animator and animator.has_animation(anim_name):
			print("Playing Scheduled Anim: ", anim_name, " at ", current_time, "s")
			animator.play(anim_name, 0.3)
			
			# Optional: Return to "Talking" after the animation finishes
			# (Only if it's a one-shot action like Jump/Wave)
			var anim_len = animator.get_animation(anim_name).length
			# We don't await here because we want to stick to the schedule, 
			# but you could queue 'Idle' if needed.

	emit_signal("chat_ended")
