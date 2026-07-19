extends GutTest

const FakeInventoryScript: GDScript = preload("res://tests/Commerce/fake_inventory_adapter.gd")
const FakeProgressionScript: GDScript = preload("res://tests/Commerce/fake_progression_adapter.gd")
const FakeWalletScript: GDScript = preload("res://tests/Commerce/fake_wallet_adapter.gd")
const NormalShopSessionScript: GDScript = preload("res://Commerce/application/normal_shop_session.gd")
const CommerceOfferScript: GDScript = preload("res://Commerce/domain/commerce_offer.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")


func test_new_item_purchase_commits_once_and_consumes_offer() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(100)
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var relic := _make_item("fresh_relic", Item.ItemType.RELIC, 30)
	var offer: RefCounted = _install_offer(session, relic, 1, 30, false)

	var first: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(first.code, PurchaseResultScript.Code.SUCCESS)
	assert_true(first.committed)
	assert_eq(wallet.amount, 70)
	assert_eq(inventory.items.size(), 1)
	assert_eq(inventory.find_owned(relic), relic)
	assert_true(session.call("get_offers")[0].consumed)
	var state_after_first := _state(inventory, progression, wallet)

	var repeated: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(repeated.code, PurchaseResultScript.Code.OFFER_CONSUMED)
	assert_false(repeated.committed)
	assert_eq(_state(inventory, progression, wallet), state_after_first)


func test_inventory_revision_change_rejects_quote_without_partial_state() -> void:
	_assert_revision_change_is_stale(&"inventory")


func test_progression_revision_change_rejects_quote_without_partial_state() -> void:
	_assert_revision_change_is_stale(&"progression")


func test_wallet_revision_change_rejects_quote_without_partial_state() -> void:
	_assert_revision_change_is_stale(&"wallet")


func test_capacity_change_rejects_without_debit() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(50)
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var relic := _make_item("capacity_relic", Item.ItemType.RELIC, 20)
	var offer: RefCounted = _install_offer(session, relic, 1, 20, false)
	inventory.capacity_available = false

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.CAPACITY_CHANGED)
	assert_eq(wallet.amount, 50)
	assert_true(inventory.items.is_empty())
	assert_false(session.call("get_offers")[0].consumed)


func test_skill_replacement_requires_authorization_then_resets_old_growth() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(80)
	var old_skill := _make_item("old_skill", Item.ItemType.SKILL, 10)
	var new_skill := _make_item("new_skill", Item.ItemType.SKILL, 25)
	assert_true(inventory.add(old_skill))
	progression.set_level(old_skill, 3)
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var offer: RefCounted = _install_offer(session, new_skill, 1, 25, false)
	var before := _state(inventory, progression, wallet)

	var blocked: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(blocked.code, PurchaseResultScript.Code.SKILL_REPLACEMENT_REQUIRED)
	assert_eq(_state(inventory, progression, wallet), before)
	assert_true(session.call("authorize_skill_replacement", offer.offer_id))

	var purchased: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(purchased.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(inventory.current_skill(), new_skill)
	assert_null(inventory.find_owned(old_skill))
	assert_eq(progression.level_of(old_skill), 1)
	assert_eq(wallet.amount, 55)


func test_invalidated_snapshot_expires_offer_without_mutation() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(40)
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var offer: RefCounted = _install_offer(
		session, _make_item("expired", Item.ItemType.RELIC, 10), 1, 10, false
	)
	var before := _state(inventory, progression, wallet)
	session.call("invalidate_snapshot")

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.STALE_SNAPSHOT)
	assert_eq(_state(inventory, progression, wallet), before)


func test_add_failure_after_mutation_restores_all_adapters() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(60)
	inventory.add_failure = FakeInventoryScript.AFTER_MUTATION
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var offer: RefCounted = _install_offer(
		session, _make_item("failed_add", Item.ItemType.RELIC, 20), 1, 20, false
	)
	var before := _state(inventory, progression, wallet)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	_assert_commit_failed_and_restored(result, session, before, inventory, progression, wallet)


func test_upgrade_failure_after_mutation_restores_all_adapters() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(60)
	var relic := _make_item("failed_upgrade", Item.ItemType.RELIC, 20)
	assert_true(inventory.add(relic))
	progression.set_level(relic, 1)
	progression.upgrade_failure_call = 1
	progression.upgrade_failure = FakeProgressionScript.AFTER_MUTATION
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var offer: RefCounted = _install_offer(session, relic, 2, 20, true)
	var before := _state(inventory, progression, wallet)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	_assert_commit_failed_and_restored(result, session, before, inventory, progression, wallet)


func test_debit_failure_after_mutation_restores_reward_and_wallet() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(60)
	wallet.debit_failure = FakeWalletScript.AFTER_MUTATION
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var offer: RefCounted = _install_offer(
		session, _make_item("failed_debit", Item.ItemType.RELIC, 20), 1, 20, false
	)
	var before := _state(inventory, progression, wallet)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	_assert_commit_failed_and_restored(result, session, before, inventory, progression, wallet)


func test_restore_failure_reports_rollback_failed() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(60)
	inventory.add_failure = FakeInventoryScript.AFTER_MUTATION
	inventory.restore_fails = true
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var relic := _make_item("rollback_failure", Item.ItemType.RELIC, 20)
	var offer: RefCounted = _install_offer(session, relic, 1, 20, false)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.ROLLBACK_FAILED)
	assert_false(result.rollback_completed)
	assert_eq(inventory.find_owned(relic), relic)
	assert_eq(wallet.amount, 60)
	assert_false(session.call("get_offers")[0].consumed)


func _assert_revision_change_is_stale(adapter_name: StringName) -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(50)
	var session: RefCounted = _normal_session(inventory, progression, wallet)
	var relic := _make_item("revision_%s" % adapter_name, Item.ItemType.RELIC, 20)
	var offer: RefCounted = _install_offer(session, relic, 1, 20, false)
	match adapter_name:
		&"inventory": inventory.bump_revision()
		&"progression": progression.bump_revision()
		&"wallet": wallet.bump_revision()
	var before := _state(inventory, progression, wallet)

	var result: RefCounted = session.call("purchase", offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.STALE_SNAPSHOT)
	assert_eq(_state(inventory, progression, wallet), before)
	assert_false(session.call("get_offers")[0].consumed)


func _assert_commit_failed_and_restored(
	result: RefCounted,
	session: RefCounted,
	before: Dictionary,
	inventory: RefCounted,
	progression: RefCounted,
	wallet: RefCounted
) -> void:
	assert_eq(result.code, PurchaseResultScript.Code.COMMIT_FAILED)
	assert_true(result.rollback_completed)
	assert_eq(_state(inventory, progression, wallet), before)
	assert_false(session.call("get_offers")[0].consumed)


func _normal_session(inventory: RefCounted, progression: RefCounted, wallet: RefCounted) -> RefCounted:
	var session: RefCounted = NormalShopSessionScript.new()
	assert_true(session.call("configure", inventory, progression, wallet))
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


func _state(inventory: RefCounted, progression: RefCounted, wallet: RefCounted) -> Dictionary:
	return {
		&"inventory": inventory.snapshot(),
		&"progression": progression.snapshot(),
		&"wallet": wallet.snapshot(),
	}


func _make_item(item_id: String, item_type: int, price: int) -> Item:
	var item := Item.new()
	item.id = item_id
	item.type = item_type as Item.ItemType
	item.price = price
	return item
