extends GutTest

const RunScopeScript: GDScript = preload("res://Game/Bootstrap/run_scope.gd")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const NormalSessionScript: GDScript = preload("res://Commerce/application/normal_shop_session.gd")
const DevilSessionScript: GDScript = preload("res://Commerce/application/devil_shop_session.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const DevilConfig: Resource = preload("res://Commerce/data/default_devil_shop_config.tres")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


class FakeStats extends Node:
	func get_stat(stat_id: String, _entity_id: String) -> Variant:
		if stat_id.contains("slot_count"):
			return 10
		if stat_id == "sell_price_multiplier":
			return 0.5
		return 1.0


func test_scope_rng_and_battle_entry_round_trip_restores_only_checkpoint_state() -> void:
	var registry := get_tree().root.get_node_or_null(^"ContentRegistry")
	var scope := _scope()
	var brown := registry.call(&"by_id", &"brown_marble") as Item
	assert_true(scope.loadout.call("add", brown))
	assert_true(scope.loadout.call("set_chain_items", [brown, registry.call(&"by_id", &"dark_marble")]))
	assert_true(scope.progression.call("upgrade_one", brown))
	assert_true(scope.wallet.call("set_balance", 321))
	assert_true(scope.health.call("set_current", 7))
	var saved_scope := scope.snapshot()

	assert_true(scope.wallet.call("set_balance", 1))
	assert_true(scope.health.call("set_current", 2))
	assert_true(scope.loadout.call("remove", brown))
	assert_true(scope.restore(saved_scope, registry))
	assert_eq(scope.wallet.call("balance"), 321)
	assert_eq(scope.health.call("current"), 7)
	assert_eq(_item_ids(scope.loadout.call("get_chain_items")), [&"brown_marble", &"dark_marble"])
	assert_eq(scope.progression.call("level_of", brown), 2)
	var held: Object = scope.held_components
	assert_not_null(held)
	assert_eq(held.call("count_of", &"barrel"), 1)
	assert_eq(held.call("count_of", &"booster"), 1)
	assert_eq(held.call("count_of", &"portal"), 1)
	var before_invalid := scope.snapshot()
	var invalid := before_invalid.duplicate(true)
	invalid[&"progression"][&"marble_levels"][999] = 99
	assert_false(scope.restore(invalid, registry))
	assert_eq(scope.snapshot(), before_invalid, "非法成长字段不得产生部分恢复")

	var random := RunRandomSource.new(991)
	random.range_int(1, 1000)
	var random_state := random.snapshot()
	var expected := random.range_int(1, 1000)
	assert_true(random.restore(random_state))
	assert_eq(random.range_int(1, 1000), expected)

	var state := RunState.new()
	assert_true(state.begin_run())
	var group := BattleGroupDef.new()
	group.id = "checkpoint_battle"
	group.kind = BattleGroupDef.Kind.WEAK_NORMAL
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = EnemyScene
	entry.position = Vector2(20, 30)
	entry.health = 47
	group.enemy_entries = [entry]
	var plan := BattlePlan.new(
		&"checkpoint_battle", group, BattlePlan.Origin.RUN_START,
		BattlePlan.RewardPolicy.NORMAL
	)
	assert_true(state.begin_first_battle(plan))
	var restored := RunState.new()
	assert_true(restored.restore(state.snapshot()))
	assert_eq(restored.phase, RunState.Phase.BATTLE_ACTIVE)
	assert_eq(restored.battle_plan.group.enemy_entries[0].health, 47)
	assert_eq(restored.battle_plan.group.enemy_entries[0].position, Vector2(20, 30))
	assert_eq(restored.battle_plan.group.enemy_entries[0].scene.resource_path, EnemyScene.resource_path)


func test_loadout_and_chain_revisions_are_stable_across_resource_instances() -> void:
	var dark := load("res://Content/data/dark_marble.tres") as Item
	var dash := load("res://Content/data/dash_skill.tres") as Item
	var first: RefCounted = LoadoutScript.new()
	var second: RefCounted = LoadoutScript.new()
	assert_true(first.call("add", dark))
	assert_true(first.call("add", dash))
	assert_true(second.call("add", dark.duplicate(true)))
	assert_true(second.call("add", dash.duplicate(true)))
	assert_ne((first.call("owned_items") as Array)[0].get_instance_id(), (second.call("owned_items") as Array)[0].get_instance_id())
	assert_eq(first.call("revision"), second.call("revision"))
	assert_eq(
		first.call("snapshot")[&"marble_loadout"][&"revision"],
		second.call("snapshot")[&"marble_loadout"][&"revision"]
	)
	first.call("dispose")
	second.call("dispose")


func test_normal_and_devil_shop_restore_same_stock_without_regeneration() -> void:
	var registry := get_tree().root.get_node_or_null(^"ContentRegistry")
	var source_scope := _scope()
	assert_true(source_scope.wallet.call("set_balance", 1000))
	var scope_state := source_scope.snapshot()
	var normal: RefCounted = NormalSessionScript.new()
	assert_true(normal.call("configure", source_scope.loadout, source_scope.progression, source_scope.wallet, RunRandomSource.new(7), registry))
	normal.call("begin_visit")
	var normal_offers: Array = normal.call("regenerate", registry.call("all_items"), 4)
	assert_false(normal_offers.is_empty())
	var normal_snapshot: Dictionary = normal.call("snapshot")

	var restored_scope := _scope()
	assert_true(restored_scope.restore(scope_state, registry))
	var restored_normal: RefCounted = NormalSessionScript.new()
	assert_true(restored_normal.call("configure", restored_scope.loadout, restored_scope.progression, restored_scope.wallet, RunRandomSource.new(999), registry))
	assert_true(restored_normal.call("restore", normal_snapshot))
	restored_normal.call("begin_visit")
	var presented_normal: Array = restored_normal.call("regenerate", registry.call("all_items"), 4)
	assert_eq(_offer_signature(presented_normal), _offer_signature(normal_offers))
	var purchased: RefCounted = restored_normal.call("purchase", presented_normal[0].offer_id)
	assert_eq(purchased.code, PurchaseResultScript.Code.SUCCESS, "恢复报价应重绑当前 revision 而不是误判过期")

	var devil: RefCounted = DevilSessionScript.new()
	assert_true(devil.call("configure", source_scope.loadout, source_scope.progression, source_scope.wallet, source_scope.health, RunRandomSource.new(11), registry))
	devil.call("begin_visit")
	var devil_offers: Array = devil.call("open", DevilConfig, DevilConfig.item_pool)
	assert_false(devil_offers.is_empty())
	var devil_snapshot: Dictionary = devil.call("snapshot")
	var restored_devil: RefCounted = DevilSessionScript.new()
	assert_true(restored_devil.call("configure", restored_scope.loadout, restored_scope.progression, restored_scope.wallet, restored_scope.health, RunRandomSource.new(999), registry))
	assert_true(restored_devil.call("restore", devil_snapshot))
	restored_devil.call("begin_visit")
	var presented_devil: Array = restored_devil.call("open", DevilConfig, DevilConfig.item_pool)
	assert_eq(_offer_signature(presented_devil), _offer_signature(devil_offers))


func _scope() -> RunScope:
	var scope := add_child_autofree(RunScopeScript.new()) as RunScope
	var stats: Node = add_child_autofree(FakeStats.new())
	assert_true(scope.initialize(stats, 100, 10))
	var registry := get_tree().root.get_node_or_null(^"ContentRegistry")
	assert_true(scope.loadout.call("add", registry.call(&"by_id", &"dark_marble")))
	assert_true(scope.loadout.call("add", registry.call(&"by_id", &"dash")))
	return scope


func _item_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName((value as Item).id))
	return result


func _offer_signature(values: Array) -> Array[String]:
	var result: Array[String] = []
	for offer: Variant in values:
		result.append("%s|%s|%d|%d" % [offer.offer_id, offer.item.id, offer.target_level, offer.price])
	return result
