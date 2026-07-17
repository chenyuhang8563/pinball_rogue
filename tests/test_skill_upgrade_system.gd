extends GutTest


const UpgradeSystemScript: GDScript = preload("res://Run/marble_upgrade_system.gd")
const InventoryScript: GDScript = preload("res://Inventory/inventory.gd")


# 验证技能升级达到指定数值并在最高等级停止。
func test_skill_levels_match_the_requested_dash_and_missile_values() -> void:
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
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


# 验证遗物、弹珠和技能升级候选作用于正确的持有状态。
func test_upgrade_candidates_include_owned_relic_marble_and_skill_then_apply_the_selected_type() -> void:
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
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


# 验证替换技能后清除旧技能升级进度。
func test_reset_skill_level_discards_replaced_skill_progression() -> void:
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(system)

	assert_true(system.upgrade_skill("dash"))
	assert_true(system.upgrade_skill("dash"))
	assert_eq(system.get_skill_level("dash"), 3)

	system.reset_skill_level("dash")

	assert_eq(system.get_skill_level("dash"), 1)


# 验证没有升级定义的技能不会被误判为可升级商品。
func test_unknown_skill_is_not_upgradeable() -> void:
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	var inventory: Variant = InventoryScript.new()
	add_child_autofree(system)
	add_child_autofree(inventory)
	var skill := Item.new()
	skill.id = "teleport"
	skill.type = Item.ItemType.SKILL

	assert_false(system.can_upgrade_item(skill, inventory))
