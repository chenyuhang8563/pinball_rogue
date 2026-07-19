extends RefCounted

const NormalShopPricingScript: GDScript = preload("res://Commerce/domain/normal_shop_pricing.gd")

signal changed(value: int)

var _balance: int = 0
var _buy_multiplier_provider: Callable = Callable()
var _sell_multiplier_provider: Callable = Callable()


func _init(initial_balance: int = 0) -> void:
	_balance = maxi(0, initial_balance)


func configure(
	buy_multiplier_provider: Callable = Callable(),
	sell_multiplier_provider: Callable = Callable()
) -> bool:
	_buy_multiplier_provider = buy_multiplier_provider
	_sell_multiplier_provider = sell_multiplier_provider
	return true


func balance() -> int:
	return _balance


func set_balance(value: int) -> bool:
	if value < 0:
		return false
	if _balance == value:
		return true
	_balance = value
	changed.emit(_balance)
	return true


func can_debit(amount: int) -> bool:
	return amount >= 0 and _balance >= amount


func debit(amount: int) -> bool:
	return can_debit(amount) and set_balance(_balance - amount)


func credit(amount: int) -> bool:
	return amount >= 0 and set_balance(_balance + amount)


func snapshot() -> Dictionary:
	return {&"balance": _balance, &"revision": revision()}


func restore(state: Dictionary) -> bool:
	if not state.has(&"balance"):
		return false
	var restored_balance := int(state[&"balance"])
	return set_balance(restored_balance) \
		and revision() == int(state.get(&"revision", revision()))


func revision() -> int:
	return {&"balance": _balance}.hash()


func quote_price(item: Item) -> int:
	var multiplier := _multiplier_from(_buy_multiplier_provider, 1.0)
	return int(NormalShopPricingScript.quote(item, multiplier))


func quote_sell_price(item: Item) -> int:
	var multiplier := _multiplier_from(_sell_multiplier_provider, 0.5)
	return int(NormalShopPricingScript.sell_quote(item, multiplier))


func dispose() -> void:
	_buy_multiplier_provider = Callable()
	_sell_multiplier_provider = Callable()


func _multiplier_from(provider: Callable, fallback: float) -> float:
	if not provider.is_valid():
		return fallback
	return maxf(0.0, float(provider.call()))
