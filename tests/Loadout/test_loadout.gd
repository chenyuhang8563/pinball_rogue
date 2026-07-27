extends GutTest

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")

var marble_capacity: int = 3
var relic_capacity: int = 3


func test_add_remove_replace_capacity_and_identity() -> void:
	var loadout: RefCounted = LoadoutScript.new(Callable(self, "_capacity"))
	var dark := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var dark_duplicate := _item("other_id", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var bomb := _item("bomb", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BOMB)
	var relic := _item("relic", Item.ItemType.RELIC)
	var relic_duplicate := _item("relic", Item.ItemType.RELIC)
	var dash := _item("dash", Item.ItemType.SKILL)
	var missile := _item("magic_missile", Item.ItemType.SKILL)

	marble_capacity = 1
	assert_true(loadout.call("add", dark))
	assert_false(loadout.call("add", dark_duplicate), "弹珠按 marble_type 去重")
	assert_false(loadout.call("add", bomb), "provider 当前容量应即时生效")
	marble_capacity = 2
	assert_true(loadout.call("add", bomb))
	assert_true(loadout.call("add", relic))
	assert_false(loadout.call("add", relic_duplicate), "遗物按稳定 identity 去重")
	assert_true(loadout.call("add", dash))
	assert_true(loadout.call("replace_skill", missile))
	assert_null(loadout.call("find_owned", dash))
	assert_eq(loadout.call("current_skill"), missile)
	assert_true(loadout.call("remove", dark_duplicate), "remove 接受同 identity 的候选")
	assert_eq(loadout.call("get_chain_items"), [bomb])


func test_marble_loadout_is_complete_order_source_and_tracks_remove() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var dark := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var bomb := _item("bomb", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BOMB)
	var green := _item("green", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.GREEN)
	var unowned := _item("blue", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BLUE)
	assert_true(loadout.call("add", dark))
	assert_true(loadout.call("add", bomb))
	assert_true(loadout.call("add", green))
	assert_eq(loadout.call("get_chain_items"), [dark, bomb, green], "add 必须自动 append")
	assert_true(loadout.call("set_chain_items", [green, dark, bomb]))
	assert_eq(loadout.call("get_chain_items"), [green, dark, bomb])
	assert_false(loadout.call("set_chain_items", [green, dark]), "拒绝缺项")
	assert_false(loadout.call("set_chain_items", [green, dark, unowned]), "拒绝非 owned")
	assert_false(loadout.call("set_chain_items", [green, dark, dark]), "拒绝重复")
	assert_eq(loadout.call("get_chain_items"), [green, dark, bomb])
	assert_true(loadout.call("remove", dark))
	assert_eq(loadout.call("get_chain_items"), [green, bomb], "ownership remove 必须同步顺序源")


func test_snapshot_restore_recovers_ownership_order_skill_signals_and_revision() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var dark := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var bomb := _item("bomb", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.BOMB)
	var dash := _item("dash", Item.ItemType.SKILL)
	var missile := _item("magic_missile", Item.ItemType.SKILL)
	assert_true(loadout.call("add", dark))
	assert_true(loadout.call("add", bomb))
	assert_true(loadout.call("add", dash))
	assert_true(loadout.call("set_chain_items", [bomb, dark]))
	var saved: Dictionary = loadout.call("snapshot")
	assert_true(loadout.call("replace_skill", missile))
	assert_true(loadout.call("set_chain_items", [dark, bomb]))
	watch_signals(loadout)

	assert_true(loadout.call("restore", saved))

	assert_eq(loadout.call("owned_items"), [dark, bomb, dash])
	assert_eq(loadout.call("get_chain_items"), [bomb, dark])
	assert_eq(loadout.call("revision"), saved[&"revision"])
	assert_signal_emit_count(loadout, "marble_loadout_changed", 1)
	assert_signal_emit_count(loadout, "skill_slot_changed", 1)
	assert_signal_emit_count(loadout, "changed", 1)


func test_default_relic_capacity_accepts_five_and_rejects_the_sixth() -> void:
	# Regression source: Phase 0c raises the baseline relic capacity from 3 to 5.
	# Boundary: the sixth unique relic is rejected without changing owned state.
	var loadout: RefCounted = LoadoutScript.new()
	for index: int in range(5):
		assert_true(loadout.call("add", _item("relic_%d" % index, Item.ItemType.RELIC)))
	assert_false(loadout.call("add", _item("relic_6", Item.ItemType.RELIC)))
	assert_eq((loadout.call("relics") as Array).size(), 5)


func _capacity(item_type: Item.ItemType, fallback: int) -> int:
	if item_type == Item.ItemType.MARBLE:
		return marble_capacity
	if item_type == Item.ItemType.RELIC:
		return relic_capacity
	return fallback


func _item(id: String, type: Item.ItemType, marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT) -> Item:
	var result := Item.new()
	result.id = id
	result.type = type
	result.marble_type = marble_type
	return result
