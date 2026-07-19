extends Node2D

const RunControllerScript: GDScript = preload("res://Run/run_controller.gd")
const RunScopeScript: GDScript = preload("res://Game/Bootstrap/run_scope.gd")
const ShopScene: PackedScene = preload("res://Shop/shop.tscn")
const NodeChoicePanelScene: PackedScene = preload("res://UI/node_choice_panel.tscn")
const DraftRewardPanelScene: PackedScene = preload("res://UI/draft_reward_panel.tscn")
const RunEventPanelScene: PackedScene = preload("res://UI/run_event_panel.tscn")
const BattleHealthHudScene: PackedScene = preload("res://UI/battle_health_hud.tscn")
const FloorHudScene: PackedScene = preload("res://UI/floor_hud.tscn")
const InventoryPanelScene: PackedScene = preload("res://UI/inventory_panel.tscn")
const PausePanelScene: PackedScene = preload("res://UI/pause_panel.tscn")
const DevilShopScene: PackedScene = preload("res://DevilShop/devil_shop.tscn")

@onready var marbles: Node2D = $Marbles
@onready var skill_controller: SkillController = $SkillController
@onready var active_skill_slot: ActiveSkillSlot = $CanvasLayer/SkillSlot
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
var run_controller: RunController = null
var normal_shop: Control = null
var battle_health_hud: Node = null
var floor_hud: Node = null
var inventory_panel: Control = null
var run_failure_panel: Node = null
var _active_skill_blocking_panels: Array[Node] = []
var _restart_in_progress: bool = false


func _ready() -> void:
	if not _setup_run_scope():
		return
	var event_bus: Node = _get_autoload_node(&"Event")
	if event_bus != null and event_bus.has_signal(&"marble_fell"):
		_connect_once(event_bus, &"marble_fell", Callable(self, "_on_marble_fell"))
	_connect_loadout_change()
	_spawn_chain()
	if not _setup_skill_system():
		return
	if not _setup_run_flow():
		return


# ---- 链生成 ----

## 用当前 RunScope 的 MarbleLoadout 顺序构建 MarbleChain。
func _spawn_chain() -> void:
	if run_controller != null and run_controller.run_is_failed:
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
func _on_marble_fell(body: RigidBody2D) -> void:
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
	run_scope = RunScopeScript.new() as RunScope
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


func _setup_run_flow() -> bool:
	var ui_layer: Node = get_node_or_null("CanvasLayer")
	if ui_layer == null:
		return false

	var node_choice_panel: NodeChoicePanel = NodeChoicePanelScene.instantiate() as NodeChoicePanel
	node_choice_panel.name = "NodeChoicePanel"
	ui_layer.add_child(node_choice_panel)

	var draft_reward_panel: DraftRewardPanel = DraftRewardPanelScene.instantiate() as DraftRewardPanel
	draft_reward_panel.name = "DraftRewardPanel"
	ui_layer.add_child(draft_reward_panel)

	var event_panel: RunEventPanel = RunEventPanelScene.instantiate() as RunEventPanel
	event_panel.name = "RunEventPanel"
	ui_layer.add_child(event_panel)

	var devil_shop: DevilShop = DevilShopScene.instantiate() as DevilShop
	devil_shop.name = "DevilShop"
	ui_layer.add_child(devil_shop)

	normal_shop = ShopScene.instantiate() as Control
	normal_shop.name = "Shop"
	add_child(normal_shop)

	if not bool(normal_shop.call("configure", run_scope.loadout, run_scope.progression, run_scope.wallet)) \
			or not devil_shop.configure(run_scope.loadout, run_scope.progression, run_scope.wallet, run_scope.health) \
			or not draft_reward_panel.configure(run_scope.loadout, run_scope.progression, run_scope.wallet):
		return false

	_setup_battle_health_hud(ui_layer)
	_setup_floor_hud(ui_layer)
	_setup_pause_panel(ui_layer)
	_setup_run_failure_panel(ui_layer)
	_setup_inventory_panel()
	if inventory_panel == null or not bool(inventory_panel.call(
		"configure", run_scope.loadout, run_scope.progression
	)):
		return false

	run_controller = RunControllerScript.new()
	run_controller.name = "RunController"
	run_controller.level_parent = self
	run_controller.node_choice_panel = node_choice_panel
	run_controller.draft_reward_panel = draft_reward_panel
	run_controller.upgrade_inventory_panel = inventory_panel
	run_controller.devil_shop = devil_shop
	run_controller.event_panel = event_panel
	run_controller.reset_battle_state_callable = Callable(self, "reset_battle_state")
	if not run_controller.configure(run_scope, normal_shop):
		return false
	run_controller.run_health_changed.connect(_on_run_health_changed)
	run_controller.run_failed.connect(_on_run_failed)
	run_controller.floor_changed.connect(_on_floor_changed)
	add_child(run_controller)
	_connect_active_skill_slot_to_battle_flow()

	var event_bus: Node = _get_autoload_node(&"Event")
	if event_bus != null:
		_connect_run_signal(run_controller, event_bus, &"run_node_completed")
		_connect_run_signal(run_controller, event_bus, &"battle_started")
		_connect_run_signal(run_controller, event_bus, &"battle_completed")
		_connect_run_signal(run_controller, event_bus, &"run_completed")

	run_controller.start_run()
	return true


func _connect_active_skill_slot_to_battle_flow() -> void:
	if run_controller == null or active_skill_slot == null:
		return
	_connect_once(run_controller, &"battle_started", Callable(active_skill_slot, "on_battle_started"))
	_connect_once(run_controller, &"battle_completed", Callable(active_skill_slot, "on_battle_completed"))

	_active_skill_blocking_panels.clear()
	for panel_path: NodePath in [
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


func _register_active_skill_blocking_panel(panel: Node) -> void:
	if panel == null or not panel.has_signal(&"visibility_changed"):
		return
	_active_skill_blocking_panels.append(panel)
	_connect_once(panel, &"visibility_changed", Callable(self, "_sync_active_skill_panel_blocker"))


func _sync_active_skill_panel_blocker() -> void:
	var blocked: bool = false
	for panel: Node in _active_skill_blocking_panels:
		if is_instance_valid(panel) and bool(panel.get("visible")):
			blocked = true
			break
	active_skill_slot.set_blocked_by_panel(blocked)


func _setup_battle_health_hud(ui_layer: Node) -> void:
	battle_health_hud = ui_layer.get_node_or_null("BattleHealthHud")
	if battle_health_hud == null:
		battle_health_hud = BattleHealthHudScene.instantiate()
		battle_health_hud.name = "BattleHealthHud"
		ui_layer.add_child(battle_health_hud)
	_sync_battle_hud_gold()
	_connect_wallet_changed()


func _setup_floor_hud(ui_layer: Node) -> void:
	floor_hud = ui_layer.get_node_or_null("FloorHud")
	if floor_hud == null:
		floor_hud = FloorHudScene.instantiate()
		floor_hud.name = "FloorHud"
		ui_layer.add_child(floor_hud)


func _setup_pause_panel(ui_layer: Node) -> void:
	var pause_panel: Node = ui_layer.get_node_or_null("PausePanel")
	if pause_panel == null:
		pause_panel = get_node_or_null("PausePanel")
	if pause_panel == null:
		pause_panel = PausePanelScene.instantiate()
		pause_panel.name = "PausePanel"
		ui_layer.add_child(pause_panel)
		return
	if pause_panel.get_parent() != ui_layer:
		pause_panel.get_parent().remove_child(pause_panel)
		ui_layer.add_child(pause_panel)


func _setup_run_failure_panel(ui_layer: Node) -> void:
	run_failure_panel = ui_layer.get_node_or_null("RunFailurePanel")
	if run_failure_panel == null or not run_failure_panel.has_signal(&"restart_requested"):
		return
	var restart_callable: Callable = Callable(self, "_on_failure_restart_requested")
	if not run_failure_panel.is_connected(&"restart_requested", restart_callable):
		run_failure_panel.connect(&"restart_requested", restart_callable)


func _setup_inventory_panel() -> void:
	inventory_panel = get_node_or_null("InventoryPanel") as Control
	if inventory_panel != null:
		return

	inventory_panel = InventoryPanelScene.instantiate() as Control
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)


func _on_run_health_changed(health: int) -> void:
	if battle_health_hud != null and battle_health_hud.has_method("set_health"):
		battle_health_hud.call("set_health", health)


func _on_run_failed() -> void:
	if skill_controller != null:
		skill_controller.cancel_active_skill("run_failed")
		skill_controller.clear_projectiles()
	if marble_chain != null and is_instance_valid(marble_chain):
		marble_chain.queue_free()
	marble_chain = null
	if run_failure_panel != null and run_failure_panel.has_method("open_failure"):
		run_failure_panel.call("open_failure")


func _on_failure_restart_requested() -> void:
	if _restart_in_progress or run_controller == null or not run_controller.run_is_failed:
		return
	_restart_in_progress = true
	run_controller.start_run()
	if run_failure_panel != null and run_failure_panel.has_method("close_failure"):
		run_failure_panel.call("close_failure")
	_restart_in_progress = false


func _on_floor_changed(floor_number: int) -> void:
	if floor_hud != null and floor_hud.has_method("set_floor"):
		floor_hud.call("set_floor", floor_number)


func _sync_battle_hud_gold() -> void:
	if run_scope != null and run_scope.wallet != null:
		_on_wallet_changed(int(run_scope.wallet.call("balance")))


func _connect_wallet_changed() -> void:
	if run_scope == null or run_scope.wallet == null:
		return
	_connect_once(run_scope.wallet, &"changed", Callable(self, "_on_wallet_changed"))


func _on_wallet_changed(value: int) -> void:
	if battle_health_hud != null and battle_health_hud.has_method("set_gold"):
		battle_health_hud.call("set_gold", value)


func _connect_run_signal(source: Object, event_bus: Node, signal_name: StringName) -> void:
	if source == null or event_bus == null:
		return
	if not source.has_signal(signal_name) or not event_bus.has_signal(signal_name):
		return

	if signal_name == &"run_completed":
		var no_arg_callable: Callable = func() -> void:
			event_bus.emit_signal(signal_name)
		if not source.is_connected(signal_name, no_arg_callable):
			source.connect(signal_name, no_arg_callable)
		return

	var one_arg_callable: Callable = func(value: String) -> void:
		event_bus.emit_signal(signal_name, value)
	if not source.is_connected(signal_name, one_arg_callable):
		source.connect(signal_name, one_arg_callable)
