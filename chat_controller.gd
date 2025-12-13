extends Control

# --- CONFIGURATION ---
# The URL where Ollama lives locally
const OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
# The model you downloaded (Check your terminal 'ollama list' if unsure)
const MODEL_NAME = "llama3.2:1b"

# --- NODES ---
@onready var output_label = $PanelContainer/VBoxContainer/RichTextLabel
@onready var input_field = $PanelContainer/VBoxContainer/LineEdit
@onready var http = $OllamaRequest

var animator: AnimationPlayer

func _ready():
	
	if owner:
		animator = owner.find_child("AnimationPlayer", true, false)
	
	# Fallback: If owner fails, try searching parents manually
	if not animator:
		animator = get_tree().root.find_child("AnimationPlayer", true, false)
		
	if animator:
		print("Lia: Body connected to Brain.")
	else:
		print("Lia ERROR: Could not find AnimationPlayer!")
	# Connect the "Enter Key" signal from the input box
	input_field.text_submitted.connect(_on_text_submitted)
	
	# Connect the "Response Received" signal from the HTTP node
	http.request_completed.connect(_on_request_completed)
	
	output_label.text = "Lia: Online. Say hi!"

# --- SENDING THE MESSAGE ---
func _on_text_submitted(new_text: String):
	if new_text.strip_edges() == "":
		return # Don't send empty messages
	
	# 1. Update UI
	output_label.text = "You: " + new_text + "\nLia is thinking..."
	input_field.clear()
	input_field.editable = false # Lock input while thinking
	
	var system_prompt = """
	You are Lia, a desktop companion. Keep replies short and cute.
	Use these tags at the START of your sentence to act:
	[SALUTE] - If the user says they are working/busy.
	[HAPPY] - If excited or laughing.
	[ANGRY] - If insulted or mad.
	[WAVE] - Hello or Goodbye.
	[DANCE] - If asked to dance or celebrating.
	[KISS] - Affectionate.
	[TIRED] - If it's late or you are bored.
	[EXERCISE] - If talking about fitness.
	[HIDE] - If told to go away.
	"""
	
	# 2. Prepare the Data (JSON)
	# We send 'stream': false so we get the whole sentence at once, not letter-by-letter
	var data = {
		"model": MODEL_NAME,
		"prompt": new_text,
		"system": system_prompt,  # <--- THIS IS THE FINE TUNING
		"stream": false 
	}
	
	# 3. Convert to JSON String
	var json_payload = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	
	# 4. Fire the request!
	var error = http.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, json_payload)
	
	if error != OK:
		output_label.text = "Error: Could not connect to Ollama."
		input_field.editable = true

# --- RECEIVING THE REPLY ---
func _on_request_completed(result, response_code, headers, body):
	input_field.editable = true # Unlock input
	
	if response_code == 200:
		# 1. Decode the raw data
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			var response_data = json.get_data()
			# 2. Extract the actual speech
			var ai_reply = response_data["response"]
			output_label.text = "Lia: " + ai_reply
			parse_and_animate(ai_reply)
		else:
			output_label.text = "Error: Could not parse AI brain."
	else:
		output_label.text = "Error: Ollama returned code " + str(response_code)
		
				
func parse_and_animate(text: String):
	var clean_text = text
	var emotion = "Idle" 
	
	# Mapped to your specific Animation Names
	var tags = {
		"[SALUTE]": "Salute",
		"[HAPPY]": "JoyfulJump",     # Or 'Excited' / 'Happy'
		"[ANGRY]": "Angry",
		"[WAVE]": "Waving",          # Or 'Waving1'
		"[DANCE]": "HipHopDancing",  # Or 'JazzDancing' / 'RumbaDancing'
		"[KISS]": "Kiss",
		"[TIRED]": "Yawn",
		"[EXERCISE]": "Situps",      # Or 'PushUp'
		"[SURPRISE]": "Surprised",
		"[TALK]": "Talking",
		"[QUESTION]": "AskingQuestion",
		"[HIDE]": "Hide"
	}
	
	# Check for tags
	for tag in tags:
		if tag in text:
			emotion = tags[tag]
			clean_text = text.replace(tag, "")
			break
	
	output_label.text = "Lia: " + clean_text.strip_edges()
	print(emotion) #TEMPORARY
	
	if emotion == "Hide":
		var main_node = get_tree().current_scene
		if main_node.has_method("force_hide"):
			main_node.force_hide()
	
	elif animator and animator.has_animation(emotion):
		# If dancing/exercise, let it play longer (queue idle later)
		animator.play(emotion)
		animator.queue("Idle")
