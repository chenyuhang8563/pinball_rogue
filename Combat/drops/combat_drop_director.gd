class_name CombatDropDirector
extends Node

signal loot_settled

const CoinPickupScene: PackedScene = preload("res://Combat/drops/coin_pickup.tscn")

@export_range(0, 100, 1) var enemy_drop_chance: int = 35
@export_range(1, 12, 1) var max_active_coins: int = 12
@export_range(0.0, 10.0, 0.1) var final_pickup_grace_seconds: float = 3.0

@onready var grace_timer: Timer = get_node_or_null("GraceTimer") as Timer

var _session: BattleSession = null
var _wallet: RefCounted = null
var _random_source: RefCounted = null
var _combat_drops: Node2D = null
var _kill_zone: Node = null
var _anchors: Array[Marker2D] = []
var _gate: LootSettlementGate = LootSettlementGate.new()
var _active_coins: Dictionary[int, CoinPickup] = {}
var _enemy_defeated_callback: Callable = Callable()
var _final_enemy_defeated: bool = false


func _ready() -> void:
	if grace_timer != null and not grace_timer.timeout.is_connected(_on_grace_timeout):
		grace_timer.timeout.connect(_on_grace_timeout)


func _exit_tree() -> void:
	unconfigure()
	if grace_timer != null and grace_timer.timeout.is_connected(_on_grace_timeout):
		grace_timer.timeout.disconnect(_on_grace_timeout)


func configure(
	session: BattleSession,
	combat_drops: Node2D,
	wallet: RefCounted,
	random_source: RefCounted,
	anchors: Array[Marker2D]
) -> bool:
	unconfigure()
	if session == null or combat_drops == null or wallet == null or random_source == null:
		return false
	if not wallet.has_method(&"credit") or not random_source.has_method(&"range_int"):
		return false
	_session = session
	_combat_drops = combat_drops
	_wallet = wallet
	_random_source = random_source
	_anchors = anchors.filter(func(anchor: Marker2D) -> bool: return is_instance_valid(anchor))
	_gate.reset(true)
	_final_enemy_defeated = false
	_enemy_defeated_callback = Callable(self, "_on_enemy_defeated")
	if not _session.enemy_defeated.is_connected(_enemy_defeated_callback):
		_session.enemy_defeated.connect(_enemy_defeated_callback)
	if not _gate.settled.is_connected(_on_gate_settled):
		_gate.settled.connect(_on_gate_settled)
	_connect_placed_barrels()
	return true


func unconfigure() -> void:
	if _session != null and is_instance_valid(_session) and _enemy_defeated_callback.is_valid() \
			and _session.enemy_defeated.is_connected(_enemy_defeated_callback):
		_session.enemy_defeated.disconnect(_enemy_defeated_callback)
	if _gate.settled.is_connected(_on_gate_settled):
		_gate.settled.disconnect(_on_gate_settled)
	if grace_timer != null:
		grace_timer.stop()
	for coin: CoinPickup in _active_coins.values():
		if is_instance_valid(coin):
			coin.expire(&"scene_cleanup")
	_active_coins.clear()
	_gate.reset(true)
	_session = null
	_wallet = null
	_random_source = null
	_combat_drops = null
	_kill_zone = null
	_anchors.clear()
	_enemy_defeated_callback = Callable()
	_final_enemy_defeated = false


func settlement_gate() -> LootSettlementGate:
	return _gate


func configure_kill_zone(kill_zone: Node) -> void:
	_kill_zone = kill_zone


func _physics_process(_delta: float) -> void:
	if _kill_zone == null or not is_instance_valid(_kill_zone) \
			or not _kill_zone.has_method(&"contains_global_point"):
		return
	for coin: CoinPickup in _active_coins.values().duplicate():
		if is_instance_valid(coin) and bool(_kill_zone.call(&"contains_global_point", coin.global_position)):
			coin.expire(&"kill_zone")


func spawn_from_source(source: Node, origin: Vector2, count: int) -> void:
	for index: int in range(maxi(0, count)):
		_spawn_or_merge_coin(source, origin)


func _on_enemy_defeated(_token: RunFlowToken, enemy: Enemy, _cause: StringName) -> void:
	if _session == null or enemy == null:
		return
	if _roll_enemy_drop():
		spawn_from_source(enemy, enemy.global_position, 1)
	_final_enemy_defeated = _session.live_enemy_count() == 0
	if _final_enemy_defeated:
		_begin_final_pickup_grace()



## 桶每次被 Head 碰撞掉一枚金币：飞行起点为 DropAnchor，落点由预置锚点池选择
## （锚点池为空时退回 DropAnchor）——避免金币落进桶自身的实体碰撞体内而不可拾取。
func _on_barrel_hit(barrel: Node, drop_anchor: Marker2D) -> void:
	if drop_anchor == null or not is_instance_valid(drop_anchor):
		return
	var origin := drop_anchor.global_position
	_spawn_or_merge_coin_at(barrel, origin, _choose_anchor(origin))


func _spawn_or_merge_coin(source: Node, origin: Vector2) -> void:
	_spawn_or_merge_coin_at(source, origin, _choose_anchor(origin))


func _spawn_or_merge_coin_at(source: Node, origin: Vector2, landing_position: Vector2) -> void:
	if _combat_drops == null or not is_instance_valid(_combat_drops):
		return
	if not landing_position.is_finite() or not _is_safe_landing_position(landing_position):
		return
	if _active_coins.size() >= max_active_coins:
		var merge_target := _nearest_available_coin(origin)
		if merge_target != null:
			merge_target.add_amount(1)
		return
	var coin: CoinPickup = CoinPickupScene.instantiate() as CoinPickup
	if coin == null:
		return
	coin.coin_collected.connect(_on_coin_collected)
	coin.coin_expired.connect(_on_coin_expired)
	_active_coins[coin.get_instance_id()] = coin
	_gate.open_pending()
	coin.begin_spawn(source, origin, landing_position)
	# 本函数可能在桶/敌人碰撞回调中执行（物理查询 flush 期间）；此时立即 add_child
	# 会把 Area2D 形状注册进物理空间，触发 "Can't change this state while flushing queries"，
	# 因此延迟到 flush 结束后再入树。begin_spawn 在树外执行是安全的（不触碰物理服务器）。
	_add_coin_to_tree.call_deferred(coin)


func _add_coin_to_tree(coin: CoinPickup) -> void:
	if coin == null or not is_instance_valid(coin) or coin.is_queued_for_deletion():
		return
	if _combat_drops == null or not is_instance_valid(_combat_drops) or not _combat_drops.is_inside_tree():
		return
	_combat_drops.add_child(coin)


func _on_coin_collected(coin: CoinPickup, amount: int, _source: Node) -> void:
	if _wallet != null and _wallet.has_method(&"credit"):
		_wallet.call(&"credit", amount)
	_resolve_coin(coin)


func _on_coin_expired(coin: CoinPickup, _reason: StringName) -> void:
	_resolve_coin(coin)


func _resolve_coin(coin: CoinPickup) -> void:
	if coin == null:
		return
	var instance_id := coin.get_instance_id()
	if not _active_coins.has(instance_id):
		return
	_active_coins.erase(instance_id)
	_gate.resolve_pending()
	if _final_enemy_defeated and _active_coins.is_empty():
		_finish_loot_settlement()


func _begin_final_pickup_grace() -> void:
	if _active_coins.is_empty():
		_finish_loot_settlement()
		return
	if grace_timer != null:
		grace_timer.start(final_pickup_grace_seconds)


func _on_grace_timeout() -> void:
	for coin: CoinPickup in _active_coins.values().duplicate():
		if is_instance_valid(coin):
			coin.expire(&"grace_timeout")
	_finish_loot_settlement()


func _finish_loot_settlement() -> void:
	if grace_timer != null:
		grace_timer.stop()
	if not _gate.is_settled():
		_gate.force_settled()
	else:
		loot_settled.emit()


func _on_gate_settled() -> void:
	loot_settled.emit()


func _roll_enemy_drop() -> bool:
	return int(_random_source.call(&"range_int", 1, 100)) <= enemy_drop_chance


func _choose_anchor(origin: Vector2) -> Vector2:
	var safe_anchors: Array[Marker2D] = []
	for anchor: Marker2D in _anchors:
		if is_instance_valid(anchor) and _is_safe_landing_position(anchor.global_position):
			safe_anchors.append(anchor)
	if safe_anchors.is_empty():
		return origin if _is_safe_landing_position(origin) else Vector2.INF
	var index: int = int(_random_source.call(&"range_int", 0, safe_anchors.size() - 1))
	return safe_anchors[clampi(index, 0, safe_anchors.size() - 1)].global_position


func _is_safe_landing_position(position: Vector2) -> bool:
	return _kill_zone == null or not is_instance_valid(_kill_zone) \
		or not _kill_zone.has_method(&"contains_global_point") \
		or not bool(_kill_zone.call(&"contains_global_point", position))


func _nearest_available_coin(origin: Vector2) -> CoinPickup:
	var nearest: CoinPickup = null
	var nearest_fallback: CoinPickup = null
	var nearest_distance := INF
	var fallback_distance := INF
	for coin: CoinPickup in _active_coins.values():
		if not is_instance_valid(coin):
			continue
		var distance := coin.global_position.distance_squared_to(origin)
		if coin.is_available() and distance < nearest_distance:
			nearest = coin
			nearest_distance = distance
		elif distance < fallback_distance:
			nearest_fallback = coin
			fallback_distance = distance
	return nearest if nearest != null else nearest_fallback


func _connect_placed_barrels() -> void:
	if get_tree() == null:
		return
	for component: Node in get_tree().get_nodes_in_group(&"table_component"):
		if component.has_signal(&"barrel_hit") and not component.barrel_hit.is_connected(_on_barrel_hit):
			component.barrel_hit.connect(_on_barrel_hit)
