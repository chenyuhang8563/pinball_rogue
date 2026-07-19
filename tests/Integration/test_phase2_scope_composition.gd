extends GutTest

const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")
const MainScene: PackedScene = preload("res://Main/main.tscn")
const ShopScene: PackedScene = preload("res://Shop/shop.tscn")
const DevilShopScene: PackedScene = preload("res://DevilShop/devil_shop.tscn")
const EffectManagerScript: GDScript = preload("res://Effects/effect_manager.gd")


func test_initial_loadout_and_consumers_share_one_scope_ports_without_starting_run() -> void:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	stats.set("values", {
		"marble_slot_count": 3,
		"relic_slot_count": 3,
		"buy_price_multiplier": 1.0,
		"sell_price_multiplier": 0.5,
	})
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var main: Node = autofree(MainScene.instantiate())
	assert_true(main.call("_setup_run_scope", stats, effect_manager))
	var scope: Node = main.get("run_scope") as Node
	assert_not_null(scope)
	assert_true(main.call("_setup_run_scope", stats, effect_manager))
	assert_eq(main.get("run_scope"), scope, "Main 重复装配不得创建第二个 RunScope")
	var loadout: RefCounted = scope.get("loadout") as RefCounted
	var progression: RefCounted = scope.get("progression") as RefCounted
	var wallet: RefCounted = scope.get("wallet") as RefCounted
	var health: RefCounted = scope.get("health") as RefCounted
	var dark: Item = load("res://Resources/dark_marble.tres") as Item
	var dash: Item = load("res://Resources/dash_skill.tres") as Item

	assert_eq(loadout.call("owned_items"), [dark, dash])
	assert_eq(loadout.call("get_chain_items"), [dark])
	assert_eq(loadout.call("current_skill"), dash)

	var shop: Control = autofree(ShopScene.instantiate()) as Control
	var devil_shop: Control = autofree(DevilShopScene.instantiate()) as Control
	var skill_controller: Node = main.get_node("SkillController")
	assert_true(shop.call("configure", loadout, progression, wallet))
	assert_true(devil_shop.call("configure", loadout, progression, wallet, health))
	assert_true(skill_controller.call("configure", loadout, progression))

	for consumer: Node in [shop, devil_shop, skill_controller, effect_manager]:
		assert_eq(consumer.get("_loadout"), loadout)
		assert_eq(consumer.get("_progression"), progression)
	assert_eq(shop.get("_wallet"), wallet)
	assert_eq(devil_shop.get("_wallet"), wallet)
	assert_eq(devil_shop.get("_health"), health)
