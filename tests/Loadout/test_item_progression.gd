extends GutTest

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


func test_marble_relic_and_skill_progress_from_i_to_awakened_iv() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	var skill := _item("dash", Item.ItemType.SKILL)
	for item: Item in [marble, relic, skill]:
		assert_true(loadout.call("add", item))
		assert_eq(progression.call("level_of", item), 1)
		assert_true(progression.call("upgrade_one", item))
		assert_eq(progression.call("level_of", item), 2)
		assert_true(progression.call("upgrade_one", item))
		assert_eq(progression.call("level_of", item), 3)
		assert_true(progression.call("upgrade_one", item))
		assert_eq(progression.call("level_of", item), 4)
		assert_false(progression.call("can_upgrade", item))


func test_skill_values_follow_owned_progression_levels() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var dash := _item("dash", Item.ItemType.SKILL)
	assert_true(loadout.call("add", dash))
	assert_eq(progression.call("get_skill_values", "dash").get("recharge_time"), 5.0)
	assert_true(progression.call("upgrade_one", dash))
	assert_eq(progression.call("get_skill_values", "dash").get("recharge_time"), 4.0)
	assert_true(progression.call("upgrade_one", dash))
	assert_eq(progression.call("get_skill_values", "dash").get("dash_damage_multiplier"), 1.2)
	assert_eq(progression.call("get_skill_values", "dash").get("dash_damage_duration"), 2.0)
	assert_true(progression.call("upgrade_one", dash))
	assert_eq(progression.call("get_skill_values", "dash").get("dash_damage_multiplier"), 1.4)
	var missile := _item("magic_missile", Item.ItemType.SKILL)
	assert_true(loadout.call("replace_skill", missile))
	for _upgrade: int in 3:
		assert_true(progression.call("upgrade_one", missile))
	var missile_values: Dictionary = progression.call("get_skill_values", "magic_missile")
	assert_eq(missile_values.get("recharge_time"), 2.5)
	assert_eq(missile_values.get("base_damage"), 24)
	assert_eq(missile_values.get("projectile_lifetime"), 6.0)
	assert_false(progression.call("upgrade_one", missile))


func test_upgradable_owned_items_include_each_supported_owned_type() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	var skill := _item("dash", Item.ItemType.SKILL)
	for item: Item in [marble, relic, skill]:
		assert_true(loadout.call("add", item))

	var candidates: Array = progression.call("upgradable_owned_items")

	assert_has(candidates, marble)
	assert_has(candidates, relic)
	assert_has(candidates, skill)


func test_unknown_skill_and_unowned_quote_semantics() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var known_unowned := _item("magic_missile", Item.ItemType.SKILL)
	var unknown := _item("not_registered", Item.ItemType.SKILL)
	assert_eq(progression.call("level_of", unknown), 0)
	assert_false(progression.call("can_upgrade", unknown))
	assert_true(progression.call("can_upgrade", known_unowned), "已知未拥有技能可用于报价")
	assert_false(progression.call("upgrade_one", known_unowned), "实际成长必须 owned")
	assert_eq(progression.call("level_of", known_unowned), 1)


func test_skill_replacement_reset_and_all_growth_snapshot_restore() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var marble := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	var relic := _item("relic", Item.ItemType.RELIC)
	var dash := _item("dash", Item.ItemType.SKILL)
	var missile := _item("magic_missile", Item.ItemType.SKILL)
	assert_true(loadout.call("add", marble))
	assert_true(loadout.call("add", relic))
	assert_true(loadout.call("add", dash))
	for item: Item in [marble, relic, dash]:
		assert_true(progression.call("upgrade_one", item))
	var saved: Dictionary = progression.call("snapshot")
	for item: Item in [marble, relic, dash]:
		assert_true(progression.call("upgrade_one", item))
	assert_true(loadout.call("replace_skill", missile))
	assert_true(progression.call("reset_skill", dash.id))
	assert_eq(progression.call("level_of", dash), 1)
	assert_eq(progression.call("level_of", missile), 1)

	assert_true(progression.call("restore", saved))
	assert_eq(progression.call("level_of", marble), 2)
	assert_eq(progression.call("level_of", relic), 2)
	assert_eq(progression.call("level_of", dash), 2)
	assert_eq(progression.call("revision"), saved[&"revision"])


func test_marble_growth_publishes_modifiers_to_stat_system() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout, stats)
	var dark := _item("dark", Item.ItemType.MARBLE, Marble.MARBLE_TYPE.DEFAULT)
	assert_true(loadout.call("add", dark))
	assert_true(progression.call("upgrade_one", dark))
	assert_eq(stats.call("modifier_value", "dark_marble_damage"), 2.0)
	assert_true(progression.call("upgrade_one", dark))
	assert_true(progression.call("upgrade_one", dark))
	assert_eq(stats.call("modifier_value", "dark_marble_damage"), 4.0)
	progression.call("dispose")
	assert_true((stats.get("modifiers") as Array).is_empty())


func _item(id: String, type: Item.ItemType, marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT) -> Item:
	var result := Item.new()
	result.id = id
	result.type = type
	result.marble_type = marble_type
	return result
