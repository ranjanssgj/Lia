extends Node3D

# --- SETTINGS (Change these in the Inspector!) ---
@export var hitbox_size = Vector2(250, 550) # Width, Height in pixels
@export var debug_mode = true # Uncheck this when you are done testing!

# --- NODES ---
@onready var character = $Lia
@onready var center_marker = $Lia/CenterMarker
@onready var camera = $Camera3D
@onready var debug_box = $DebugBox # Make sure you added this node!

# --- STATE ---
var is_dragging = false
var drag_offset = Vector2i() # Note: Using Vector2i for strict pixel math

func _ready():
	get_window().transparent_bg = true
	# Hide the debug box if we aren't testing
	#debug_box.visible = debug_mode
	print("Lia: Phase 3.5 - Debug Mode Initialized")

func _process(delta):
	# 1. EXIT KEY
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	# 2. CALCULATE SCREEN POSITION
	# Where is the character on the 2D screen?
	var screen_pos = camera.unproject_position(center_marker.global_position)
	
	# Calculate the box corners based on the center point
	var top_left = screen_pos - (hitbox_size / 2)
	
	# 3. UPDATE DEBUG BOX (Visual Feedback)
	#if debug_mode:
	#	debug_box.position = top_left
	#	debug_box.size = hitbox_size

	# 4. DRAGGING LOGIC
	if is_dragging:
		var current_mouse_pos = DisplayServer.mouse_get_position()
		# Force move the window using integers
		var new_pos = current_mouse_pos - drag_offset
		get_window().position = new_pos
		
		# Keep the window solid while dragging so we don't lose grip
		DisplayServer.window_set_mouse_passthrough([], get_window().get_window_id())
		
	else:
		# 5. DYNAMIC HITBOX (The Passthrough)
		var bottom_right = screen_pos + (hitbox_size / 2)
		
		# Define the clickable polygon
		var polygon = PackedVector2Array([
			Vector2(top_left.x, top_left.y),
			Vector2(bottom_right.x, top_left.y),
			Vector2(bottom_right.x, bottom_right.y),
			Vector2(top_left.x, bottom_right.y)
		])
		
		# Send to Linux
		DisplayServer.window_set_mouse_passthrough(polygon, get_window().get_window_id())

# --- INPUT ---
func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				# Calculate offset using Integers (Vector2i) prevents jitter
				var win_pos = get_window().position
				var mouse_pos = DisplayServer.mouse_get_position()
				drag_offset = mouse_pos - win_pos
			else:
				is_dragging = false
				
	#
		
		
