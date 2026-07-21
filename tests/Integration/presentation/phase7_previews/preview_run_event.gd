extends Node


func _ready() -> void:
	var executor := get_node_or_null("/root/GameExecutor")
	if executor != null:
		executor.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var panel := $RunEventPanel as RunEventPanel
	panel.call("_show_crossroads_event")
