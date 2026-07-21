extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")

class TypedKillZone:
	extends Node
	signal marble_fell(marble: Variant)


class TreeEntryDefeatObserver:
	extends RefCounted

	var entered_enemy: Enemy = null

	func defeat_entered_enemy(child: Node) -> void:
		if entered_enemy != null or not child is Enemy:
			return
		entered_enemy = child as Enemy
		entered_enemy.defeat(&"entered_tree")


class SealedCountTamper:
	extends RefCounted

	var spawner: BattleSpawner
	var session: BattleSession
	var live_count_when_sealed: int = -1

	func report_wrong_sealed_count(child: Node) -> void:
		if not child is Enemy:
			return
		var enemy: Enemy = child as Enemy
		enemy.defeat(&"before_seal")
		live_count_when_sealed = session.live_enemy_count()
		spawner.spawn_batch_sealed.emit(session.active_batch_id(), 0)


var _container: Node2D
var _spawner: BattleSpawner
var _session: BattleSession
var _kill_zone: TypedKillZone
var _registration_count: int
var _spawn_count: int


func before_each() -> void:
	_registration_count = 0
	_spawn_count = 0
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


func after_each() -> void:
	if is_instance_valid(_session):
		_session.dispose()
	if is_instance_valid(_spawner):
		_spawner.dispose()


func test_zero_entry_seals_then_completes_synchronously() -> void:
	watch_signals(_spawner)
	watch_signals(_session)
	var plan: BattlePlan = _plan(0, &"typed_zero")
	var token := RunFlowToken.new(1, 1, 1)
	assert_true(_session.start(plan, token, _kill_zone))
	assert_signal_emitted_with_parameters(_spawner, "spawn_batch_sealed", [1, 0])
	assert_signal_not_emitted(_spawner, "spawn_batch_failed")
	assert_signal_emitted_with_parameters(_session, "completed", [token, plan.battle_id, plan])
	assert_eq(_session.live_enemy_count(), 0)
	assert_null(_session.active_plan())


func test_real_enemy_batch_registers_outside_tree_before_atomic_publish() -> void:
	_session.enemy_registered.connect(func(_token: RunFlowToken, enemy: Enemy) -> void:
		_registration_count += 1
		assert_null(enemy.get_parent(), "registration must happen while Enemy is outside the tree")
		assert_eq(enemy.defeated.get_connections().size(), 1, "Session must connect before Enemy enters the tree")
	)
	_spawner.enemy_spawned.connect(func(_batch: int, _entry: int, enemy: Enemy) -> void:
		_spawn_count += 1
		assert_eq(enemy.get_parent(), _container)
		assert_eq(_session.live_enemy_count(), 3, "all entries register before the first publish")
	)
	watch_signals(_session)
	var plan: BattlePlan = _plan(3, &"typed_three")
	var token := RunFlowToken.new(2, 1, 1)
	assert_true(_session.start(plan, token, _kill_zone))
	assert_eq(_registration_count, 3)
	assert_eq(_spawn_count, 3)
	assert_eq(_container.get_child_count(), 3)
	assert_eq(_session.live_enemy_count(), 3)

	var enemies: Array[Enemy] = []
	for child: Node in _container.get_children():
		enemies.append(child as Enemy)
	assert_true(enemies[0].defeat(&"one"))
	assert_true(enemies[1].defeat(&"two"))
	assert_signal_not_emitted(_session, "completed")
	assert_eq(_session.registered_enemy_count(), 3, "defeat must not weaken sealed count")
	assert_true(enemies[2].defeat(&"three"))
	assert_signal_emit_count(_session, "enemy_defeated", 3)
	assert_signal_emit_count(_session, "completed", 1)
	assert_eq(_session.registered_enemy_count(), 0, "completion reset must clear registered count")


func test_real_enemy_defeat_during_tree_entry_seals_closes_once_and_clears_connections() -> void:
	watch_signals(_spawner)
	watch_signals(_session)
	var observer := TreeEntryDefeatObserver.new()
	var entered_callback: Callable = Callable(observer, "defeat_entered_enemy")
	_container.child_entered_tree.connect(entered_callback)

	assert_true(_session.start(
		_plan(1, &"tree_entry_defeat"), RunFlowToken.new(2, 2, 1), _kill_zone
	))
	# watch_signals(_spawner) keeps a GUT spy on the spawner signals, so assert
	# the Session's own callbacks are gone rather than the raw connection count.
	assert_false(_spawner.spawn_batch_sealed.is_connected(
		Callable(_session, "_on_spawn_batch_sealed")
	))
	assert_false(_spawner.spawn_batch_failed.is_connected(
		Callable(_session, "_on_spawn_batch_failed")
	))
	assert_eq(_kill_zone.marble_fell.get_connections().size(), 0)
	assert_not_null(observer.entered_enemy)
	assert_eq(observer.entered_enemy.defeated.get_connections().size(), 0)
	assert_signal_emitted_with_parameters(_spawner, "spawn_batch_sealed", [1, 1])
	assert_signal_emit_count(_session, "enemy_defeated", 1)
	assert_signal_emit_count(_session, "completed", 1)
	assert_eq(_session.live_enemy_count(), 0)
	assert_eq(_session.registered_enemy_count(), 0)
	assert_null(_session.active_plan())

	assert_true(_container.child_entered_tree.is_connected(entered_callback))
	_container.child_entered_tree.disconnect(entered_callback)
	assert_false(_container.child_entered_tree.is_connected(entered_callback))


func test_sealed_count_must_equal_registered_count_even_when_no_enemy_is_live() -> void:
	watch_signals(_session)
	var rejections: Array[Dictionary] = []
	var reject_callback := func(kind: StringName, reason: String) -> void:
		rejections.append({&"kind": kind, &"reason": reason})
	_session.callback_rejected.connect(reject_callback)
	var tamper := SealedCountTamper.new()
	tamper.spawner = _spawner
	tamper.session = _session
	var tamper_callback: Callable = Callable(tamper, "report_wrong_sealed_count")
	_container.child_entered_tree.connect(tamper_callback)

	assert_false(_session.start(
		_plan(1, &"strict_sealed_count"), RunFlowToken.new(2, 3, 1), _kill_zone
	))
	# The tampered sealed(0) must first be rejected against the registered count;
	# the real sealed signal arrives afterwards and is rejected as stale.
	assert_eq(rejections[0], {
		&"kind": &"batch_sealed",
		&"reason": "sealed enemy count does not match registered count",
	})
	assert_eq(tamper.live_count_when_sealed, 0)
	assert_signal_emit_count(_session, "enemy_defeated", 1)
	assert_eq(_session.live_enemy_count(), 0)
	assert_eq(_session.registered_enemy_count(), 0)
	assert_null(_session.active_plan())

	assert_true(_container.child_entered_tree.is_connected(tamper_callback))
	_container.child_entered_tree.disconnect(tamper_callback)
	assert_false(_container.child_entered_tree.is_connected(tamper_callback))
	_session.callback_rejected.disconnect(reject_callback)


func test_partial_batch_failure_rolls_back_session_bridge_and_real_enemies() -> void:
	var registered: Array[Enemy] = []
	_session.enemy_registered.connect(func(_token: RunFlowToken, enemy: Enemy) -> void:
		registered.append(enemy)
		if registered.size() == 2:
			_spawner.enemy_container = null
	)
	watch_signals(_spawner)
	watch_signals(_session)
	var plan: BattlePlan = _plan(2, &"typed_rollback")
	assert_false(_session.start(plan, RunFlowToken.new(3, 1, 1), _kill_zone))
	assert_eq(registered.size(), 2)
	assert_signal_emit_count(_spawner, "spawn_batch_failed", 1)
	assert_signal_not_emitted(_spawner, "spawn_batch_sealed")
	assert_signal_not_emitted(_session, "completed")
	assert_eq(_session.live_enemy_count(), 0)
	for enemy: Enemy in registered:
		assert_false(is_instance_valid(enemy), "rollback must free every prepared real Enemy")


func test_registration_rejection_rolls_back_without_spawn_or_completion_facts() -> void:
	var registered: Array[Enemy] = []
	_session.enemy_registered.connect(func(_token: RunFlowToken, enemy: Enemy) -> void:
		registered.append(enemy)
		_session.clear()
	, CONNECT_ONE_SHOT)
	watch_signals(_spawner)
	watch_signals(_session)

	assert_false(_session.start(
		_plan(2, &"registration_rejected"), RunFlowToken.new(3, 2, 1), _kill_zone
	))
	assert_eq(registered.size(), 1)
	assert_signal_not_emitted(_spawner, "enemy_spawned")
	assert_signal_not_emitted(_spawner, "spawn_batch_sealed")
	assert_signal_not_emitted(_session, "completed")
	assert_eq(_session.live_enemy_count(), 0)
	assert_eq(_container.get_child_count(), 0)
	assert_false(is_instance_valid(registered[0]))


func test_invalid_entries_fail_instead_of_becoming_empty_success() -> void:
	watch_signals(_spawner)
	watch_signals(_session)
	var null_scene_plan: BattlePlan = _plan(0, &"null_scene")
	var null_entry := BattleGroupDef.EnemyEntry.new()
	null_scene_plan.group.enemy_entries.append(null_entry)
	assert_false(_session.start(null_scene_plan, RunFlowToken.new(4, 1, 1), _kill_zone))
	assert_signal_emit_count(_spawner, "spawn_batch_failed", 1)
	assert_signal_not_emitted(_spawner, "spawn_batch_sealed")

	_session.clear()
	var not_enemy_plan: BattlePlan = _plan(0, &"not_enemy")
	var not_enemy_entry := BattleGroupDef.EnemyEntry.new()
	not_enemy_entry.scene = _packed_node_scene()
	not_enemy_plan.group.enemy_entries.append(not_enemy_entry)
	assert_false(_session.start(not_enemy_plan, RunFlowToken.new(4, 2, 1), _kill_zone))
	assert_signal_emit_count(_spawner, "spawn_batch_failed", 2)
	assert_signal_not_emitted(_session, "completed")


func test_zero_entry_still_requires_container_and_registration_collaborator() -> void:
	watch_signals(_spawner)
	var empty_group: BattleGroupDef = _plan(0, &"preconditions").group
	_spawner.enemy_container = null
	assert_false(_spawner.start_batch(
		empty_group, 101, func(_batch: int, _entry: int, _enemy: Enemy) -> bool: return true
	))
	_spawner.enemy_container = _container
	assert_false(_spawner.start_batch(empty_group, 102, Callable()))
	assert_false(_spawner.start_batch(
		null, 103, func(_batch: int, _entry: int, _enemy: Enemy) -> bool: return true
	))
	assert_signal_emit_count(_spawner, "spawn_batch_failed", 3)
	assert_signal_not_emitted(_spawner, "spawn_batch_sealed")


func test_empty_packed_scene_fails_on_the_first_expected_entry() -> void:
	watch_signals(_spawner)
	watch_signals(_session)
	var plan: BattlePlan = _plan(0, &"empty_packed_scene")
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = PackedScene.new()
	plan.group.enemy_entries.append(entry)
	assert_false(_session.start(plan, RunFlowToken.new(4, 3, 1), _kill_zone))
	assert_signal_emitted_with_parameters(
		_spawner, "spawn_batch_failed", [1, 0, &"instantiate_failed"]
	)
	assert_signal_not_emitted(_session, "completed")


func test_duplicate_terminal_callbacks_do_not_change_a_sealed_batch() -> void:
	watch_signals(_session)
	var plan: BattlePlan = _plan(1, &"terminal_once")
	assert_true(_session.start(plan, RunFlowToken.new(5, 1, 1), _kill_zone))
	var batch_id: int = _session.active_batch_id()
	_spawner.spawn_batch_sealed.emit(batch_id, 1)
	_spawner.spawn_batch_failed.emit(batch_id, 0, &"late_failure")
	assert_eq(_session.live_enemy_count(), 1)
	assert_signal_emit_count(_session, "callback_rejected", 2)
	var enemy: Enemy = _container.get_child(0) as Enemy
	assert_true(enemy.defeat(&"only"))
	assert_signal_emit_count(_session, "completed", 1)


func test_marble_identity_is_accepted_once_and_old_callback_is_stale() -> void:
	watch_signals(_session)
	var first_plan: BattlePlan = _plan(1, &"marble_first")
	assert_true(_session.start(first_plan, RunFlowToken.new(6, 1, 1), _kill_zone))
	var old_callback: Callable = _session._kill_zone_callback
	var marble := RigidBody2D.new()
	marble.add_to_group("marbles")
	add_child_autofree(marble)
	_kill_zone.marble_fell.emit(marble)
	_kill_zone.marble_fell.emit(marble)
	assert_signal_emit_count(_session, "marble_fell", 1)
	assert_eq(_session.accepted_marble_count(), 1)

	_session.clear()
	_spawner.clear_enemies()
	_spawner.enemy_container = _container
	assert_true(_session.start(_plan(1, &"marble_second"), RunFlowToken.new(6, 2, 1), _kill_zone))
	old_callback.call(marble)
	assert_signal_emit_count(_session, "marble_fell", 1)
	assert_eq(_session.accepted_marble_count(), 0)


func test_dispose_is_idempotent_and_saved_callback_emits_no_business_fact() -> void:
	watch_signals(_session)
	assert_true(_session.start(
		_plan(1, &"dispose"), RunFlowToken.new(7, 1, 1), _kill_zone
	))
	var old_callback: Callable = _session._kill_zone_callback
	var marble := RigidBody2D.new()
	marble.add_to_group("marbles")
	add_child_autofree(marble)
	_session.dispose()
	_session.dispose()
	old_callback.call(marble)
	assert_signal_not_emitted(_session, "marble_fell")
	assert_signal_not_emitted(_session, "completed")
	assert_false(_session.start(
		_plan(0, &"after_dispose"), RunFlowToken.new(7, 2, 1), _kill_zone
	))


func _plan(enemy_count: int, battle_id: StringName) -> BattlePlan:
	var group := BattleGroupDef.new()
	group.id = String(battle_id)
	for index: int in range(enemy_count):
		var entry := BattleGroupDef.EnemyEntry.new()
		entry.scene = EnemyScene
		entry.position = Vector2(20 + index * 12, 30)
		entry.health = 20 + index
		group.enemy_entries.append(entry)
	return BattlePlan.new(battle_id, group, BattlePlan.Origin.NODE, BattlePlan.RewardPolicy.NORMAL)


func _packed_node_scene() -> PackedScene:
	var root := Node2D.new()
	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	root.free()
	return packed
