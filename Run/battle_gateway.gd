extends Node
class_name BattleGateway

## Narrow runtime adapter between typed Run flow and the legacy battle runtime.
## All global/runtime dependencies are supplied by the composition root.

signal battle_completed(token: RunFlowToken, battle_id: StringName, plan: BattlePlan)
signal marble_fell(token: RunFlowToken, marble: RigidBody2D)

const BOUNCELESS_WALL_BOUNCE: StringName = &"bounceless_wall_bounce"
const PINBALL_TABLE_ENTITY: StringName = &"pinball_table"

var active_level_scene: Node = null

var _spawner: Node = null
var _base_enemy_container: Node2D = null
var _enemy_container: Node2D = null
var _level_parent: Node = null
var _reset_battle: Callable = Callable()
var _release_floating_texts: Callable = Callable()
var _read_stat: Callable = Callable()
var _legacy_event_source: Node = null

var _active_plan: BattlePlan = null
var _active_token: RunFlowToken = null
var _spawner_completion_callable: Callable = Callable()
var _legacy_marble_callable: Callable = Callable()
var _configured: bool = false


func configure(
	spawner: Node,
	enemy_container: Node2D,
	level_parent: Node,
	reset_battle: Callable,
	release_floating_texts: Callable = Callable(),
	read_stat: Callable = Callable(),
	legacy_event_source: Node = null
) -> bool:
	dispose()
	if spawner == null or not is_instance_valid(spawner) \
			or not spawner.has_method("start_battle") \
			or not spawner.has_method("clear_enemies") \
			or not spawner.has_signal(&"battle_completed"):
		return false
	if enemy_container == null or not is_instance_valid(enemy_container) \
			or level_parent == null or not is_instance_valid(level_parent) \
			or not reset_battle.is_valid():
		return false
	if legacy_event_source != null and (not is_instance_valid(legacy_event_source) \
			or not legacy_event_source.has_signal(&"marble_fell")):
		return false

	_spawner = spawner
	_base_enemy_container = enemy_container
	_enemy_container = enemy_container
	_level_parent = level_parent
	_reset_battle = reset_battle
	_release_floating_texts = release_floating_texts
	_read_stat = read_stat
	_legacy_event_source = legacy_event_source
	_set_spawner_enemy_container(_enemy_container)
	_configured = true
	return true


func start(plan: BattlePlan, token: RunFlowToken) -> bool:
	_disconnect_battle_signals()
	_active_plan = null
	_active_token = null
	if not _configured or plan == null or not plan.is_valid() \
			or token == null or not token.is_valid():
		_clear_runtime(false)
		return false

	_release_floating_texts_now()
	if not _activate_level_for(plan.group):
		_clear_runtime(false)
		return false

	_active_plan = plan
	_active_token = token
	_spawner_completion_callable = Callable(self, "_on_spawner_battle_completed").bind(
		token, plan.battle_id, plan.group
	)
	_spawner.connect(&"battle_completed", _spawner_completion_callable)
	_connect_legacy_marble(token)
	_reset_battle.call()

	var start_result: Variant = _spawner.call("start_battle", plan.group)
	if start_result is bool and not bool(start_result):
		_clear_runtime(true)
		return false
	return true


func clear(restart: bool = false) -> void:
	_clear_runtime(true)
	if restart and _configured:
		_reset_battle.call()


func dispose() -> void:
	_disconnect_battle_signals()
	if _spawner != null and is_instance_valid(_spawner) and _spawner.has_method("clear_enemies"):
		_spawner.call("clear_enemies")
	_clear_active_level_scene()
	_restore_base_enemy_container()
	_active_plan = null
	_active_token = null
	_spawner = null
	_base_enemy_container = null
	_enemy_container = null
	_level_parent = null
	_reset_battle = Callable()
	_release_floating_texts = Callable()
	_read_stat = Callable()
	_legacy_event_source = null
	_configured = false


func _exit_tree() -> void:
	dispose()


func _activate_level_for(group: BattleGroupDef) -> bool:
	var level_def: LevelDef = group.level_def as LevelDef
	if level_def == null or level_def.level_scene == null:
		_clear_active_level_scene()
		_restore_base_enemy_container()
		return _enemy_container != null and is_instance_valid(_enemy_container)

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

	var next_container: Node2D = scene.get_node_or_null("Enemies") as Node2D
	if next_container == null:
		_clear_active_level_scene()
		_restore_base_enemy_container()
		return false
	_clear_previous_enemy_container(previous_container, next_container)
	_enemy_container = next_container
	_set_spawner_enemy_container(next_container)
	return true


func _clear_runtime(release_floating_texts: bool) -> void:
	_disconnect_battle_signals()
	if _spawner != null and is_instance_valid(_spawner) and _spawner.has_method("clear_enemies"):
		_spawner.call("clear_enemies")
	_clear_active_level_scene()
	_restore_base_enemy_container()
	if release_floating_texts:
		_release_floating_texts_now()
	_active_plan = null
	_active_token = null


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
		_spawner.set("enemy_container", container)


func _apply_bounceless_wall_material(level_scene: Node) -> void:
	if not _read_stat.is_valid():
		return
	var wall: StaticBody2D = level_scene.find_child("BouncelessWall", true, false) as StaticBody2D
	if wall == null:
		return
	var material: PhysicsMaterial = wall.physics_material_override
	material = PhysicsMaterial.new() if material == null else material.duplicate()
	material.bounce = float(_read_stat.call(BOUNCELESS_WALL_BOUNCE, PINBALL_TABLE_ENTITY))
	wall.physics_material_override = material


func _release_floating_texts_now() -> void:
	if _release_floating_texts.is_valid():
		_release_floating_texts.call()


func _connect_legacy_marble(battle_token: RunFlowToken) -> void:
	_disconnect_legacy_marble()
	if _legacy_event_source == null:
		return
	_legacy_marble_callable = Callable(self, "_on_legacy_marble_fell").bind(battle_token)
	_legacy_event_source.connect(&"marble_fell", _legacy_marble_callable)


func _disconnect_battle_signals() -> void:
	if _spawner != null and is_instance_valid(_spawner) \
			and _spawner_completion_callable.is_valid() \
			and _spawner.is_connected(&"battle_completed", _spawner_completion_callable):
		_spawner.disconnect(&"battle_completed", _spawner_completion_callable)
	_spawner_completion_callable = Callable()
	_disconnect_legacy_marble()


func _disconnect_legacy_marble() -> void:
	if _legacy_event_source != null and is_instance_valid(_legacy_event_source) \
			and _legacy_marble_callable.is_valid() \
			and _legacy_event_source.is_connected(&"marble_fell", _legacy_marble_callable):
		_legacy_event_source.disconnect(&"marble_fell", _legacy_marble_callable)
	_legacy_marble_callable = Callable()


func _on_spawner_battle_completed(
	group_id: String,
	battle_token: RunFlowToken,
	battle_id: StringName,
	battle_group: BattleGroupDef
) -> void:
	if _active_plan == null or _active_token == null \
			or not _active_token.matches(battle_token) \
			or _active_plan.battle_id != battle_id \
			or _active_plan.group != battle_group \
			or battle_group.id != group_id:
		return
	var completed_plan: BattlePlan = _active_plan
	var completed_token: RunFlowToken = _active_token
	_disconnect_battle_signals()
	_active_plan = null
	_active_token = null
	battle_completed.emit(completed_token, completed_plan.battle_id, completed_plan)


func _on_legacy_marble_fell(marble: Variant, battle_token: RunFlowToken) -> void:
	if not marble is RigidBody2D:
		return
	var body: RigidBody2D = marble as RigidBody2D
	if not is_instance_valid(body) or not body.is_in_group("marbles"):
		return
	marble_fell.emit(battle_token, body)
