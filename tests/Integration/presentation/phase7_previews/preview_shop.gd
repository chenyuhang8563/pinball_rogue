extends Node


func _ready() -> void:
	var executor := get_node_or_null("/root/GameExecutor")
	if executor != null:
		executor.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ui := $Shop/UI as CanvasLayer
	ui.show()
	($Shop/UI/Panel/Label as Label).text = "普通商店 SHOP 12"
	($Shop/UI/Panel/ExitButton as Button).text = "退出 EXIT"
