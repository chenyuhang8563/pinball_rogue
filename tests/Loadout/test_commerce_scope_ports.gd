extends GutTest

const RunScopeScript: GDScript = preload("res://Game/Bootstrap/run_scope.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")
const NormalSessionScript: GDScript = preload("res://Commerce/application/normal_shop_session.gd")
const DevilSessionScript: GDScript = preload("res://Commerce/application/devil_shop_session.gd")
const CommerceOfferScript: GDScript = preload("res://Commerce/domain/commerce_offer.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const DevilShopConfigScript: GDScript = preload("res://DevilShop/devil_shop_config.gd")


func test_normal_purchase_uses_scope_ports_directly() -> void:
	var scope := _scope(100, 20)
	var session: RefCounted = NormalSessionScript.new()
	assert_true(session.call("configure", scope.get("loadout"), scope.get("progression"), scope.get("wallet")))
	var relic := _item("normal_relic", Item.ItemType.RELIC, 30)
	var offer := _normal_offer(session, relic, 1, 30, false)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(scope.get("loadout").call("find_owned", relic), relic)
	assert_eq(scope.get("wallet").call("balance"), 70)


func test_normal_failed_skill_reset_rolls_back_real_scope_ports() -> void:
	var scope := _scope(100, 20)
	var unknown_old := _item("unknown_old_normal", Item.ItemType.SKILL, 1)
	var dash := _item("dash", Item.ItemType.SKILL, 25)
	assert_true(scope.get("loadout").call("add", unknown_old))
	var session: RefCounted = NormalSessionScript.new()
	assert_true(session.call("configure", scope.get("loadout"), scope.get("progression"), scope.get("wallet")))
	var offer := _normal_offer(session, dash, 1, 25, false)
	assert_true(session.call("authorize_skill_replacement", offer.offer_id))
	var before := _scope_state(scope)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.COMMIT_FAILED)
	assert_true(result.rollback_completed)
	assert_eq(_scope_state(scope), before)
	assert_eq(scope.get("loadout").call("current_skill"), unknown_old)
	assert_null(scope.get("loadout").call("find_owned", dash))


func test_devil_purchase_uses_scope_ports_directly() -> void:
	var scope := _scope(100, 20)
	var session := _devil_session(scope)
	var relic := _item("devil_relic", Item.ItemType.RELIC, 20)
	var offer := _devil_offer(session, relic, 2, 20, false)
	assert_eq(session.call("select_payment", offer.offer_id, 10, 2).code, PurchaseResultScript.Code.SUCCESS)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(scope.get("wallet").call("balance"), 90)
	assert_eq(scope.get("health").call("current"), 18)
	assert_eq(scope.get("progression").call("level_of", relic), 2)


func test_devil_failed_skill_reset_rolls_back_all_real_scope_ports() -> void:
	var scope := _scope(100, 20)
	var unknown_old := _item("unknown_old_devil", Item.ItemType.SKILL, 1)
	var dash := _item("dash", Item.ItemType.SKILL, 25)
	assert_true(scope.get("loadout").call("add", unknown_old))
	var session := _devil_session(scope)
	var offer := _devil_offer(session, dash, 2, 25, false)
	assert_true(session.call("authorize_skill_replacement", offer.offer_id))
	assert_eq(session.call("select_payment", offer.offer_id, 15, 2).code, PurchaseResultScript.Code.SUCCESS)
	var before := _scope_state(scope)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.COMMIT_FAILED)
	assert_true(result.rollback_completed)
	assert_eq(_scope_state(scope), before)
	assert_eq(scope.get("loadout").call("current_skill"), unknown_old)
	assert_null(scope.get("loadout").call("find_owned", dash))


func _scope(gold: int, health: int) -> Node:
	var stats: Node = add_child_autofree(FakeStatSystemScript.new())
	stats.set("values", {
		"marble_slot_count": 3,
		"relic_slot_count": 3,
		"buy_price_multiplier": 1.0,
		"sell_price_multiplier": 0.5,
	})
	var scope: Node = add_child_autofree(RunScopeScript.new())
	assert_true(scope.call("initialize", stats, gold, health))
	return scope


func _normal_offer(session: RefCounted, item: Item, target: int, price: int, upgrade: bool) -> RefCounted:
	var external: RefCounted = CommerceOfferScript.new(&"external", 0, item, "", target, price, price, upgrade)
	var offers: Array = session.call("replace_offers", [external])
	assert_eq(offers.size(), 1)
	return offers[0] as RefCounted


func _devil_session(scope: Node) -> RefCounted:
	var session: RefCounted = DevilSessionScript.new()
	assert_true(session.call("configure", scope.get("loadout"), scope.get("progression"), scope.get("wallet"), scope.get("health")))
	var config: Resource = DevilShopConfigScript.new()
	config.set("stock_count", 0)
	config.set("health_to_gold", 5)
	config.set("minimum_remaining_health", 1)
	config.set("level_price_multipliers", {1: 1.0, 2: 1.5, 3: 2.0, 4: 3.0})
	assert_true((session.call("open", config, []) as Array).is_empty())
	return session


func _devil_offer(session: RefCounted, item: Item, target: int, price: int, upgrade: bool) -> RefCounted:
	var external: RefCounted = CommerceOfferScript.new(&"external", 0, item, "", target, price, price, upgrade)
	var offers: Array = session.call("replace_offers", [external])
	assert_eq(offers.size(), 1)
	return offers[0] as RefCounted


func _scope_state(scope: Node) -> Dictionary:
	return {
		&"loadout": scope.get("loadout").call("snapshot"),
		&"progression": scope.get("progression").call("snapshot"),
		&"wallet": scope.get("wallet").call("snapshot"),
		&"health": scope.get("health").call("snapshot"),
	}


func _item(id: String, type: Item.ItemType, price: int) -> Item:
	var result := Item.new()
	result.id = id
	result.type = type
	result.price = price
	return result
