extends GutTest

const WalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")
const HealthScript: GDScript = preload("res://Run/domain/run_health.gd")

var buy_multiplier: float = 1.0
var sell_multiplier: float = 0.5


func test_wallet_debit_credit_snapshot_restore_and_dynamic_price_multipliers() -> void:
	var wallet: RefCounted = WalletScript.new(100)
	assert_true(wallet.call("configure", Callable(self, "_buy_multiplier"), Callable(self, "_sell_multiplier")))
	assert_true(wallet.call("can_debit", 100))
	assert_true(wallet.call("debit", 40))
	assert_false(wallet.call("debit", 61))
	assert_false(wallet.call("credit", -1))
	assert_true(wallet.call("credit", 5))
	assert_eq(wallet.call("balance"), 65)
	var saved: Dictionary = wallet.call("snapshot")
	assert_true(wallet.call("credit", 35))
	assert_true(wallet.call("restore", saved))
	assert_eq(wallet.call("balance"), 65)
	assert_eq(wallet.call("revision"), saved[&"revision"])
	var item := _priced_item(21)
	buy_multiplier = 1.5
	sell_multiplier = 0.25
	assert_eq(wallet.call("quote_price", item), 32)
	assert_eq(wallet.call("quote_sell_price", item), 5)
	buy_multiplier = 2.0
	assert_eq(wallet.call("quote_price", item), 42, "provider 变化应即时反映")


func test_health_enforces_payment_minimum_but_damage_can_reach_zero() -> void:
	var default_health: RefCounted = HealthScript.new()
	assert_eq(default_health.call("current"), 10)
	var clamped_minimum_health: RefCounted = HealthScript.new(10, 0)
	assert_eq(clamped_minimum_health.call("minimum_remaining"), 1)
	assert_false(clamped_minimum_health.call("can_debit", 10))
	var health: RefCounted = HealthScript.new(10, 2)
	assert_true(health.call("can_debit", 8))
	assert_false(health.call("can_debit", 9))
	assert_true(health.call("debit", 8))
	assert_eq(health.call("current"), 2)
	assert_false(health.call("debit", 1))
	assert_true(health.call("damage", 3))
	assert_eq(health.call("current"), 0)
	assert_true(health.call("credit", 5))
	var saved: Dictionary = health.call("snapshot")
	assert_true(health.call("credit", 5))
	assert_true(health.call("restore", saved))
	assert_eq(health.call("current"), 5)
	assert_eq(health.call("minimum_remaining"), 2)
	assert_eq(health.call("revision"), saved[&"revision"])


func _buy_multiplier() -> float:
	return buy_multiplier


func _sell_multiplier() -> float:
	return sell_multiplier


func _priced_item(price: int) -> Item:
	var item := Item.new()
	item.type = Item.ItemType.RELIC
	item.id = "priced"
	item.price = price
	return item
