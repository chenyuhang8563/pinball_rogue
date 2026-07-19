extends GutTest

const RunScopeScript: GDScript = preload("res://Game/Bootstrap/run_scope.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


func test_initialize_once_explicitly_owns_four_states_and_dispose_is_terminal() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var scope: Node = add_child_autofree(RunScopeScript.new())
	assert_true(scope.call("initialize", stats, 75, 30))
	assert_true(scope.call("is_initialized"))
	assert_not_null(scope.get("loadout"))
	assert_not_null(scope.get("progression"))
	assert_not_null(scope.get("wallet"))
	assert_not_null(scope.get("health"))
	assert_eq(scope.get("wallet").call("balance"), 75)
	assert_eq(scope.get("health").call("current"), 30)
	assert_false(scope.call("initialize", stats), "同一 scope 只允许 initialize 一次")
	scope.call("dispose")
	assert_false(scope.call("is_initialized"))
	assert_null(scope.get("loadout"))
	assert_null(scope.get("progression"))
	assert_null(scope.get("wallet"))
	assert_null(scope.get("health"))
	assert_false(scope.call("initialize", stats), "dispose 后也不能复用")


func test_reset_for_run_preserves_ownership_and_chain_but_resets_growth_wallet_health() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	stats.set("values", {
		"marble_slot_count": 3,
		"relic_slot_count": 3,
		"buy_price_multiplier": 1.0,
		"sell_price_multiplier": 0.5,
	})
	var scope: Node = add_child_autofree(RunScopeScript.new())
	assert_true(scope.call("initialize", stats, 80, 25))
	var dark := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var bomb := _item("bomb", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BOMB)
	assert_true(scope.get("loadout").call("add", dark))
	assert_true(scope.get("loadout").call("add", bomb))
	assert_true(scope.get("loadout").call("set_chain_items", [bomb, dark]))
	assert_true(scope.get("progression").call("upgrade_one", dark))
	assert_true(scope.get("wallet").call("debit", 30))
	assert_true(scope.get("health").call("debit", 5))

	assert_true(scope.call("reset_for_run"))

	assert_eq(scope.get("loadout").call("owned_items"), [dark, bomb])
	assert_eq(scope.get("loadout").call("get_chain_items"), [bomb, dark])
	assert_eq(scope.get("progression").call("level_of", dark), 1)
	assert_eq(scope.get("wallet").call("balance"), 80)
	assert_eq(scope.get("health").call("current"), 25)


func test_scope_providers_read_dynamic_capacity_and_price_stats() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	stats.set("values", {
		"marble_slot_count": 1,
		"relic_slot_count": 1,
		"buy_price_multiplier": 1.5,
		"sell_price_multiplier": 0.25,
	})
	var scope: Node = add_child_autofree(RunScopeScript.new())
	assert_true(scope.call("initialize", stats))
	assert_eq(scope.get("health").call("current"), 10)
	var first := _item("first", Item.ItemType.RELIC)
	first.price = 20
	var second := _item("second", Item.ItemType.RELIC)
	assert_true(scope.get("loadout").call("add", first))
	assert_false(scope.get("loadout").call("add", second))
	assert_eq(scope.get("wallet").call("quote_price", first), 30)
	assert_eq(scope.get("wallet").call("quote_sell_price", first), 5)
	var values: Dictionary = stats.get("values")
	values["relic_slot_count"] = 2
	values["buy_price_multiplier"] = 2.0
	assert_true(scope.get("loadout").call("add", second))
	assert_eq(scope.get("wallet").call("quote_price", first), 40)


func _item(id: String, type: Item.ItemType, marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT) -> Item:
	var result := Item.new()
	result.id = id
	result.type = type
	result.marble_type = marble_type
	return result
