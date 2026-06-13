extends Node2D

const MARBLE_SCENE: PackedScene = preload("../Marbles/marble.tscn")
const BROWN_MARBLE_SCENE: PackedScene = preload("../Marbles/brown_marble.tscn")
const BOMB_MARBLE_SCENE: PackedScene = preload("../Marbles/bomb_marble.tscn")

@onready var marbles: Node2D = $Marbles
@export var purchased_marble_spawn_position: Vector2 = Vector2(56, 48)

func _ready() -> void:
    var event_bus: Node = _get_autoload_node(&"Event")
    if event_bus != null and event_bus.has_signal(&"marble_fell"):
        _connect_once(event_bus, &"marble_fell", Callable(self, "_on_marble_fell"))

    var inventory: Node = _get_autoload_node(&"Inventory")
    if inventory != null and inventory.has_signal(&"item_added"):
        _connect_once(inventory, &"item_added", Callable(self, "_on_item_added"))

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


func _on_item_added(item: Item) -> void:
    if item == null or item.effect_type != Item.EffectType.BOMB_MARBLE:
        return
    _spawn_marble_type(Marble.MARBLE_TYPE.BOMB, purchased_marble_spawn_position)


func _spawn_marble_type(marble_type: Marble.MARBLE_TYPE, spawn_position: Vector2) -> void:
    var marble_scene: PackedScene = _get_marble_scene_for_type(marble_type)
    var new_marble: RigidBody2D = marble_scene.instantiate()
    new_marble.position = spawn_position
    marbles.add_child(new_marble)


func _get_next_marble_type(marble: Marble) -> Marble.MARBLE_TYPE:
    if marble == null:
        return Marble.MARBLE_TYPE.DEFAULT
    return marble.marble_type


func _get_marble_scene_for_type(marble_type: Marble.MARBLE_TYPE) -> PackedScene:
    match marble_type:
        Marble.MARBLE_TYPE.BROWN:
            return BROWN_MARBLE_SCENE
        Marble.MARBLE_TYPE.BOMB:
            return BOMB_MARBLE_SCENE
        _:
            return MARBLE_SCENE


func _get_autoload_node(node_name: StringName) -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    return tree.root.get_node_or_null(NodePath(node_name))


func _connect_once(source: Object, signal_name: StringName, callable: Callable) -> void:
    if not source.is_connected(signal_name, callable):
        source.connect(signal_name, callable)
