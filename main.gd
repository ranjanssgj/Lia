extends Node3D

# ==============================================================================
# 1. SETTINGS & CONFIGURATION
# ==============================================================================

# --- HITBOX SETTINGS ---
@export_group("Hitbox Settings")
@export var hitbox_size = Vector2(250, 550) 
@export var debug_mode = true 

# --- ANIMATION FIX SETTINGS ---
@export_group("Chiropractor Settings")
@export var fix_orientation = true
@export var hip_rotation_offset = 180 # Set to 0 or 180 if she faces wrong way


# --- NODES (Assign in Inspector) ---
@export_group("Nodes")
@onready var chat_bubble= $Lia/GeneralSkeleton/Face/ChatBubble  

# ==============================================================================
# 2. INTERNAL VARIABLES
# ==============================================================================

# --- ONREADY NODES ---
@onready var center_marker = $Lia/CenterMarker
@onready var camera = $Camera3D
@onready var debug_box = $DebugBox 
@onready var animator = $Lia/AnimationPlayer 
@onready var skeleton = $Lia/GeneralSkeletonzzzzzzzz

# --- STATE MACHINE ---
enum State { IDLE, ROAMING, HIDING, PEEKING }
var current_state = State.IDLE
var state_timer = Timer.new()

# --- MOVEMENT ---
var target_position = Vector2i()
var move_speed = 150.0 # Pixels per second
var screen_size = Vector2i()

# --- INPUT/DRAG ---
var is_dragging = false
var drag_offset = Vector2i()

# --- BONE FIX STATE ---
var hips_bone_idx = -1

# ==============================================================================
# 3. INITIALIZATION
# ==============================================================================

func _ready():
	# 1. Window Setup
	get_window().transparent_bg = true
	# Start Solid to catch first input
	get_window().mouse_passthrough = false
	screen_size = DisplayServer.screen_get_size()
	
	if debug_mode: debug_box.visible = false
	
	# 2. Brain Timer Setup
	add_child(state_timer)
	state_timer.wait_time = 5.0
	state_timer.timeout.connect(_on_brain_tick)
	state_timer.start()
	
	# 3. Find Hips for Rotation Fix
	if skeleton:
		hips_bone_idx = skeleton.find_bone("Hips")
		if hips_bone_idx == -1:
			hips_bone_idx = skeleton.find_bone("Hips")
	
	print("Lia: All Systems Online (Hitbox + AI + Animation Fix).")

# ==============================================================================
# 4. MAIN LOOP
# ==============================================================================

func _process(delta):
	# 1. Emergency Exit
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	# 2. Run Systems
	process_behavior(delta)   # AI Logic
	apply_hip_fix()           # Animation Fix
	update_hitbox()           # Passthrough Logic

# ==============================================================================
# 5. BEHAVIOR LAYER (THE BRAIN)
# ==============================================================================

func process_behavior(delta):
	# If dragging, pause AI movement
	if is_dragging: return

	match current_state:
		State.IDLE:
			pass # Just breathing
			
		State.ROAMING:
			move_window_towards(target_position, delta)
			
			# Ensure walking animation plays
			if animator and animator.current_animation != "Walk":
				animator.play("Walk")
				
			if at_target():
				print("Lia: Roaming complete.")
				change_state(State.IDLE)
		
		State.HIDING:
			move_window_towards(target_position, delta)
			if at_target():
				# Arrived at edge. Stop walking.
				if animator: animator.play("Idle")

func _on_brain_tick():
	if is_dragging: return
	
	# Random Decision Maker
	var roll = randf()
	
	if current_state == State.IDLE:
		# 30% chance to start walking
		if roll < 0.3:
			pick_random_spot()
			change_state(State.ROAMING)
	
	# Randomize next think time (5 to 15 seconds)
	state_timer.wait_time = randf_range(5.0, 15.0)

# ==============================================================================
# 6. INTERACTION LAYER (THE BODY)
# ==============================================================================

func update_hitbox():
	# --- 1. CALCULATE RECTANGLES ---
	var screen_pos = camera.unproject_position(center_marker.global_position)
	var top_left = screen_pos - (hitbox_size / 2)
	var final_rect = Rect2(top_left, hitbox_size)

	# Add Chat Bubble area if visible
	if chat_bubble and chat_bubble.visible:
		var ui_rect = chat_bubble.get_global_rect()
		final_rect = final_rect.merge(ui_rect)

	# --- 2. DEBUG VISUALS ---
	if debug_mode:
		debug_box.position = final_rect.position
		debug_box.size = final_rect.size

	# --- 3. WINDOW MANAGEMENT ---
	if is_dragging:
		# Force Window Move
		var current_mouse_pos = DisplayServer.mouse_get_position()
		var new_pos = current_mouse_pos - drag_offset
		DisplayServer.window_set_position(new_pos, get_window().get_window_id())
		
		# Make solid so we don't drop her
		DisplayServer.window_set_mouse_passthrough([], get_window().get_window_id())
		
	else:
		# Apply Passthrough Polygon
		var polygon = PackedVector2Array([
			Vector2(final_rect.position.x, final_rect.position.y),
			Vector2(final_rect.end.x, final_rect.position.y),
			Vector2(final_rect.end.x, final_rect.end.y),
			Vector2(final_rect.position.x, final_rect.end.y)
		])
		DisplayServer.window_set_mouse_passthrough(polygon, get_window().get_window_id())

func _on_area_3d_input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			var win_pos = DisplayServer.window_get_position(get_window().get_window_id())
			var mouse_pos = DisplayServer.mouse_get_position()
			drag_offset = mouse_pos - win_pos
		else:
			is_dragging = false

# ==============================================================================
# 7. HELPER FUNCTIONS
# ==============================================================================

func change_state(new_state):
	current_state = new_state
	if animator:
		match new_state:
			State.IDLE: animator.play("Idle")
			State.ROAMING: 
				if animator.has_animation("Walk"): animator.play("Walk")
				else: animator.play("Idle")
			State.HIDING:
				if animator.has_animation("Hide"): animator.play("Hide")
				else: animator.play("Idle")

func pick_random_spot():
	var margin = 100
	var random_x = randi_range(margin, screen_size.x - margin)
	var random_y = randi_range(margin, screen_size.y - margin)
	target_position = Vector2i(random_x, random_y)

func move_window_towards(target: Vector2i, delta):
	var current_pos = DisplayServer.window_get_position(get_window().get_window_id())
	var smooth_pos = Vector2(current_pos).move_toward(Vector2(target), move_speed * delta)
	DisplayServer.window_set_position(Vector2i(smooth_pos), get_window().get_window_id())

func at_target() -> bool:
	var current_pos = DisplayServer.window_get_position(get_window().get_window_id())
	return Vector2(current_pos).distance_to(Vector2(target_position)) < 10.0

func apply_hip_fix():
	if fix_orientation and skeleton and hips_bone_idx != -1:
		var current_pose = skeleton.get_bone_pose_rotation(hips_bone_idx)
		var rotation_fix = Quaternion.from_euler(Vector3(0, deg_to_rad(hip_rotation_offset), 0))
		skeleton.set_bone_pose_rotation(hips_bone_idx, current_pose * rotation_fix)

# Called by Chat Controller when user types "Hide" or "Go away"
func force_hide():
	screen_size = DisplayServer.screen_get_size() # Refresh size just in case
	var current_y = DisplayServer.window_get_position(get_window().get_window_id()).y
	target_position = Vector2i(screen_size.x - 100, current_y) # Go to right edge
	change_state(State.HIDING)
