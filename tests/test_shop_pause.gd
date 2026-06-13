extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	await _test_shop_pauses_while_open_and_resumes_when_closed(failures)

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


func _assert_eq(actual: Variant, expected: Variant, message: String, failures: Array[String]) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


func _assert_true(actual: bool, message: String, failures: Array[String]) -> void:
	if not actual:
		failures.append("%s: expected true, got false" % message)


func _assert_false(actual: bool, message: String, failures: Array[String]) -> void:
	if actual:
		failures.append("%s: expected false, got true" % message)
