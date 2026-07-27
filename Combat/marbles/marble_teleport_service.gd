class_name MarbleTeleportService
extends RefCounted

signal portal_transfer_committed(chain: MarbleChain, pair_id: StringName, destination: Vector2)
signal portal_transfer_cancelled(chain: MarbleChain, pair_id: StringName)

@export_range(0.0, 2.0, 0.01) var lockout_seconds: float = 0.35
@export_range(0.0, 1000.0, 1.0) var minimum_speed: float = 140.0
@export_range(0.0, 1000.0, 1.0) var maximum_speed: float = 480.0
@export_range(0.0, 128.0, 1.0) var exit_offset: float = 24.0

var _lockouts: Dictionary[int, Dictionary] = {}
var _pending_transfers: Dictionary[int, Dictionary] = {}


func tick(delta: float) -> void:
	for chain_id: int in _pending_transfers.keys().duplicate():
		var request: Dictionary = _pending_transfers[chain_id]
		var head: Marble = request[&"head"] as Marble
		if head != null and is_instance_valid(head):
			continue
		_pending_transfers.erase(chain_id)
		var chain: MarbleChain = request[&"chain"] as MarbleChain
		if chain != null and is_instance_valid(chain):
			portal_transfer_cancelled.emit(chain, request[&"pair_id"] as StringName)
	for chain_id: int in _lockouts.keys().duplicate():
		var entries: Dictionary = _lockouts[chain_id]
		for pair_id: StringName in entries.keys().duplicate():
			var remaining: float = float(entries[pair_id]) - delta
			if remaining <= 0.0:
				entries.erase(pair_id)
			else:
				entries[pair_id] = remaining
		if entries.is_empty():
			_lockouts.erase(chain_id)


func is_locked(chain: MarbleChain, pair_id: StringName) -> bool:
	if chain == null or not is_instance_valid(chain):
		return false
	var chain_id := chain.get_instance_id()
	var pending: Dictionary = _pending_transfers.get(chain_id, {})
	return (not pending.is_empty() and pending[&"pair_id"] == pair_id) \
		or _lockouts.get(chain_id, {}).has(pair_id)


func exit_destination(exit_anchor: Vector2, exit_forward: Vector2) -> Vector2:
	return exit_anchor + exit_forward.normalized() * exit_offset


func transfer(chain: MarbleChain, entry_forward: Vector2, exit_anchor: Vector2, exit_forward: Vector2, pair_id: StringName) -> bool:
	if chain == null or chain.head == null or not is_instance_valid(chain.head) \
		or entry_forward.is_zero_approx() or exit_forward.is_zero_approx() or is_locked(chain, pair_id):
		return false
	var head: Marble = chain.head
	var speed := clampf(head.linear_velocity.length(), minimum_speed, maximum_speed)
	var angle_delta := entry_forward.angle_to(exit_forward)
	var velocity := head.linear_velocity.rotated(angle_delta)
	if velocity.is_zero_approx():
		velocity = exit_forward.normalized() * speed
	else:
		velocity = velocity.normalized() * speed
	var forward := exit_forward.normalized()
	var destination := exit_destination(exit_anchor, forward)
	var chain_id := chain.get_instance_id()
	var commit_callback := Callable(self, "_on_head_portal_teleport_applied").bind(chain_id)
	if not head.portal_teleport_applied.is_connected(commit_callback):
		head.portal_teleport_applied.connect(commit_callback, CONNECT_ONE_SHOT)
	if not head.queue_portal_teleport(destination, velocity):
		if head.portal_teleport_applied.is_connected(commit_callback):
			head.portal_teleport_applied.disconnect(commit_callback)
		return false
	_pending_transfers[chain_id] = {
		&"chain": chain,
		&"head": head,
		&"pair_id": pair_id,
		&"destination": destination,
		&"exit_forward": forward,
	}
	return true


func _on_head_portal_teleport_applied(destination: Vector2, _velocity: Vector2, chain_id: int) -> void:
	var request: Dictionary = _pending_transfers.get(chain_id, {})
	if request.is_empty():
		return
	_pending_transfers.erase(chain_id)
	var chain: MarbleChain = request[&"chain"] as MarbleChain
	if chain == null or not is_instance_valid(chain) or chain.head == null or not is_instance_valid(chain.head):
		return
	var pair_id: StringName = request[&"pair_id"] as StringName
	var exit_forward: Vector2 = request[&"exit_forward"] as Vector2
	chain.reset_after_teleport(destination, exit_forward)
	var entries: Dictionary = _lockouts.get(chain_id, {})
	entries[pair_id] = lockout_seconds
	_lockouts[chain_id] = entries
	portal_transfer_committed.emit(chain, pair_id, destination)
