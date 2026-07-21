extends Node


func _ready() -> void:
	var executor := get_node_or_null("/root/GameExecutor")
	if executor != null:
		executor.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ui := $InventoryPanel/UI as CanvasLayer
	ui.show()
	($InventoryPanel/UI/Panel/MarginContainer/Layout/Header/TitleLabel as Label).text = "选择一个物品升级"
	($InventoryPanel/UI/Panel/MarginContainer/Layout/Content/SkillLabel as Label).text = "技能"
