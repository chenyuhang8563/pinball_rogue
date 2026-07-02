extends Node2D

@onready var marbles: Node2D = $Marbles
@export var purchased_marble_spawn_position: Vector2 = Vector2(56, 48)
@export var starting_marble_spawn_positions: Array[Vector2] = [
	Vector2(56, 96),
	Vector2(56, 72),
	Vector2(56, 48),
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
		marble_chain.queue_free()
		marble_chain = null
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
	if inventory == null or not inventory.has("marble_items"):
		return items

	var marble_items: Array = inventory.get("marble_items")
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
