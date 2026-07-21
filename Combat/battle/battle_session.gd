class_name BattleSession
extends Node

signal started(token: RunFlowToken, plan: BattlePlan)
signal enemy_registered(token: RunFlowToken, enemy: Enemy)
signal enemy_defeated(token: RunFlowToken, enemy: Enemy, cause: StringName)
signal marble_fell(token: RunFlowToken, marble: RigidBody2D)
signal completed(token: RunFlowToken, battle_id: StringName, plan: BattlePlan)
signal callback_rejected(kind: StringName, reason: String)

enum BatchState {
	IDLE,
	OPEN,
	SEALED,
	FAILED,
	CLOSED,
}

var _spawner: BattleSpawner = null
var _active_token: RunFlowToken = null
var _active_plan: BattlePlan = null
var _kill_zone: Node = null
var _batch_id: int = 0
var _next_batch_id: int = 1
var _batch_state: BatchState = BatchState.IDLE
var _registered_enemies: Dictionary[int, Enemy] = {}
var _registered_enemy_count: int = 0
var _live_enemies: Dictionary[int, Enemy] = {}
var _enemy_callbacks: Dictionary[int, Callable] = {}
var _accepted_marble_instance_ids: Dictionary[int, bool] = {}
var _spawner_connected: bool = false
var _kill_zone_callback: Callable = Callable()
var _disposed: bool = false
var _start_call_in_progress: bool = false


func configure(spawner: BattleSpawner) -> bool:
	if _disposed or spawner == null or not is_instance_valid(spawner):
		return false
	clear()
	_spawner = spawner
	return true


func start(plan: BattlePlan, token: RunFlowToken, kill_zone: Node) -> bool:
	if _disposed:
		_reject(&"start", "session is disposed")
		return false
	if _active_plan != null:
		_reject(&"start", "a battle session is already active")
		return false
	if _start_call_in_progress:
		_reject(&"start", "a start call is already in progress")
		return false
	if _spawner == null or not is_instance_valid(_spawner):
		_reject(&"start", "spawner is not configured")
		return false
	if plan == null or not plan.is_valid():
		_reject(&"start", "plan is invalid")
		return false
	if token == null or not token.is_valid():
		_reject(&"start", "token is invalid")
		return false
	if kill_zone == null or not is_instance_valid(kill_zone):
		_reject(&"start", "kill zone is invalid")
		return false

	_start_call_in_progress = true
	_active_plan = plan
	_active_token = token
	_kill_zone = kill_zone
	_batch_id = _next_batch_id
	_next_batch_id += 1
	_batch_state = BatchState.OPEN
	_clear_enemy_tracking()
	_accepted_marble_instance_ids.clear()
	_connect_spawner()
	_connect_kill_zone(token, _batch_id)
	started.emit(token, plan)

	var register_enemy: Callable = Callable(self, "_register_enemy").bind(token)
	var sealed: bool = _spawner.start_batch(plan.group, _batch_id, register_enemy)
	if sealed and _batch_state != BatchState.FAILED:
		if _batch_state == BatchState.SEALED and _live_enemies.is_empty():
			_try_complete()
		# A legal zero-entry batch may synchronously close from the sealed signal.
		# Disconnect only after start_batch() has returned from signal dispatch.
		if _batch_state == BatchState.CLOSED:
			_disconnect_session_sources()
		_start_call_in_progress = false
		return true
	if _batch_state != BatchState.FAILED:
		_batch_state = BatchState.FAILED
		_clear_enemy_tracking()
	_disconnect_session_sources()
	if _spawner != null and is_instance_valid(_spawner):
		_spawner.clear_enemies()
	_reset_active_identity(false)
	_start_call_in_progress = false
	return false


func clear(_restart: bool = false) -> void:
	_clear_enemy_tracking()
	_disconnect_session_sources()
	_accepted_marble_instance_ids.clear()
	_reset_active_identity(true)


func dispose() -> void:
	if _disposed:
		return
	clear()
	_spawner = null
	_disposed = true


func live_enemy_count() -> int:
	return _live_enemies.size()


func registered_enemy_count() -> int:
	return _registered_enemy_count


func accepted_marble_count() -> int:
	return _accepted_marble_instance_ids.size()


func active_batch_id() -> int:
	return _batch_id


func active_token() -> RunFlowToken:
	return _active_token


func active_plan() -> BattlePlan:
	return _active_plan


func force_complete() -> bool:
	if _disposed or _active_plan == null or _active_token == null \
			or _batch_state != BatchState.OPEN and _batch_state != BatchState.SEALED:
		return false
	_batch_state = BatchState.SEALED
	_clear_enemy_tracking()
	var did_complete := _try_complete()
	if did_complete:
		_disconnect_session_sources()
	return did_complete


func _register_enemy(
	batch_id: int,
	entry_index: int,
	enemy: Enemy,
	token: RunFlowToken
) -> bool:
	if _disposed or _batch_state != BatchState.OPEN:
		_reject(&"enemy_register", "batch is not open")
		return false
	if batch_id != _batch_id or token != _active_token:
		_reject(&"enemy_register", "batch identity is stale")
		return false
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		_reject(&"enemy_register", "enemy is invalid")
		return false
	var instance_id: int = enemy.get_instance_id()
	if _registered_enemies.has(instance_id):
		_reject(&"enemy_register", "enemy instance is already registered")
		return false
	var callback: Callable = Callable(self, "_on_enemy_defeated").bind(
		token, batch_id, entry_index
	)
	if not enemy.defeated.is_connected(callback):
		enemy.defeated.connect(callback)
	_enemy_callbacks[instance_id] = callback
	_registered_enemies[instance_id] = enemy
	_registered_enemy_count += 1
	_live_enemies[instance_id] = enemy
	enemy_registered.emit(token, enemy)
	return true


func _on_enemy_defeated(
	enemy: Enemy,
	cause: StringName,
	token: RunFlowToken,
	batch_id: int,
	_entry_index: int
) -> void:
	if _disposed or token != _active_token or batch_id != _batch_id:
		_reject(&"enemy_defeated", "enemy callback is stale")
		return
	if _batch_state != BatchState.OPEN and _batch_state != BatchState.SEALED:
		_reject(&"enemy_defeated", "batch is terminal")
		return
	if enemy == null or not is_instance_valid(enemy):
		_reject(&"enemy_defeated", "enemy is invalid")
		return
	var instance_id: int = enemy.get_instance_id()
	if not _live_enemies.has(instance_id) or _live_enemies[instance_id] != enemy:
		_reject(&"enemy_defeated", "enemy is not live in this batch")
		return
	_disconnect_enemy(enemy)
	_live_enemies.erase(instance_id)
	enemy_defeated.emit(token, enemy, cause)
	if _try_complete():
		_disconnect_session_sources()


func _on_spawn_batch_sealed(batch_id: int, enemy_count: int) -> void:
	if _disposed or _batch_state != BatchState.OPEN or batch_id != _batch_id:
		_reject(&"batch_sealed", "sealed callback is stale or duplicate")
		return
	if enemy_count != _registered_enemy_count:
		_reject(&"batch_sealed", "sealed enemy count does not match registered count")
		_batch_state = BatchState.FAILED
		_clear_enemy_tracking()
		return
	_batch_state = BatchState.SEALED


func _on_spawn_batch_failed(
	batch_id: int,
	_entry_index: int,
	_reason: StringName
) -> void:
	if _disposed or _batch_state != BatchState.OPEN or batch_id != _batch_id:
		_reject(&"batch_failed", "failed callback is stale or duplicate")
		return
	_batch_state = BatchState.FAILED
	_clear_enemy_tracking()


func _on_raw_marble_fell(
	marble_value: Variant,
	token: RunFlowToken,
	batch_id: int
) -> void:
	if _disposed or token != _active_token or batch_id != _batch_id:
		_reject(&"marble_fell", "marble callback is stale")
		return
	if _batch_state != BatchState.OPEN and _batch_state != BatchState.SEALED:
		_reject(&"marble_fell", "batch is terminal")
		return
	if not marble_value is RigidBody2D:
		_reject(&"marble_fell", "body is not a rigid body")
		return
	var marble: RigidBody2D = marble_value as RigidBody2D
	if not is_instance_valid(marble) or not marble.is_in_group("marbles"):
		_reject(&"marble_fell", "body is not a marble")
		return
	var instance_id: int = marble.get_instance_id()
	if _accepted_marble_instance_ids.has(instance_id):
		_reject(&"marble_fell", "marble was already accepted")
		return
	_accepted_marble_instance_ids[instance_id] = true
	marble_fell.emit(token, marble)


func _try_complete() -> bool:
	if _batch_state != BatchState.SEALED or not _live_enemies.is_empty():
		return false
	var token: RunFlowToken = _active_token
	var plan: BattlePlan = _active_plan
	_batch_state = BatchState.CLOSED
	_accepted_marble_instance_ids.clear()
	_clear_enemy_tracking()
	_reset_active_identity(false)
	completed.emit(token, plan.battle_id, plan)
	return true


func _connect_spawner() -> void:
	if _spawner_connected:
		return
	_spawner.spawn_batch_sealed.connect(_on_spawn_batch_sealed)
	_spawner.spawn_batch_failed.connect(_on_spawn_batch_failed)
	_spawner_connected = true


func _connect_kill_zone(token: RunFlowToken, batch_id: int) -> void:
	if _kill_zone == null or not _kill_zone.has_signal(&"marble_fell"):
		return
	_kill_zone_callback = Callable(self, "_on_raw_marble_fell").bind(token, batch_id)
	if not _kill_zone.is_connected(&"marble_fell", _kill_zone_callback):
		_kill_zone.connect(&"marble_fell", _kill_zone_callback)


func _disconnect_session_sources() -> void:
	if _spawner_connected and _spawner != null and is_instance_valid(_spawner):
		if _spawner.spawn_batch_sealed.is_connected(_on_spawn_batch_sealed):
			_spawner.spawn_batch_sealed.disconnect(_on_spawn_batch_sealed)
		if _spawner.spawn_batch_failed.is_connected(_on_spawn_batch_failed):
			_spawner.spawn_batch_failed.disconnect(_on_spawn_batch_failed)
	_spawner_connected = false
	if _kill_zone != null and is_instance_valid(_kill_zone) \
			and _kill_zone_callback.is_valid() \
			and _kill_zone.has_signal(&"marble_fell") \
			and _kill_zone.is_connected(&"marble_fell", _kill_zone_callback):
		_kill_zone.disconnect(&"marble_fell", _kill_zone_callback)
	_kill_zone_callback = Callable()
	_kill_zone = null


func _disconnect_live_enemies() -> void:
	for enemy: Enemy in _live_enemies.values():
		_disconnect_enemy(enemy)


func _clear_enemy_tracking() -> void:
	_disconnect_live_enemies()
	_live_enemies.clear()
	_enemy_callbacks.clear()
	_registered_enemies.clear()
	_registered_enemy_count = 0


func _disconnect_enemy(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var instance_id: int = enemy.get_instance_id()
	var callback: Callable = _enemy_callbacks.get(instance_id, Callable())
	if callback.is_valid() and enemy.defeated.is_connected(callback):
		enemy.defeated.disconnect(callback)
	_enemy_callbacks.erase(instance_id)


func _reset_active_identity(reset_state: bool) -> void:
	_active_token = null
	_active_plan = null
	_batch_id = 0
	if reset_state:
		_batch_state = BatchState.IDLE


func _reject(kind: StringName, reason: String) -> void:
	callback_rejected.emit(kind, reason)
