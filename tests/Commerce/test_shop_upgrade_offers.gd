extends GutTest

const NormalShopSessionScript: GDScript = preload("res://Commerce/application/normal_shop_session.gd")
const NormalShopSaleServiceScript: GDScript = preload("res://Commerce/application/normal_shop_sale_service.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")
const FakeInventoryScript: GDScript = preload("res://tests/Commerce/fake_inventory_adapter.gd")
const FakeProgressionScript: GDScript = preload("res://tests/Commerce/fake_progression_adapter.gd")
const FakeWalletScript: GDScript = preload("res://tests/Commerce/fake_wallet_adapter.gd")
const ShopOfferScript: GDScript = preload("res://Commerce/domain/shop_offer.gd")
const SlotScene: PackedScene = preload("res://Loadout/presentation/slot.tscn")


func test_normal_shop_quote_targets_next_owned_marble_level_without_discount() -> void:
	var fixture := _normal_fixture(100)
	var marble := _make_marble("normal_marble", 40)
	assert_true(fixture.inventory.add(marble))
	fixture.progression.set_level(marble, 2)

	var offers: Array = fixture.session.regenerate([marble], 1)

	assert_eq(offers.size(), 1)
	var offer: Variant = offers[0]
	assert_ne(offer.offer_id, &"")
	assert_eq(offer.target_level, 3)
	assert_eq(offer.price, 40)
	assert_true(offer.is_upgrade)


func test_slot_displays_upgrade_quote_level_and_regular_price() -> void:
	var slot: Variant = SlotScene.instantiate()
	add_child_autofree(slot)
	var marble := _make_marble("slot_marble", 25)
	var offer: Variant = ShopOfferScript.new(marble, 2, 25)

	slot.set_offer(offer)

	assert_eq(slot.item, marble)
	var level_badge := slot.get_node("Icon/LevelBadge") as Label
	assert_eq(level_badge.text, "II")
	assert_eq((slot.get_node("Price") as Label).text, "$ 25")


func test_purchase_upgrade_offer_spends_gold_and_upgrades_owned_item() -> void:
	var fixture := _normal_fixture(30)
	var marble := _make_marble("purchase_marble", 30)
	assert_true(fixture.inventory.add(marble))
	fixture.progression.set_level(marble, 1)
	var offer: Variant = fixture.session.regenerate([marble], 1)[0]
	var offer_id := StringName(offer.offer_id)

	var result: RefCounted = fixture.session.purchase(offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.SUCCESS)
	assert_true(result.committed)
	assert_eq(fixture.wallet.amount, 0)
	assert_eq(fixture.progression.level_of(marble), 2)
	assert_true(fixture.session.get_offers()[0].consumed)


func test_normal_shop_quotes_owned_relic_and_skill_at_next_level_without_discount() -> void:
	var fixture := _normal_fixture(100)
	var relic := _make_relic("normal_relic", 17)
	var skill := _make_skill("dash", 23)
	assert_true(fixture.inventory.add(relic))
	assert_true(fixture.inventory.add(skill))
	fixture.progression.set_level(relic, 1)
	fixture.progression.set_level(skill, 1)

	var offers: Array = fixture.session.regenerate([relic, skill], 2)
	var relic_offer: Variant = _offer_for_type(offers, Item.ItemType.RELIC)
	var skill_offer: Variant = _offer_for_type(offers, Item.ItemType.SKILL)

	assert_not_null(relic_offer)
	assert_not_null(skill_offer)
	assert_eq(relic_offer.target_level, 2)
	assert_eq(relic_offer.price, 17)
	assert_eq(skill_offer.target_level, 2)
	assert_eq(skill_offer.price, 23)


func test_normal_shop_generates_owned_upgrade_quotes_for_each_category() -> void:
	var fixture := _normal_fixture(100)
	var marble := _make_marble("stock_marble", 10)
	var relic := _make_relic("stock_relic", 10)
	var skill := _make_skill("dash", 10)
	assert_true(fixture.inventory.add(marble))
	assert_true(fixture.inventory.add(relic))
	assert_true(fixture.inventory.add(skill))

	var offers: Array = fixture.session.regenerate([marble, relic, skill], 3)

	assert_eq(offers.size(), 3)
	assert_eq(offers.filter(func(offer): return offer.item.type == Item.ItemType.MARBLE).size(), 1)
	assert_eq(offers.filter(func(offer): return offer.item.type == Item.ItemType.RELIC).size(), 1)
	assert_eq(offers.filter(func(offer): return offer.item.type == Item.ItemType.SKILL).size(), 1)
	for offer: Variant in offers:
		assert_ne(offer.offer_id, &"")


func test_purchase_same_skill_upgrade_quote_keeps_equipped_skill_and_increases_level() -> void:
	var fixture := _normal_fixture(12)
	var skill := _make_skill("dash", 12)
	assert_true(fixture.inventory.add(skill))
	fixture.progression.set_level(skill, 1)
	var offer: Variant = fixture.session.regenerate([skill], 1)[0]

	var result: RefCounted = fixture.session.purchase(offer.offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(fixture.inventory.current_skill(), skill)
	assert_eq(fixture.progression.level_of(skill), 2)
	assert_eq(fixture.wallet.amount, 0)


func test_normal_shop_keeps_and_sells_unowned_items() -> void:
	var fixture := _normal_fixture(18)
	var relic := _make_relic("new_relic", 18)

	var offers: Array = fixture.session.regenerate([relic], 1)
	assert_eq(offers.size(), 1)
	assert_false(offers[0].is_upgrade)
	assert_ne(offers[0].offer_id, &"")

	var result: RefCounted = fixture.session.purchase(offers[0].offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(fixture.inventory.find_owned(relic), relic)
	assert_eq(fixture.wallet.amount, 0)


func test_normal_shop_filters_maxed_item_and_backfills_from_other_candidates() -> void:
	var fixture := _normal_fixture(100)
	var maxed := _make_marble("maxed", 10)
	assert_true(fixture.inventory.add(maxed))
	fixture.progression.set_level(maxed, 4)
	var candidates: Array[Item] = [maxed]
	for index: int in 6:
		candidates.append(_make_relic("replacement_%d" % index, 10))

	var offers: Array = fixture.session.regenerate(candidates, 6)

	assert_eq(offers.size(), 6)
	assert_eq(offers.filter(func(offer): return offer.item == maxed).size(), 0)
	assert_eq(offers.filter(func(offer): return offer.item.type == Item.ItemType.RELIC).size(), 6)


func test_slot_reports_regular_upgrade_and_discounted_states() -> void:
	var slot: Variant = SlotScene.instantiate()
	add_child_autofree(slot)
	var marble := _make_marble("states", 20)
	var presentation := slot.get_node("OfferPresentationAnimation") as AnimationPlayer
	var level_up := slot.get_node("LevelUp") as Sprite2D
	var original_price := slot.get_node("OriginalPrice") as Label
	var discount_slash := slot.get_node("DiscountSlash") as Line2D

	slot.set_offer(ShopOfferScript.new(marble, 1, 20, false, 20))
	presentation.advance(0.0)
	assert_eq(slot.get_offer_presentation_state(), &"regular")
	assert_false(level_up.visible)
	assert_false(original_price.visible)
	assert_false(discount_slash.visible)

	slot.set_offer(ShopOfferScript.new(marble, 2, 20, true, 20))
	presentation.advance(0.0)
	assert_eq(slot.get_offer_presentation_state(), &"upgrade")
	assert_true(level_up.visible)
	assert_false(original_price.visible)
	assert_false(discount_slash.visible)

	slot.set_offer(ShopOfferScript.new(marble, 4, 40, true, 60))
	presentation.advance(0.0)
	assert_eq(slot.get_offer_presentation_state(), &"discounted")
	assert_true(level_up.visible)
	assert_true(original_price.visible)
	assert_true(discount_slash.visible)
	assert_eq((slot.get_node("OriginalCurrency") as Label).text, "$")
	assert_eq(original_price.text, "60")
	assert_eq(discount_slash.points[0], Vector2(15, 63))
	assert_eq(discount_slash.points[1], Vector2(32, 75))
	assert_eq(discount_slash.width, 2.0)
	assert_eq((slot.get_node("Price") as Label).text, "$ 40")


func test_upgrade_offer_rejects_item_removed_after_quote_generation() -> void:
	var fixture := _normal_fixture(30)
	var marble := _make_marble("removed_marble", 30)
	assert_true(fixture.inventory.add(marble))
	fixture.progression.set_level(marble, 1)
	var offer: Variant = fixture.session.regenerate([marble], 1)[0]
	var offer_id := StringName(offer.offer_id)
	assert_true(fixture.inventory.remove(marble))
	var state_before := _fixture_state(fixture)

	var result: RefCounted = fixture.session.purchase(offer_id)

	assert_eq(result.code, PurchaseResultScript.Code.OWNERSHIP_CHANGED)
	assert_false(result.committed)
	assert_eq(_fixture_state(fixture), state_before)
	assert_eq(fixture.wallet.amount, 30)
	assert_eq(fixture.progression.level_of(marble), 1)


func test_selling_marble_resets_progress_and_rebuilds_quote() -> void:
	var fixture := _normal_fixture(0)
	var marble := _make_marble("sold_marble", 30)
	assert_true(fixture.inventory.add(marble))
	fixture.progression.set_level(marble, 2)
	var old_offer: Variant = fixture.session.regenerate([marble], 1)[0]
	assert_true(old_offer.is_upgrade)
	var sale_service: RefCounted = NormalShopSaleServiceScript.new()
	assert_true(sale_service.configure(fixture.inventory, fixture.progression, fixture.wallet))

	var sale_result: RefCounted = sale_service.sell(marble)

	assert_eq(sale_result.code, PurchaseResultScript.Code.SUCCESS)
	assert_eq(fixture.progression.level_of(marble), 1)
	assert_null(fixture.inventory.find_owned(marble))
	assert_eq(fixture.wallet.amount, 15)
	var rebuilt: Array = fixture.session.regenerate([marble], 1)
	assert_eq(rebuilt.size(), 1)
	assert_false(rebuilt[0].is_upgrade)
	assert_eq(rebuilt[0].target_level, 1)
	assert_ne(rebuilt[0].offer_id, old_offer.offer_id)


func _normal_fixture(balance: int) -> Dictionary:
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(balance)
	var session: RefCounted = NormalShopSessionScript.new()
	assert_true(session.configure(inventory, progression, wallet))
	return {
		&"inventory": inventory,
		&"progression": progression,
		&"wallet": wallet,
		&"session": session,
	}


func _fixture_state(fixture: Dictionary) -> Dictionary:
	return {
		&"inventory": fixture.inventory.snapshot(),
		&"progression": fixture.progression.snapshot(),
		&"wallet": fixture.wallet.snapshot(),
	}


func _offer_for_type(offers: Array, item_type: int) -> Variant:
	for offer: Variant in offers:
		if offer.item.type == item_type:
			return offer
	return null


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


func _make_marble(item_id: String, price: int) -> Item:
	var marble := Item.new()
	marble.id = item_id
	marble.type = Item.ItemType.MARBLE
	marble.price = price
	return marble
