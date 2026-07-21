extends GutTest

const RunScopeScript: GDScript = preload("res://Game/Bootstrap/run_scope.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")
const DevilShopConfigScript: GDScript = preload("res://DevilShop/devil_shop_config.gd")
const FakeInventoryScript: GDScript = preload("res://tests/Commerce/fake_inventory_adapter.gd")
const FakeProgressionScript: GDScript = preload("res://tests/Commerce/fake_progression_adapter.gd")
const FakeWalletScript: GDScript = preload("res://tests/Commerce/fake_wallet_adapter.gd")
const FakeHealthScript: GDScript = preload("res://tests/Commerce/fake_health_adapter.gd")


func test_shop_slot_signal_delegates_stable_offer_once_and_sale_resyncs_presentation() -> void:
	var scope := _scope(100, 20)
	var loadout: RefCounted = scope.get("loadout") as RefCounted
	var progression: RefCounted = scope.get("progression") as RefCounted
	var wallet: RefCounted = scope.get("wallet") as RefCounted
	var dark_marble: Item = (load("res://Resources/dark_marble.tres") as Item).duplicate(true) as Item
	var bomb_marble: Item = (load("res://Resources/bomb_marble.tres") as Item).duplicate(true) as Item
	assert_true(loadout.call("add", dark_marble))
	assert_true(loadout.call("add", bomb_marble))
	assert_true(progression.call("upgrade_one", bomb_marble))

	var shop_scene: PackedScene = load("res://Shop/shop.tscn") as PackedScene
	var shop: Control = autofree(shop_scene.instantiate()) as Control
	shop_scene = null
	assert_true(shop.call("configure", loadout, progression, wallet))
	var item_pool: Array[Item] = [bomb_marble]
	shop.set("shop_item_pool", item_pool)
	add_child(shop)
	shop.call("refresh_shop_inventory")
	await get_tree().process_frame
	var shop_container := shop.get("shop_container") as GridContainer
	assert_not_null(shop_container)
	assert_eq(shop_container.get_child_count(), 1)
	var slot: Variant = shop_container.get_child(0)
	var offer: RefCounted = slot.get("offer") as RefCounted
	assert_not_null(offer)
	var stable_id := StringName(offer.get("offer_id"))
	assert_ne(stable_id, &"")
	assert_eq(int(offer.get("target_level")), 3)

	slot.purchase_requested.emit(stable_id)
	var state_after_first := {
		&"gold": int(shop.get("gold")),
		&"level": int(progression.call("level_of", bomb_marble)),
		&"inventory_count": (loadout.call("marbles") as Array).size(),
	}
	slot.purchase_requested.emit(stable_id)

	assert_eq(state_after_first[&"gold"], 70)
	assert_eq(state_after_first[&"level"], 3)
	assert_eq(int(shop.get("gold")), state_after_first[&"gold"])
	assert_eq(int(progression.call("level_of", bomb_marble)), state_after_first[&"level"])
	assert_eq((loadout.call("marbles") as Array).size(), state_after_first[&"inventory_count"])
	assert_true((shop.get("shop_offers") as Array).is_empty())
	await get_tree().process_frame
	assert_eq(shop_container.get_child_count(), 0)

	assert_true(shop.call("sell_item", bomb_marble))
	await get_tree().process_frame

	assert_null(loadout.call("find_owned", bomb_marble))
	assert_eq(progression.call("level_of", bomb_marble), 1)
	assert_eq(shop.get("gold"), 85)
	assert_eq((shop.get("shop_offers") as Array).size(), 1)
	assert_false(bool((shop.get("shop_offers") as Array)[0].get("is_upgrade")))
	assert_eq(shop_container.get_child_count(), 1)


func test_devil_confirm_purchase_delegates_selection_commit_and_advances_presentation() -> void:
	var devil_shop_scene: PackedScene = load("res://DevilShop/devil_shop.tscn") as PackedScene
	var devil_shop: Control = devil_shop_scene.instantiate() as Control
	devil_shop_scene = null
	add_child_autofree(devil_shop)
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(100)
	var health: RefCounted = FakeHealthScript.new(20)
	var config: Resource = _devil_config()
	var first_item := _make_relic("presentation_first", 20)
	var second_item := _make_relic("presentation_second", 20)
	var candidates: Array[Item] = [first_item, second_item]
	devil_shop.set("config", config)
	assert_true(devil_shop.call("configure", inventory, progression, wallet, health))
	var session: RefCounted = devil_shop.get("devil_shop_session") as RefCounted
	var opened: Array = session.call("open", config, candidates)
	assert_eq(opened.size(), 2)
	devil_shop.call("_set_offer_views", opened)
	var first_offer: Variant = devil_shop.call("get_current_offer")
	assert_not_null(first_offer)
	var first_id := StringName(first_offer.get("offer_id"))
	assert_ne(first_id, &"")
	devil_shop.call("adjust_gold_chips", 5)
	devil_shop.call("adjust_health_chips", 5)

	assert_true(devil_shop.call("confirm_purchase"))

	assert_eq(wallet.amount, 95)
	assert_eq(health.amount, 15)
	assert_not_null(inventory.find_owned(first_offer.get("item") as Item))
	assert_eq(progression.level_of(first_offer.get("item") as Item), 2)
	var next_offer: Variant = devil_shop.call("get_current_offer")
	assert_not_null(next_offer)
	assert_ne(StringName(next_offer.get("offer_id")), first_id)
	assert_true(bool((devil_shop.get("offers") as Array)[0].get("consumed")))
	assert_eq(devil_shop.get("gold_chips"), 0)
	assert_eq(devil_shop.get("health_chips"), 0)


func test_devil_confirm_button_replaces_claim_text_when_last_reward_is_sold_out() -> void:
	# 问题来源：最后一件商品购买后，“已售罄”曾显示在独立状态标签并挤占确认按钮文案。
	# 修复边界：售罄与重新刷新状态都复用同一确认按钮，保留其场景定义的字体主题与字号。
	var devil_shop_scene: PackedScene = load("res://DevilShop/devil_shop.tscn") as PackedScene
	var devil_shop: Control = devil_shop_scene.instantiate() as Control
	devil_shop_scene = null
	add_child_autofree(devil_shop)
	var inventory: RefCounted = FakeInventoryScript.new()
	var progression: RefCounted = FakeProgressionScript.new()
	var wallet: RefCounted = FakeWalletScript.new(100)
	var health: RefCounted = FakeHealthScript.new(20)
	var config: Resource = _devil_config()
	config.set("stock_count", 1)
	var reward := _make_relic("presentation_last_reward", 20)
	devil_shop.set("config", config)
	assert_true(devil_shop.call("configure", inventory, progression, wallet, health))
	var session: RefCounted = devil_shop.get("devil_shop_session") as RefCounted
	var opened: Array = session.call("open", config, [reward])
	devil_shop.call("_set_offer_views", opened)
	devil_shop.call("_refresh_ui")
	var confirm := devil_shop.get_node("BottomHUD/ConfirmButton") as Button
	var status := devil_shop.get_node("BottomHUD/Status") as Label
	assert_eq(confirm.text, tr("DEVIL_SHOP_CONFIRM"))

	devil_shop.call("adjust_gold_chips", 5)
	devil_shop.call("adjust_health_chips", 5)
	assert_true(devil_shop.call("confirm_purchase"))

	assert_true(confirm.disabled)
	assert_eq(confirm.text, tr("DEVIL_SHOP_SOLD_OUT"))
	assert_eq(status.text, "")


func _devil_config() -> Resource:
	var config: Resource = DevilShopConfigScript.new()
	config.set("stock_count", 2)
	config.set("health_to_gold", 5)
	config.set("minimum_remaining_health", 1)
	config.set("level_weights", {2: 1, 3: 0, 4: 0})
	config.set("level_price_multipliers", {1: 1.0, 2: 1.5, 3: 2.0, 4: 3.0})
	return config


func _make_relic(item_id: String, price: int) -> Item:
	var relic := Item.new()
	relic.id = item_id
	relic.type = Item.ItemType.RELIC
	relic.price = price
	return relic


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
