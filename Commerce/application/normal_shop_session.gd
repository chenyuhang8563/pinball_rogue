extends RefCounted

const CommerceOfferScript: GDScript = preload("res://Commerce/domain/commerce_offer.gd")
const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")
const PurchasePlanScript: GDScript = preload("res://Commerce/application/purchase_plan.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")

var _inventory: Variant = null
var _progression: Variant = null
var _wallet: Variant = null
var _random_source: RunRandomSource = null
var _content_registry: Node = null
var _configured: bool = false
var _offers: Dictionary = {}
var _offer_order: Array[StringName] = []
var _skill_replacement_authorizations: Dictionary = {}
var _version: int = 0
var _nonce: int = 0


func configure(
	inventory_adapter: Variant,
	progression_adapter: Variant,
	wallet_adapter: Variant,
	random_source: RunRandomSource = null,
	content_registry: Node = null
) -> bool:
	_inventory = inventory_adapter
	_progression = progression_adapter
	_wallet = wallet_adapter
	_random_source = random_source if random_source != null else RunRandomSource.new()
	_content_registry = content_registry
	_configured = _has_api(_inventory, [&"find_owned", &"can_add", &"add", &"replace_skill", &"current_skill", &"revision"]) \
		and _has_api(_progression, [&"level_of", &"can_upgrade", &"upgrade_one", &"reset_skill", &"revision"]) \
		and _has_api(_wallet, [&"balance", &"quote_price", &"can_debit", &"debit", &"revision"])
	return _configured


func regenerate(candidates: Array, max_offers: int = 6) -> Array:
	if not _configured:
		return []
	var source_candidates: Array = candidates
	if _content_registry != null:
		source_candidates = _registry_candidates()
	var available: Array = []
	for value: Variant in source_candidates:
		var candidate := value as Item
		if not _is_purchasable(candidate) or candidate.weight <= 0.0 \
				or not _requirements_met(candidate) or _contains_identity(available, candidate):
			continue
		var owned: Item = _inventory.call("find_owned", candidate) as Item
		if owned == null:
			available.append(_make_uninstalled_offer(candidate, 1, false))
		elif bool(_progression.call("can_upgrade", owned)):
			var current_level := int(_progression.call("level_of", owned))
			if current_level > 0:
				available.append(_make_uninstalled_offer(owned, current_level + 1, true))
	var selected: Array = []
	for item_type: int in [Item.ItemType.RELIC, Item.ItemType.MARBLE, Item.ItemType.SKILL]:
		var category: Array = []
		for offer: Variant in available:
			if offer.item.type == item_type:
				category.append(offer)
		if not category.is_empty() and selected.size() < maxi(0, max_offers):
			selected.append(_take_weighted_offer(category))
	var remaining: Array = []
	for offer: Variant in available:
		if not selected.has(offer):
			remaining.append(offer)
	var target_count := mini(maxi(0, max_offers), available.size())
	while selected.size() < target_count and not remaining.is_empty():
		selected.append(_take_weighted_offer(remaining))
	_random_source.shuffle(selected)
	return _install_offers(selected)


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


func purchase(offer_id: StringName) -> RefCounted:
	if not _configured:
		return _failure(PurchaseResultScript.Code.NOT_CONFIGURED, null, "normal session is not configured")
	var offer: Variant = _offers.get(offer_id)
	if offer == null:
		return _failure(PurchaseResultScript.Code.UNKNOWN_OFFER, null, "offer id is unknown", offer_id)
	var validation_code := _validate_offer(offer, true)
	if validation_code != PurchaseResultScript.Code.SUCCESS:
		return _failure(validation_code, offer, "offer validation failed")
	var balance_before := int(_wallet.call("balance"))
	var previous_skill: Item = _inventory.call("current_skill") as Item
	var plan: RefCounted = PurchasePlanScript.new([_inventory, _progression, _wallet])
	var steps: Array[Callable] = [Callable(self, "_commit_reward").bind(offer, previous_skill)]
	steps.append(Callable(_wallet, "debit").bind(offer.price))
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
			0,
			0,
			offer.item_identity,
			bool(plan.get("rollback_completed"))
		)
	offer.consumed = true
	_skill_replacement_authorizations.erase(offer.offer_id)
	_refresh_unconsumed_revisions()
	return PurchaseResultScript.success(
		offer.offer_id,
		offer.snapshot_version,
		balance_before,
		int(_wallet.call("balance")),
		0,
		0,
		offer.item_identity
	)


func authorize_skill_replacement(offer_id: StringName) -> bool:
	if not _configured:
		return false
	var offer: Variant = _offers.get(offer_id)
	if offer == null or offer.consumed or offer.snapshot_version != _version:
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
	_skill_replacement_authorizations.clear()


## Re-stamps all unconsumed offers after an external state change (e.g. a sale)
## so they remain valid without regenerating the offer set.
func acknowledge_external_change() -> void:
	if not _configured:
		return
	_version += 1
	_skill_replacement_authorizations.clear()
	for offer_id: StringName in _offer_order:
		var offer: Variant = _offers.get(offer_id)
		if offer == null or offer.consumed:
			continue
		offer.snapshot_version = _version
		offer.inventory_revision = int(_inventory.call("revision"))
		offer.progression_revision = int(_progression.call("revision"))
		offer.wallet_revision = int(_wallet.call("revision"))


func _make_uninstalled_offer(item: Item, target_level: int, is_upgrade: bool) -> RefCounted:
	var price := int(_wallet.call("quote_price", item))
	return CommerceOfferScript.new(&"", 0, item, ItemIdentityScript.key(item), target_level, price, price, is_upgrade)


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
	_skill_replacement_authorizations.clear()
	for value: Variant in values:
		if value == null or value.item == null:
			continue
		_nonce += 1
		var offer_id := StringName("normal:%d:%d" % [_version, _nonce])
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
			0
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
	var owned: Item = _inventory.call("find_owned", offer.item) as Item
	if offer.is_upgrade:
		if owned == null:
			return PurchaseResultScript.Code.OWNERSHIP_CHANGED
		if int(_progression.call("level_of", owned)) + 1 != offer.target_level:
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
	if int(_inventory.call("revision")) != offer.inventory_revision:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if int(_progression.call("revision")) != offer.progression_revision:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if int(_wallet.call("revision")) != offer.wallet_revision:
		return PurchaseResultScript.Code.STALE_SNAPSHOT
	if not bool(_wallet.call("can_debit", offer.price)):
		return PurchaseResultScript.Code.INSUFFICIENT_FUNDS
	return PurchaseResultScript.Code.SUCCESS


func _commit_reward(offer: Variant, previous_skill: Item) -> bool:
	if offer.is_upgrade:
		var owned: Item = _inventory.call("find_owned", offer.item) as Item
		return owned != null and bool(_progression.call("upgrade_one", owned)) \
			and int(_progression.call("level_of", owned)) == offer.target_level
	if offer.item.type == Item.ItemType.SKILL and previous_skill != null:
		return bool(_inventory.call("replace_skill", offer.item)) \
			and bool(_progression.call("reset_skill", previous_skill.id))
	return bool(_inventory.call("add", offer.item))


func _refresh_unconsumed_revisions() -> void:
	for offer_id: StringName in _offer_order:
		var offer: Variant = _offers.get(offer_id)
		if offer == null or offer.consumed:
			continue
		offer.inventory_revision = int(_inventory.call("revision"))
		offer.progression_revision = int(_progression.call("revision"))
		offer.wallet_revision = int(_wallet.call("revision"))


func _failure(code: int, offer: Variant, detail: String, fallback_id: StringName = &"") -> RefCounted:
	return PurchaseResultScript.failure(
		code,
		offer.offer_id if offer != null else fallback_id,
		offer.snapshot_version if offer != null else _version,
		detail,
		int(_wallet.call("balance")) if _configured else 0,
		int(_wallet.call("balance")) if _configured else 0,
		0,
		0,
		offer.item_identity if offer != null else ""
	)


func _contains_identity(offers: Array, candidate: Item) -> bool:
	for offer: Variant in offers:
		if ItemIdentityScript.same(offer.item, candidate):
			return true
	return false


func _take_weighted_offer(offers: Array) -> Variant:
	if offers.is_empty():
		return null
	var weights := PackedFloat64Array()
	for offer: Variant in offers:
		weights.append(maxf(0.0, float(offer.item.weight)))
	var index := _random_source.weighted_index_float(weights)
	if index < 0:
		return null
	return offers.pop_at(index)


func _registry_candidates() -> Array:
	if _content_registry == null or not is_instance_valid(_content_registry) \
			or not _content_registry.has_method(&"query"):
		return []
	var result: Array = []
	for item_type: Item.ItemType in [
		Item.ItemType.RELIC, Item.ItemType.MARBLE, Item.ItemType.SKILL,
	]:
		result.append_array(_content_registry.call(&"query", item_type) as Array)
	return result


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
