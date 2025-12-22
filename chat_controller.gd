extends Control

const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
const MODEL_NAME = "llama3.2:1b"

@onready var output_label = $PanelContainer/VBoxContainer/RichTextLabel
@onready var input_field = $PanelContainer/VBoxContainer/LineEdit
@onready var http = $OllamaRequest

# Reference to Memory (Autoload)
var animator: AnimationPlayer
var is_setup_mode = false # Are we currently asking for the name?

func _ready():
	if owner: animator = owner.find_child("AnimationPlayer", true, false)
	if not animator: animator = get_tree().root.find_child("AnimationPlayer", true, false)

	input_field.text_submitted.connect(_on_text_submitted)
	http.request_completed.connect(_on_request_completed)
	
	# --- FIRST RUN CHECK ---
	# Check if the user is still named "User" (Default)
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
	
	# --- HANDLE SETUP MODE (Name Input) ---
	if is_setup_mode:
		# Save the name
		var name = new_text.strip_edges()
		Memory.context_data["user_name"] = name
		Memory.save_memory() # Write to disk
		
		output_label.text = "Lia: Nice to meet you, " + name + "!\n(Context Saved)"
		is_setup_mode = false # Switch back to normal chat
		return

	# --- NORMAL CHAT MODE ---
	output_label.text = "You: " + new_text + "\n..."
	input_field.editable = false
	
	var context_block = Memory.get_system_context()
	
	# Updated prompt to force TEXT after the tag
	var system_prompt = """
	You are Lia. 
	%s
	
	INSTRUCTIONS:
	1. You MUST include a text reply after the tag.
	2. Keep it cute and short.
	3. Format: [TAG] Your Message Here.
	
	TAGS:
	[WORK] - User is working.
	[HAPPY] - Excited.
	[ANGRY] - Mad.
	[WAVE] - Hello/Bye.
	[DANCE] - Celebrate.
	[IDLE] - Normal chat.
	""" % context_block

	var data = {
		"model": MODEL_NAME,
		"prompt": new_text,
		"system": system_prompt,
		"stream": false 
	}
	
	var headers = ["Content-Type: application/json"]
	http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _on_request_completed(result, response_code, headers, body):
	input_field.editable = true
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response = json.get_data()
			var raw_text = response["response"]
			parse_and_animate(raw_text)

func parse_and_animate(text: String):
	var clean_text = text
	var emotion = "Idle" 
	
	var tags = {
		"[WORK]": "Salute",
		"[HAPPY]": "JoyfulJump",
		"[ANGRY]": "Angry",
		"[WAVE]": "Waving",
		"[DANCE]": "HipHopDancing",
		"[TIRED]": "Yawn",
		"[IDLE]": "Idle"
	}
	
	# Improved Parser: Finds the tag, plays animation, removes tag from text
	for tag in tags:
		if text.contains(tag): # 'contains' is safer than 'in' for some string types
			emotion = tags[tag]
			clean_text = text.replace(tag, "") # Remove the tag
			break
	
	# If the AI forgot to write text and only sent "[TAG]", handle it gracefully
	if clean_text.strip_edges() == "":
		clean_text = "..." # Or some default "I'm listening" text
	
	output_label.text = "Lia: " + clean_text.strip_edges()
	
	if emotion == "Hide":
		var main_node = get_tree().current_scene
		if main_node.has_method("force_hide"):
			main_node.force_hide()
	
	elif animator and animator.has_animation(emotion):
		# TELL MAIN WE ARE CHATTING
		var main_node = get_tree().current_scene
		if "is_chatting" in main_node:
			main_node.is_chatting = true
			
		if animator.current_animation != emotion:
			animator.play(emotion)
