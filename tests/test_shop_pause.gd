extends SceneTree

const TYPE_MARBLE := 1
const TYPE_RELIC := 2

func _initialize() -> void:
	var failures: Array[String] = []
	await _test_shop_pauses_while_open_and_resumes_when_closed(failures)
	await _test_purchased_shop_item_is_removed_and_cannot_be_bought_again(failures)
	await _test_clicking_shop_slot_removes_purchased_item_safely(failures)
	await _test_selling_owned_item_returns_half_price_and_removes_item(failures)
	await _test_right_click_owned_collection_slot_sells_item(failures)

	if failures.is_empty():
		print("test_shop_pause: PASS")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _test_shop_pauses_while_open_and_resumes_when_closed(failures: Array[String]) -> void:
	paused = false
	var shop: Control = get_root().get_node_or_null("Shop") as Control
	if shop == null:
		failures.append("Shop autoload should exist")
		return
	await process_frame

	shop.mode = shop.MODE.ON
	_assert_true(paused, "opening shop should pause the game", failures)
	_assert_eq(shop.process_mode, Node.PROCESS_MODE_ALWAYS, "shop should continue processing while paused", failures)

	shop.mode = shop.MODE.OFF
	_assert_false(paused, "closing shop should resume the game", failures)


func _test_purchased_shop_item_is_removed_and_cannot_be_bought_again(failures: Array[String]) -> void:
	var shop: Control = get_root().get_node_or_null("Shop") as Control
	var inventory: Node = get_root().get_node_or_null("Inventory")
	if shop == null or inventory == null:
		failures.append("Shop and Inventory autoloads should exist")
		return

	_clear_inventory(inventory)
	var item := _make_item("single_purchase", 30, true, false)
	shop.set_initial_gold()
	var shop_list: Array[Item] = [item]
	shop.set_shop_inventory(shop_list)
	await process_frame

	if not shop.has_method("purchase_item"):
		failures.append("Shop should expose purchase_item for one-time purchases")
		return
	_assert_true(shop.purchase_item(item), "first purchase should succeed", failures)
	_assert_eq(shop.gold, 70, "successful purchase should subtract item price", failures)
	_assert_eq(shop.shop_items.size(), 0, "purchased item should be removed from shop inventory", failures)
	_assert_eq(shop.shop_container.get_child_count(), 0, "purchased item slot should disappear from shop UI", failures)

	_assert_false(shop.purchase_item(item), "removed shop item should not be purchasable again", failures)
	_assert_eq(shop.gold, 70, "failed repeated purchase should not subtract gold", failures)


func _test_clicking_shop_slot_removes_purchased_item_safely(failures: Array[String]) -> void:
	var shop: Control = get_root().get_node_or_null("Shop") as Control
	var inventory: Node = get_root().get_node_or_null("Inventory")
	if shop == null or inventory == null:
		failures.append("Shop and Inventory autoloads should exist")
		return

	_clear_inventory(inventory)
	var item := _make_item("clicked_purchase", 20, true, false)
	shop.set_initial_gold()
	var shop_list: Array[Item] = [item]
	shop.set_shop_inventory(shop_list)
	shop.mode = shop.MODE.ON
	await process_frame

	var slot: Node = shop.shop_container.get_child(0)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	slot._on_gui_input(event)
	await process_frame

	_assert_eq(shop.shop_items.size(), 0, "clicked purchase should remove item from shop inventory", failures)
	_assert_eq(shop.shop_container.get_child_count(), 0, "clicked purchase should remove shop slot after signal completes", failures)
	_assert_eq(shop.gold, 80, "clicked purchase should subtract item price", failures)
	shop.mode = shop.MODE.OFF


func _test_selling_owned_item_returns_half_price_and_removes_item(failures: Array[String]) -> void:
	var shop: Control = get_root().get_node_or_null("Shop") as Control
	var inventory: Node = get_root().get_node_or_null("Inventory")
	if shop == null or inventory == null:
		failures.append("Shop and Inventory autoloads should exist")
		return

	_clear_inventory(inventory)
	var item := _make_item("sell_half", 31, false, true)
	inventory.add_item(item)
	shop.gold = 10

	_assert_eq(shop.call("sell_item", item), true, "selling owned item should succeed", failures)
	_assert_eq(shop.gold, 25, "selling should return floor half of item price", failures)
	_assert_false(inventory.has_item_id("sell_half"), "sold item should be removed from inventory", failures)
	_assert_eq(inventory.relic_items.size(), 0, "sold relic should be removed from relic bar", failures)

	_assert_eq(shop.call("sell_item", item), false, "selling an item no longer owned should fail", failures)
	_assert_eq(shop.gold, 25, "failed sell should not add gold", failures)


func _test_right_click_owned_collection_slot_sells_item(failures: Array[String]) -> void:
	var shop: Control = get_root().get_node_or_null("Shop") as Control
	var inventory: Node = get_root().get_node_or_null("Inventory")
	if shop == null or inventory == null:
		failures.append("Shop and Inventory autoloads should exist")
		return

	_clear_inventory(inventory)
	var item := _make_item("right_click_sell", 20, false, true)
	inventory.add_item(item)
	shop.gold = 5
	shop.mode = shop.MODE.ON
	shop.refresh_collection_rows()

	var relic_row: HBoxContainer = shop.relic_bar_container
	if relic_row == null or relic_row.get_child_count() == 0:
		failures.append("relic row should have at least one slot")
		return

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	shop._on_collection_slot_gui_input(event, relic_row.get_child(0))

	_assert_eq(shop.gold, 15, "right-clicking owned item should sell for half price", failures)
	_assert_false(inventory.has_item_id("right_click_sell"), "right-click sold item should leave inventory", failures)
	shop.mode = shop.MODE.OFF


func _assert_eq(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _assert_true(actual: bool, message: String, failures: Array[String]) -> void:
	if not actual:
		failures.append("%s: expected true, got false" % message)


func _assert_false(actual: bool, message: String, failures: Array[String]) -> void:
	if actual:
		failures.append("%s: expected false, got true" % message)


func _make_item(id: String, price: int, is_marble: bool, is_relic: bool) -> Item:
	var item := Item.new()
	item.id = id
	item.title = id
	item.price = price
	if is_marble:
		item.type = TYPE_MARBLE
	elif is_relic:
		item.type = TYPE_RELIC
	return item


func _clear_inventory(inventory: Node) -> void:
	inventory.items.clear()
	if _has_property(inventory, "marble_items"):
		inventory.marble_items.clear()
	if _has_property(inventory, "relic_items"):
		inventory.relic_items.clear()
	if inventory.has_signal(&"inventory_changed"):
		inventory.inventory_changed.emit()


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return true
	return false
