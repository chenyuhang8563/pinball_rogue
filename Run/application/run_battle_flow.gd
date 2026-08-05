extends RefCounted
class_name RunBattleFlow

## Owns only BattleGateway session identity. RunState and reward routing remain
## controller concerns.
signal completed(token: RunFlowToken, battle_id: StringName, plan: BattlePlan)
signal enemy_attack_hit(token: RunFlowToken, enemy: Enemy, amount: int)
signal marble_fell(token: RunFlowToken, marble: RigidBody2D)
signal callback_rejected(command: StringName, reason: String)

var _gateway: BattleGateway = null
var _active_token: RunFlowToken = null
var _active_plan: BattlePlan = null


func configure(gateway: BattleGateway) -> bool:
	dispose()
	if gateway == null or not is_instance_valid(gateway):
		return false
	_gateway = gateway
	_gateway.battle_completed.connect(_on_gateway_completed)
	_gateway.enemy_attack_hit.connect(_on_gateway_enemy_attack_hit)
	_gateway.marble_fell.connect(_on_gateway_marble_fell)
	return true


func start(plan: BattlePlan, token: RunFlowToken) -> bool:
	if _gateway == null or plan == null or not plan.is_valid() \
			or token == null or not token.is_valid() or _active_plan != null:
		return false
	_active_plan = plan
	_active_token = token
	# This call may synchronously emit completed. The callback intentionally has
	# no public-command guard; it validates the committed session identity here.
	if _gateway.start(plan, token):
		return true
	_gateway.clear()
	_active_plan = null
	_active_token = null
	return false


func clear() -> void:
	_active_plan = null
	_active_token = null
	if _gateway != null and is_instance_valid(_gateway):
		_gateway.clear()


func active_plan() -> BattlePlan:
	return _active_plan


func active_token() -> RunFlowToken:
	return _active_token


func force_complete_current_battle() -> bool:
	if _gateway == null or not is_instance_valid(_gateway) or _active_plan == null or _active_token == null:
		return false
	return _gateway.force_complete_current_battle()


func dispose() -> void:
	if _gateway != null and is_instance_valid(_gateway):
		if _gateway.battle_completed.is_connected(_on_gateway_completed):
			_gateway.battle_completed.disconnect(_on_gateway_completed)
		if _gateway.enemy_attack_hit.is_connected(_on_gateway_enemy_attack_hit):
			_gateway.enemy_attack_hit.disconnect(_on_gateway_enemy_attack_hit)
		if _gateway.marble_fell.is_connected(_on_gateway_marble_fell):
			_gateway.marble_fell.disconnect(_on_gateway_marble_fell)
	_gateway = null
	_active_plan = null
	_active_token = null


func _on_gateway_completed(
	token: RunFlowToken,
	battle_id: StringName,
	plan: BattlePlan
) -> void:
	if token == null or _active_token == null or not _active_token.matches(token):
		callback_rejected.emit(&"battle_complete", "battle completion token is stale")
		return
	if plan == null or plan != _active_plan or battle_id != _active_plan.battle_id:
		callback_rejected.emit(&"battle_complete", "battle completion identity changed")
		return
	var committed_token := _active_token
	var committed_plan := _active_plan
	_active_token = null
	_active_plan = null
	completed.emit(committed_token, committed_plan.battle_id, committed_plan)


func _on_gateway_marble_fell(token: RunFlowToken, marble: RigidBody2D) -> void:
	if token == null or _active_token == null or not _active_token.matches(token):
		callback_rejected.emit(&"marble_fall", "marble fall token is stale")
		return
	marble_fell.emit(token, marble)


func _on_gateway_enemy_attack_hit(
	token: RunFlowToken,
	enemy: Enemy,
	amount: int
) -> void:
	if token == null or _active_token == null or not _active_token.matches(token):
		callback_rejected.emit(&"enemy_attack_hit", "enemy attack token is stale")
		return
	if _active_plan == null or enemy == null or not is_instance_valid(enemy):
		callback_rejected.emit(&"enemy_attack_hit", "enemy attack identity is invalid")
		return
	if amount <= 0:
		callback_rejected.emit(&"enemy_attack_hit", "enemy attack damage is invalid")
		return
	enemy_attack_hit.emit(token, enemy, amount)
