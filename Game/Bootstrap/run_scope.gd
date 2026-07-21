extends Node
class_name RunScope

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ItemProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const RunWalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")
const RunHealthScript: GDScript = preload("res://Run/domain/run_health.gd")

const STAT_BUY_PRICE_MULTIPLIER: String = "buy_price_multiplier"
const STAT_SELL_PRICE_MULTIPLIER: String = "sell_price_multiplier"
const STAT_MARBLE_SLOT_COUNT: String = "marble_slot_count"
const STAT_RELIC_SLOT_COUNT: String = "relic_slot_count"
const STAT_ENTITY_PLAYER: String = "player"

var loadout: RefCounted = null
var progression: RefCounted = null
var wallet: RefCounted = null
var health: RefCounted = null

var initial_gold: int = 100
var initial_health: int = 10

var _stat_system: Object = null
var _initialized: bool = false
var _ever_initialized: bool = false
var _disposed: bool = false


func initialize(stat_system: Object, starting_gold: int = 100, starting_health: int = 10) -> bool:
	if _ever_initialized or stat_system == null or not is_instance_valid(stat_system) \
			or not stat_system.has_method("get_stat"):
		return false
	if starting_gold < 0 or starting_health < 0:
		return false
	_stat_system = stat_system
	self.initial_gold = starting_gold
	self.initial_health = starting_health
	loadout = LoadoutScript.new(Callable(self, "_capacity_for"))
	progression = ItemProgressionScript.new(loadout, _stat_system)
	wallet = RunWalletScript.new()
	wallet.call(
		"configure",
		Callable(self, "_buy_multiplier"),
		Callable(self, "_sell_multiplier")
	)
	health = RunHealthScript.new()
	wallet.call("set_balance", self.initial_gold)
	health.call("reset", self.initial_health)
	_initialized = true
	_ever_initialized = true
	_disposed = false
	return true


func reset_for_run() -> bool:
	if not _initialized or _disposed:
		return false
	progression.call("reset_for_run")
	var wallet_reset := bool(wallet.call("set_balance", initial_gold))
	var health_reset := bool(health.call("reset", initial_health))
	return wallet_reset and health_reset


## Resets run-scoped progression and resources while intentionally preserving ownership.
func reset() -> bool:
	return reset_for_run()


## Permanently releases this scope. A disposed RunScope cannot be initialized again.
func dispose() -> void:
	if _disposed:
		return
	if progression != null and is_instance_valid(progression) and progression.has_method("dispose"):
		progression.call("dispose")
	if wallet != null and is_instance_valid(wallet) and wallet.has_method("dispose"):
		wallet.call("dispose")
	if loadout != null and is_instance_valid(loadout) and loadout.has_method("dispose"):
		loadout.call("dispose")
	loadout = null
	progression = null
	wallet = null
	health = null
	_stat_system = null
	_initialized = false
	_disposed = true


func is_initialized() -> bool:
	return _initialized and not _disposed


func _exit_tree() -> void:
	dispose()


func _capacity_for(item_type: Item.ItemType, fallback: int) -> int:
	var stat_id := ""
	match item_type:
		Item.ItemType.MARBLE:
			stat_id = STAT_MARBLE_SLOT_COUNT
		Item.ItemType.RELIC:
			stat_id = STAT_RELIC_SLOT_COUNT
		_:
			return fallback
	return maxi(0, int(_stat_value(stat_id, fallback)))


func _buy_multiplier() -> float:
	return maxf(0.0, float(_stat_value(STAT_BUY_PRICE_MULTIPLIER, 1.0)))


func _sell_multiplier() -> float:
	return maxf(0.0, float(_stat_value(STAT_SELL_PRICE_MULTIPLIER, 0.5)))


func _stat_value(stat_id: String, fallback: Variant) -> Variant:
	if _stat_system == null or not is_instance_valid(_stat_system) \
			or not _stat_system.has_method("get_stat"):
		return fallback
	return _stat_system.call("get_stat", stat_id, STAT_ENTITY_PLAYER)
