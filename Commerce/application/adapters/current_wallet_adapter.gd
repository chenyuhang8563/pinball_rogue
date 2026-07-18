extends RefCounted

const NormalShopPricingScript: GDScript = preload("res://Commerce/domain/normal_shop_pricing.gd")

var _wallet: Object = null
var _price_provider: Callable = Callable()
var _sell_price_provider: Callable = Callable()


func _init(
	wallet: Object = null,
	price_provider: Callable = Callable(),
	sell_price_provider: Callable = Callable()
) -> void:
	_wallet = wallet
	_price_provider = price_provider
	_sell_price_provider = sell_price_provider


func balance() -> int:
	if not _is_available():
		return 0
	if _wallet.has_method("get_balance"):
		return int(_wallet.call("get_balance"))
	var property_name := _balance_property()
	return int(_wallet.get(property_name)) if property_name != &"" else 0


func quote_price(item: Item) -> int:
	if item == null:
		return 0
	if _price_provider.is_valid():
		return maxi(0, int(_price_provider.call(item)))
	if _is_available() and _wallet.has_method("quote_price"):
		return maxi(0, int(_wallet.call("quote_price", item)))
	return NormalShopPricingScript.quote(item)


func quote_sell_price(item: Item) -> int:
	if item == null:
		return 0
	if _sell_price_provider.is_valid():
		return maxi(0, int(_sell_price_provider.call(item)))
	return NormalShopPricingScript.sell_quote(item)


func can_debit(amount: int) -> bool:
	return amount >= 0 and _is_available() and balance() >= amount


func debit(amount: int) -> bool:
	if not can_debit(amount):
		return false
	var expected := balance() - amount
	return _write_balance(expected) and balance() == expected


func credit(amount: int) -> bool:
	if amount < 0 or not _is_available():
		return false
	var expected := balance() + amount
	return _write_balance(expected) and balance() == expected


func snapshot() -> Dictionary:
	return {&"balance": balance(), &"revision": revision()} if _is_available() else {}


func restore(state: Dictionary) -> bool:
	if not _is_available() or not state.has(&"balance"):
		return false
	var expected := int(state[&"balance"])
	return _write_balance(expected) and balance() == expected


func revision() -> int:
	return {&"balance": balance()}.hash() if _is_available() else 0


func _write_balance(value: int) -> bool:
	if _wallet.has_method("set_balance"):
		_wallet.call("set_balance", value)
		return true
	var property_name := _balance_property()
	if property_name == &"":
		return false
	_wallet.set(property_name, value)
	return true


func _balance_property() -> StringName:
	if not _is_available():
		return &""
	for property: Dictionary in _wallet.get_property_list():
		var property_name := StringName(property.get("name", ""))
		if property_name == &"balance":
			return property_name
	for property: Dictionary in _wallet.get_property_list():
		var property_name := StringName(property.get("name", ""))
		if property_name == &"gold":
			return property_name
	return &""


func _is_available() -> bool:
	return _wallet != null and is_instance_valid(_wallet)
