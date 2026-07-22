extends RefCounted

const CommerceOfferScript: GDScript = preload("res://Commerce/domain/commerce_offer.gd")
const DevilShopPricingScript: GDScript = preload("res://Commerce/domain/devil_shop_pricing.gd")
const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")
const PurchasePlanScript: GDScript = preload("res://Commerce/application/purchase_plan.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")

var _inventory: Variant = null
var _progression: Variant = null
var _wallet: Variant = null
var _health: Variant = null
var _config: Resource = null
var _random_source: RunRandomSource = null
var _content_registry: Node = null
var _configured: bool = false
var _offers: Dictionary = {}
var _offer_order: Array[StringName] = []
var _current_index: int = 0
var _payments: Dictionary = {}
var _skill_replacement_authorizations: Dictionary = {}
var _version: int = 0
var _nonce: int = 0


func configure(
	inventory_adapter: Variant,
	progression_adapter: Variant,
	wallet_adapter: Variant,
	health_adapter: Variant,
	random_source: RunRandomSource = null,
	content_registry: Node = null
) -> bool:
	_inventory = inventory_adapter
	_progression = progression_adapter
	_wallet = wallet_adapter
	_health = health_adapter
	_random_source = random_source if random_source != null else RunRandomSource.new()
	_content_registry = content_registry
	_configured = _has_api(_inventory, [&"find_owned", &"can_add", &"add", &"replace_skill", &"current_skill", &"revision"]) \
		and _has_api(_progression, [&"level_of", &"can_upgrade", &"upgrade_one", &"reset_skill", &"revision"]) \
		and _has_api(_wallet, [&"balance", &"can_debit", &"debit", &"revision"]) \
		and _has_api(_health, [&"current", &"can_debit", &"debit", &"revision"])
	return _configured


func open(config: Resource, candidates: Array) -> Array:
	_config = config
	if not _configured or _config == null:
		return []
	var source_candidates: Array = candidates
	if _content_registry != null:
		source_candidates = _registry_candidates()
	var eligible := _eligible_items(source_candidates)
	var generated: Array = []
	var stock_count := maxi(0, int(_config.get("stock_count")))
	var multipliers: Dictionary = _config.get("level_price_multipliers") as Dictionary
	while generated.size() < stock_count and not eligible.is_empty():
		var item: Item = _take_weighted_item(eligible)
		if item == null:
			break
		var owned: Item = _inventory.call("find_owned", item) as Item
		var current_level := int(_progression.call("level_of", owned)) if owned != null else 0
		var target_level := _pick_target_level(current_level)
		if target_level <= current_level:
			continue
		var full_price: int = int(DevilShopPricingScript.full_target_price(item, target_level, multipliers))
		var price: int = int(DevilShopPricingScript.quote(item, target_level, current_level, multipliers))
		generated.append(CommerceOfferScript.new(
			&"", 0, item, ItemIdentityScript.key(item), target_level, price, full_price, owned != null
		))
	return _install_offers(generated)


func replace_offers(offers: Array) -> Array:
	if not _configured:
		return []
	var replacements: Array = []
	for value: Variant in offers:
		var replacement := _copy_external_offer(value)
		if replacement != null:
			replacements.append(replacement)
	return _install_offers(replacements)


func get_offers() -> Array:
	var result: Array = []
	for offer_id: StringName in _offer_order:
		var offer: Variant = _offers.get(offer_id)
		if offer != null:
			result.append(offer.duplicate_view())
	return result


func get_current_offer() -> RefCounted:
	var offer: Variant = _current_internal()
	return offer.duplicate_view() if offer != null else null


func select_payment(offer_id: StringName, gold: int, health: int) -> RefCounted:
	if not _configured or _config == null:
		return _failure(PurchaseResultScript.Code.NOT_CONFIGURED, null, "devil session is not open")
	var offer: Variant = _offers.get(offer_id)
	if offer == null or offer != _current_internal():
		return _failure(PurchaseResultScript.Code.UNKNOWN_OFFER, null, "offer is not current", offer_id)
	var validation_code := _validate_offer(offer, false)
	if validation_code != PurchaseResultScript.Code.SUCCESS:
		return _failure(validation_code, offer, "offer validation failed")
	if gold < 0 or health < 0:
		return _failure(PurchaseResultScript.Code.INVALID_PAYMENT, offer, "payment chips cannot be negative")
	if not bool(_wallet.call("can_debit", gold)):
		return _failure(PurchaseResultScript.Code.INSUFFICIENT_FUNDS, offer, "selected gold exceeds balance")
	var minimum_health := int(_config.get("minimum_remaining_health"))
	if int(_health.call("current")) - health < minimum_health or not bool(_health.call("can_debit", health)):
		return _failure(PurchaseResultScript.Code.MINIMUM_HEALTH_VIOLATED, offer, "selected health violates minimum")
	if _payment_value(gold, health) < offer.price:
		return _failure(PurchaseResultScript.Code.INVALID_PAYMENT, offer, "selected payment is below quote")
	_payments[offer_id] = {
		&"gold": gold,
		&"health": health,
		&"snapshot_version": offer.snapshot_version,
	}
	var result: RefCounted = PurchaseResultScript.success(
		offer.offer_id,
		offer.snapshot_version,
		int(_wallet.call("balance")),
		int(_wallet.call("balance")),
		int(_health.call("current")),
		int(_health.call("current")),
		offer.item_identity,
		"payment selected"
	)
	result.committed = false
	return result


func purchase(offer_id: StringName) -> RefCounted:
	if not _configured or _config == null:
		return _failure(PurchaseResultScript.Code.NOT_CONFIGURED, null, "devil session is not open")
	var offer: Variant = _offers.get(offer_id)
	if offer == null or offer != _current_internal():
		return _failure(PurchaseResultScript.Code.UNKNOWN_OFFER, null, "offer is not current", offer_id)
	var validation_code := _validate_offer(offer, true)
	if validation_code != PurchaseResultScript.Code.SUCCESS:
		return _failure(validation_code, offer, "offer validation failed")
	var payment: Dictionary = _payments.get(offer_id, {})
	if payment.is_empty() or int(payment.get(&"snapshot_version", -1)) != offer.snapshot_version:
		return _failure(PurchaseResultScript.Code.PAYMENT_NOT_SELECTED, offer, "payment is not selected")
	var gold := int(payment.get(&"gold", -1))
	var health := int(payment.get(&"health", -1))
	if gold < 0 or health < 0 or _payment_value(gold, health) < offer.price:
		return _failure(PurchaseResultScript.Code.INVALID_PAYMENT, offer, "selected payment is invalid")
	if not bool(_wallet.call("can_debit", gold)):
		return _failure(PurchaseResultScript.Code.INSUFFICIENT_FUNDS, offer, "selected gold exceeds balance")
	var minimum_health := int(_config.get("minimum_remaining_health"))
	if int(_health.call("current")) - health < minimum_health or not bool(_health.call("can_debit", health)):
		return _failure(PurchaseResultScript.Code.MINIMUM_HEALTH_VIOLATED, offer, "selected health violates minimum")
	var balance_before := int(_wallet.call("balance"))
	var health_before := int(_health.call("current"))
	var previous_skill: Item = _inventory.call("current_skill") as Item
	var plan: RefCounted = PurchasePlanScript.new([_inventory, _progression, _wallet, _health])
	var steps: Array[Callable] = [Callable(self, "_commit_reward").bind(offer, previous_skill)]
	steps.append(Callable(_wallet, "debit").bind(gold))
	steps.append(Callable(_health, "debit").bind(health))
	if not bool(plan.call("execute", steps)):
		var failure_code := PurchaseResultScript.Code.COMMIT_FAILED \
			if bool(plan.get("rollback_completed")) else PurchaseResultScript.Code.ROLLBACK_FAILED
		return PurchaseResultScript.failure(
			failure_code,
			offer.offer_id,
			offer.snapshot_version,
			"purchase commit failed at step %d" % int(plan.get("failed_step")),
			balance_before,
			int(_wallet.call("balance")),
			health_before,
			int(_health.call("current")),
			offer.item_identity,
			bool(plan.get("rollback_completed"))
		)
	offer.consumed = true
	_payments.erase(offer.offer_id)
	_skill_replacement_authorizations.erase(offer.offer_id)
	_current_index += 1
	_refresh_unconsumed_revisions()
	return PurchaseResultScript.success(
		offer.offer_id,
		offer.snapshot_version,
		balance_before,
		int(_wallet.call("balance")),
		health_before,
		int(_health.call("current")),
		offer.item_identity
	)


func authorize_skill_replacement(offer_id: StringName) -> bool:
	if not _configured:
		return false
	var offer: Variant = _offers.get(offer_id)
	if offer == null or offer != _current_internal() or offer.consumed or offer.snapshot_version != _version:
		return false
	if offer.item == null or offer.item.type != Item.ItemType.SKILL:
		return false
	var current: Item = _inventory.call("current_skill") as Item
	if current == null or ItemIdentityScript.same(current, offer.item):
		return false
	_skill_replacement_authorizations[offer_id] = true
	return true


func invalidate_snapshot() -> void:
	_version += 1
	_payments.clear()
	_skill_replacement_authorizations.clear()


func _eligible_items(candidates: Array) -> Array:
	var result: Array = []
	for value: Variant in candidates:
		var candidate := value as Item
		if not _is_purchasable(candidate) or candidate.weight <= 0.0 \
				or not _requirements_met(candidate) or _contains_identity(result, candidate):
			continue
		var owned: Item = _inventory.call("find_owned", candidate) as Item
		if owned != null:
			if bool(_progression.call("can_upgrade", owned)):
				result.append(owned)
			continue
		var current_skill: Item = _inventory.call("current_skill") as Item
		var can_acquire := candidate.type == Item.ItemType.SKILL and current_skill != null \
			or bool(_inventory.call("can_add", candidate))
		if can_acquire and bool(_progression.call("can_upgrade", candidate)):
			result.append(candidate)
	return result


func _pick_target_level(current_level: int) -> int:
	var weights: Dictionary = _config.get("level_weights") as Dictionary
	var choices: Array[int] = []
	var choice_weights := PackedFloat64Array()
	for level: int in [2, 3, 4]:
		var weight := maxf(0.0, float(weights.get(level, 1)))
		if level > current_level and weight > 0:
			choices.append(level)
			choice_weights.append(weight)
	if choices.is_empty():
		return 0
	var index := _random_source.weighted_index_float(choice_weights)
	return choices[index] if index >= 0 else 0


func _copy_external_offer(value: Variant) -> RefCounted:
	if not value is Object:
		return null
	var source := value as Object
	var item := source.get("item") as Item
	if not _is_purchasable(item):
		return null
	var price := maxi(0, int(source.get("price")))
	var original_price := maxi(0, int(source.get("original_price")))
	if original_price == 0 and price > 0:
		original_price = price
	return CommerceOfferScript.new(
		&"",
		0,
		item,
		ItemIdentityScript.key(item),
		int(source.get("target_level")),
		price,
		original_price,
		bool(source.get("is_upgrade"))
	)


func _install_offers(values: Array) -> Array:
	_version += 1
	_offers.clear()
	_offer_order.clear()
	_current_index = 0
	_payments.clear()
	_skill_replacement_authorizations.clear()
	for value: Variant in values:
		if value == null or value.item == null:
			continue
		_nonce += 1
		var offer_id := StringName("devil:%d:%d" % [_version, _nonce])
		var offer: RefCounted = CommerceOfferScript.new(
			offer_id,
			_version,
			value.item,
			ItemIdentityScript.key(value.item),
			int(value.target_level),
			maxi(0, int(value.price)),
			maxi(0, int(value.original_price)),
			bool(value.is_upgrade),
			false,
			int(_inventory.call("revision")),
			int(_progression.call("revision")),
			int(_wallet.call("revision")),
			int(_health.call("revision"))
		)
		_offers[offer_id] = offer
		_offer_order.append(offer_id)
	return get_offers()


func _validate_offer(offer: Variant, require_skill_authorization: bool) -> int:
	if offer.snapshot_version != _version:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if offer.consumed:
		return PurchaseResultScript.Code.OFFER_CONSUMED
	if offer.item == null or ItemIdentityScript.key(offer.item) != offer.item_identity:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if offer.target_level < 2 or offer.target_level > 4:
		return PurchaseResultScript.Code.LEVEL_CHANGED
	var owned: Item = _inventory.call("find_owned", offer.item) as Item
	if offer.is_upgrade:
		if owned == null:
			return PurchaseResultScript.Code.OWNERSHIP_CHANGED
		var current_level := int(_progression.call("level_of", owned))
		if current_level <= 0 or current_level >= offer.target_level:
			return PurchaseResultScript.Code.LEVEL_CHANGED
		if not bool(_progression.call("can_upgrade", owned)):
			return PurchaseResultScript.Code.LEVEL_CHANGED
	else:
		if owned != null:
			return PurchaseResultScript.Code.OWNERSHIP_CHANGED
		var current_skill: Item = _inventory.call("current_skill") as Item
		if offer.item.type == Item.ItemType.SKILL and current_skill != null:
			if require_skill_authorization and not bool(_skill_replacement_authorizations.get(offer.offer_id, false)):
				return PurchaseResultScript.Code.SKILL_REPLACEMENT_REQUIRED
		elif not bool(_inventory.call("can_add", offer.item)):
			return PurchaseResultScript.Code.CAPACITY_CHANGED
		if not bool(_progression.call("can_upgrade", offer.item)):
			return PurchaseResultScript.Code.LEVEL_CHANGED
	if int(_inventory.call("revision")) != offer.inventory_revision:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if int(_progression.call("revision")) != offer.progression_revision:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if int(_wallet.call("revision")) != offer.wallet_revision:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if int(_health.call("revision")) != offer.health_revision:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	return PurchaseResultScript.Code.SUCCESS


func _commit_reward(offer: Variant, previous_skill: Item) -> bool:
	var owned: Item = _inventory.call("find_owned", offer.item) as Item
	if owned == null:
		if offer.item.type == Item.ItemType.SKILL and previous_skill != null:
			if not bool(_inventory.call("replace_skill", offer.item)):
				return false
			if not bool(_progression.call("reset_skill", previous_skill.id)):
				return false
		else:
			if not bool(_inventory.call("add", offer.item)):
				return false
		owned = _inventory.call("find_owned", offer.item) as Item
		if owned == null:
			return false
	while int(_progression.call("level_of", owned)) < offer.target_level:
		if not bool(_progression.call("upgrade_one", owned)):
			return false
	return int(_progression.call("level_of", owned)) == offer.target_level


func _refresh_unconsumed_revisions() -> void:
	for offer_id: StringName in _offer_order:
		var offer: Variant = _offers.get(offer_id)
		if offer == null or offer.consumed:
			continue
		offer.inventory_revision = int(_inventory.call("revision"))
		offer.progression_revision = int(_progression.call("revision"))
		offer.wallet_revision = int(_wallet.call("revision"))
		offer.health_revision = int(_health.call("revision"))


func _current_internal() -> Variant:
	if _current_index < 0 or _current_index >= _offer_order.size():
		return null
	return _offers.get(_offer_order[_current_index])


func _payment_value(gold: int, health: int) -> int:
	var exchange_rate := int(_config.get("health_to_gold")) if _config != null else 5
	return gold + health * exchange_rate


func _failure(code: int, offer: Variant, detail: String, fallback_id: StringName = &"") -> RefCounted:
	return PurchaseResultScript.failure(
		code,
		offer.offer_id if offer != null else fallback_id,
		offer.snapshot_version if offer != null else _version,
		detail,
		int(_wallet.call("balance")) if _configured else 0,
		int(_wallet.call("balance")) if _configured else 0,
		int(_health.call("current")) if _configured else 0,
		int(_health.call("current")) if _configured else 0,
		offer.item_identity if offer != null else ""
	)


func _contains_identity(items: Array, candidate: Item) -> bool:
	for item: Item in items:
		if ItemIdentityScript.same(item, candidate):
			return true
	return false


func _take_weighted_item(items: Array) -> Item:
	if items.is_empty():
		return null
	var weights := PackedFloat64Array()
	for value: Variant in items:
		var item := value as Item
		weights.append(maxf(0.0, item.weight) if item != null else 0.0)
	var index := _random_source.weighted_index_float(weights)
	if index < 0:
		return null
	return items.pop_at(index) as Item


func _registry_candidates() -> Array:
	if _content_registry == null or not is_instance_valid(_content_registry) \
			or not _content_registry.has_method(&"query"):
		return []
	return _content_registry.call(&"query", Item.ItemType.RELIC) as Array


func _requirements_met(item: Item) -> bool:
	if item == null or item.requires_tags.is_empty():
		return true
	var owned_tags: Array[StringName] = []
	if _inventory != null and _inventory.has_method(&"owned_items"):
		for value: Variant in _inventory.call(&"owned_items") as Array:
			var owned := value as Item
			if owned == null:
				continue
			for tag: StringName in owned.tags:
				if not owned_tags.has(tag):
					owned_tags.append(tag)
	for required: StringName in item.requires_tags:
		if not owned_tags.has(required):
			return false
	return true


func _is_purchasable(item: Item) -> bool:
	return item != null and item.type in [Item.ItemType.MARBLE, Item.ItemType.RELIC, Item.ItemType.SKILL]


func _has_api(adapter: Variant, methods: Array[StringName]) -> bool:
	if adapter == null:
		return false
	for method: StringName in methods:
		if not adapter.has_method(method):
			return false
	return adapter.has_method("snapshot") and adapter.has_method("restore")
