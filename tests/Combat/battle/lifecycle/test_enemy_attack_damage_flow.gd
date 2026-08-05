extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


class FakeAttackWarning extends Node:
	signal player_damage_requested(amount: int)

	var configured_profile: Resource = null
	var accepts_profile: bool = true

	func configure(profile: Resource) -> bool:
		configured_profile = profile
		return accepts_profile

	func interrupt() -> void:
		pass


class TypedKillZone extends Node:
	signal marble_fell(marble: Variant)


var _container: Node2D
var _spawner: BattleSpawner
var _session: BattleSession
var _kill_zone: TypedKillZone
var _warning: FakeAttackWarning
var _profile: Resource


func before_each() -> void:
	_container = Node2D.new()
	add_child_autofree(_container)
	_spawner = BattleSpawner.new()
	_spawner.enemy_container = _container
	add_child_autofree(_spawner)
	_session = BattleSession.new()
	add_child_autofree(_session)
	assert_true(_session.configure(_spawner))
	_kill_zone = TypedKillZone.new()
	add_child_autofree(_kill_zone)
	_profile = Resource.new()


func after_each() -> void:
	if is_instance_valid(_session):
		_session.dispose()
	if is_instance_valid(_spawner):
		_spawner.dispose()


func test_warning_damage_becomes_one_session_fact_for_the_active_enemy() -> void:
	_session.enemy_registered.connect(func(_token: RunFlowToken, enemy: Enemy) -> void:
		_warning = FakeAttackWarning.new()
		_warning.name = "AttackWarning"
		enemy.add_child(_warning)
		assert_true(enemy.has_method(&"configure_attack"))
		if enemy.has_method(&"configure_attack"):
			assert_true(bool(enemy.call(&"configure_attack", _profile)))
	)
	watch_signals(_session)
	var token := RunFlowToken.new(31, 4, 1)

	assert_true(_session.start(_plan(), token, _kill_zone))
	assert_true(_session.has_signal(&"enemy_attack_hit"))
	assert_not_null(_warning)
	if not _session.has_signal(&"enemy_attack_hit") or _warning == null:
		return
	var enemy: Enemy = _container.get_child(0) as Enemy
	_warning.player_damage_requested.emit(3)

	assert_signal_emitted_with_parameters(
		_session, "enemy_attack_hit", [token, enemy, 3]
	)


func test_enemy_attack_connections_disconnect_when_session_and_enemy_clear() -> void:
	_session.enemy_registered.connect(func(_token: RunFlowToken, enemy: Enemy) -> void:
		_warning = FakeAttackWarning.new()
		_warning.name = "AttackWarning"
		enemy.add_child(_warning)
		assert_true(enemy.configure_attack(_profile))
	)
	var token := RunFlowToken.new(32, 4, 1)
	assert_true(_session.start(_plan(), token, _kill_zone))
	var enemy: Enemy = _container.get_child(0) as Enemy
	var session_callback: Callable = _session._enemy_attack_callbacks[enemy.get_instance_id()]
	var warning_callback: Callable = enemy._attack_warning_damage_callback
	assert_true(_warning.is_connected(&"player_damage_requested", warning_callback))
	assert_true(enemy.player_damage_requested.is_connected(session_callback))

	_session.clear()

	assert_false(enemy.player_damage_requested.is_connected(session_callback))
	enemy.call("_disconnect_attack_warning")
	assert_false(_warning.is_connected(&"player_damage_requested", warning_callback))


func test_stale_invalid_and_terminal_enemy_attack_callbacks_are_rejected() -> void:
	var token := RunFlowToken.new(33, 4, 1)
	assert_true(_session.start(_plan(), token, _kill_zone))
	var enemy: Enemy = _container.get_child(0) as Enemy
	var batch_id := _session.active_batch_id()
	watch_signals(_session)

	_session.call("_on_enemy_attack_hit", enemy, 2, RunFlowToken.new(33, 4, 2), batch_id)
	_session.call("_on_enemy_attack_hit", null, 2, token, batch_id)
	_session.call("_on_enemy_attack_hit", enemy, 0, token, batch_id)
	assert_signal_not_emitted(_session, "enemy_attack_hit")
	assert_signal_emit_count(_session, "callback_rejected", 3)

	assert_true(_session.force_complete())
	_session.call("_on_enemy_attack_hit", enemy, 2, token, batch_id)
	assert_signal_emit_count(_session, "callback_rejected", 4)
	assert_signal_not_emitted(_session, "enemy_attack_hit")


func _plan() -> BattlePlan:
	var group := BattleGroupDef.new()
	group.id = "enemy_attack_damage"
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = EnemyScene
	entry.position = Vector2(20, 30)
	entry.health = 20
	group.enemy_entries.append(entry)
	return BattlePlan.new(
		&"enemy_attack_damage",
		group,
		BattlePlan.Origin.NODE,
		BattlePlan.RewardPolicy.NORMAL
	)
