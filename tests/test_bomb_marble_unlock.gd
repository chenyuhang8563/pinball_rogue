extends SceneTree

const MainScript: GDScript = preload("res://Main/main.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_test_default_refill_stays_default_with_bomb_item_in_box(failures)
	await _test_adding_bomb_marble_item_does_not_spawn_immediately(failures)

	if failures.is_empty():
		print("test_bomb_marble_unlock: PASS")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _test_default_refill_stays_default_with_bomb_item_in_box(failures: Array[String]) -> void:
	var inventory: Node = _get_inventory()
	inventory.items.clear()

	var bomb_item: Item = load("res://Resources/bomb_marble.tres")
	inventory.add_item(bomb_item)

	var main: Node = MainScript.new()
	var marble: Marble = Marble.new()
	marble.marble_type = Marble.MARBLE_TYPE.DEFAULT

	var next_type: Marble.MARBLE_TYPE = main._get_next_marble_type(marble)
	_assert_eq(next_type, Marble.MARBLE_TYPE.DEFAULT, "default refill should stay default even when bomb marble is in the box", failures)
	marble.free()
	main.free()


func _test_adding_bomb_marble_item_does_not_spawn_immediately(failures: Array[String]) -> void:
	var inventory: Node = _get_inventory()
	inventory.items.clear()
	if _has_property(inventory, "marble_items"):
		inventory.marble_items.clear()

	var main: Node2D = MainScript.new()
	main.name = "MainUnderTest"
	var marbles: Node2D = Node2D.new()
	marbles.name = "Marbles"
	main.add_child(marbles)
	get_root().add_child(main)
	await process_frame

	var bomb_item: Item = load("res://Resources/bomb_marble.tres")
	paused = true
	inventory.add_item(bomb_item)
	await process_frame
	paused = false

	_assert_eq(marbles.get_child_count(), 0, "adding bomb marble item should only fill the marble box", failures)

	main.queue_free()
	await process_frame


func _assert_eq(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _assert_true(actual: bool, message: String, failures: Array[String]) -> void:
	if not actual:
		failures.append("%s: expected true, got false" % message)


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


func _get_inventory() -> Node:
	var root: Window = get_root()
	if root.has_node("Inventory"):
		return root.get_node("Inventory")

	var inventory: Node = preload("res://Inventory/inventory.gd").new()
	inventory.name = "Inventory"
	root.add_child(inventory)
	return inventory
