extends GutTest

const RegistryScript: GDScript = preload("res://Content/application/content_registry.gd")
const RandomSourceScript: GDScript = preload("res://Run/application/run_random_source.gd")
const RewardServiceScript: GDScript = preload("res://Run/application/reward_service.gd")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const WalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")
const NormalSessionScript: GDScript = preload("res://Commerce/application/normal_shop_session.gd")
const DevilSessionScript: GDScript = preload("res://Commerce/application/devil_shop_session.gd")
const DevilConfigScript: GDScript = preload("res://Commerce/domain/devil_shop_config.gd")
const TokenScript: GDScript = preload("res://Run/domain/run_flow_token.gd")
const MainScene: PackedScene = preload("res://Game/Bootstrap/main.tscn")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")
const EffectManagerScript: GDScript = preload("res://Combat/effects/effect_manager.gd")


class ChannelRegistry extends Node:
	var items: Array[Item] = []

	func is_valid() -> bool:
		return true

	func all_items() -> Array[Item]:
		return items.duplicate()

	func query(item_type: Item.ItemType) -> Array[Item]:
		var result: Array[Item] = []
		for item: Item in items:
			if item.type == item_type:
				result.append(item)
		return result


class HealthPort extends RefCounted:
	var amount: int = 100

	func current() -> int:
		return amount

	func can_debit(value: int) -> bool:
		return value >= 0 and value <= amount

	func debit(value: int) -> bool:
		if not can_debit(value):
			return false
		amount -= value
		return true

	func revision() -> int:
		return amount

	func snapshot() -> Dictionary:
		return {&"amount": amount}

	func restore(state: Dictionary) -> bool:
		amount = int(state.get(&"amount", amount))
		return true


class TrackingController extends RunFlowController:
	func configure(
		_run_scope: RunScope,
		_factory: BattlePlanFactory,
		_reward: RewardService,
		_resolver: EventResolver,
		_floor_config: RunFloorConfig,
		_random: RunRandomSource,
		_gateway: BattleGateway
	) -> bool:
		return true

	func start_run() -> bool:
		return true


var _relic_capacity: int = 5


func test_registry_scan_order_and_ids_are_stable() -> void:
	var registry: Node = autofree(RegistryScript.new())

	# Sorted resource paths define public iteration order; ids must be unique.
	assert_eq(registry.call("rebuild"), OK)
	assert_true(bool(registry.call("is_valid")))
	var ids: Array[StringName] = []
	for item: Item in registry.call("all_items") as Array[Item]:
		ids.append(StringName(item.id))
		assert_eq(registry.call("by_id", StringName(item.id)), item)
	assert_eq(ids.size(), ids.duplicate().reduce(
		func(unique: Array[StringName], id: StringName) -> Array[StringName]:
			if not unique.has(id):
				unique.append(id)
			return unique,
		[] as Array[StringName]
	).size())
	assert_eq(ids, [
		&"assassin_marble", &"assassins_whetstone", &"blue_marble", &"bomb_marble", &"brown_marble",
		&"dark_marble", &"dash", &"execution_decree", &"fire_bellows", &"fire_marble",
		&"fortuna_dice", &"green_marble", &"ice_hammer", &"lightning", &"magic_missile",
		&"many_faced_prism", &"poison_culture", &"scarlet_thread",
	] as Array[StringName])


func test_float_weighted_and_fisher_yates_repeat_for_same_seed() -> void:
	var first: RunRandomSource = RandomSourceScript.new(20260722)
	var second: RunRandomSource = RandomSourceScript.new(20260722)
	var weights := PackedFloat64Array([0.125, 1.75, 4.5])
	var first_picks: Array[int] = []
	var second_picks: Array[int] = []
	for _draw: int in range(32):
		first_picks.append(first.weighted_index_float(weights))
		second_picks.append(second.weighted_index_float(weights))
	assert_eq(first_picks, second_picks)
	assert_eq(first.weighted_index_float(PackedFloat64Array([0.0, -0.5])), -1)
	var first_order: Array = [&"a", &"b", &"c", &"d", &"e"]
	var second_order: Array = [&"a", &"b", &"c", &"d", &"e"]
	first.shuffle(first_order)
	second.shuffle(second_order)
	assert_eq(first_order, second_order)


func test_reward_defaults_use_registry_and_filter_requirements_before_draw() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new()
	var registry := ChannelRegistry.new()
	autofree(registry)
	var blue := _item(&"blue", Item.ItemType.MARBLE, [&"frost"])
	blue.marble_type = Marble.MARBLE_TYPE.BLUE
	var dash := _item(&"dash", Item.ItemType.SKILL)
	var missile := _item(&"missile", Item.ItemType.SKILL)
	var blocked := _item(&"blocked", Item.ItemType.RELIC)
	blocked.requires_tags = [&"fire"]
	registry.items = [blue, dash, missile, blocked]
	var service: RewardService = RewardServiceScript.new()
	assert_true(service.configure(
		loadout, progression, wallet, BattleRewardConfig.new(),
		RandomSourceScript.new(7), registry
	))

	# The default node channel is registry-backed: Blue and both skills survive,
	# while the unmet fire relic is removed before any weighted RNG call.
	var draft: RewardOffer = service.create_node_draft(
		TokenScript.new(1, 1, 1), &"phase0c-node"
	)
	var offered_ids: Array[String] = []
	for option: RewardOption in draft.options():
		offered_ids.append(option.item.id)
	offered_ids.sort()
	assert_eq(offered_ids, ["blue", "dash", "missile"])


func test_shop_channels_use_registry_and_one_shared_random_source() -> void:
	var registry: Node = autofree(RegistryScript.new())
	assert_eq(registry.call("rebuild"), OK)
	var loadout: RefCounted = LoadoutScript.new()
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new(1000)
	var random: RunRandomSource = RandomSourceScript.new(99)
	var normal: RefCounted = NormalSessionScript.new()
	assert_true(normal.call("configure", loadout, progression, wallet, random, registry))

	# Normal stock ignores scene-authored pools once injected and includes Blue.
	var normal_offers: Array = normal.call("regenerate", [], 20)
	assert_true(_offer_ids(normal_offers).has("blue_marble"))
	assert_eq(normal.get("_random_source"), random)
	assert_eq(normal.get("_content_registry"), registry)

	# Owning each producer satisfies the existing gates. The two universally
	# eligible M2 relics join this deterministic Devil Shop draw.
	assert_true(loadout.call("add", registry.call("by_id", &"fire_marble") as Item))
	assert_true(loadout.call("add", registry.call("by_id", &"green_marble") as Item))
	assert_true(loadout.call("add", registry.call("by_id", &"blue_marble") as Item))
	var devil: RefCounted = DevilSessionScript.new()
	var health := HealthPort.new()
	assert_true(devil.call("configure", loadout, progression, wallet, health, random, registry))
	var config: Resource = DevilConfigScript.new()
	config.set("stock_count", 4)
	config.set("level_weights", {2: 1, 3: 0, 4: 0})
	var devil_offers: Array = devil.call("open", config, [])
	assert_eq(_offer_ids(devil_offers), [
		"execution_decree", "fortuna_dice", "ice_hammer", "lightning",
	])
	assert_eq(devil.get("_random_source"), random)
	assert_eq(devil.get("_content_registry"), registry)


func test_restore_rejects_snapshot_that_exceeds_current_capacity() -> void:
	_relic_capacity = 2
	var loadout: RefCounted = LoadoutScript.new(Callable(self, "_capacity"))
	var first := _item(&"first", Item.ItemType.RELIC)
	var second := _item(&"second", Item.ItemType.RELIC)
	assert_true(loadout.call("add", first))
	assert_true(loadout.call("add", second))
	var oversized_snapshot: Dictionary = loadout.call("snapshot")
	assert_true(loadout.call("remove", second))
	_relic_capacity = 1

	# Restore validates against the live capacity provider before mutating state.
	assert_false(loadout.call("restore", oversized_snapshot))
	assert_eq(loadout.call("owned_items"), [first] as Array[Item])


func test_bootstrap_injects_same_registry_and_rng_into_all_consumers() -> void:
	var main: Node = autofree(MainScene.instantiate())
	main.set("skill_controller", main.get_node("SkillController") as SkillController)
	main.set("active_skill_slot", main.get_node("CanvasLayer/SkillSlot") as ActiveSkillSlot)
	var stats: Node = autofree(FakeStatSystemScript.new())
	stats.set("values", {
		"marble_slot_count": 3,
		"relic_slot_count": 5,
		"buy_price_multiplier": 1.0,
		"sell_price_multiplier": 0.5,
	})
	var effect_manager: Node = autofree(EffectManagerScript.new())
	var random: RunRandomSource = RandomSourceScript.new(1234)
	assert_true(main.call(
		"_setup_run_flow", stats, effect_manager,
		{&"run_flow_controller": TrackingController.new(), &"run_random_source": random}
	))
	var registry: Node = main.get("content_registry") as Node
	var normal_session: RefCounted = (main.get("normal_shop") as Node).get(
		"normal_shop_session"
	) as RefCounted
	var devil_session: RefCounted = (main.get("devil_shop") as Node).get(
		"devil_shop_session"
	) as RefCounted
	assert_eq((main.get("reward_service") as RewardService).get("_random_source"), random)
	assert_eq((main.get("reward_service") as RewardService).get("_content_registry"), registry)
	assert_eq(normal_session.get("_random_source"), random)
	assert_eq(normal_session.get("_content_registry"), registry)
	assert_eq(devil_session.get("_random_source"), random)
	assert_eq(devil_session.get("_content_registry"), registry)
	main.call("_dispose_run_flow_composition")


func _capacity(item_type: Item.ItemType, fallback: int) -> int:
	return _relic_capacity if item_type == Item.ItemType.RELIC else fallback


func _item(item_id: StringName, item_type: Item.ItemType, tags: Array[StringName] = []) -> Item:
	var item := Item.new()
	item.id = String(item_id)
	item.type = item_type
	item.tags = tags
	item.weight = 1.0
	item.price = 20
	return item


func _offer_ids(offers: Array) -> Array[String]:
	var ids: Array[String] = []
	for offer: Variant in offers:
		ids.append((offer.item as Item).id)
	ids.sort()
	return ids
