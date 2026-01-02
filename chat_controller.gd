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
	
	# SYSTEM PROMPT (Reinforcement)
	var user_name = Memory.context_data["user_name"]
	var system_prompt = """You are Lia, a loving desktop assistant. User: %s.
    
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
    
    Example: [WAVE] Hello!
    Example: [SIT_FOCUS] I am listening.
	""" % user_name
	
	var data = {
		"model": MODEL_NAME,
		"prompt": new_text,
		"system": system_prompt,
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
	var user_name = Memory.context_data["user_name"]
	var system_prompt = """You are Lia, the user's close friend and desktop assistant.
    User: %s.
    CURRENT SCENARIO: %s
    INSTRUCTIONS:
    1. Be proactive. YOU are starting this conversation.
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
    
    Example: [WAVE] Hello!
    Example: [SIT_FOCUS] I am listening.
	
    3. Keep it short (1 sentence).
	""" % [user_name, system_instruction]
	var data = {
		"model": MODEL_NAME,
		"prompt": "...", # Empty prompt triggers the system instruction
		"system": system_prompt,
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
	var found_anim
	
	var regex = RegEx.new()
	regex.compile("\\[(.*?)\\]") 
	var match = regex.search(full_response)
	
	if match:
		var tag = match.get_string()
		if tag in anim_map:
			found_anim = anim_map[tag]
		clean_text = full_response.replace(tag, "").strip_edges()
	
	if clean_text == "": clean_text = full_response
	output_label.text = "Lia: " + clean_text
	
	# PLAY ANIMATION
	if found_anim == "Hide":
		if main_node.has_method("force_hide"): main_node.force_hide()
	elif animator:
		# Check if animation exists to prevent crash
		if found_anim == null: 
			found_anim = "Talking"
		if animator.has_animation(found_anim):
			animator.play(found_anim)
		else:
			print("Lia Error: Animation missing -> ", found_anim)
			animator.play("Talking")
