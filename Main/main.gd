extends Node2D

const MARBLE_SCENE: PackedScene = preload("../Marbles/marble.tscn")
const BROWN_MARBLE_SCENE: PackedScene = preload("../Marbles/brown_marble.tscn")
const BOMB_MARBLE_SCENE: PackedScene = preload("../Marbles/bomb_marble.tscn")

@onready var marbles: Node2D = $Marbles

func _ready() -> void:
    Event.marble_fell.connect(_on_marble_fell)

func _on_marble_fell(marble: RigidBody2D) -> void:
    _spawn_marble(marble)

func _spawn_marble(marble: RigidBody2D) -> void:
    var marble_scene: PackedScene = MARBLE_SCENE
    match marble.marble_type:
        Marble.MARBLE_TYPE.BROWN:
            marble_scene = BROWN_MARBLE_SCENE
        Marble.MARBLE_TYPE.BOMB:
            marble_scene = BOMB_MARBLE_SCENE

    var new_marble: RigidBody2D = marble_scene.instantiate()
    new_marble.position = marble.init_position
    marbles.call_deferred("add_child", new_marble)
