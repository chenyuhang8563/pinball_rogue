extends GutTest


const DevilShopScript: GDScript = preload("res://DevilShop/devil_shop.gd")
const DevilShopConfigScript: GDScript = preload("res://DevilShop/devil_shop_config.gd")
const InventoryScript: GDScript = preload("res://Inventory/inventory.gd")
const UpgradeSystemScript: GDScript = preload("res://Run/marble_upgrade_system.gd")


# 用途：验证已拥有的遗物、弹珠和技能只会报价更高等级，并按等级差价计费。
func test_devil_shop_quotes_owned_items_at_higher_levels() -> void:
	var devil_shop: DevilShop = DevilShopScript.new() as DevilShop
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(devil_shop)
	add_child_autofree(inventory)
	add_child_autofree(system)

	var marble := _make_marble("devil_marble", 40)
	var relic := _make_relic("devil_relic", 40)
	var skill := _make_skill("dash", 40)
	assert_true(inventory.add_item(marble))
	assert_true(inventory.add_item(relic))
	assert_true(inventory.has_item_id("dash"))
	inventory.skill_item.price = 40
	devil_shop.config = _make_config([marble, relic, skill])

	var offers: Array[DevilShopOffer] = devil_shop.generate_upgrade_offers(inventory, system)

	assert_eq(offers.size(), 3)
	for offer: DevilShopOffer in offers:
		assert_eq(offer.target_level, 2)
		assert_eq(offer.price, 20)
		assert_true(offer.is_upgrade)


# 用途：验证跨级升级按“目标完整价值减当前等级价值”报价。
func test_devil_shop_jump_quote_uses_discounted_level_value_difference() -> void:
	var devil_shop: DevilShop = DevilShopScript.new() as DevilShop
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(devil_shop)
	add_child_autofree(inventory)
	add_child_autofree(system)

	var marble := _make_marble("jump_marble", 40)
	assert_true(inventory.add_item(marble))
	assert_true(system.upgrade_item(marble, inventory))
	var config := _make_config([marble])
	config.level_weights = {2: 0, 3: 0, 4: 1}
	devil_shop.config = config

	var offer: DevilShopOffer = devil_shop.generate_upgrade_offers(inventory, system).front()

	assert_eq(offer.target_level, 4)
	assert_eq(offer.original_price, 120)
	assert_eq(offer.price, 60)


# 用途：验证已觉醒或达到技能最高等级的物品不会进入升级报价。
func test_devil_shop_filters_max_level_items_from_upgrade_quotes() -> void:
	var devil_shop: DevilShop = DevilShopScript.new() as DevilShop
	var inventory: Variant = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(devil_shop)
	add_child_autofree(inventory)
	add_child_autofree(system)

	var marble := _make_marble("max_marble", 40)
	var relic := _make_relic("max_relic", 40)
	var skill := _make_skill("dash", 40)
	assert_true(inventory.add_item(marble))
	assert_true(inventory.add_item(relic))
	assert_true(inventory.has_item_id("dash"))
	for _index in 3:
		assert_true(system.upgrade_item(marble, inventory))
		assert_true(system.upgrade_item(relic, inventory))
		assert_true(system.upgrade_item(skill, inventory))
	devil_shop.config = _make_config([marble, relic, skill])

	assert_eq(devil_shop.generate_upgrade_offers(inventory, system).size(), 0)


# 用途：回归未拥有三类物品被错误过滤的问题；验证 II 级完整价、非升级标记及公共接缝发放。
# 边界：遗物、弹珠、技能共用同一规则，且发放后都必须精确达到目标等级。
func test_unowned_items_use_full_price_and_public_grant_seam() -> void:
	var devil_shop: DevilShop = DevilShopScript.new() as DevilShop
	var inventory: Node = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(devil_shop)
	add_child_autofree(system)

	var marble := _make_marble("new_marble", 40)
	var relic := _make_relic("new_relic", 40)
	var skill := _make_skill("magic_missile", 40)
	devil_shop.config = _make_config([marble, relic, skill])

	var offers: Array[DevilShopOffer] = devil_shop.generate_upgrade_offers(inventory, system)

	assert_eq(offers.size(), 3)
	for offer: DevilShopOffer in offers:
		assert_eq(offer.target_level, 2)
		assert_eq(offer.original_price, 60)
		assert_eq(offer.price, 60)
		assert_false(offer.is_upgrade)
		assert_true(devil_shop.grant_levelled_item(inventory, offer, system))
		assert_eq(_get_item_level(inventory, system, offer.item), 2)
	inventory.free()


# 用途：回归不同技能被当作升级折价的问题；验证完整价报价、替换以及旧技能等级重置。
# 边界：替换至 II 级新技能时，仅新技能升级，旧技能再次取得应从 I 级开始。
func test_different_skill_is_full_price_and_replacement_resets_old_level() -> void:
	var devil_shop: DevilShop = DevilShopScript.new() as DevilShop
	var inventory: Node = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(devil_shop)
	add_child_autofree(system)

	var old_skill: Item = load("res://Resources/dash_skill.tres") as Item
	var new_skill: Item = load("res://Resources/magic_missile_skill.tres") as Item
	assert_true(bool(inventory.call("add_item", old_skill)))
	assert_true(system.upgrade_skill(old_skill.id))
	assert_true(system.upgrade_skill(old_skill.id))
	devil_shop.config = _make_config([new_skill])

	var offers: Array[DevilShopOffer] = devil_shop.generate_upgrade_offers(inventory, system)
	var offer: DevilShopOffer = offers.front()

	assert_eq(offer.price, 83)
	assert_false(offer.is_upgrade)
	assert_true(devil_shop.grant_levelled_item(inventory, offer, system, true))
	assert_eq((inventory.get("skill_item") as Item).id, new_skill.id)
	assert_eq(system.get_skill_level(new_skill.id), 2)
	assert_eq(system.get_skill_level(old_skill.id), 1)
	inventory.free()


# 验证容量已满时，未拥有的弹珠和遗物不会成为阻塞队列的无效报价。
func test_unowned_items_at_full_capacity_are_not_quoted() -> void:
	var devil_shop: DevilShop = DevilShopScript.new() as DevilShop
	var inventory: Node = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(devil_shop)
	add_child_autofree(system)
	var marble_candidate := _make_marble("capacity_marble", 40)
	marble_candidate.marble_type = Marble.MARBLE_TYPE.BOMB
	var relic_candidate := _make_relic("capacity_relic", 40)
	var marble_items: Array = inventory.get("marble_items")
	var relic_items: Array = inventory.get("relic_items")
	for index: int in 16:
		marble_items.append(_make_marble("filler_marble_%d" % index, 1))
		relic_items.append(_make_relic("filler_relic_%d" % index, 1))
	devil_shop.config = _make_config([marble_candidate, relic_candidate])

	assert_eq(devil_shop.generate_upgrade_offers(inventory, system).size(), 0)
	inventory.free()


# 验证同一领域身份在一次恶魔商店库存中最多生成一份报价。
func test_devil_shop_deduplicates_candidates_by_item_identity() -> void:
	var devil_shop: DevilShop = DevilShopScript.new() as DevilShop
	var inventory: Node = InventoryScript.new()
	var system: MarbleUpgradeSystem = UpgradeSystemScript.new() as MarbleUpgradeSystem
	add_child_autofree(devil_shop)
	add_child_autofree(system)
	var owned := _make_marble("owned_default", 40)
	var duplicate_candidate := _make_marble("duplicate_default", 50)
	assert_true(bool(inventory.call("add_item", owned)))
	devil_shop.config = _make_config([owned, duplicate_candidate])

	var offers := devil_shop.generate_upgrade_offers(inventory, system)

	assert_eq(offers.size(), 1)
	assert_true(offers[0].is_upgrade)
	inventory.free()


func _make_config(items: Array[Item]) -> DevilShopConfig:
	var config: DevilShopConfig = DevilShopConfigScript.new() as DevilShopConfig
	config.item_pool = items
	config.stock_count = 3
	config.level_weights = {2: 1, 3: 0, 4: 0}
	config.level_price_multipliers = {1: 1.0, 2: 1.5, 3: 2.0, 4: 3.0}
	return config


func _make_marble(item_id: String, price: int) -> Item:
	var marble := Item.new()
	marble.id = item_id
	marble.type = Item.ItemType.MARBLE
	marble.marble_type = Marble.MARBLE_TYPE.DEFAULT
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


func _get_item_level(inventory: Node, system: MarbleUpgradeSystem, item: Item) -> int:
	if item.type == Item.ItemType.RELIC:
		return int(inventory.call("get_relic_level", item))
	if item.type == Item.ItemType.MARBLE:
		return 4 if system.is_awakened(item.marble_type) else system.get_level(item.marble_type)
	return system.get_skill_level(item.id)
