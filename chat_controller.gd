extends Control

const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
const MODEL_NAME = "lia-v3" 

@onready var output_label = $PanelContainer/VBoxContainer/RichTextLabel
@onready var input_field = $PanelContainer/VBoxContainer/LineEdit
@onready var http = $OllamaRequest
@onready var main_node = get_tree().current_scene 

var animator: AnimationPlayer
var is_setup_mode = false 

# --- ANIMATION MAP ---
var anim_map = {
	"[JUMP]": "Jump", "[WAVE]": "Wave", "[KISS]": "Kiss",
	"[DANCE_HIP]": "Dance_Hip", "[DANCE_JAZZ]": "Dance_Jazz", 
	"[DANCE_RUMBA]": "Dance_Rumba", "[LAY]": "Lay_Down", 
	"[SIT_CHILL]": "Sit_Chill", "[SIT_FOCUS]": "Sit_Focus", 
	"[PRAY]": "Pray", "[SALUTE]": "Salute", "[SHOCK]": "Shock", 
	"[ANGRY]": "Angry", "[RUN]": "Run", "[WORKOUT_ABS]": "Workout_Abs", 
	"[HANG]": "Hang", "[HIDE]": "Hide", "[YAWN]": "Yawn",
	"[CRYING]": "Crying", "[SADIDLE]": "Sad_Idle", "[SADWALK]": "Sad_Walk",
	"[TALK]": "Idle_Talk" 
}

func _ready():
	if owner: animator = owner.find_child("AnimationPlayer", true, false)
	if not animator: animator = get_tree().root.find_child("AnimationPlayer", true, false)

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
	
	# --- SETUP MODE ---
	if is_setup_mode:
		Memory.context_data["user_name"] = new_text.strip_edges()
		Memory.save_memory()
		output_label.text = "Lia: Nice to meet you, " + new_text + "!"
		is_setup_mode = false
		return

	# --- CHAT MODE ---
	if main_node: main_node.is_chatting = true
	if animator: animator.play("Thinking") 
	
	output_label.text = "You: " + new_text + "\n..."
	input_field.editable = false
	
	# --- SYSTEM PROMPT INJECTION (The Fix) ---
	# Even though the model is fine-tuned, we force the format via API to be safe.
	var user_name = Memory.context_data["user_name"]
	var system_prompt = """You are Lia, a loving desktop assistant.
    User Name: %s
    INSTRUCTIONS:
    1. Start EVERY response with one of these tags: [JUMP], [WAVE], [KISS], [DANCE_HIP], [DANCE_JAZZ], [DANCE_RUMBA], [LAY], [SIT_CHILL], [SIT_FOCUS], [PRAY], [SALUTE], [SHOCK], [ANGRY], [RUN], [WORKOUT_ABS], [HANG], [HIDE], [YAWN], [CRYING], [SADIDLE], [SADWALK].
    2. Example: [WAVE] Hello there!
    3. Do not output anything else before the tag.
	""" % user_name
	
	var data = {
		"model": MODEL_NAME,
		"prompt": new_text,
		"system": system_prompt, # <--- Explicitly sending instructions again
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
		output_label.text = "Lia: Error connecting to Brain (Ollama)."
		print("Ollama Error: ", response_code)
		if main_node: main_node.is_chatting = false

func parse_and_animate(full_response: String):
	var clean_text = full_response
	var found_anim = "Idle_Talk" 
	
	var regex = RegEx.new()
	regex.compile("\\[(.*?)\\]") 
	var match = regex.search(full_response)
	
	if match:
		var tag = match.get_string()
		if tag in anim_map:
			found_anim = anim_map[tag]
		# Clean the text
		clean_text = full_response.replace(tag, "").strip_edges()
	
	# Fail-safe: If model forgets tag, still show text
	if clean_text == "": clean_text = full_response

	output_label.text = "Lia: " + clean_text
	
	if found_anim == "Hide":
		if main_node.has_method("force_hide"): main_node.force_hide()
	elif animator:
		animator.play(found_anim, 0.2)
