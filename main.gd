extends Node3D

func _ready():
	# 1. Force the Viewport to be clear (Removes the black skybox)
	get_viewport().transparent_bg = true
	222
	# 2. Force the Window itself to support alpha blending
	get_window().transparent = true
	
	# 3. Enable click-through
	get_window().mouse_passthrough = true
	
	# Debug print to confirm script is running
	print("Lia: Window settings applied.")
