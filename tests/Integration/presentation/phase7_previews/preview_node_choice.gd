extends Node


func _ready() -> void:
	var executor := get_node_or_null("/root/GameExecutor")
	if executor != null:
		executor.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var panel := $NodeChoicePanel as Control
	panel.show()
	($NodeChoicePanel/Center/Panel/MarginContainer/Layout/TitleLabel as Label).text = "选择下个节点"
	var buttons: Array[Button] = [
		$NodeChoicePanel/Center/Panel/MarginContainer/Layout/ButtonRow/ChoiceButton1,
		$NodeChoicePanel/Center/Panel/MarginContainer/Layout/ButtonRow/ChoiceButton2,
		$NodeChoicePanel/Center/Panel/MarginContainer/Layout/ButtonRow/ChoiceButton3,
	]
	for index: int in range(buttons.size()):
		buttons[index].text = "%d号 节点" % (index + 1)
		buttons[index].show()
