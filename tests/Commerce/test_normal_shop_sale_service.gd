extends GutTest

const FakeInventoryScript: GDScript = preload("res://tests/Commerce/fake_inventory_adapter.gd")
const FakeProgressionScript: GDScript = preload("res://tests/Commerce/fake_progression_adapter.gd")
const FakeWalletScript: GDScript = preload("res://tests/Commerce/fake_wallet_adapter.gd")
const SaleServiceScript: GDScript = preload("res://Commerce/application/normal_shop_sale_service.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")


func test_selling_marble_removes_it_resets_growth_and_credits_quote() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(10)
	var marble := _make_item("sold_marble", Item.ItemType.MARBLE, 31)
	assert_true(inventory.add(marble))
	progression.set_level(marble, 4)
	var service: RefCounted = _sale_service(inventory, progression, wallet)

	var result: RefCounted = service.call("sell", marble)

	assert_eq(result.code, PurchaseResultScript.Code.SUCCESS)
	assert_true(result.committed)
	assert_eq(result.balance_before, 10)
	assert_eq(result.balance_after, 25)
	assert_null(inventory.find_owned(marble))
	assert_eq(progression.level_of(marble), 1)
	assert_eq(wallet.amount, 25)


func test_missing_sale_capability_rejects_configuration_without_mutation() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet_without_sale_api := RefCounted.new()
	var marble := _make_item("not_configured", Item.ItemType.MARBLE, 20)
	assert_true(inventory.add(marble))
	progression.set_level(marble, 3)
	var before := {
		&"inventory": inventory.snapshot(),
		&"progression": progression.snapshot(),
	}
	var service: RefCounted = SaleServiceScript.new()

	assert_false(service.call("configure", inventory, progression, wallet_without_sale_api))
	var result: RefCounted = service.call("sell", marble)

	assert_eq(result.code, PurchaseResultScript.Code.NOT_CONFIGURED)
	assert_eq(inventory.snapshot(), before[&"inventory"])
	assert_eq(progression.snapshot(), before[&"progression"])


func test_remove_failure_after_mutation_restores_sale_state() -> void:
	var fixture := _sale_fixture("remove_failure")
	fixture.inventory.remove_failure = FakeInventoryScript.AFTER_MUTATION
	var before: Dictionary = _state(fixture.inventory, fixture.progression, fixture.wallet)

	var result: RefCounted = fixture.service.call("sell", fixture.item)

	_assert_commit_failure_restored(result, fixture, before)


func test_reset_failure_after_mutation_restores_sale_state() -> void:
	var fixture := _sale_fixture("reset_failure")
	fixture.progression.reset_item_failure = FakeProgressionScript.AFTER_MUTATION
	var before: Dictionary = _state(fixture.inventory, fixture.progression, fixture.wallet)

	var result: RefCounted = fixture.service.call("sell", fixture.item)

	_assert_commit_failure_restored(result, fixture, before)


func test_credit_failure_after_mutation_restores_sale_state() -> void:
	var fixture := _sale_fixture("credit_failure")
	fixture.wallet.credit_failure = FakeWalletScript.AFTER_MUTATION
	var before: Dictionary = _state(fixture.inventory, fixture.progression, fixture.wallet)

	var result: RefCounted = fixture.service.call("sell", fixture.item)

	_assert_commit_failure_restored(result, fixture, before)


func test_sale_restore_failure_reports_rollback_failed() -> void:
	var fixture := _sale_fixture("rollback_failure")
	fixture.inventory.remove_failure = FakeInventoryScript.AFTER_MUTATION
	fixture.inventory.restore_fails = true

	var result: RefCounted = fixture.service.call("sell", fixture.item)

	assert_eq(result.code, PurchaseResultScript.Code.ROLLBACK_FAILED)
	assert_false(result.rollback_completed)
	assert_null(fixture.inventory.find_owned(fixture.item))
	assert_eq(fixture.progression.level_of(fixture.item), 3)
	assert_eq(fixture.wallet.amount, 10)


func test_skill_sale_is_forbidden_without_mutation() -> void:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(10)
	var skill := _make_item("unsellable_skill", Item.ItemType.SKILL, 40)
	assert_true(inventory.add(skill))
	progression.set_level(skill, 3)
	var service: RefCounted = _sale_service(inventory, progression, wallet)
	var before := _state(inventory, progression, wallet)

	var result: RefCounted = service.call("sell", skill)

	assert_eq(result.code, PurchaseResultScript.Code.UNKNOWN_OFFER)
	assert_false(result.committed)
	assert_eq(_state(inventory, progression, wallet), before)


func _sale_fixture(item_id: String) -> Dictionary:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(10)
	var marble := _make_item(item_id, Item.ItemType.MARBLE, 30)
	assert_true(inventory.add(marble))
	progression.set_level(marble, 3)
	return {
		&"inventory": inventory,
		&"progression": progression,
		&"wallet": wallet,
		&"item": marble,
		&"service": _sale_service(inventory, progression, wallet),
	}


func _sale_service(inventory: RefCounted, progression: RefCounted, wallet: RefCounted) -> RefCounted:
	var service: RefCounted = SaleServiceScript.new()
	assert_true(service.call("configure", inventory, progression, wallet))
	return service


func _assert_commit_failure_restored(
	result: RefCounted,
	fixture: Dictionary,
	before: Dictionary
) -> void:
	assert_eq(result.code, PurchaseResultScript.Code.COMMIT_FAILED)
	assert_true(result.rollback_completed)
	assert_eq(_state(fixture.inventory, fixture.progression, fixture.wallet), before)


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
