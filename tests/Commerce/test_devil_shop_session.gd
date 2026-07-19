extends GutTest

const FakeInventoryScript: GDScript = preload("res://tests/Commerce/fake_inventory_adapter.gd")
const FakeProgressionScript: GDScript = preload("res://tests/Commerce/fake_progression_adapter.gd")
const FakeWalletScript: GDScript = preload("res://tests/Commerce/fake_wallet_adapter.gd")
const FakeHealthScript: GDScript = preload("res://tests/Commerce/fake_health_adapter.gd")
const DevilShopSessionScript: GDScript = preload("res://Commerce/application/devil_shop_session.gd")
const CommerceOfferScript: GDScript = preload("res://Commerce/domain/commerce_offer.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const DevilShopConfigScript: GDScript = preload("res://DevilShop/devil_shop_config.gd")


func test_overpay_debits_full_selected_gold_and_health_at_minimum_boundary() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(100)
	var health: RefCounted = FakeHealthScript.new(3)
	var session: RefCounted = _devil_session(inventory, progression, wallet, health)
	var relic := _make_item("overpay_relic", Item.ItemType.RELIC, 10)
	var offer: RefCounted = _install_offer(session, relic, 2, 10, false)

	var selected: RefCounted = session.call("select_payment", offer.offer_id, 7, 2)
	var purchased: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(selected.code, PurchaseResultScript.Code.SUCCESS)
	assert_false(selected.committed)
	assert_eq(purchased.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(purchased.balance_before, 100)
	assert_eq(purchased.balance_after, 93)
	assert_eq(purchased.health_before, 3)
	assert_eq(purchased.health_after, 1)
	assert_eq(wallet.amount, 93)
	assert_eq(health.amount, 1)
	assert_eq(progression.level_of(relic), 2)
	assert_true(session.call("get_offers")[0].consumed)


func test_cross_level_second_upgrade_failure_restores_every_adapter() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(90)
	var health: RefCounted = FakeHealthScript.new(10)
	var relic := _make_item("cross_level", Item.ItemType.RELIC, 30)
	assert_true(inventory.add(relic))
	progression.set_level(relic, 1)
	progression.upgrade_failure_call = 2
	progression.upgrade_failure = FakeProgressionScript.AFTER_MUTATION
	var session: RefCounted = _devil_session(inventory, progression, wallet, health)
	var offer: RefCounted = _install_offer(session, relic, 3, 30, true)
	assert_eq(session.call("select_payment", offer.offer_id, 20, 2).code, PurchaseResultScript.Code.SUCCESS)
	var before := _state(inventory, progression, wallet, health)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.COMMIT_FAILED)
	assert_true(result.rollback_completed)
	assert_eq(_state(inventory, progression, wallet, health), before)
	assert_eq(progression.level_of(relic), 1)
	assert_false(session.call("get_offers")[0].consumed)


func test_different_skill_replacement_is_atomic_and_clears_old_growth() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(100)
	var health: RefCounted = FakeHealthScript.new(20)
	var old_skill := _make_item("devil_old_skill", Item.ItemType.SKILL, 10)
	var new_skill := _make_item("devil_new_skill", Item.ItemType.SKILL, 25)
	assert_true(inventory.add(old_skill))
	progression.set_level(old_skill, 4)
	var session: RefCounted = _devil_session(inventory, progression, wallet, health)
	var offer: RefCounted = _install_offer(session, new_skill, 2, 25, false)
	assert_eq(session.call("select_payment", offer.offer_id, 25, 0).code, PurchaseResultScript.Code.SUCCESS)
	var before := _state(inventory, progression, wallet, health)

	var blocked: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(blocked.code, PurchaseResultScript.Code.SKILL_REPLACEMENT_REQUIRED)
	assert_eq(_state(inventory, progression, wallet, health), before)
	assert_true(session.call("authorize_skill_replacement", offer.offer_id))

	var purchased: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(purchased.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(inventory.current_skill(), new_skill)
	assert_null(inventory.find_owned(old_skill))
	assert_eq(progression.level_of(old_skill), 1)
	assert_eq(progression.level_of(new_skill), 2)
	assert_eq(wallet.amount, 75)
	assert_eq(health.amount, 20)


func test_capacity_change_rejects_payment_selection_without_state_change() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(50)
	var health: RefCounted = FakeHealthScript.new(10)
	var session: RefCounted = _devil_session(inventory, progression, wallet, health)
	var offer: RefCounted = _install_offer(
		session, _make_item("devil_capacity", Item.ItemType.RELIC, 20), 2, 20, false
	)
	inventory.capacity_available = false
	var before := _state(inventory, progression, wallet, health)

	var result: RefCounted = session.call("select_payment", offer.offer_id, 20, 0)

	assert_eq(result.code, PurchaseResultScript.Code.CAPACITY_CHANGED)
	assert_eq(_state(inventory, progression, wallet, health), before)


func test_repeated_settlement_after_success_does_not_change_state() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(50)
	var health: RefCounted = FakeHealthScript.new(10)
	var session: RefCounted = _devil_session(inventory, progression, wallet, health)
	var offer: RefCounted = _install_offer(
		session, _make_item("settled_once", Item.ItemType.RELIC, 20), 2, 20, false
	)
	assert_eq(session.call("select_payment", offer.offer_id, 20, 0).code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(session.call("purchase", offer.offer_id).code, PurchaseResultScript.Code.SUCCESS)
	var settled_state := _state(inventory, progression, wallet, health)

	var repeated: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(repeated.code, PurchaseResultScript.Code.UNKNOWN_OFFER)
	assert_false(repeated.committed)
	assert_eq(_state(inventory, progression, wallet, health), settled_state)


func _devil_session(
	inventory: RefCounted,
	progression: RefCounted,
	wallet: RefCounted,
	health: RefCounted
) -> RefCounted:
	var session: RefCounted = DevilShopSessionScript.new()
	assert_true(session.call("configure", inventory, progression, wallet, health))
	assert_true((session.call("open", _config(), []) as Array).is_empty())
	return session


func _install_offer(
	session: RefCounted,
	item: Item,
	target_level: int,
	price: int,
	is_upgrade: bool
) -> RefCounted:
	var source: RefCounted = CommerceOfferScript.new(
		&"external", 0, item, "", target_level, price, price, is_upgrade
	)
	var offers: Array = session.call("replace_offers", [source])
	assert_eq(offers.size(), 1)
	return offers[0] as RefCounted


func _config() -> Resource:
	var config: Resource = DevilShopConfigScript.new()
	config.set("stock_count", 0)
	config.set("health_to_gold", 5)
	config.set("minimum_remaining_health", 1)
	config.set("level_weights", {2: 1, 3: 1, 4: 1})
	config.set("level_price_multipliers", {1: 1.0, 2: 1.5, 3: 2.0, 4: 3.0})
	return config


func _state(
	inventory: RefCounted,
	progression: RefCounted,
	wallet: RefCounted,
	health: RefCounted
) -> Dictionary:
	return {
		&"inventory": inventory.snapshot(),
		&"progression": progression.snapshot(),
		&"wallet": wallet.snapshot(),
		&"health": health.snapshot(),
	}


func _make_item(item_id: String, item_type: int, price: int) -> Item:
	var item := Item.new()
	item.id = item_id
	item.type = item_type as Item.ItemType
	item.price = price
	return item
