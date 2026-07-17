extends GutTest


const ShopScript: GDScript = preload("res://Shop/shop.gd")
const InventoryScript: GDScript = preload("res://Inventory/inventory.gd")
const UpgradeSystemScript: GDScript = preload("res://Run/marble_upgrade_system.gd")
const ShopOfferScript: GDScript = preload("res://Shop/shop_offer.gd")
const SlotScene: PackedScene = preload("res://Items/slot.tscn")


# 验证普通商店以原价把已拥有弹珠提升一级。
func test_normal_shop_quote_targets_next_owned_marble_level_without_discount() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)

	var marble := _make_marble("normal_marble", 40)
	assert_true(inventory.add_item(marble))
	assert_true(system.upgrade_item(marble, inventory))

	var offer = shop.create_upgrade_offer(marble, inventory, system)

	assert_not_null(offer)
	assert_eq(offer.target_level, 3)
	assert_eq(offer.price, 40)
	assert_true(offer.is_upgrade)
	shop.free()


# 验证 Slot 通过公共展示接缝显示升级目标等级和原价。
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


# 验证购买普通升级报价会扣除报价金额并只升级一次。
func test_purchase_upgrade_offer_spends_gold_and_upgrades_owned_item() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)

	var marble := _make_marble("purchase_marble", 30)
	assert_true(inventory.add_item(marble))
	var offer = shop.create_upgrade_offer(marble, inventory, system)
	shop.set_upgrade_offers([offer])
	shop.gold = 30

	assert_true(shop.purchase_offer_with_dependencies(offer, inventory, system))
	assert_eq(shop.gold, 0)
	assert_eq(system.get_level(marble.marble_type), 2)
	assert_false(shop.shop_offers.has(offer))
	shop.free()


# 验证普通商店对已拥有遗物和技能也生成原价的下一级报价。
func test_normal_shop_quotes_owned_relic_and_skill_at_next_level_without_discount() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)

	var relic := _make_relic("normal_relic", 17)
	var skill := _make_skill("dash", 23)
	assert_true(inventory.add_item(relic))
	assert_true(inventory.has_item_id("dash"))

	var relic_offer = shop.create_upgrade_offer(relic, inventory, system)
	var skill_offer = shop.create_upgrade_offer(skill, inventory, system)

	assert_eq(relic_offer.target_level, 2)
	assert_eq(relic_offer.price, 17)
	assert_eq(skill_offer.target_level, 2)
	assert_eq(skill_offer.price, 23)
	shop.free()


# 验证普通商店库存为每个可升级类别保留一个报价。
func test_normal_shop_generates_owned_upgrade_quotes_for_each_category() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)

	var marble := _make_marble("stock_marble", 10)
	var relic := _make_relic("stock_relic", 10)
	var skill := _make_skill("dash", 10)
	assert_true(inventory.add_item(marble))
	assert_true(inventory.add_item(relic))
	assert_true(inventory.has_item_id("dash"))

	var offers: Array = shop.generate_upgrade_offers([marble, relic, skill], inventory, system)

	assert_eq(offers.size(), 3)
	assert_eq(offers.filter(func(offer): return offer.item.type == Item.ItemType.MARBLE).size(), 1)
	assert_eq(offers.filter(func(offer): return offer.item.type == Item.ItemType.RELIC).size(), 1)
	assert_eq(offers.filter(func(offer): return offer.item.type == Item.ItemType.SKILL).size(), 1)
	shop.free()


# 验证购买同技能报价会升级当前技能而不是替换。
func test_purchase_same_skill_upgrade_quote_keeps_equipped_skill_and_increases_level() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)

	var skill := _make_skill("dash", 12)
	assert_true(inventory.has_item_id("dash"))
	var offer = shop.create_upgrade_offer(skill, inventory, system)
	shop.set_upgrade_offers([offer])
	shop.gold = 12

	assert_true(shop.purchase_offer_with_dependencies(offer, inventory, system))
	assert_eq(inventory.skill_item.id, "dash")
	assert_eq(system.get_skill_level("dash"), 2)
	shop.free()


# 验证未拥有的新商品仍会进入普通商店并可按报价购买。
func test_normal_shop_keeps_and_sells_unowned_items() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)
	var relic := _make_relic("new_relic", 18)

	var offers: Array = shop.generate_upgrade_offers([relic], inventory, system)
	assert_eq(offers.size(), 1)
	assert_false(offers[0].is_upgrade)
	shop.set_upgrade_offers(offers)
	shop.gold = 18

	assert_true(shop.purchase_offer_with_dependencies(offers[0], inventory, system))
	assert_true(inventory.has_item_id("new_relic"))
	assert_eq(shop.gold, 0)
	shop.free()


# 验证满级同物会被过滤并由其他候选补足普通商店库存。
func test_normal_shop_filters_maxed_item_and_backfills_from_other_candidates() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)
	var maxed := _make_marble("maxed", 10, Marble.MARBLE_TYPE.DEFAULT)
	assert_true(inventory.add_item(maxed))
	for _index: int in 3:
		assert_true(system.upgrade_item(maxed, inventory))
	var candidates: Array[Item] = [maxed]
	for index: int in 6:
		candidates.append(_make_relic("replacement_%d" % index, 10))

	var offers: Array = shop.generate_upgrade_offers(candidates, inventory, system)

	assert_eq(offers.size(), 6)
	assert_eq(offers.filter(func(offer): return offer.item == maxed).size(), 0)
	shop.free()


# 验证 Slot 可区分新商品、普通升级和折扣升级三种展示状态。
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
	assert_eq(original_price.text, "$ 60")
	assert_eq((slot.get_node("Price") as Label).text, "$ 40")


# 验证升级报价在物品已被移出库存后不能扣款或升级残留等级。
func test_upgrade_offer_rejects_item_removed_after_quote_generation() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)
	var marble := _make_marble("removed_marble", 30)
	assert_true(inventory.add_item(marble))
	var offer = shop.create_upgrade_offer(marble, inventory, system)
	shop.set_upgrade_offers([offer])
	shop.gold = 30
	assert_true(inventory.remove_item(marble))

	assert_false(shop.purchase_offer_with_dependencies(offer, inventory, system))
	assert_eq(shop.gold, 30)
	assert_eq(system.get_level(marble.marble_type), 1)
	shop.free()


# 验证出售弹珠会清除等级进度，并把旧升级报价重建为新商品报价。
func test_selling_marble_resets_progress_and_rebuilds_quote() -> void:
	var shop: Variant = ShopScript.new()
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(inventory)
	add_child_autofree(system)
	var marble := _make_marble("sold_marble", 30)
	assert_true(inventory.add_item(marble))
	assert_true(system.upgrade_item(marble, inventory))
	var pool: Array[Item] = [marble]
	shop.shop_item_pool = pool
	shop.set_upgrade_offers(shop.generate_upgrade_offers(shop.shop_item_pool, inventory, system))

	assert_true(shop.sell_item_with_dependencies(marble, inventory, system))
	assert_eq(system.get_level(marble.marble_type), 1)
	assert_false(inventory.has_item_id(marble.id))
	assert_eq(shop.shop_offers.size(), 1)
	assert_false(shop.shop_offers[0].is_upgrade)
	assert_eq(shop.shop_offers[0].target_level, 1)
	shop.free()


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


func _make_marble(item_id: String, price: int, marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT) -> Item:
	var marble := Item.new()
	marble.id = item_id
	marble.type = Item.ItemType.MARBLE
	marble.marble_type = marble_type
	marble.price = price
	return marble
