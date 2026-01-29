extends Node

var server := UDPServer.new()
@onready var chat_controller = $"../Lia/Node/Armature/Skeleton3D/Face/ChatBubble" # Update path!

func _ready():
	# Listen on Port 4242
	var err = server.listen(4242)
	if err != OK:
		print("Lia Voice Error: Could not listen on Port 4242")
	else:
		print("Lia Voice: Listening for Python ears on Port 4242...")

func _process(delta):
	server.poll() # Check for new packets
	
	if server.is_connection_available():
		var peer = server.take_connection()
		var packet = peer.get_packet()
		var text = packet.get_string_from_utf8()
		
		if text and text != "":
			print("VoiceReceiver: Packet Received from Python!")
			print("VoiceReceiver Raw Text: ", text)
			_handle_voice_command(text)

func _handle_voice_command(text: String):
	if chat_controller:
		
		if chat_controller.input_field.has_focus() or chat_controller.input_field.text != "":
			print("Lia: Voice ignored (User is typing)")
			return
		chat_controller.input_field.text = text
		
		# 2. Trigger the submit function manually
		chat_controller._on_text_submitted(text)
