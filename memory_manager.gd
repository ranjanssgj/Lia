extends Node

# Path to the permanent memory file
const MEMORY_FILE = "user://lia_memory.json"

# The Brain Data
var context_data = {
	"user_name": "User",
	"current_task": "Unknown",
	"mood": "Neutral",
	"facts": [] # List of learned things like "Likes guitar", "Studying CS"
}

func _ready():
	load_memory()

func save_memory():
	var file = FileAccess.open(MEMORY_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(context_data, "\t"))
		file.close()

func load_memory():
	if not FileAccess.file_exists(MEMORY_FILE):
		save_memory() # Create default if missing
		return

	var file = FileAccess.open(MEMORY_FILE, FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			var loaded_data = json.get_data()
			# Merge loaded data safely (keep defaults if keys are missing)
			context_data.merge(loaded_data, true)
		file.close()

# Call this when the user mentions a new fact
func add_fact(fact: String):
	if fact not in context_data["facts"]:
		context_data["facts"].append(fact)
		save_memory()
		print("Lia remembered: " + fact)

func get_system_context() -> String:
	var memory_str = "User Context: Name is " + context_data["user_name"] + ". "
	memory_str += "Current Task: " + context_data["current_task"] + ". "
	if not context_data["facts"].is_empty():
		memory_str += "Known Facts: " + ", ".join(context_data["facts"]) + "."
	return memory_str
