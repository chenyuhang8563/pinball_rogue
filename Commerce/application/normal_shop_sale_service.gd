extends RefCounted

const ItemIdentityScript: GDScript = preload("res://Commerce/domain/item_identity.gd")
const PurchasePlanScript: GDScript = preload("res://Commerce/application/purchase_plan.gd")
const PurchaseResultScript: GDScript = preload("res://Commerce/domain/purchase_result.gd")

var _inventory: Variant = null
var _progression: Variant = null
var _wallet: Variant = null
var _configured: bool = false


func configure(inventory_adapter: Variant, progression_adapter: Variant, wallet_adapter: Variant) -> bool:
	_inventory = inventory_adapter
	_progression = progression_adapter
	_wallet = wallet_adapter
	_configured = _has_api(_inventory, [&"find_owned", &"remove"]) \
		and _has_api(_progression, [&"reset_item"]) \
		and _has_api(_wallet, [&"balance", &"quote_sell_price", &"credit"])
	return _configured


func sell(item: Item) -> RefCounted:
	if not _configured:
		return _failure(PurchaseResultScript.Code.NOT_CONFIGURED, item, "sale service is not configured")
	if item == null:
		return _failure(PurchaseResultScript.Code.UNKNOWN_OFFER, null, "sale item is null")
	if item.type == Item.ItemType.SKILL:
		return _failure(PurchaseResultScript.Code.UNKNOWN_OFFER, item, "skills cannot be sold")
	var owned: Item = _inventory.call("find_owned", item) as Item
	if owned == null:
		return _failure(PurchaseResultScript.Code.OWNERSHIP_CHANGED, item, "sale item is no longer owned")
	if owned.type == Item.ItemType.MARBLE and not _progression.has_method("reset_item"):
		return _failure(PurchaseResultScript.Code.NOT_CONFIGURED, owned, "marble progression cannot be reset")
	var sell_price := maxi(0, int(_wallet.call("quote_sell_price", owned)))
	var balance_before := int(_wallet.call("balance"))
	var plan: RefCounted = PurchasePlanScript.new([_inventory, _progression, _wallet])
	var steps: Array[Callable] = [
		Callable(_inventory, "remove").bind(owned),
		Callable(_progression, "reset_item").bind(owned),
		Callable(_wallet, "credit").bind(sell_price),
	]
	if not bool(plan.call("execute", steps)):
		var failure_code := PurchaseResultScript.Code.COMMIT_FAILED \
			if bool(plan.get("rollback_completed")) else PurchaseResultScript.Code.ROLLBACK_FAILED
		return PurchaseResultScript.failure(
			failure_code,
			&"",
			0,
			"sale commit failed at step %d" % int(plan.get("failed_step")),
			balance_before,
			int(_wallet.call("balance")),
			0,
			0,
			ItemIdentityScript.key(owned),
			bool(plan.get("rollback_completed"))
		)
	return PurchaseResultScript.success(
		&"",
		0,
		balance_before,
		int(_wallet.call("balance")),
		0,
		0,
		ItemIdentityScript.key(owned),
		"item sold"
	)


func _failure(code: int, item: Item, detail: String) -> RefCounted:
	var balance := int(_wallet.call("balance")) if _configured else 0
	return PurchaseResultScript.failure(
		code,
		&"",
		0,
		detail,
		balance,
		balance,
		0,
		0,
		ItemIdentityScript.key(item)
	)


func _has_api(adapter: Variant, methods: Array[StringName]) -> bool:
	if adapter == null:
		return false
	for method: StringName in methods:
		if not adapter.has_method(method):
			return false
	return adapter.has_method("snapshot") and adapter.has_method("restore")
