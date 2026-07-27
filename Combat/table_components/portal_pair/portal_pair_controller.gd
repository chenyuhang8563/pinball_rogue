class_name PortalPairController
extends Node2D

signal component_activated(component_id: StringName, marble: Marble)

enum TransferResult {
	COMMIT_QUEUED,
	EXIT_UNSAFE,
	LOCKED,
	ALREADY_PENDING,
	INVALID,
}

@export var component_id: StringName = &""
@export_range(0.0, 1.0, 0.01) var pending_timeout_seconds: float = 0.2
@export_range(0.0, 128.0, 1.0) var head_collision_radius_for_validation: float = 8.0

var _registry: MarbleChainRegistry = null
var _teleport_service: MarbleTeleportService = null
var _endpoints: Array[PortalEndpoint] = []
var _enabled: bool = false
var _pending: Dictionary[int, Dictionary] = {}
var _exit_suppressed: Dictionary[int, PortalEndpoint] = {}
var _queued_commits: Dictionary[int, Dictionary] = {}
var validation_error: String = ""


func _ready() -> void:
	for child: Node in get_children():
		if child is PortalEndpoint:
			_endpoints.append(child as PortalEndpoint)
	_validate_pair()
	for endpoint: PortalEndpoint in _endpoints:
		var callback := Callable(self, "_on_transfer_requested").bind(endpoint)
		if not endpoint.portal_transfer_requested.is_connected(callback):
			endpoint.portal_transfer_requested.connect(callback)
		var exit_callback := Callable(self, "_on_portal_body_exited").bind(endpoint)
		if not endpoint.portal_body_exited.is_connected(exit_callback):
			endpoint.portal_body_exited.connect(exit_callback)


func _exit_tree() -> void:
	for endpoint: PortalEndpoint in _endpoints:
		var callback := Callable(self, "_on_transfer_requested").bind(endpoint)
		if endpoint.portal_transfer_requested.is_connected(callback):
			endpoint.portal_transfer_requested.disconnect(callback)
		var exit_callback := Callable(self, "_on_portal_body_exited").bind(endpoint)
		if endpoint.portal_body_exited.is_connected(exit_callback):
			endpoint.portal_body_exited.disconnect(exit_callback)
	_disconnect_teleport_service()
	_pending.clear()
	_exit_suppressed.clear()
	_queued_commits.clear()


func configure(registry: MarbleChainRegistry, teleport_service: MarbleTeleportService) -> bool:
	_disconnect_teleport_service()
	_registry = registry
	_teleport_service = teleport_service
	_connect_teleport_service()
	_enabled = _validate_pair() and _validate_exit_offset() and _registry != null and _teleport_service != null
	return _enabled


func is_enabled() -> bool:
	return _enabled


func configured_pair_id() -> StringName:
	return _endpoints[0].pair_id if _endpoints.size() == 2 and is_instance_valid(_endpoints[0]) else &""


func disable_with_validation_error(reason: String) -> void:
	_enabled = false
	validation_error = reason
	push_warning(reason)


func _physics_process(delta: float) -> void:
	if _teleport_service != null:
		_teleport_service.tick(delta)
	for marble_id: int in _pending.keys().duplicate():
		var request: Dictionary = _pending[marble_id]
		var head: Marble = request[&"head"] as Marble
		var entry: PortalEndpoint = request[&"entry"] as PortalEndpoint
		if head == null or not is_instance_valid(head) or entry == null or not entry.is_overlapping_head(head):
			_pending.erase(marble_id)
			continue
		request[&"remaining"] = float(request[&"remaining"]) - delta
		var result := _try_transfer(entry, head, true)
		match result:
			TransferResult.COMMIT_QUEUED, TransferResult.LOCKED, TransferResult.ALREADY_PENDING, TransferResult.INVALID:
				_pending.erase(marble_id)
			TransferResult.EXIT_UNSAFE:
				if float(request[&"remaining"]) <= 0.0:
					_pending.erase(marble_id)
				else:
					_pending[marble_id] = request


func _on_transfer_requested(_pair_id: StringName, marble: Marble, entry: PortalEndpoint) -> void:
	if not _enabled or marble == null or not is_instance_valid(marble):
		return
	var marble_id := marble.get_instance_id()
	match _try_transfer(entry, marble):
		TransferResult.COMMIT_QUEUED:
			_pending.erase(marble_id)
		TransferResult.EXIT_UNSAFE:
			if not _pending.has(marble_id):
				_pending[marble_id] = {
					&"head": marble,
					&"entry": entry,
					&"remaining": pending_timeout_seconds,
				}
		TransferResult.LOCKED, TransferResult.ALREADY_PENDING, TransferResult.INVALID:
			_pending.erase(marble_id)


func _on_portal_body_exited(_pair_id: StringName, marble: Marble, endpoint: PortalEndpoint) -> void:
	if marble == null or endpoint == null:
		return
	var marble_id := marble.get_instance_id()
	if _exit_suppressed.get(marble_id) == endpoint:
		_exit_suppressed.erase(marble_id)


func _on_portal_transfer_committed(chain: MarbleChain, pair_id: StringName, _destination: Vector2) -> void:
	if chain == null or not is_instance_valid(chain) or chain.head == null or not is_instance_valid(chain.head):
		return
	var head: Marble = chain.head
	var marble_id := head.get_instance_id()
	var queued: Dictionary = _queued_commits.get(marble_id, {})
	if queued.is_empty():
		return
	_queued_commits.erase(marble_id)
	if queued[&"chain"] != chain or queued[&"pair_id"] != pair_id:
		return
	var exit: PortalEndpoint = queued[&"exit"] as PortalEndpoint
	if exit == null or not is_instance_valid(exit):
		return
	_exit_suppressed[marble_id] = exit
	call_deferred("_emit_component_activated_after_commit", head)


func _on_portal_transfer_cancelled(chain: MarbleChain, pair_id: StringName) -> void:
	for marble_id: int in _queued_commits.keys().duplicate():
		var queued: Dictionary = _queued_commits[marble_id]
		if queued[&"chain"] == chain and queued[&"pair_id"] == pair_id:
			_queued_commits.erase(marble_id)


func _emit_component_activated_after_commit(head: Marble) -> void:
	if head != null and is_instance_valid(head):
		component_activated.emit(component_id, head)


func _try_transfer(entry: PortalEndpoint, head: Marble, retrying_pending: bool = false) -> TransferResult:
	if entry == null or head == null or _registry == null or _teleport_service == null:
		return TransferResult.INVALID
	var marble_id := head.get_instance_id()
	var chain := _registry.find_chain_for_head(head)
	if chain == null:
		return TransferResult.INVALID
	if _exit_suppressed.has(marble_id) or _teleport_service.is_locked(chain, entry.pair_id):
		return TransferResult.LOCKED
	if not retrying_pending and _pending.has(marble_id):
		return TransferResult.ALREADY_PENDING
	var exit := _other_endpoint(entry)
	if exit == null:
		return TransferResult.INVALID
	var destination := _teleport_service.exit_destination(exit.anchor_position(), exit.forward())
	if not exit.is_exit_safe(head, destination):
		return TransferResult.EXIT_UNSAFE
	if not _teleport_service.transfer(chain, entry.forward(), exit.anchor_position(), exit.forward(), entry.pair_id):
		return TransferResult.INVALID
	_queued_commits[marble_id] = {
		&"chain": chain,
		&"pair_id": entry.pair_id,
		&"exit": exit,
	}
	return TransferResult.COMMIT_QUEUED


func _other_endpoint(entry: PortalEndpoint) -> PortalEndpoint:
	for endpoint: PortalEndpoint in _endpoints:
		if endpoint != entry:
			return endpoint
	return null


func _validate_pair() -> bool:
	if _endpoints.size() != 2:
		validation_error = "PortalPairController requires exactly two PortalEndpoint children"
		push_warning(validation_error)
		return false
	var first_id: StringName = _endpoints[0].pair_id
	var second_id: StringName = _endpoints[1].pair_id
	if first_id == &"" or first_id != second_id:
		validation_error = "PortalPairController endpoints must share one non-empty pair_id"
		push_warning(validation_error)
		return false
	validation_error = ""
	return true


func _validate_exit_offset() -> bool:
	if _teleport_service == null:
		return false
	var minimum_offset := 0.0
	for endpoint: PortalEndpoint in _endpoints:
		minimum_offset = maxf(minimum_offset, endpoint.minimum_exit_offset(head_collision_radius_for_validation))
	if _teleport_service.exit_offset <= minimum_offset:
		validation_error = "Portal exit_offset %.1f must exceed %.1f to clear exit trigger geometry" % [
			_teleport_service.exit_offset,
			minimum_offset,
		]
		push_warning(validation_error)
		return false
	return true


func _connect_teleport_service() -> void:
	if _teleport_service == null:
		return
	if not _teleport_service.portal_transfer_committed.is_connected(_on_portal_transfer_committed):
		_teleport_service.portal_transfer_committed.connect(_on_portal_transfer_committed)
	if not _teleport_service.portal_transfer_cancelled.is_connected(_on_portal_transfer_cancelled):
		_teleport_service.portal_transfer_cancelled.connect(_on_portal_transfer_cancelled)


func _disconnect_teleport_service() -> void:
	if _teleport_service == null:
		return
	if _teleport_service.portal_transfer_committed.is_connected(_on_portal_transfer_committed):
		_teleport_service.portal_transfer_committed.disconnect(_on_portal_transfer_committed)
	if _teleport_service.portal_transfer_cancelled.is_connected(_on_portal_transfer_cancelled):
		_teleport_service.portal_transfer_cancelled.disconnect(_on_portal_transfer_cancelled)
