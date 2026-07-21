extends Node


func execute(controller: Node, definition: SkillDefinition) -> bool:
	if controller == null or not controller.has_method("get_active_head"):
		return false
	var head: Node2D = controller.call("get_active_head") as Node2D
	if head == null or not is_instance_valid(head) or not head.has_method("dash_toward"):
		return false
	var target: Node2D = controller.call("find_nearest_enemy", head.global_position) as Node2D
	if target == null:
		return false
	var direction: Vector2 = head.global_position.direction_to(target.global_position)
	if direction == Vector2.ZERO:
		return false
	head.call("dash_toward", direction)
	if controller.has_method("apply_dash_damage_bonus"):
		controller.call("apply_dash_damage_bonus", definition.dash_damage_multiplier, definition.dash_damage_duration)
	return true
