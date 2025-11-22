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
	
	var system_prompt = "You are Lia, a virtual desktop companion. " + \
	"Keep replies short (max 20 words). " + \
	"Start replies with one of these tags if suitable: " + \
	"[WAVE] (Hello/Bye), [HAPPY] (Positive), [ANGRY] (Negative), " + \
	"[SURPRISED] (Shock), [BLUSH] (Shy), [THINK] (Reasoning), [HIDE] (Dismissal). " + \
	"Example: '[WAVE] Hi there! How can I help?'"
	
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
		else:
			output_label.text = "Error: Could not parse AI brain."
	else:
		output_label.text = "Error: Ollama returned code " + str(response_code)
		
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			# --- THIS WAS MISSING ---
			# We must define 'response' by getting the data from the JSON object
			var response = json.get_data()
			# ------------------------
			
			# Now we can use it safely
			var raw_text = response["response"]
			
			# Send to our emotion parser
			parse_and_animate(raw_text)
			
		else:
			output_label.text = "Lia: Error parsing brain data."
	else:
		output_label.text = "Lia: Connection failed (Code " + str(response_code) + ")"
		
		
func parse_and_animate(text: String):
	var clean_text = text
	var emotion = "Idle" 
	
	var tags = {
		"[HAPPY]": "Jump",      # Maps to your 'Jump' animation
		"[ANGRY]": "Angry",     # Maps to 'Angry'
		"[WAVE]": "Wave",       # Maps to 'Wave'
		"[SURPRISED]": "Jump",  # Re-use Jump for now
		"[BLUSH]": "Idle",      # Re-use Idle for now
		"[THINK]": "Idle",      # Re-use Idle for now
		"[HIDE]": "Hide"        # SPECIAL: We will build this in Layer 4
	}
	
	for tag in tags:
		if tag in text:
			emotion = tags[tag]
			clean_text = text.replace(tag, "")
			# If we find a tag, stop searching (priority order)
			break
	# DETECT EMOTION TAGS
	if "[HAPPY]" in text:
		emotion = "Jump"
		clean_text = text.replace("[HAPPY]", "")
		print("Lia Emotion: HAPPY (Triggering Jump)")
		
	elif "[ANGRY]" in text:
		emotion = "Angry"
		clean_text = text.replace("[ANGRY]", "")
		print("Lia Emotion: ANGRY")
		
	elif "[WAVE]" in text:
		emotion = "Wave"
		clean_text = text.replace("[WAVE]", "")
		print("Lia Emotion: WAVE")
	
	# SHOW CLEAN TEXT
	output_label.text = "Lia: " + clean_text.strip_edges()
	
	# PLAY ANIMATION
	if animator:
		if animator.has_animation(emotion):
			animator.play(emotion)
			
			# SPECIAL BEHAVIOR: Handling the "Hide" command
			if emotion == "Hide":
				# We will replace this print with real movement in Layer 4
				print("Lia: Executing HIDE protocol...") 
			else:
				animator.queue("Idle")
		else:
			# If animation doesn't exist yet, just print it so we know it worked
			print("Lia: Wants to play animation '" + emotion + "' but it is missing.")
