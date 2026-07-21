extends Node2D

const RunScopeScene: PackedScene = preload("res://Game/Bootstrap/run_scope.tscn")
const RunFlowUIAdapterScript: GDScript = preload("res://UI/run_flow_ui_adapter.gd")
const DefaultBattleRewardConfig: BattleRewardConfig = preload(
	"res://Run/default_battle_reward_config.tres"
)
const DefaultRunFloorConfig: RunFloorConfig = preload("res://Run/default_run_floor_config.tres")
const DebugGrantServiceScript: GDScript = preload("res://Debug/debug_grant_service.gd")

@onready var marbles: Node2D = $Marbles
@onready var skill_controller: SkillController = $SkillController
@onready var active_skill_slot: ActiveSkillSlot = $CanvasLayer/SkillSlot
@onready var debug_grant_panel: Control = $DebugCanvasLayer/DebugGrantPanel
@export var starting_marble_spawn_positions: Array[Vector2] = [
	Vector2(56, 96),
	Vector2(56, 72),
	Vector2(56, 48),
]

## 链重生时的基准生成位置。
@export var chain_spawn_position: Vector2 = Vector2(56, 48)

## 当前活跃的弹珠链。由 _spawn_chain() 创建，整条链只有一个 RigidBody2D（Head）。
var marble_chain: MarbleChain = null
var run_scope: RunScope = null
## P3-B production composition. RunFlowController is the sole orchestrator.
var battle_spawner: BattleSpawner = null
var base_enemies: Node2D = null
var battle_gateway: BattleGateway = null
var reward_service: RewardService = null
var event_resolver: EventResolver = null
var battle_plan_factory: BattlePlanFactory = null
var run_flow_controller: RunFlowController = null
var run_random_source: RunRandomSource = null
var battle_reward_config: BattleRewardConfig = null
var run_floor_config: RunFloorConfig = null
var run_ui_adapter: RunFlowUIAdapter = null
var reset_battle_callable: Callable = Callable()
var release_floating_texts_callable: Callable = Callable()
var read_stat_callable: Callable = Callable()
var node_choice_panel: NodeChoicePanel = null
var draft_reward_panel: DraftRewardPanel = null
var run_event_panel: RunEventPanel = null
var devil_shop: DevilShop = null
var normal_shop: Control = null
var battle_health_hud: BattleHealthHud = null
var floor_hud: FloorHud = null
var inventory_panel: InventoryPanel = null
var run_failure_panel: RunFailurePanel = null
var debug_grant_service: RefCounted = null
var _active_skill_blocking_panels: Array[Node] = []
var _gateway_marble_fell_callable: Callable = Callable()
var _run_flow_composition_configured: bool = false


func _ready() -> void:
	if not _setup_run_scope():
		return
	_setup_debug_cheats()
	_connect_loadout_change()
	_spawn_chain()
	if not _setup_skill_system():
		return
	if not _setup_run_flow():
		return


func _exit_tree() -> void:
	_dispose_run_flow_composition()


# ---- 链生成 ----

## 用当前 RunScope 的 MarbleLoadout 顺序构建 MarbleChain。
func _spawn_chain() -> void:
	if run_flow_controller != null and run_flow_controller.current_state().phase == RunState.Phase.FAILED:
		return
	if marbles == null:
		return

	# 清理旧链
	if marble_chain != null and is_instance_valid(marble_chain):
		marble_chain.queue_free()
	marble_chain = null

	var chain_items: Array[Item] = _get_chain_items()
	if chain_items.is_empty():
		return

	marble_chain = MarbleChain.new()
	marble_chain.name = "MarbleChain"
	marbles.add_child(marble_chain)
	marble_chain.build_chain(chain_items, starting_marble_spawn_positions)


## 用当前 RunScope 的 MarbleLoadout 顺序构建弹珠链。
func _get_chain_items() -> Array[Item]:
	if run_scope == null or run_scope.loadout == null:
		return []
	return run_scope.loadout.call("get_chain_items") as Array[Item]


# ---- 事件处理 ----

## 弹珠掉入 KillZone。Head 仍是 RigidBody2D 且在 "marbles" group，检测逻辑不变。
## 整条链重建而非单独重建一个弹珠。
func _on_accepted_marble_fell(_token: RunFlowToken, body: RigidBody2D) -> void:
	if marble_chain == null or not is_instance_valid(marble_chain):
		return
	# 确认掉落的确实是 Head
	if body == marble_chain.head:
		if skill_controller != null:
			skill_controller.cancel_active_skill("head_fell")
		marble_chain.queue_free()
		marble_chain = null
		call_deferred(&"_spawn_chain")


func _on_marble_loadout_changed(_items: Array[Item]) -> void:
	_spawn_chain()


func reset_battle_state() -> void:
	if skill_controller != null:
		skill_controller.cancel_active_skill("battle_reset")
		skill_controller.clear_projectiles()
	_spawn_chain()


# ---- 辅助方法 ----

## 返回链的 Head（Dash 等系统使用）。
func _get_active_marble() -> Marble:
	if marble_chain != null and is_instance_valid(marble_chain):
		return marble_chain.head
	return null


func _find_nearest_enemy(from: Vector2) -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_dist: float = INF
	var tree: SceneTree = get_tree()
	if tree == null:
		return null

	for enemy: Node in tree.get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		var enemy_node: Node2D = enemy as Node2D
		var dist: float = from.distance_squared_to(enemy_node.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy_node
	return nearest_enemy


func _setup_skill_system() -> bool:
	if skill_controller == null or run_scope == null:
		return false
	if not skill_controller.configure(run_scope.loadout, run_scope.progression):
		return false
	skill_controller.head_provider = Callable(self, "_get_active_marble")
	skill_controller.projectile_parent_provider = Callable(self, "_get_skill_projectile_parent")
	if active_skill_slot == null:
		return false
	active_skill_slot.bind_controller(skill_controller)
	if not active_skill_slot.skill_pressed.is_connected(skill_controller.press_active_skill):
		active_skill_slot.skill_pressed.connect(skill_controller.press_active_skill)
	if not active_skill_slot.skill_released.is_connected(skill_controller.release_active_skill):
		active_skill_slot.skill_released.connect(skill_controller.release_active_skill)
	return true


func _get_skill_projectile_parent() -> Node:
	return self


func _setup_run_scope(
	stat_system_override: Object = null,
	effect_manager_override: Node = null
) -> bool:
	if run_scope != null:
		return is_instance_valid(run_scope) and run_scope.is_initialized()
	var stat_system: Object = stat_system_override
	if stat_system == null:
		stat_system = _get_autoload_node(&"StatSystem")
	if stat_system == null:
		return false
	run_scope = RunScopeScene.instantiate() as RunScope
	run_scope.name = "RunScope"
	add_child(run_scope)
	if not run_scope.initialize(stat_system):
		_discard_run_scope()
		return false
	var dark_marble := preload("res://Resources/dark_marble.tres") as Item
	var dash_skill := preload("res://Resources/dash_skill.tres") as Item
	if dark_marble == null or dash_skill == null \
			or not bool(run_scope.loadout.call("add", dark_marble)) \
			or not bool(run_scope.loadout.call("add", dash_skill)):
		_discard_run_scope()
		return false
	var effect_manager: Node = effect_manager_override
	if effect_manager == null:
		effect_manager = _get_autoload_node(&"EffectManager")
	if effect_manager == null or not effect_manager.has_method("configure") \
			or not bool(effect_manager.call("configure", run_scope.loadout, run_scope.progression)):
		_discard_run_scope()
		return false
	return true


func _discard_run_scope() -> void:
	if run_scope == null or not is_instance_valid(run_scope):
		run_scope = null
		return
	run_scope.dispose()
	if run_scope.get_parent() == self:
		remove_child(run_scope)
	run_scope.free()
	run_scope = null


func _setup_debug_cheats() -> void:
	if not OS.is_debug_build() or debug_grant_panel == null or run_scope == null:
		return
	debug_grant_service = DebugGrantServiceScript.new()
	if not debug_grant_service.configure(run_scope.loadout, run_scope.progression):
		debug_grant_service = null
		return
	debug_grant_panel.configure_items(debug_grant_service.item_ids())
	_connect_once(debug_grant_panel, &"skip_battle_requested", Callable(self, "_on_debug_skip_battle_requested"))
	_connect_once(debug_grant_panel, &"grant_requested", Callable(self, "_on_debug_grant_requested"))


func _on_debug_skip_battle_requested() -> void:
	if run_flow_controller == null:
		debug_grant_panel.present_result("跳过战斗：运行流程未就绪")
		return
	debug_grant_panel.present_result(
		"跳过战斗：成功" if run_flow_controller.skip_current_battle() else "跳过战斗：当前不在战斗中"
	)


func _on_debug_grant_requested(item_id: StringName) -> void:
	if debug_grant_service == null:
		return
	var result: int = int(debug_grant_service.call("grant", item_id))
	var detail := "发放失败"
	match result:
		DebugGrantServiceScript.Result.GRANTED:
			detail = "发放成功"
		DebugGrantServiceScript.Result.UNKNOWN_ID:
			detail = "未知物品"
		DebugGrantServiceScript.Result.DUPLICATE:
			detail = "已拥有该物品"
		DebugGrantServiceScript.Result.CAPACITY_REACHED:
			detail = "对应栏位已满"
		DebugGrantServiceScript.Result.COMMIT_FAILED:
			detail = "替换技能失败"
	debug_grant_panel.present_result("%s：%s" % [detail, item_id])


## Builds the Phase 3 modular composition without starting it. P3-A focused
## tests call this boundary directly; P3-B production adds UI/bridge wiring in
## `_setup_run_flow()` and starts the same controller only after every wire is valid.
func _setup_run_flow_composition(
	stat_system_override: Object = null,
	effect_manager_override: Node = null,
	component_overrides: Dictionary = {}
) -> bool:
	if _run_flow_composition_configured:
		if _has_valid_run_flow_composition():
			return true
	_dispose_run_flow_composition()

	var created_run_scope: bool = run_scope == null
	if not _setup_run_scope(stat_system_override, effect_manager_override):
		return false

	var stat_system: Node = _get_autoload_node(&"StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		if created_run_scope:
			_discard_run_scope()
		return false

	# Bootstrap nodes are pre-placed in main.tscn (visualized and auditable).
	# Slots resolve here: an injected override wins (replacing the pre-placed
	# node of the same name), otherwise the scene's pre-placed node is used,
	# falling back to dynamic creation only when neither exists (e.g. a
	# re-setup after dispose). RefCounted collaborators stay dynamic. The
	# shared random stream is always created once per composition.
	battle_spawner = _resolve_composition_node(
		&"BattleSpawner", component_overrides.get(&"battle_spawner"),
		func() -> Node: return BattleSpawner.new(),
		func(node: Node) -> bool: return node is BattleSpawner
	) as BattleSpawner
	base_enemies = _resolve_composition_node(
		&"Enemies", component_overrides.get(&"base_enemies"),
		func() -> Node: return Node2D.new(),
		func(node: Node) -> bool: return node is Node2D
	) as Node2D
	battle_gateway = _resolve_composition_node(
		&"BattleGateway", component_overrides.get(&"battle_gateway"),
		func() -> Node: return BattleGateway.new(),
		func(node: Node) -> bool: return node is BattleGateway
	) as BattleGateway
	reward_service = component_overrides.get(&"reward_service") as RewardService
	if reward_service == null:
		reward_service = RewardService.new()
	event_resolver = component_overrides.get(&"event_resolver") as EventResolver
	if event_resolver == null:
		event_resolver = EventResolver.new()
	battle_plan_factory = component_overrides.get(&"battle_plan_factory") as BattlePlanFactory
	if battle_plan_factory == null:
		battle_plan_factory = BattlePlanFactory.new()
	run_flow_controller = _resolve_composition_node(
		&"RunFlowController", component_overrides.get(&"run_flow_controller"),
		func() -> Node: return RunFlowController.new(),
		func(node: Node) -> bool: return node is RunFlowController
	) as RunFlowController
	run_random_source = RunRandomSource.new()
	reset_battle_callable = Callable(self, "reset_battle_state")
	release_floating_texts_callable = Callable(self, "_release_all_floating_texts")
	read_stat_callable = Callable(self, "_read_stat")
	battle_reward_config = DefaultBattleRewardConfig
	run_floor_config = DefaultRunFloorConfig

	if battle_spawner == null or base_enemies == null or battle_gateway == null \
			or run_flow_controller == null:
		_dispose_failed_run_flow_composition(created_run_scope)
		return false
	battle_spawner.enemy_container = base_enemies

	# phase4-plan.md locks this configure order. Stop at the first failure and
	# route every failure through the same reverse-order cleanup path.
	if not reward_service.configure(
		run_scope.loadout,
		run_scope.progression,
		run_scope.wallet,
		battle_reward_config,
		run_random_source
	):
		_dispose_failed_run_flow_composition(created_run_scope)
		return false
	if not event_resolver.configure(run_scope.wallet, run_random_source):
		_dispose_failed_run_flow_composition(created_run_scope)
		return false
	if not battle_gateway.configure(
		battle_spawner,
		base_enemies,
		self,
		reset_battle_callable,
		release_floating_texts_callable,
		read_stat_callable
	):
		_dispose_failed_run_flow_composition(created_run_scope)
		return false
	if not _connect_gateway_marble_fell():
		_dispose_failed_run_flow_composition(created_run_scope)
		return false
	if not run_flow_controller.configure(
		run_scope,
		battle_plan_factory,
		reward_service,
		event_resolver,
		run_floor_config,
		run_random_source,
		battle_gateway
	):
		_dispose_failed_run_flow_composition(created_run_scope)
		return false

	_run_flow_composition_configured = true
	return true


## Idempotent reverse-order teardown for configure/start rollback and normal
## ownership release.
func _dispose_run_flow_composition() -> void:
	_run_flow_composition_configured = false
	if run_ui_adapter != null:
		run_ui_adapter.dispose()
	run_ui_adapter = null
	if skill_controller != null:
		skill_controller.disconnect_lifecycle()
	_disconnect_gateway_marble_fell()
	_disconnect_active_skill_panel_blockers()
	_disconnect_wallet_changed()
	_unconfigure_run_ui()
	node_choice_panel = null
	draft_reward_panel = null
	run_event_panel = null
	devil_shop = null
	normal_shop = null
	battle_health_hud = null
	floor_hud = null
	inventory_panel = null
	run_failure_panel = null

	if run_flow_controller != null and is_instance_valid(run_flow_controller):
		if run_flow_controller.is_inside_tree():
			if run_flow_controller.get_parent() != null:
				run_flow_controller.get_parent().remove_child(run_flow_controller)
		else:
			run_flow_controller.call("_exit_tree")
		if is_instance_valid(run_flow_controller):
			run_flow_controller.free()
	run_flow_controller = null

	if reward_service != null:
		reward_service.clear_active()
	if event_resolver != null:
		event_resolver.clear_active()

	if battle_gateway != null and is_instance_valid(battle_gateway):
		battle_gateway.dispose()
		_free_owned_run_flow_node(battle_gateway)
	battle_gateway = null

	if battle_spawner != null and is_instance_valid(battle_spawner):
		battle_spawner.clear_enemies()
		_free_owned_run_flow_node(battle_spawner)
	battle_spawner = null
	if base_enemies != null and is_instance_valid(base_enemies):
		_free_owned_run_flow_node(base_enemies)
	base_enemies = null

	reward_service = null
	event_resolver = null
	battle_plan_factory = null
	battle_reward_config = null
	run_floor_config = null
	run_random_source = null
	reset_battle_callable = Callable()
	release_floating_texts_callable = Callable()
	read_stat_callable = Callable()


func _unconfigure_run_ui() -> void:
	for ui: Node in [draft_reward_panel, run_event_panel, devil_shop, normal_shop, inventory_panel]:
		if ui != null and is_instance_valid(ui) and ui.has_method(&"unconfigure"):
			ui.call(&"unconfigure")


func _dispose_failed_run_flow_composition(discard_created_scope: bool) -> void:
	_dispose_run_flow_composition()
	if discard_created_scope:
		_discard_run_scope()


func _free_owned_run_flow_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


## Resolves a Bootstrap slot to a single, correctly-typed node owned by Main.
## Transactional: a rejected candidate never disturbs the pre-placed node.
## - an override of the wrong type, or one owned by another branch, is rejected
##   and treated as no valid override;
## - a valid override replaces the pre-placed node of the same name;
## - without an override the scene's pre-placed node is used, recreated only if
##   it is missing or mistyped (e.g. after a dispose freed it).
func _resolve_composition_node(
	slot_name: StringName,
	override_value: Variant,
	creator: Callable,
	type_check: Callable
) -> Node:
	var override: Node = override_value as Node
	if override != null:
		var parent: Node = override.get_parent()
		if not bool(type_check.call(override)) or (parent != null and parent != self):
			override = null
	var existing: Node = get_node_or_null(NodePath(slot_name))
	var candidate: Node = override
	if candidate != null:
		if existing != null and existing != candidate:
			if existing.get_parent() == self:
				remove_child(existing)
			existing.free()
	else:
		candidate = existing
		if candidate != null and not bool(type_check.call(candidate)):
			candidate = null
		if candidate == null:
			candidate = creator.call()
	if candidate != null:
		if candidate.get_parent() == null:
			add_child(candidate)
		if candidate.name != String(slot_name):
			candidate.name = String(slot_name)
	return candidate


func _has_valid_run_flow_composition() -> bool:
	return run_scope != null and is_instance_valid(run_scope) and run_scope.is_initialized() \
		and battle_spawner != null and is_instance_valid(battle_spawner) \
		and base_enemies != null and is_instance_valid(base_enemies) \
		and battle_gateway != null and is_instance_valid(battle_gateway) \
		and reward_service != null and event_resolver != null \
		and battle_plan_factory != null \
		and run_flow_controller != null and is_instance_valid(run_flow_controller) \
		and run_random_source != null \
		and reset_battle_callable.is_valid() \
		and release_floating_texts_callable.is_valid() \
		and read_stat_callable.is_valid()


func _release_all_floating_texts() -> void:
	var pool: Node = _get_autoload_node(&"FloatDamageTextPool")
	if pool != null and pool.has_method("release_all_active"):
		pool.call("release_all_active")


func _read_stat(stat_id: StringName, entity_id: StringName) -> Variant:
	var stat_system: Node = _get_autoload_node(&"StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat"):
		return null
	return stat_system.call("get_stat", String(stat_id), String(entity_id))


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _connect_once(source: Object, signal_name: StringName, callable: Callable) -> void:
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _connect_loadout_change() -> void:
	if run_scope == null or run_scope.loadout == null:
		return
	_connect_once(
		run_scope.loadout,
		&"marble_loadout_changed",
		Callable(self, "_on_marble_loadout_changed")
	)


func _setup_run_flow(
	stat_system_override: Object = null,
	effect_manager_override: Node = null,
	component_overrides: Dictionary = {}
) -> bool:
	if not _setup_run_flow_composition(
		stat_system_override,
		effect_manager_override,
		component_overrides
	):
		_discard_run_scope()
		return false
	var ui_layer: Node = get_node_or_null("CanvasLayer")
	if ui_layer == null or run_flow_controller == null:
		return _rollback_run_flow_startup()

	node_choice_panel = ui_layer.get_node_or_null("NodeChoicePanel") as NodeChoicePanel
	draft_reward_panel = ui_layer.get_node_or_null("DraftRewardPanel") as DraftRewardPanel
	run_event_panel = ui_layer.get_node_or_null("RunEventPanel") as RunEventPanel
	devil_shop = ui_layer.get_node_or_null("DevilShop") as DevilShop
	normal_shop = get_node_or_null("Shop") as Control
	battle_health_hud = ui_layer.get_node_or_null("BattleHealthHud") as BattleHealthHud
	floor_hud = ui_layer.get_node_or_null("FloorHud") as FloorHud
	run_failure_panel = ui_layer.get_node_or_null("RunFailurePanel") as RunFailurePanel
	inventory_panel = get_node_or_null("InventoryPanel") as InventoryPanel
	var pause_panel: Node = ui_layer.get_node_or_null("PausePanel")
	if node_choice_panel == null or draft_reward_panel == null or run_event_panel == null \
			or devil_shop == null or normal_shop == null or battle_health_hud == null \
			or floor_hud == null or run_failure_panel == null or inventory_panel == null \
			or pause_panel == null or active_skill_slot == null:
		return _rollback_run_flow_startup()

	if not bool(normal_shop.call("configure", run_scope.loadout, run_scope.progression, run_scope.wallet)) \
			or not devil_shop.configure(run_scope.loadout, run_scope.progression, run_scope.wallet, run_scope.health) \
			or not draft_reward_panel.configure(run_scope.loadout) \
			or not run_event_panel.configure(run_scope.wallet):
		return _rollback_run_flow_startup()

	if inventory_panel == null or battle_health_hud == null or floor_hud == null \
			or run_failure_panel == null or active_skill_slot == null \
			or not inventory_panel.configure(run_scope.loadout, run_scope.progression):
		return _rollback_run_flow_startup()

	run_ui_adapter = RunFlowUIAdapterScript.new() as RunFlowUIAdapter
	if run_ui_adapter == null or not run_ui_adapter.configure(
		run_flow_controller,
		node_choice_panel,
		draft_reward_panel,
		run_event_panel,
		inventory_panel,
		normal_shop,
		devil_shop,
		run_failure_panel,
		battle_health_hud,
		floor_hud,
		active_skill_slot
	):
		return _rollback_run_flow_startup()
	if skill_controller == null or not skill_controller.configure_lifecycle(run_flow_controller):
		return _rollback_run_flow_startup()
	_connect_active_skill_panel_blockers()
	_sync_battle_hud_gold()
	_connect_wallet_changed()
	_connect_once(run_flow_controller, &"run_failed", Callable(self, "_on_run_failed"))
	if not run_flow_controller.start_run():
		return _rollback_run_flow_startup()
	return true


func _rollback_run_flow_startup() -> bool:
	_dispose_run_flow_composition()
	_discard_run_scope()
	return false


func _connect_active_skill_panel_blockers() -> void:
	if active_skill_slot == null:
		return
	_disconnect_active_skill_panel_blockers()
	_active_skill_blocking_panels.clear()
	for panel_path: NodePath in [
		^"DebugCanvasLayer/DebugGrantPanel",
		^"CanvasLayer/PausePanel",
		^"CanvasLayer/RunFailurePanel",
		^"CanvasLayer/NodeChoicePanel",
		^"CanvasLayer/DraftRewardPanel",
		^"CanvasLayer/DevilShop",
		^"CanvasLayer/RunEventPanel",
	]:
		_register_active_skill_blocking_panel(get_node_or_null(panel_path))
	if inventory_panel != null:
		_register_active_skill_blocking_panel(inventory_panel.get_node_or_null("UI"))
	if normal_shop != null:
		_register_active_skill_blocking_panel(normal_shop.get_node_or_null("UI"))
	_sync_active_skill_panel_blocker()


func _disconnect_active_skill_panel_blockers() -> void:
	var callable: Callable = Callable(self, "_sync_active_skill_panel_blocker")
	for panel: Node in _active_skill_blocking_panels:
		if panel != null and is_instance_valid(panel) \
				and panel.has_signal(&"visibility_changed") \
				and panel.is_connected(&"visibility_changed", callable):
			panel.disconnect(&"visibility_changed", callable)
	_active_skill_blocking_panels.clear()


func _register_active_skill_blocking_panel(panel: Node) -> void:
	if panel == null or not panel.has_signal(&"visibility_changed"):
		return
	_active_skill_blocking_panels.append(panel)
	_connect_once(panel, &"visibility_changed", Callable(self, "_sync_active_skill_panel_blocker"))


func _sync_active_skill_panel_blocker() -> void:
	if active_skill_slot == null:
		return
	var blocked: bool = false
	for panel: Node in _active_skill_blocking_panels:
		if is_instance_valid(panel) and bool(panel.get("visible")):
			blocked = true
			break
	active_skill_slot.set_blocked_by_panel(blocked)


func _on_run_failed(_token: RunFlowToken, _reason: StringName) -> void:
	if skill_controller != null:
		skill_controller.cancel_active_skill("run_failed")
		skill_controller.clear_projectiles()
	if marble_chain != null and is_instance_valid(marble_chain):
		marble_chain.queue_free()
	marble_chain = null


func _sync_battle_hud_gold() -> void:
	if run_scope != null and run_scope.wallet != null:
		_on_wallet_changed(int(run_scope.wallet.call("balance")))


func _connect_wallet_changed() -> void:
	if run_scope == null or run_scope.wallet == null:
		return
	_connect_once(run_scope.wallet, &"changed", Callable(self, "_on_wallet_changed"))


func _disconnect_wallet_changed() -> void:
	if run_scope == null or run_scope.wallet == null or not is_instance_valid(run_scope.wallet):
		return
	var callable: Callable = Callable(self, "_on_wallet_changed")
	if run_scope.wallet.is_connected(&"changed", callable):
		run_scope.wallet.disconnect(&"changed", callable)


func _on_wallet_changed(value: int) -> void:
	if battle_health_hud != null:
		battle_health_hud.set_gold(value)


func _connect_gateway_marble_fell() -> bool:
	_disconnect_gateway_marble_fell()
	if battle_gateway == null or not is_instance_valid(battle_gateway):
		return false
	_gateway_marble_fell_callable = Callable(self, "_on_accepted_marble_fell")
	if battle_gateway.connect(&"marble_fell", _gateway_marble_fell_callable) != OK:
		_gateway_marble_fell_callable = Callable()
		return false
	return true


func _disconnect_gateway_marble_fell() -> void:
	if battle_gateway != null and is_instance_valid(battle_gateway) \
			and _gateway_marble_fell_callable.is_valid() \
			and battle_gateway.is_connected(&"marble_fell", _gateway_marble_fell_callable):
		battle_gateway.disconnect(&"marble_fell", _gateway_marble_fell_callable)
	_gateway_marble_fell_callable = Callable()
