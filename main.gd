extends Node3D

@export_group("Hitbox Settings")
@export var hitbox_size = Vector2(250, 550) 
@export var debug_mode = false

@export_group("Nodes")
@onready var activity_monitor = $ActivityMonitor
@onready var chat_bubble = $Lia/Node/Armature/Skeleton3D/Face/ChatBubble 
@onready var center_marker = $Lia/CenterMarker
@onready var camera = $Camera3D
@onready var debug_box = $DebugBox 
@onready var animator = $Lia/AnimationPlayer 
@onready var skeleton = $Lia/Node/Armature/Skeleton3D 

# --- OBSERVER MODE SETTINGS ---
@export_group("Observer Settings")
@export var head_bone_name: String = "Head" # Check your Skeleton for exact name!
@export var track_mouse = true
var head_bone_idx = -1

enum State { IDLE, ROAMING, HIDING }
var current_state = State.IDLE
var state_timer = Timer.new()
var target_position = Vector2i()
var move_speed = 150.0 
var screen_size = Vector2i()
var is_dragging = false
var drag_offset = Vector2i()

# CONFLICT MANAGER FLAG
var is_chatting = false 

var idle_timer = 0.0
var time_until_bored = 8.0 

func _ready():
	get_window().transparent_bg = true
	get_window().mouse_passthrough = false
	screen_size = DisplayServer.screen_get_size()
	
	# Find Head Bone for Tracking
	head_bone_idx = skeleton.find_bone(head_bone_name)
	if head_bone_idx == -1: print("Lia Warning: Head bone not found!")
	
	if debug_mode: debug_box.visible = true
	
	add_child(state_timer)
	state_timer.wait_time = 5.0
	state_timer.timeout.connect(_on_brain_tick)
	state_timer.start()
	
	print("Lia: v3 Logic Online.")
	activity_monitor.user_is_working.connect(_on_user_working)
	activity_monitor.user_is_bored.connect(_on_user_bored)
	activity_monitor.user_is_active.connect(_on_user_active)
	
	animator.animation_finished.connect(_on_animation_finished)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"): get_tree().quit()
	
	# This was causing your error - the function is defined below now
	update_hitbox()
	
	if is_dragging: return

	# --- CONFLICT MANAGER ---
	# If Chatting, AI has control. Physics/Reflexes are disabled.
	if is_chatting:
		return 

	# --- OBSERVER MODE (Reflex Brain) ---
	handle_observer_mode(delta)
	process_behavior(delta) 

func handle_observer_mode(delta):
	if not track_mouse or head_bone_idx == -1: return
	
	# 1. MOUSE VELOCITY CHECK (Wake up if user moves mouse fast)
	if Input.get_last_mouse_velocity().length() > 50.0:
		idle_timer = 0.0 # Reset boredom
		# If she was deep chilling, wake her up
		if animator.current_animation == "Sit_Chill":
			animator.play("Idle", 0.5)
	else:
		idle_timer += delta

	# 2. HEAD TRACKING logic
	# Simplified look-at logic can go here if needed
	pass 

func process_behavior(delta):
	match current_state:
		State.ROAMING:
			move_window_towards(target_position, delta)
			if animator.current_animation != "mixamo_com":
				animator.play("mixamo_com")
			if at_target():
				change_state(State.IDLE)
				
		State.HIDING:
			move_window_towards(target_position, delta)
			if at_target():
				change_state(State.IDLE)

func _on_brain_tick():
	# CONFLICT MANAGER: Don't do random stuff if talking
	if is_chatting or (chat_bubble and chat_bubble.visible): return
	if is_dragging or current_state != State.IDLE: return
	
	# --- BOREDOM LOGIC ---
	if idle_timer > time_until_bored:
		if animator.current_animation != "Sit_Chill":
			animator.play("Sit_Chill")
		return

	# --- RANDOM BEHAVIOR ---
	var roll = randf()
	if roll < 0.3: 
		pick_random_spot()
		change_state(State.ROAMING)
	elif roll < 0.6:
		var random_anims = ["Yawn", "HangingIdle", "SittingIdle"]
		animator.play(random_anims.pick_random())
		animator.queue("Idle")
	else:
		animator.play("Idle")
	
	state_timer.wait_time = randf_range(5.0, 15.0)

# --- HELPER FUNCTIONS (Restored) ---

func move_window_towards(target: Vector2i, delta):
	var current_pos = DisplayServer.window_get_position(get_window().get_window_id())
	var smooth_pos = Vector2(current_pos).move_toward(Vector2(target), move_speed * delta)
	DisplayServer.window_set_position(Vector2i(smooth_pos), get_window().get_window_id())

func at_target() -> bool:
	var current_pos = DisplayServer.window_get_position(get_window().get_window_id())
	return Vector2(current_pos).distance_to(Vector2(target_position)) < 10.0

func pick_random_spot():
	var margin = 100
	var random_x = randi_range(margin, screen_size.x - margin)
	var random_y = randi_range(margin, screen_size.y - margin)
	target_position = Vector2i(random_x, random_y)

func change_state(new_state):
	current_state = new_state
	match new_state:
		State.IDLE: animator.play("Idle")
		State.ROAMING: animator.play("mixamo_com")
		State.HIDING: 
			if animator.has_animation("Hide"): animator.play("Hide")
			else: animator.play("Idle")

func force_hide():
	screen_size = DisplayServer.screen_get_size()
	var current_y = DisplayServer.window_get_position(get_window().get_window_id()).y
	target_position = Vector2i(screen_size.x - 100, current_y)
	change_state(State.HIDING)

func update_hitbox():
	if not center_marker or not camera: return
	var screen_pos = camera.unproject_position(center_marker.global_position)
	var top_left = screen_pos - (hitbox_size / 2)
	var final_rect = Rect2(top_left, hitbox_size)
	
	if chat_bubble and chat_bubble.visible:
		var ui_rect = chat_bubble.get_global_rect()
		final_rect = final_rect.merge(ui_rect)
		
	if debug_mode and debug_box:
		debug_box.position = final_rect.position
		debug_box.size = final_rect.size
		
	if is_dragging:
		var current_mouse_pos = DisplayServer.mouse_get_position()
		var new_pos = current_mouse_pos - drag_offset
		DisplayServer.window_set_position(new_pos, get_window().get_window_id())
		DisplayServer.window_set_mouse_passthrough([], get_window().get_window_id())
	else:
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

func _on_user_working():
	if is_chatting: return 
	if animator.current_animation != "Salute":
		print("Lia: User working. Saluting.")
		animator.play("Salute")

func _on_user_bored():
	if is_chatting: return
	var bored_anims = ["Yawn", "SittingIdle", "HangingIdle"]
	if animator.has_animation("Yawn"): 
		animator.play(bored_anims.pick_random())

func _on_user_active():
	if is_chatting: return
	if animator.current_animation in ["Salute", "Yawn", "SittingIdle", "Sit_Chill"]:
		animator.play("Idle")

func _on_animation_finished(anim_name):
	# Unlocks conflict manager when AI animation finishes
	if is_chatting:
		is_chatting = false
		animator.play("Idle")
