extends GutTest

## 冰封遗物的投放渠道前置过滤：permafrost（requires_tags=[frost]）在没有冰霜弹珠
## （frost 标签）时是死选，必须在节点奖励 / 精英奖励 / 普通商店 / 恶魔商店四个渠道
## 全部被过滤掉；持有冰霜弹珠时四个渠道都能投放。各渠道共享同一套 _requirements_met
## 语义，这里用真实 ContentRegistry（加载真实 permafrost.tres）端到端验证。

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


var _registry: Node = null
var _permafrost: Item = null
var _blue_marble: Item = null


func before_each() -> void:
	_registry = RegistryScript.new()
	add_child_autofree(_registry)
	assert_eq(_registry.call("rebuild"), OK)
	_permafrost = _registry.call("by_id", &"permafrost") as Item
	_blue_marble = _registry.call("by_id", &"blue_marble") as Item
	assert_not_null(_permafrost, "real permafrost.tres must be registered")
	assert_not_null(_blue_marble, "blue marble supplies the frost tag")
	assert_true(_permafrost.requires_tags.has(&"frost"))


func test_permafrost_blocked_across_all_channels_without_frost_marble() -> void:
	var loadout: RefCounted = LoadoutScript.new()  # 无冰霜弹珠 → 无 frost 标签
	var service: RewardService = _configure_service(loadout)

	# 节点奖励：以 permafrost 为唯一候选 → 被过滤 → 只剩金币补偿。
	var node: RewardOffer = service.create_node_draft(
		TokenScript.new(1, 1, 1), &"frost-req-node", [_permafrost]
	)
	assert_false(_draft_item_ids(node).has("permafrost"), "node channel hides permafrost")
	service.clear_active()

	# 精英奖励：同样以 permafrost 为唯一遗物候选 → 被过滤 → 只剩金币。
	var elite: RewardOffer = service.create_elite_draft(
		TokenScript.new(1, 1, 1), &"frost-req-elite", [_permafrost]
	)
	assert_false(_draft_item_ids(elite).has("permafrost"), "elite channel hides permafrost")

	# 恶魔商店：以 permafrost 为唯一候选 → 被过滤 → 0 件商品。
	var devil_offers: Array = _open_devil(loadout, [_permafrost])
	assert_false(_offer_ids(devil_offers).has("permafrost"), "devil shop hides permafrost")

	# 普通商店：结构上不卖遗物，但其共享前置门也必须拒绝 permafrost。
	var normal: RefCounted = _configure_normal(loadout)
	assert_false(
		bool(normal.call("_requirements_met", _permafrost)),
		"normal shop requirement gate rejects permafrost without frost"
	)


func test_permafrost_offered_across_all_channels_with_frost_marble() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	assert_true(loadout.call("add", _blue_marble), "blue marble grants the frost tag")
	var service: RewardService = _configure_service(loadout)

	var node: RewardOffer = service.create_node_draft(
		TokenScript.new(1, 1, 1), &"frost-req-node2", [_permafrost]
	)
	assert_true(_draft_item_ids(node).has("permafrost"), "node channel offers permafrost")
	service.clear_active()

	var elite: RewardOffer = service.create_elite_draft(
		TokenScript.new(1, 1, 1), &"frost-req-elite2", [_permafrost]
	)
	assert_true(_draft_item_ids(elite).has("permafrost"), "elite channel offers permafrost")

	var devil_offers: Array = _open_devil(loadout, [_permafrost])
	assert_true(_offer_ids(devil_offers).has("permafrost"), "devil shop offers permafrost")

	var normal: RefCounted = _configure_normal(loadout)
	assert_true(
		bool(normal.call("_requirements_met", _permafrost)),
		"normal shop requirement gate accepts permafrost with frost"
	)


func _configure_service(loadout: RefCounted) -> RewardService:
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new(1000)
	var service: RewardService = RewardServiceScript.new()
	assert_true(service.configure(
		loadout, progression, wallet, BattleRewardConfig.new(),
		RandomSourceScript.new(7), _registry
	))
	return service


func _configure_normal(loadout: RefCounted) -> RefCounted:
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new(1000)
	var normal: RefCounted = NormalSessionScript.new()
	assert_true(normal.call(
		"configure", loadout, progression, wallet, RandomSourceScript.new(7), _registry
	))
	return normal


func _open_devil(loadout: RefCounted, candidates: Array) -> Array:
	var progression: RefCounted = ProgressionScript.new(loadout)
	var wallet: RefCounted = WalletScript.new(1000)
	var devil: RefCounted = DevilSessionScript.new()
	assert_true(devil.call(
		"configure", loadout, progression, wallet, HealthPort.new(),
		RandomSourceScript.new(7), _registry
	))
	# 恶魔商店一旦注入 ContentRegistry 就会忽略 candidates、改用注册表遗物池，
	# 故把 stock_count 设得足够大以抽干全部合格遗物，使 permafrost 的成员判定确定化。
	var config: Resource = DevilConfigScript.new()
	config.set("stock_count", 99)
	config.set("level_weights", {2: 1, 3: 0, 4: 0})
	return devil.call("open", config, candidates) as Array


func _draft_item_ids(draft: RewardOffer) -> Array[String]:
	var ids: Array[String] = []
	if draft == null:
		return ids
	for option: RewardOption in draft.options():
		if option.item != null:
			ids.append(option.item.id)
	return ids


func _offer_ids(offers: Array) -> Array[String]:
	var ids: Array[String] = []
	for offer: Variant in offers:
		var item: Item = (offer as Object).get("item") as Item
		if item != null:
			ids.append(item.id)
	return ids
