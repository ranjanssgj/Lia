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

enum State { IDLE, ROAMING, HIDING }
var current_state = State.IDLE
var state_timer = Timer.new()
var target_position = Vector2i()
var move_speed = 150.0 
var screen_size = Vector2i()
var is_dragging = false
var drag_offset = Vector2i()
var is_chatting = false
var idle_variations = ["Idle", "Yawn", "HangingIdle", "SittingIdle", "FemaleLayingPose"]

func _ready():
	get_window().transparent_bg = true
	get_window().mouse_passthrough = false
	screen_size = DisplayServer.screen_get_size()
	
	if debug_mode: debug_box.visible = true
	
	add_child(state_timer)
	state_timer.wait_time = 5.0
	state_timer.timeout.connect(_on_brain_tick)
	state_timer.start()
	
	print("Lia: Advanced Animation Logic Online.")
	activity_monitor.user_is_working.connect(_on_user_working)
	activity_monitor.user_is_bored.connect(_on_user_bored)
	activity_monitor.user_is_active.connect(_on_user_active)
	
	animator.animation_finished.connect(_on_animation_finished)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	process_behavior(delta) 
	update_hitbox()

func process_behavior(delta):
	if is_dragging: return

	match current_state:
		State.IDLE:
			# we don't need to force 'Idle' constantly.
			pass 
			
		State.ROAMING:
			move_window_towards(target_position, delta)
			# "mixamo_com" is the Walking animation
			if animator and animator.current_animation != "mixamo_com":
				animator.play("mixamo_com")
			
			if at_target():
				change_state(State.IDLE)
				
		State.HIDING:
			move_window_towards(target_position, delta)
			if at_target():
				change_state(State.IDLE)

func move_window_towards(target: Vector2i, delta):
	var current_pos = DisplayServer.window_get_position(get_window().get_window_id())
	var smooth_pos = Vector2(current_pos).move_toward(Vector2(target), move_speed * delta)
	DisplayServer.window_set_position(Vector2i(smooth_pos), get_window().get_window_id())

func at_target() -> bool:
	var current_pos = DisplayServer.window_get_position(get_window().get_window_id())
	return Vector2(current_pos).distance_to(Vector2(target_position)) < 10.0

func _on_brain_tick():
	if is_chatting or (chat_bubble and chat_bubble.visible):
		return
	
	if is_dragging: return
	var roll = randf()
	
	if current_state == State.IDLE:
		# 30% Chance to Walk
		if roll < 0.3: 
			pick_random_spot()
			change_state(State.ROAMING)
			
		# 30% Chance to perform a "Special Idle" (Yawn, Sit, etc)
		elif roll < 0.6:
			play_random_idle()
			
		# 40% Chance to just stay standard Idle
		else:
			animator.play("Idle")
			
	state_timer.wait_time = randf_range(5.0, 15.0)

func play_random_idle():
	var anim_name = idle_variations.pick_random()
	
	if animator.has_animation(anim_name):
		animator.play(anim_name)
		animator.queue("Idle")

func pick_random_spot():
	var margin = 100
	var random_x = randi_range(margin, screen_size.x - margin)
	var random_y = randi_range(margin, screen_size.y - margin)
	target_position = Vector2i(random_x, random_y)

func change_state(new_state):
	current_state = new_state
	if animator:
		match new_state:
			State.IDLE: animator.play("Idle")
			State.ROAMING: animator.play("mixamo_com") # Walking
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
	if is_chatting: return # IGNORE if chatting
	if animator.current_animation != "Salute":
		print("Lia: User working. Saluting.")
		animator.play("Salute")

func _on_user_bored():
	if is_chatting: return # IGNORE if chatting
	var bored_anims = ["Yawn", "SittingIdle", "HangingIdle"]
	if animator.has_animation("Yawn"): # Safety check
		animator.play(bored_anims.pick_random())

func _on_user_active():
	if is_chatting: return # IGNORE if chatting
	# Only wake up if she was actually sleeping/saluting
	if animator.current_animation in ["Salute", "Yawn", "SittingIdle"]:
		animator.play("Idle")

func _on_animation_finished(anim_name):
	# If a chat animation (like JoyfulJump) just finished, we are done chatting.
	# We can now listen to the system state again.
	if is_chatting:
		is_chatting = false
		animator.play("Idle")
