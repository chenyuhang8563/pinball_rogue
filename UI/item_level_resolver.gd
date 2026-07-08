extends RefCounted
class_name ItemLevelResolver


static func get_inventory_level(item: Item) -> int:
	if item == null:
		return 0
	if item.type == Item.ItemType.RELIC:
		var inventory: Node = _get_root_node("Inventory")
		if inventory != null and inventory.has_method("get_relic_level"):
			if inventory.has_method("is_relic_awakened") and bool(inventory.call("is_relic_awakened", item)):
				return 4
			return int(inventory.call("get_relic_level", item))
		return 0
	if item.type == Item.ItemType.MARBLE:
		var upgrade_system: Node = _get_marble_upgrade_system()
		if upgrade_system != null and upgrade_system.has_method("get_level"):
			if upgrade_system.has_method("is_awakened") and bool(upgrade_system.call("is_awakened", item.marble_type)):
				return 4
			return int(upgrade_system.call("get_level", item.marble_type))
		return 1
	return 0


static func get_upgrade_option_level(option: Variant) -> int:
	if option is Dictionary:
		if bool((option as Dictionary).get("awakens", false)):
			return 4
		return int((option as Dictionary).get("next_level", 0))
	return 0


static func _get_root_node(node_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


static func _get_marble_upgrade_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var candidates: Array[Node] = []
	if tree.current_scene != null:
		candidates.append(tree.current_scene)
	candidates.append(tree.root)
	for candidate: Node in candidates:
		var direct: Node = candidate.get_node_or_null("RunController/MarbleUpgradeSystem")
		if _is_live_node(direct):
			return direct
		for run_controller: Node in candidate.find_children("RunController", "", true, false):
			if not _is_live_node(run_controller):
				continue
			var system: Node = run_controller.get_node_or_null("MarbleUpgradeSystem")
			if _is_live_node(system):
				return system
	return null


static func _is_live_node(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current.is_queued_for_deletion():
			return false
		current = current.get_parent()
	return node != null
