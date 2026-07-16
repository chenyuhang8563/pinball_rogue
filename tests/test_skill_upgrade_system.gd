extends GutTest


const UpgradeSystemScript: GDScript = preload("res://Run/marble_upgrade_system.gd")
const InventoryScript: GDScript = preload("res://Inventory/inventory.gd")


# Verifies each skill upgrade reaches the requested values and stops at its maximum level.
func test_skill_levels_match_the_requested_dash_and_missile_values() -> void:
	var system := UpgradeSystemScript.new()
	add_child_autofree(system)

	assert_eq(system.get_skill_values("dash").get("recharge_time"), 5.0)
	assert_true(system.upgrade_skill("dash"))
	assert_eq(system.get_skill_values("dash").get("recharge_time"), 4.0)
	assert_true(system.upgrade_skill("dash"))
	assert_eq(system.get_skill_values("dash").get("dash_damage_multiplier"), 1.2)
	assert_eq(system.get_skill_values("dash").get("dash_damage_duration"), 2.0)
	assert_true(system.upgrade_skill("dash"))
	assert_eq(system.get_skill_values("dash").get("dash_damage_multiplier"), 1.4)
	assert_false(system.upgrade_skill("dash"))

	assert_true(system.upgrade_skill("magic_missile"))
	assert_true(system.upgrade_skill("magic_missile"))
	assert_true(system.upgrade_skill("magic_missile"))
	var missile_values: Dictionary = system.get_skill_values("magic_missile")
	assert_eq(missile_values.get("recharge_time"), 2.5)
	assert_eq(missile_values.get("base_damage"), 24)
	assert_eq(missile_values.get("projectile_lifetime"), 6.0)


# Verifies relic, marble, and skill upgrade candidates apply to their intended owner state.
func test_upgrade_candidates_include_owned_relic_marble_and_skill_then_apply_the_selected_type() -> void:
	var inventory := InventoryScript.new()
	var system := UpgradeSystemScript.new()
	add_child_autofree(inventory)
	add_child_autofree(system)

	var marble := Item.new()
	marble.id = "test_marble"
	marble.type = Item.ItemType.MARBLE
	marble.marble_type = Marble.MARBLE_TYPE.DEFAULT
	var relic := Item.new()
	relic.id = "test_relic"
	relic.type = Item.ItemType.RELIC
	assert_true(inventory.add_item(marble))
	assert_true(inventory.add_item(relic))

	var candidates: Array = system.get_upgradable_items(inventory)
	assert_has(candidates, marble)
	assert_has(candidates, relic)
	assert_true(system.upgrade_item(marble, inventory))
	assert_eq(system.get_level(Marble.MARBLE_TYPE.DEFAULT), 2)
	assert_true(system.upgrade_item(relic, inventory))
	assert_eq(inventory.get_relic_level(relic), 2)
