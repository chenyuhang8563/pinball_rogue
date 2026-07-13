extends Node2D

const RunControllerScript: GDScript = preload("res://Run/run_controller.gd")
const NodeChoicePanelScene: PackedScene = preload("res://UI/node_choice_panel.tscn")
const DraftRewardPanelScene: PackedScene = preload("res://UI/draft_reward_panel.tscn")
const RunEventPanelScene: PackedScene = preload("res://UI/run_event_panel.tscn")
const BattleHealthHudScene: PackedScene = preload("res://UI/battle_health_hud.tscn")
const InventoryPanelScene: PackedScene = preload("res://UI/inventory_panel.tscn")
const PausePanelScene: PackedScene = preload("res://UI/pause_panel.tscn")

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
var run_controller: RunController = null
var battle_health_hud: Node = null
var inventory_panel: Control = null
var _active_skill_blocking_panels: Array[Node] = []


func _ready() -> void:
	var event_bus: Node = _get_autoload_node(&"Event")
	if event_bus != null and event_bus.has_signal(&"marble_fell"):
		_connect_once(event_bus, &"marble_fell", Callable(self, "_on_marble_fell"))
	_connect_inventory_change()
	_spawn_chain()
	_setup_skill_system()
	_setup_run_flow()


# ---- 链生成 ----

## 用库存中的弹珠 Item 构建 MarbleChain。
## Head 永远为 DEFAULT（Dark），Body 段按 Shop 槽位顺序排序。
func _spawn_chain() -> void:
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


## 获取按 Shop MarbleBox 槽位从左到右排序的 Item 列表。
## 生成时该顺序映射到出生点自下而上，Head 始终使用 dark marble。
func _get_chain_items() -> Array[Item]:
	var ordered_items: Array[Item] = _get_shop_marble_box_items()
	if ordered_items.is_empty():
		ordered_items = _get_inventory_marble_items()

	var head_item: Item = null
	var body_items: Array[Item] = []
	for item: Item in ordered_items:
		if item == null or item.type != Item.ItemType.MARBLE:
			continue
		if item.marble_type == Marble.MARBLE_TYPE.DEFAULT and head_item == null:
			head_item = item
		else:
			body_items.append(item)

	if head_item == null:
		head_item = _get_default_marble_item()

	var result: Array[Item] = []
	if head_item != null:
		result.append(head_item)
	result.append_array(body_items)
	return result


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


## Dash 技能激活。仅瞄准 Head（链中唯一物理体）。
func _on_inventory_changed() -> void:
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


func _setup_skill_system() -> void:
	if skill_controller == null:
		return
	skill_controller.head_provider = Callable(self, "_get_active_marble")
	skill_controller.projectile_parent_provider = Callable(self, "_get_skill_projectile_parent")
	if active_skill_slot == null:
		return
	active_skill_slot.bind_controller(skill_controller)
	if not active_skill_slot.skill_pressed.is_connected(skill_controller.press_active_skill):
		active_skill_slot.skill_pressed.connect(skill_controller.press_active_skill)
	if not active_skill_slot.skill_released.is_connected(skill_controller.release_active_skill):
		active_skill_slot.skill_released.connect(skill_controller.release_active_skill)


func _get_skill_projectile_parent() -> Node:
	return self


func _get_shop_marble_box_items() -> Array[Item]:
	var items: Array[Item] = []
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null:
		return items

	var marble_box: Node = shop.get_node_or_null("UI/Panel/CollectionRows/MarbleBox")
	if marble_box == null:
		return items

	for index: int in range(marble_box.get_child_count()):
		var slot: Node = marble_box.get_child(index)
		if not slot.has_meta("item"):
			continue
		var item: Item = slot.get_meta("item") as Item
		if item != null and item.type == Item.ItemType.MARBLE:
			items.append(item)
	return items


func _get_inventory_marble_items() -> Array[Item]:
	var items: Array[Item] = []
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		return items

	var raw_marble_items: Variant = inventory.get("marble_items")
	if not raw_marble_items is Array:
		return items

	var marble_items: Array = raw_marble_items
	for item: Item in marble_items:
		if item != null and item.type == Item.ItemType.MARBLE:
			items.append(item)
	return items


func _get_default_marble_item() -> Item:
	return preload("res://Resources/dark_marble.tres") as Item


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _connect_once(source: Object, signal_name: StringName, callable: Callable) -> void:
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _connect_inventory_change() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory != null and inventory.has_signal(&"inventory_changed"):
		_connect_once(inventory, &"inventory_changed", Callable(self, "_on_inventory_changed"))


func _setup_run_flow() -> void:
	var ui_layer: Node = get_node_or_null("CanvasLayer")
	if ui_layer == null:
		ui_layer = get_node_or_null("CanvsLayer")
	if ui_layer == null:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "RunFlowLayer"
		add_child(ui_layer)

	var node_choice_panel: NodeChoicePanel = NodeChoicePanelScene.instantiate() as NodeChoicePanel
	node_choice_panel.name = "NodeChoicePanel"
	ui_layer.add_child(node_choice_panel)

	var draft_reward_panel: DraftRewardPanel = DraftRewardPanelScene.instantiate() as DraftRewardPanel
	draft_reward_panel.name = "DraftRewardPanel"
	ui_layer.add_child(draft_reward_panel)

	var event_panel: RunEventPanel = RunEventPanelScene.instantiate() as RunEventPanel
	event_panel.name = "RunEventPanel"
	ui_layer.add_child(event_panel)

	_setup_battle_health_hud(ui_layer)
	_setup_pause_panel(ui_layer)
	_setup_inventory_panel()

	run_controller = RunControllerScript.new()
	run_controller.name = "RunController"
	run_controller.level_parent = self
	run_controller.node_choice_panel = node_choice_panel
	run_controller.draft_reward_panel = draft_reward_panel
	run_controller.upgrade_inventory_panel = inventory_panel
	run_controller.event_panel = event_panel
	run_controller.reset_battle_state_callable = Callable(self, "reset_battle_state")
	run_controller.run_health_changed.connect(_on_run_health_changed)
	add_child(run_controller)
	skill_controller.call("_connect_upgrade_system")
	_connect_active_skill_slot_to_battle_flow()

	var event_bus: Node = _get_autoload_node(&"Event")
	if event_bus != null:
		_connect_run_signal(run_controller, event_bus, &"run_node_completed")
		_connect_run_signal(run_controller, event_bus, &"battle_started")
		_connect_run_signal(run_controller, event_bus, &"battle_completed")
		_connect_run_signal(run_controller, event_bus, &"run_completed")

	run_controller.start_run()


func _connect_active_skill_slot_to_battle_flow() -> void:
	if run_controller == null or active_skill_slot == null:
		return
	_connect_once(run_controller, &"battle_started", Callable(active_skill_slot, "on_battle_started"))
	_connect_once(run_controller, &"battle_completed", Callable(active_skill_slot, "on_battle_completed"))

	_active_skill_blocking_panels.clear()
	for panel_path: NodePath in [
		^"CanvasLayer/PausePanel",
		^"CanvasLayer/NodeChoicePanel",
		^"CanvasLayer/DraftRewardPanel",
		^"CanvasLayer/MarbleUpgradePanel",
		^"CanvasLayer/RunEventPanel",
	]:
		_register_active_skill_blocking_panel(get_node_or_null(panel_path))
	if inventory_panel != null:
		_register_active_skill_blocking_panel(inventory_panel.get_node_or_null("UI"))
	var shop: Node = _get_autoload_node(&"Shop")
	if shop != null:
		_register_active_skill_blocking_panel(shop.get_node_or_null("UI"))
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
	_connect_shop_gold_changed()


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


func _sync_battle_hud_gold() -> void:
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null:
		return
	_on_shop_gold_changed(int(shop.get("gold")))


func _connect_shop_gold_changed() -> void:
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null or not shop.has_signal(&"gold_changed"):
		return
	_connect_once(shop, &"gold_changed", Callable(self, "_on_shop_gold_changed"))


func _on_shop_gold_changed(value: int) -> void:
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
