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
var _run_wallet: RefCounted = null
var _run_random_source: RefCounted = null
var _marble_chain_registry: MarbleChainRegistry = null

var _active_plan: BattlePlan = null
var _active_token: RunFlowToken = null
var _configured: bool = false


func configure(
	spawner: BattleSpawner,
	enemy_container: Node2D,
	level_parent: Node,
	reset_battle: Callable,
	release_floating_texts: Callable = Callable(),
	read_stat: Callable = Callable(),
	run_wallet: RefCounted = null,
	run_random_source: RefCounted = null,
	marble_chain_registry: MarbleChainRegistry = null
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
	_run_wallet = run_wallet
	_run_random_source = run_random_source
	_marble_chain_registry = marble_chain_registry
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
	if not _validate_level_component_safety(active_level_scene, kill_zone):
		_rollback_start(false)
		return false
	var drop_director := active_level_scene.find_child(
		"CombatDropDirector", true, false
	) as CombatDropDirector
	if drop_director != null:
		drop_director.configure_kill_zone(kill_zone)

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


func force_complete_current_battle() -> bool:
	if not _configured or _session == null or not is_instance_valid(_session) \
			or _active_plan == null or _active_token == null:
		return false
	return _session.force_complete()


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
	if not _validate_level_component_ids(scene):
		_clear_active_level_scene()
		_restore_base_enemy_container()
		return false
	_configure_level_drop_director(scene)
	_configure_level_portals(scene)

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
	_run_wallet = null
	_run_random_source = null
	_marble_chain_registry = null
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


func _configure_level_drop_director(level_scene: Node) -> void:
	_session.configure_loot_settlement_gate()
	if _run_wallet == null or _run_random_source == null:
		return
	var director := level_scene.find_child("CombatDropDirector", true, false) as CombatDropDirector
	var drops := level_scene.find_child("CombatDrops", true, false) as Node2D
	if director == null or drops == null:
		return
	var anchors: Array[Marker2D] = []
	for anchor: Node in level_scene.get_tree().get_nodes_in_group(&"coin_drop_anchors"):
		if anchor is Marker2D and level_scene.is_ancestor_of(anchor):
			anchors.append(anchor as Marker2D)
	if director.configure(_session, drops, _run_wallet, _run_random_source, anchors):
		_session.configure_loot_settlement_gate(director.settlement_gate())


func _configure_level_portals(level_scene: Node) -> void:
	if _marble_chain_registry == null or not is_instance_valid(_marble_chain_registry):
		return
	var controllers_by_pair: Dictionary[StringName, PortalPairController] = {}
	for controller: Node in level_scene.get_tree().get_nodes_in_group(&"table_component"):
		if not controller is PortalPairController or not level_scene.is_ancestor_of(controller):
			continue
		var pair_controller := controller as PortalPairController
		if not pair_controller.configure(_marble_chain_registry, MarbleTeleportService.new()):
			continue
		var pair_id := pair_controller.configured_pair_id()
		if controllers_by_pair.has(pair_id):
			var reason := "Duplicate portal pair_id: %s" % pair_id
			pair_controller.disable_with_validation_error(reason)
			var existing: PortalPairController = controllers_by_pair[pair_id] as PortalPairController
			if existing != null:
				existing.disable_with_validation_error(reason)
			continue
		controllers_by_pair[pair_id] = pair_controller


func _validate_level_component_ids(level_scene: Node) -> bool:
	var component_ids: Dictionary[StringName, Node] = {}
	for component: Node in level_scene.get_tree().get_nodes_in_group(&"table_component"):
		if not level_scene.is_ancestor_of(component):
			continue
		var component_id: StringName = component.get("component_id") as StringName
		if component_id == &"":
			continue
		if component_ids.has(component_id):
			push_error("Duplicate table component_id: %s" % component_id)
			return false
		component_ids[component_id] = component
	return true


func _validate_level_component_safety(level_scene: Node, kill_zone: Node) -> bool:
	if level_scene == null or kill_zone == null or not kill_zone.has_method(&"contains_global_point"):
		return false
	for node: Node in level_scene.find_children("*", "Barrel", true, false):
		var barrel := node as Barrel
		if barrel == null or barrel.drop_anchor == null \
				or bool(kill_zone.call(&"contains_global_point", barrel.drop_anchor.global_position)):
			push_error("Barrel DropAnchor is missing or inside the kill zone: %s" % node.get_path())
			return false
	_disable_unsafe_portal_pairs(level_scene, kill_zone)
	return true


func _disable_unsafe_portal_pairs(level_scene: Node, kill_zone: Node) -> void:
	var disabled_pairs: Dictionary[int, bool] = {}
	for node: Node in level_scene.find_children("*", "PortalEndpoint", true, false):
		var endpoint := node as PortalEndpoint
		if endpoint == null or endpoint.portal_anchor == null:
			continue
		if not bool(kill_zone.call(&"contains_global_point", endpoint.anchor_position())):
			continue
		var pair_controller := endpoint.get_parent() as PortalPairController
		if pair_controller == null or disabled_pairs.has(pair_controller.get_instance_id()):
			continue
		disabled_pairs[pair_controller.get_instance_id()] = true
		pair_controller.disable_with_validation_error(
			"Portal exit is inside the kill zone: %s" % endpoint.get_path()
		)


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
