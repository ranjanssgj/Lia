extends Control

const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
const MODEL_NAME = "llama3.2:1b"

@onready var output_label = $PanelContainer/VBoxContainer/RichTextLabel
@onready var input_field = $PanelContainer/VBoxContainer/LineEdit
@onready var http = $OllamaRequest

# Reference to the Memory Manager (Autoload)
# Go to Project -> Project Settings -> Autoload -> Add "res://memory_manager.gd" as "Memory"
var animator: AnimationPlayer

func _ready():
	if owner: animator = owner.find_child("AnimationPlayer", true, false)
	if not animator: animator = get_tree().root.find_child("AnimationPlayer", true, false)

	input_field.text_submitted.connect(_on_text_submitted)
	http.request_completed.connect(_on_request_completed)
	
	# Greet using memory
	output_label.text = "Lia: Hi " + Memory.context_data["user_name"] + "!"

func _on_text_submitted(new_text: String):
	if new_text.strip_edges() == "": return
	
	output_label.text = "You: " + new_text + "\n..."
	input_field.clear()
	input_field.editable = false
	
	# 1. GET CONTEXT FROM MEMORY
	var context_block = Memory.get_system_context()
	
	# 2. CONSTRUCT DYNAMIC PROMPT
	var system_prompt = """
	You are Lia, a desktop companion. 
	%s
	
	INSTRUCTIONS:
	- Keep replies short (under 15 words).
	- Respond to the user's input based on the Context above.
	- START your reply with an emotion tag.
	
	TAGS (Choose ONE):
	[WORK] - If user mentions working/studying.
	[HAPPY] - Positive/Excited.
	[ANGRY] - Negative/Insulted.
	[WAVE] - Hello/Goodbye.
	[DANCE] - Celebration.
	[TIRED] - Boredom/Sleep.
	[IDLE] - Default/Neutral.
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
	
	if response_code != 200:
		output_label.text = "Error: AI disconnected."
		print("HTTP Error: ", response_code)
		return

	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result == OK:
		var response = json.get_data()
		if "response" in response:
			var raw_text = response["response"]
			print("AI RAW OUTPUT: ", raw_text) # DEBUG: Check this in console!
			parse_and_animate(raw_text)
		else:
			print("Error: JSON missing 'response' key")
	else:
		output_label.text = "Error parsing JSON."

func parse_and_animate(text: String):
	var clean_text = text
	var emotion = "Idle" # Default
	
	# Tag Mapping
	var tags = {
		"[WORK]": "Salute",
		"[HAPPY]": "JoyfulJump",
		"[ANGRY]": "Angry",
		"[WAVE]": "Waving",
		"[DANCE]": "HipHopDancing",
		"[TIRED]": "Yawn",
		"[IDLE]": "Idle"
	}
	
	# Find the first matching tag
	for tag in tags:
		if tag in text:
			emotion = tags[tag]
			clean_text = text.replace(tag, "")
			break
	
	# Update UI
	output_label.text = "Lia: " + clean_text.strip_edges()
	
	# Play Animation (Only if it exists)
	if animator and animator.has_animation(emotion):
		# Prevent restarting the same animation if it's already looping
		if animator.current_animation != emotion:
			animator.play(emotion)
			animator.queue("Idle")
