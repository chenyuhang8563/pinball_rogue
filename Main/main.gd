extends Node2D

@onready var marbles: Node2D = $Marbles
@export var purchased_marble_spawn_position: Vector2 = Vector2(56, 48)
@export var starting_marble_spawn_positions: Array[Vector2] = [
	Vector2(56, 48),
	Vector2(56, 72),
]

## 链重生时的基准生成位置。
@export var chain_spawn_position: Vector2 = Vector2(56, 48)

## 当前活跃的弹珠链。由 _spawn_chain() 创建，整条链只有一个 RigidBody2D（Head）。
var marble_chain: MarbleChain = null


func _ready() -> void:
	var event_bus: Node = _get_autoload_node(&"Event")
	if event_bus != null and event_bus.has_signal(&"marble_fell"):
		_connect_once(event_bus, &"marble_fell", Callable(self, "_on_marble_fell"))
	if event_bus != null and event_bus.has_signal(&"dash_skill_activated"):
		_connect_once(event_bus, &"dash_skill_activated", Callable(self, "_on_dash_skill_activated"))
	_connect_inventory_change()
	_spawn_chain()


# ---- 链生成 ----

## 用库存中的弹珠规格构建 MarbleChain。
## Head 永远为 DEFAULT（Dark），Body 段按 chain_order 排序。
func _spawn_chain() -> void:
	if marbles == null:
		return

	# 清理旧链
	if marble_chain != null and is_instance_valid(marble_chain):
		marble_chain.queue_free()
	marble_chain = null

	var specs: Array = _get_chain_specs()
	if specs.is_empty():
		return

	marble_chain = MarbleChain.new()
	marble_chain.name = "MarbleChain"
	marbles.add_child(marble_chain)
	marble_chain.build_chain(specs, chain_spawn_position)


## 获取按 chain_order 排序的规格列表：Head 第一位，Body 段按 chain_order 升序。
## 确保 dark marble 始终作为 Head（即使库存中没有）。
func _get_chain_specs() -> Array:
	var raw_specs: Array[MarbleSpec] = _get_inventory_marble_specs()

	# 确保 dark marble 始终存在作为 Head
	var has_dark: bool = false
	for spec in raw_specs:
		if spec.marble_type == Marble.MARBLE_TYPE.DEFAULT:
			has_dark = true
			break

	if not has_dark:
		var default_spec: MarbleSpec = _get_default_marble_spec()
		if default_spec != null:
			raw_specs.append(default_spec)

	# 排序：chain_order 升序（-1 head first, 0, 1, 2...）
	raw_specs.sort_custom(func(a: MarbleSpec, b: MarbleSpec): return a.chain_order < b.chain_order)
	return raw_specs


# ---- 事件处理 ----

## 弹珠掉入 KillZone。Head 仍是 RigidBody2D 且在 "marbles" group，检测逻辑不变。
## 整条链重建而非单独重建一个弹珠。
func _on_marble_fell(body: RigidBody2D) -> void:
	if marble_chain == null or not is_instance_valid(marble_chain):
		return
	# 确认掉落的确实是 Head
	if body == marble_chain.head:
		marble_chain.queue_free()
		marble_chain = null
		# 延迟到物理帧结束后再重建链，避免在 flush queries 阶段操作物理体
		call_deferred(&"_spawn_chain")


## Dash 技能激活。仅瞄准 Head（链中唯一物理体）。
func _on_dash_skill_activated() -> void:
	if marble_chain == null or not is_instance_valid(marble_chain):
		return
	var head_marble: Marble = marble_chain.head
	if head_marble == null or not is_instance_valid(head_marble):
		return
	if $Enemies.get_child_count() <= 0:
		return

	var target: Vector2 = _find_nearest_enemy(head_marble.global_position)
	var direction: Vector2 = (target - head_marble.global_position).normalized()
	head_marble.dash_toward(direction)


func _on_inventory_changed() -> void:
	_spawn_chain()


# ---- 辅助方法 ----

## 返回链的 Head（Dash 等系统使用）。
func _get_active_marble() -> Marble:
	if marble_chain != null and is_instance_valid(marble_chain):
		return marble_chain.head
	return null


func _find_nearest_enemy(from: Vector2) -> Vector2:
	var nearest_pos: Vector2 = Vector2.ZERO
	var nearest_dist: float = INF
	for enemy: Node in $Enemies.get_children():
		if enemy is Node2D:
			var pos: Vector2 = enemy.global_position
			var dist: float = from.distance_squared_to(pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_pos = pos
	return nearest_pos


func _get_inventory_marble_specs() -> Array[MarbleSpec]:
	var specs: Array[MarbleSpec] = []
	var inventory: Node = _get_autoload_node(&"Inventory")
	var effect_registry: Node = _get_autoload_node(&"EffectRegistry")
	if inventory == null or effect_registry == null:
		return specs

	var owned_effects: Array = effect_registry.get_marble_effect_types(inventory)
	for effect_type in owned_effects:
		var spec: MarbleSpec = effect_registry.get_marble_spec(effect_type)
		if spec != null and spec.scene != null:
			specs.append(spec)
	return specs


func _get_default_marble_spec() -> MarbleSpec:
	var effect_registry: Node = _get_autoload_node(&"EffectRegistry")
	if effect_registry == null:
		return null
	return effect_registry.get_marble_spec(Item.EffectType.DARK_MARBLE)


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
