extends Node2D

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
	if event_bus != null and event_bus.has_signal(&"dash_skill_activated"):
		_connect_once(event_bus, &"dash_skill_activated", Callable(self, "_on_dash_skill_activated"))
	_connect_inventory_change()
	_spawn_starting_marbles()

func _on_marble_fell(body: RigidBody2D) -> void:
	var marble: Marble = body as Marble
	if marble == null:
		return
	_spawn_marble(marble)

func _on_dash_skill_activated() -> void:
	var marble: Marble = _get_active_marble()
	if marble == null:
		return
	if $Enemies.get_child_count() <= 0:
		return

	var target: Vector2 = _find_nearest_enemy(marble.global_position)
	var direction: Vector2 = (target - marble.global_position).normalized()
	marble.dash_toward(direction)


func _get_active_marble() -> Marble:
	for child: Node in marbles.get_children():
		if child is Marble:
			return child
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

func _spawn_marble(marble: Marble) -> void:
	var spec: MarbleSpec = _get_next_marble_spec(marble)
	if spec == null or spec.scene == null:
		return

	var new_marble: RigidBody2D = spec.scene.instantiate()
	new_marble.position = marble.init_position
	marbles.call_deferred("add_child", new_marble)


func _spawn_marble_from_spec(spec: MarbleSpec, spawn_position: Vector2) -> void:
	if spec == null or spec.scene == null:
		return
	var new_marble: RigidBody2D = spec.scene.instantiate()
	new_marble.position = spawn_position
	marbles.add_child(new_marble)


func _get_next_marble_spec(marble: Marble) -> MarbleSpec:
	var specs: Array[MarbleSpec] = _get_inventory_marble_specs()
	if specs.is_empty():
		return _get_default_marble_spec()
	if marble != null:
		for spec in specs:
			if spec.marble_type == marble.marble_type:
				return spec
	return specs[0]


func _spawn_starting_marbles() -> void:
	if marbles == null:
		return

	var specs: Array[MarbleSpec] = _get_inventory_marble_specs()
	if specs.is_empty():
		var default_spec := _get_default_marble_spec()
		if default_spec != null:
			specs.append(default_spec)

	for index: int in range(specs.size()):
		_spawn_marble_from_spec(specs[index], _get_starting_spawn_position(index))


func _on_inventory_changed() -> void:
	_spawn_missing_marbles()


func _spawn_missing_marbles() -> void:
	if marbles == null:
		return

	var specs: Array[MarbleSpec] = _get_inventory_marble_specs()
	if specs.is_empty():
		return

	for index: int in range(specs.size()):
		if not _has_marble_of_type(specs[index].marble_type):
			_spawn_marble_from_spec(specs[index], _get_starting_spawn_position(index))


func _has_marble_of_type(marble_type: Marble.MARBLE_TYPE) -> bool:
	for child: Node in marbles.get_children():
		if child is Marble and child.marble_type == marble_type:
			return true
	return false


func _connect_inventory_change() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory != null and inventory.has_signal(&"inventory_changed"):
		_connect_once(inventory, &"inventory_changed", Callable(self, "_on_inventory_changed"))


func _get_starting_spawn_position(index: int) -> Vector2:
	if index >= 0 and index < starting_marble_spawn_positions.size():
		return starting_marble_spawn_positions[index]
	return purchased_marble_spawn_position + Vector2(0, 24 * index)


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
