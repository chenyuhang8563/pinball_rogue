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


func test_scope_restores_after_tres_serialization_round_trip() -> void:
	# 回归：progression.revision 曾用顺序敏感的 Dictionary.hash()，经 .tres
	# 写盘重载后字典插入顺序改变，revision 永不匹配，导致真实存档（进战斗退出后
	# 点继续）恢复失败、只剩默认黑弹珠。这里走仓库的真实写读路径，把 scope
	# 快照序列化到 .tres 再加载，确认能完整恢复。
	var registry := get_tree().root.get_node_or_null(^"ContentRegistry")
	var repo: Node = get_tree().root.get_node_or_null(^"RunSaveRepository")
	assert_not_null(repo, "RunSaveRepository autoload 应在测试场景中")
	var save_path := "user://saves/test_tres_round_trip.tres"
	repo.call("set_paths_for_test", save_path)
	repo.call("delete_save")

	var source := _scope()
	var lightning := registry.call(&"by_id", &"lightning_marble") as Item
	var brown := registry.call(&"by_id", &"brown_marble") as Item
	var dark := registry.call(&"by_id", &"dark_marble") as Item
	assert_true(source.loadout.call("add", lightning))
	assert_true(source.loadout.call("add", brown))
	# 链必须包含全部已拥有弹珠（_is_complete_marble_order）。
	assert_true(source.loadout.call("set_chain_items", [lightning, brown, dark]))
	assert_true(source.progression.call("set_level", lightning, 3))
	assert_true(source.progression.call("set_level", brown, 4))
	assert_true(source.wallet.call("set_balance", 321))
	assert_true(source.health.call("set_current", 7))
	var scope_state: Dictionary = source.snapshot()

	var checkpoint := {
		&"scope": scope_state,
		&"random": {},
		&"flow": {},
		&"content_ids": scope_state[&"owned_item_ids"],
	}
	assert_true(repo.call("write_checkpoint", checkpoint), "checkpoint 应能写盘")
	var loaded: RunSaveData = repo.call("load_save")
	assert_not_null(loaded, "写盘后应能重新加载存档")

	var restored := _scope()
	assert_true(restored.restore(loaded.checkpoint[&"scope"] as Dictionary, registry),
		"经 .tres 往返后的 scope 应可完整恢复")
	assert_eq(restored.wallet.call("balance"), 321)
	assert_eq(restored.health.call("current"), 7)
	assert_eq(restored.progression.call("level_of", lightning), 3)
	assert_eq(restored.progression.call("level_of", brown), 4)
	assert_eq(_item_ids(restored.loadout.call("get_chain_items")),
		[&"lightning_marble", &"brown_marble", &"dark_marble"])

	repo.call("delete_save")
	repo.call("reset_paths")


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
