extends Node3D

# --- SETTINGS ---
@export var hitbox_size = Vector2(250, 550) 
@export var debug_mode = true 

# --- NODES ---
@onready var center_marker = $Lia/CenterMarker
@onready var camera = $Camera3D
@onready var debug_box = $DebugBox 

# LINK THIS IN THE INSPECTOR!
# If you forget, the script will now ignore it instead of crashing.
@onready var chat_bubble = $Lia/GeneralSkeleton/Face/ChatBubble

# --- STATE ---
var is_dragging = false
var drag_offset = Vector2i()

func _ready():
	get_window().transparent_bg = true
	# We start with NO passthrough (Solid) to ensure we catch the first frame
	get_window().mouse_passthrough = false
	
	if debug_mode:
		debug_box.visible = false
	
	print("Lia: Smart Hitbox Engine Ready.")

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	# --- 1. CALCULATE BODY AREA ---
	# Project the 3D center marker to a 2D screen rectangle
	var screen_pos = camera.unproject_position(center_marker.global_position)
	var top_left = screen_pos - (hitbox_size / 2)
	var final_rect = Rect2(top_left, hitbox_size)

	# --- 2. ADD CHAT BUBBLE (Safety Check) ---
	# Only try to add the bubble if the node is actually assigned!
	if chat_bubble and chat_bubble.visible:
		var ui_rect = chat_bubble.get_global_rect()
		# "Merge" creates a big box that covers both the Body and the Bubble
		final_rect = final_rect.merge(ui_rect)

	# --- 3. UPDATE VISUAL DEBUGGER ---
	if debug_mode:
		debug_box.position = final_rect.position
		debug_box.size = final_rect.size

	# --- 4. SEND THE SHAPE TO LINUX ---
	if is_dragging:
		# While dragging, we make the window completely solid to prevent dropping her
		DisplayServer.window_set_mouse_passthrough([], get_window().get_window_id())
		
		# Handle movement (Universal)
		var current_mouse_pos = DisplayServer.mouse_get_position()
		var new_pos = current_mouse_pos - drag_offset
		DisplayServer.window_set_position(new_pos, get_window().get_window_id())
		
	else:
		# Define the Polygon (The 4 corners of our 'Final Rect')
		var polygon = PackedVector2Array([
			Vector2(final_rect.position.x, final_rect.position.y),
			Vector2(final_rect.end.x, final_rect.position.y),
			Vector2(final_rect.end.x, final_rect.end.y),
			Vector2(final_rect.position.x, final_rect.end.y)
		])
		
		# Tell the OS: "Only these pixels are clickable!"
		DisplayServer.window_set_mouse_passthrough(polygon, get_window().get_window_id())

# --- INPUT ---
func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			var win_pos = DisplayServer.window_get_position(get_window().get_window_id())
			var mouse_pos = DisplayServer.mouse_get_position()
			drag_offset = mouse_pos - win_pos
		else:
			is_dragging = false
