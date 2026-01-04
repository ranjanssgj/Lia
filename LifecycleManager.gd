extends Node

var pid: int = -1

func _ready():
	# 1. Determine Command based on OS
	var python_cmd = "python" # Default for Windows
	if OS.get_name() != "Windows":
		python_cmd = "python3" # Default for Linux/Mac
	
	var path = ""
	var args = []
	
	if OS.has_feature("editor"):
		# We are in Godot Editor -> Run .py file
		path = python_cmd 
		# Use "globalized" path to ensure python finds the file even if working dir is weird
		var script_path = ProjectSettings.globalize_path("res://audio_server.py")
		args = [script_path]
		print("Lia System: Starting Python Backend (%s)..." % python_cmd)
	else:
		# We are Exported Game -> Run compiled Exe/Binary
		path = OS.get_executable_path().get_base_dir() + "/audio_server"
		if OS.get_name() == "Windows":
			path += ".exe"
		args = []
		print("Lia System: Starting Audio Server Binary...")

	# 2. Launch
	# open_console = true so you can debug errors if it fails (change to false later)
	pid = OS.create_process(path, args, true) 
	
	if pid == -1:
		print("Lia Error: Failed to launch audio backend! Command: ", path, args)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if pid != -1:
			print("Lia System: Shutting down audio backend (PID %s)..." % pid)
			OS.kill(pid)
