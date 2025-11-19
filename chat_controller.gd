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

func _ready():
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
	
	# 2. Prepare the Data (JSON)
	# We send 'stream': false so we get the whole sentence at once, not letter-by-letter
	var data = {
		"model": MODEL_NAME,
		"prompt": new_text,
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
