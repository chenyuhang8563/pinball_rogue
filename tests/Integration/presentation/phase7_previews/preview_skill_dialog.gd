extends Node


func _ready() -> void:
	var executor := get_node_or_null("/root/GameExecutor")
	if executor != null:
		executor.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var dialog := $SkillReplaceDialog as SkillReplaceDialog
	dialog.show()
	($SkillReplaceDialog/Center/Panel/Margin/Layout/Message as Label).text = "确认升级 技能 Skill 12?"
	($SkillReplaceDialog/Center/Panel/Margin/Layout/Buttons/Confirm as Button).text = "确认"
	($SkillReplaceDialog/Center/Panel/Margin/Layout/Buttons/Cancel as Button).text = "取消"
