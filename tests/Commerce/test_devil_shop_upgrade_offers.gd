extends GutTest

const DevilShopSessionScript: GDScript = preload("res://Commerce/application/devil_shop_session.gd")
const DevilShopConfigScript: GDScript = preload("res://Commerce/domain/devil_shop_config.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const FakeInventoryScript: GDScript = preload("res://tests/Commerce/fake_inventory_adapter.gd")
const FakeProgressionScript: GDScript = preload("res://tests/Commerce/fake_progression_adapter.gd")
const FakeWalletScript: GDScript = preload("res://tests/Commerce/fake_wallet_adapter.gd")
const FakeHealthScript: GDScript = preload("res://tests/Commerce/fake_health_adapter.gd")


func test_devil_shop_quotes_owned_items_at_higher_levels() -> void:
	var fixture := _devil_fixture(500)
	var marble := _make_marble("devil_marble", 40)
	var relic := _make_relic("devil_relic", 40)
	var skill := _make_skill("dash", 40)
	assert_true(fixture.inventory.add(marble))
	assert_true(fixture.inventory.add(relic))
	assert_true(fixture.inventory.add(skill))

	var offers: Array = fixture.session.open(_make_config(), [marble, relic, skill])

	assert_eq(offers.size(), 3)
	for offer: Variant in offers:
		assert_ne(offer.offer_id, &"")
		assert_eq(offer.target_level, 2)
		assert_eq(offer.price, 20)
		assert_true(offer.is_upgrade)


func test_devil_shop_jump_quote_uses_discounted_level_value_difference() -> void:
	var fixture := _devil_fixture(500)
	var marble := _make_marble("jump_marble", 40)
	assert_true(fixture.inventory.add(marble))
	fixture.progression.set_level(marble, 2)
	var config: Resource = _make_config()
	config.set("level_weights", {2: 0, 3: 0, 4: 1})

	var offers: Array = fixture.session.open(config, [marble])

	assert_eq(offers.size(), 1)
	var offer: Variant = offers[0]
	assert_ne(offer.offer_id, &"")
	assert_eq(offer.target_level, 4)
	assert_eq(offer.original_price, 120)
	assert_eq(offer.price, 60)
	assert_true(offer.is_upgrade)


func test_devil_shop_filters_max_level_items_from_upgrade_quotes() -> void:
	var fixture := _devil_fixture(500)
	var marble := _make_marble("max_marble", 40)
	var relic := _make_relic("max_relic", 40)
	var skill := _make_skill("dash", 40)
	assert_true(fixture.inventory.add(marble))
	assert_true(fixture.inventory.add(relic))
	assert_true(fixture.inventory.add(skill))
	fixture.progression.set_level(marble, 4)
	fixture.progression.set_level(relic, 4)
	fixture.progression.set_level(skill, 4)

	var offers: Array = fixture.session.open(_make_config(), [marble, relic, skill])

	assert_true(offers.is_empty())
	assert_null(fixture.session.get_current_offer())


func test_unowned_items_use_full_price_and_session_purchase_flow() -> void:
	var fixture := _devil_fixture(500)
	var marble := _make_marble("new_marble", 40)
	var relic := _make_relic("new_relic", 40)
	var skill := _make_skill("magic_missile", 40)

	var offers: Array = fixture.session.open(_make_config(), [marble, relic, skill])

	assert_eq(offers.size(), 3)
	for offer: Variant in offers:
		assert_ne(offer.offer_id, &"")
		assert_eq(offer.target_level, 2)
		assert_eq(offer.original_price, 60)
		assert_eq(offer.price, 60)
		assert_false(offer.is_upgrade)

	var purchase_count := 0
	while fixture.session.get_current_offer() != null:
		var current: Variant = fixture.session.get_current_offer()
		var selected: RefCounted = fixture.session.select_payment(current.offer_id, current.price, 0)
		assert_eq(selected.code, PurchaseResultScript.Code.SUCCESS)
		assert_false(selected.committed)
		var purchased: RefCounted = fixture.session.purchase(current.offer_id)
		assert_eq(purchased.code, PurchaseResultScript.Code.SUCCESS)
		assert_eq(fixture.progression.level_of(current.item), 2)
		assert_eq(fixture.inventory.find_owned(current.item), current.item)
		purchase_count += 1
	assert_eq(purchase_count, 3)


func test_different_skill_is_full_price_and_replacement_resets_old_level() -> void:
	var fixture := _devil_fixture(200)
	var old_skill: Item = load("res://Content/data/dash_skill.tres") as Item
	var new_skill: Item = load("res://Content/data/magic_missile_skill.tres") as Item
	assert_true(fixture.inventory.add(old_skill))
	fixture.progression.set_level(old_skill, 3)
	var offers: Array = fixture.session.open(_make_config(), [new_skill])
	assert_eq(offers.size(), 1)
	var offer: Variant = offers[0]

	assert_ne(offer.offer_id, &"")
	assert_eq(offer.price, 83)
	assert_false(offer.is_upgrade)
	assert_eq(
		fixture.session.select_payment(offer.offer_id, offer.price, 0).code,
		PurchaseResultScript.Code.SUCCESS
	)
	var before := _fixture_state(fixture)
	var blocked: RefCounted = fixture.session.purchase(offer.offer_id)
	assert_eq(blocked.code, PurchaseResultScript.Code.SKILL_REPLACEMENT_REQUIRED)
	assert_eq(_fixture_state(fixture), before)
	assert_true(fixture.session.authorize_skill_replacement(offer.offer_id))

	var purchased: RefCounted = fixture.session.purchase(offer.offer_id)

	assert_eq(purchased.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(fixture.inventory.current_skill(), new_skill)
	assert_eq(fixture.progression.level_of(new_skill), 2)
	assert_eq(fixture.progression.level_of(old_skill), 1)
	assert_eq(fixture.wallet.amount, 117)


func test_unowned_items_at_full_capacity_are_not_quoted() -> void:
	var fixture := _devil_fixture(500)
	fixture.inventory.capacity_available = false
	var marble_candidate := _make_marble("capacity_marble", 40)
	var relic_candidate := _make_relic("capacity_relic", 40)

	var offers: Array = fixture.session.open(_make_config(), [marble_candidate, relic_candidate])

	assert_true(offers.is_empty())
	assert_null(fixture.session.get_current_offer())


func test_devil_shop_deduplicates_candidates_by_item_identity() -> void:
	var fixture := _devil_fixture(500)
	var owned := _make_marble("owned_default", 40)
	var duplicate_candidate := _make_marble("duplicate_default", 50)
	assert_true(fixture.inventory.add(owned))
	fixture.progression.set_level(owned, 1)

	var offers: Array = fixture.session.open(_make_config(), [owned, duplicate_candidate])

	assert_eq(offers.size(), 1)
	assert_ne(offers[0].offer_id, &"")
	assert_true(offers[0].is_upgrade)
	assert_eq(offers[0].item, owned)


func _devil_fixture(balance: int) -> Dictionary:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(balance)
	var health: RefCounted = FakeHealthScript.new(100)
	var session: RefCounted = DevilShopSessionScript.new()
	assert_true(session.configure(inventory, progression, wallet, health))
	return {
		&"inventory": inventory,
		&"progression": progression,
		&"wallet": wallet,
		&"health": health,
		&"session": session,
	}


func _make_config() -> Resource:
	var config: Resource = DevilShopConfigScript.new()
	config.set("stock_count", 3)
	config.set("health_to_gold", 5)
	config.set("minimum_remaining_health", 1)
	config.set("level_weights", {2: 1, 3: 0, 4: 0})
	config.set("level_price_multipliers", {1: 1.0, 2: 1.5, 3: 2.0, 4: 3.0})
	return config


func _fixture_state(fixture: Dictionary) -> Dictionary:
	return {
		&"inventory": fixture.inventory.snapshot(),
		&"progression": fixture.progression.snapshot(),
		&"wallet": fixture.wallet.snapshot(),
		&"health": fixture.health.snapshot(),
	}


func _make_marble(item_id: String, price: int) -> Item:
	var marble := Item.new()
	marble.id = item_id
	marble.type = Item.ItemType.MARBLE
	marble.price = price
	return marble


func _make_relic(item_id: String, price: int) -> Item:
	var relic := Item.new()
	relic.id = item_id
	relic.type = Item.ItemType.RELIC
	relic.price = price
	return relic


func _make_skill(item_id: String, price: int) -> Item:
	var skill := Item.new()
	skill.id = item_id
	skill.type = Item.ItemType.SKILL
	skill.price = price
	return skill
