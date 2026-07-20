extends Node
class_name BattleGateway

## Runtime adapter between typed Run flow and the local battle session.
## All global/runtime dependencies are supplied by the composition root.

signal battle_completed(token: RunFlowToken, battle_id: StringName, plan: BattlePlan)
signal marble_fell(token: RunFlowToken, marble: RigidBody2D)

const BOUNCELESS_WALL_BOUNCE: StringName = &"bounceless_wall_bounce"
const PINBALL_TABLE_ENTITY: StringName = &"pinball_table"
const ACTIVE_ENEMY_CONTAINER_PATH: NodePath = ^"Enemies"
const ACTIVE_KILL_ZONE_PATH: NodePath = ^"TableBase/KillZone"

var active_level_scene: Node = null

var _spawner: BattleSpawner = null
var _session: BattleSession = null
var _base_enemy_container: Node2D = null
var _enemy_container: Node2D = null
var _level_parent: Node = null
var _reset_battle: Callable = Callable()
var _release_floating_texts: Callable = Callable()
var _read_stat: Callable = Callable()

var _active_plan: BattlePlan = null
var _active_token: RunFlowToken = null
var _configured: bool = false


func configure(
	spawner: BattleSpawner,
	enemy_container: Node2D,
	level_parent: Node,
	reset_battle: Callable,
	release_floating_texts: Callable = Callable(),
	read_stat: Callable = Callable()
) -> bool:
	dispose()
	if spawner == null or not is_instance_valid(spawner):
		return false
	if enemy_container == null or not is_instance_valid(enemy_container) \
			or level_parent == null or not is_instance_valid(level_parent) \
			or not reset_battle.is_valid():
		return false

	_spawner = spawner
	_base_enemy_container = enemy_container
	_enemy_container = enemy_container
	_level_parent = level_parent
	_reset_battle = reset_battle
	_release_floating_texts = release_floating_texts
	_read_stat = read_stat
	_set_spawner_enemy_container(_enemy_container)

	_session = BattleSession.new()
	_session.name = "BattleSession"
	add_child(_session)
	if not _session.configure(_spawner):
		_destroy_session()
		_clear_configuration()
		return false
	_session.completed.connect(_on_session_completed)
	_session.marble_fell.connect(_on_session_marble_fell)
	_configured = true
	return true


func start(plan: BattlePlan, token: RunFlowToken) -> bool:
	_clear_active_session()
	if not _configured or plan == null or not plan.is_valid() \
			or token == null or not token.is_valid():
		_rollback_start(false)
		return false

	_release_floating_texts_now()
	if not _activate_level_for(plan.group):
		_rollback_start(false)
		return false
	var kill_zone: Area2D = active_level_scene.get_node_or_null(
		ACTIVE_KILL_ZONE_PATH
	) as Area2D
	if kill_zone == null or not kill_zone.has_signal(&"marble_fell"):
		_rollback_start(false)
		return false

	# The active level may contain editor preview enemies. The typed batch is the
	# only runtime owner, so clear the switched container before opening Session.
	_spawner.clear_enemies()
	_active_plan = plan
	_active_token = token
	_reset_battle.call()

	# Session may synchronously emit completed for a legal zero-entry batch. Its
	# true return remains authoritative even though the callback clears identity.
	if _session.start(plan, token, kill_zone):
		return true
	_rollback_start(true)
	return false


func clear(restart: bool = false) -> void:
	_clear_runtime(true)
	if restart and _configured:
		_reset_battle.call()


func dispose() -> void:
	_clear_runtime(false)
	_destroy_session()
	_clear_configuration()


func _exit_tree() -> void:
	dispose()


func _activate_level_for(group: BattleGroupDef) -> bool:
	if group == null:
		return false
	var level_def: LevelDef = group.level_def as LevelDef
	if level_def == null or level_def.level_scene == null:
		return false

	var previous_container: Node2D = _enemy_container
	_clear_active_level_scene()
	var scene: Node = level_def.level_scene.instantiate()
	if scene == null:
		_restore_base_enemy_container()
		return false
	scene.name = "ActiveLevel"
	_level_parent.add_child(scene)
	active_level_scene = scene
	_apply_bounceless_wall_material(scene)

	var next_container: Node2D = scene.get_node_or_null(
		ACTIVE_ENEMY_CONTAINER_PATH
	) as Node2D
	if next_container == null:
		_clear_active_level_scene()
		_restore_base_enemy_container()
		return false
	_clear_previous_enemy_container(previous_container, next_container)
	_enemy_container = next_container
	_set_spawner_enemy_container(next_container)
	return true


func _rollback_start(release_floating_texts: bool) -> void:
	_clear_runtime(release_floating_texts)


func _clear_runtime(release_floating_texts: bool) -> void:
	_clear_active_session()
	if _spawner != null and is_instance_valid(_spawner):
		_spawner.clear_enemies()
	_clear_active_level_scene()
	_restore_base_enemy_container()
	if release_floating_texts:
		_release_floating_texts_now()


func _clear_active_session() -> void:
	if _session != null and is_instance_valid(_session):
		_session.clear()
	_active_plan = null
	_active_token = null


func _destroy_session() -> void:
	if _session == null or not is_instance_valid(_session):
		_session = null
		return
	if _session.completed.is_connected(_on_session_completed):
		_session.completed.disconnect(_on_session_completed)
	if _session.marble_fell.is_connected(_on_session_marble_fell):
		_session.marble_fell.disconnect(_on_session_marble_fell)
	_session.dispose()
	if _session.get_parent() == self:
		remove_child(_session)
	_session.free()
	_session = null


func _clear_configuration() -> void:
	_spawner = null
	_base_enemy_container = null
	_enemy_container = null
	_level_parent = null
	_reset_battle = Callable()
	_release_floating_texts = Callable()
	_read_stat = Callable()
	_configured = false


func _clear_active_level_scene() -> void:
	if active_level_scene == null or not is_instance_valid(active_level_scene):
		active_level_scene = null
		return
	active_level_scene.queue_free()
	active_level_scene = null


func _restore_base_enemy_container() -> void:
	if _base_enemy_container == null or not is_instance_valid(_base_enemy_container):
		return
	_enemy_container = _base_enemy_container
	_base_enemy_container.visible = true
	_set_spawner_enemy_container(_base_enemy_container)


func _clear_previous_enemy_container(previous: Node2D, next: Node2D) -> void:
	if previous == null or previous == next or not is_instance_valid(previous):
		return
	for child: Node in previous.get_children():
		child.free()
	previous.visible = false


func _set_spawner_enemy_container(container: Node2D) -> void:
	if _spawner != null and is_instance_valid(_spawner):
		_spawner.enemy_container = container


func _apply_bounceless_wall_material(level_scene: Node) -> void:
	if not _read_stat.is_valid():
		return
	var wall: StaticBody2D = level_scene.find_child(
		"BouncelessWall", true, false
	) as StaticBody2D
	if wall == null:
		return
	var material: PhysicsMaterial = wall.physics_material_override
	material = PhysicsMaterial.new() if material == null else material.duplicate()
	material.bounce = float(_read_stat.call(
		BOUNCELESS_WALL_BOUNCE, PINBALL_TABLE_ENTITY
	))
	wall.physics_material_override = material


func _release_floating_texts_now() -> void:
	if _release_floating_texts.is_valid():
		_release_floating_texts.call()


func _on_session_completed(
	token: RunFlowToken,
	battle_id: StringName,
	plan: BattlePlan
) -> void:
	if token == null or _active_token == null or not _active_token.matches(token):
		return
	if plan == null or plan != _active_plan or battle_id != _active_plan.battle_id:
		return
	var completed_token: RunFlowToken = _active_token
	var completed_plan: BattlePlan = _active_plan
	_active_token = null
	_active_plan = null
	battle_completed.emit(completed_token, completed_plan.battle_id, completed_plan)


func _on_session_marble_fell(token: RunFlowToken, marble: RigidBody2D) -> void:
	if token == null or _active_token == null or not _active_token.matches(token):
		return
	if marble == null or not is_instance_valid(marble):
		return
	marble_fell.emit(token, marble)
