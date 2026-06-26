extends Node2D

const MARBLE_SCENE: PackedScene = preload("../Marbles/marble.tscn")
const BROWN_MARBLE_SCENE: PackedScene = preload("../Marbles/brown_marble.tscn")
const BOMB_MARBLE_SCENE: PackedScene = preload("../Marbles/bomb_marble.tscn")
const MARBLE_EFFECT_TYPES: Dictionary = {
	Item.EffectType.BOMB_MARBLE: Marble.MARBLE_TYPE.BOMB,
}

@onready var marbles: Node2D = $Marbles
@export var purchased_marble_spawn_position: Vector2 = Vector2(56, 48)
@export var starting_marble_spawn_positions: Array[Vector2] = [
	Vector2(56, 48),
	Vector2(56, 72),
]

func _ready() -> void:
	var event_bus: Node = _get_autoload_node(&"Event")
	if event_bus != null and event_bus.has_signal(&"marble_fell"):
		_connect_once(event_bus, &"marble_fell", Callable(self, "_on_marble_fell"))
	_spawn_starting_marbles()

func _on_marble_fell(body: RigidBody2D) -> void:
	var marble: Marble = body as Marble
	if marble == null:
		return
	_spawn_marble(marble)

func _spawn_marble(marble: Marble) -> void:
	var marble_scene: PackedScene = _get_marble_scene_for_type(_get_next_marble_type(marble))

	var new_marble: RigidBody2D = marble_scene.instantiate()
	new_marble.position = marble.init_position
	marbles.call_deferred("add_child", new_marble)


func _spawn_marble_type(marble_type: Marble.MARBLE_TYPE, spawn_position: Vector2) -> void:
	var marble_scene: PackedScene = _get_marble_scene_for_type(marble_type)
	var new_marble: RigidBody2D = marble_scene.instantiate()
	new_marble.position = spawn_position
	marbles.add_child(new_marble)


func _get_next_marble_type(marble: Marble) -> Marble.MARBLE_TYPE:
	var inventory_marble_types: Array[Marble.MARBLE_TYPE] = _get_inventory_marble_types()
	if inventory_marble_types.is_empty():
		return Marble.MARBLE_TYPE.DEFAULT
	if marble != null and inventory_marble_types.has(marble.marble_type):
		return marble.marble_type
	return inventory_marble_types[0]


func _get_marble_scene_for_type(marble_type: Marble.MARBLE_TYPE) -> PackedScene:
	match marble_type:
		Marble.MARBLE_TYPE.BROWN:
			return BROWN_MARBLE_SCENE
		Marble.MARBLE_TYPE.BOMB:
			return BOMB_MARBLE_SCENE
		_:
			return MARBLE_SCENE


func _spawn_starting_marbles() -> void:
	if marbles == null or marbles.get_child_count() > 0:
		return

	var marble_types: Array[Marble.MARBLE_TYPE] = _get_inventory_marble_types()
	if marble_types.is_empty():
		marble_types.append(Marble.MARBLE_TYPE.DEFAULT)

	for index: int in range(marble_types.size()):
		_spawn_marble_type(marble_types[index], _get_starting_spawn_position(index))


func _get_starting_spawn_position(index: int) -> Vector2:
	if index >= 0 and index < starting_marble_spawn_positions.size():
		return starting_marble_spawn_positions[index]
	return purchased_marble_spawn_position + Vector2(0, 24 * index)


func _get_inventory_marble_types() -> Array[Marble.MARBLE_TYPE]:
	var marble_types: Array[Marble.MARBLE_TYPE] = []
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_method("has_effect"):
		return marble_types

	for effect_type: int in MARBLE_EFFECT_TYPES.keys():
		if inventory.call("has_effect", effect_type):
			marble_types.append(MARBLE_EFFECT_TYPES[effect_type])
	return marble_types


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _connect_once(source: Object, signal_name: StringName, callable: Callable) -> void:
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)
