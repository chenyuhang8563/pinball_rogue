extends Node
class_name BattleSpawner

signal battle_started(group_id: String)
signal battle_completed(group_id: String)

@export var enemy_container: Node2D

var _current_group: BattleGroupDef
var _live_enemies: Array[Node] = []
var _completion_emitted: bool = false


func _ready() -> void:
	var event_bus: Node = _get_event_bus()
	if event_bus != null and event_bus.has_signal(&"enemy_killed"):
		var callable: Callable = Callable(self, "_on_enemy_killed")
		if not event_bus.is_connected(&"enemy_killed", callable):
			event_bus.connect(&"enemy_killed", callable)


func start_battle(group: BattleGroupDef) -> void:
	if enemy_container == null or group == null:
		return

	clear_enemies()
	_current_group = group
	_completion_emitted = false

	for entry: BattleGroupDef.EnemyEntry in group.enemy_entries:
		var enemy: Node = _spawn_enemy(entry)
		if enemy != null:
			_live_enemies.append(enemy)

	battle_started.emit(group.id)
	if _live_enemies.is_empty():
		_complete_battle()


func clear_enemies() -> void:
	_live_enemies.clear()
	_completion_emitted = false
	if enemy_container == null:
		return

	for child: Node in enemy_container.get_children():
		child.queue_free()


func _spawn_enemy(entry: BattleGroupDef.EnemyEntry) -> Node:
	if entry == null or entry.scene == null:
		return null

	var enemy: Node = entry.scene.instantiate()

	if enemy is Node2D:
		(enemy as Node2D).position = entry.position
	if enemy.has_method("set"):
		enemy.set("health", entry.health)
	enemy_container.add_child(enemy)
	if enemy is Node2D:
		(enemy as Node2D).global_position = entry.position
	enemy.name = "Enemy_%d" % _live_enemies.size()

	return enemy


func _on_enemy_killed(enemy: Node2D) -> void:
	if enemy == null:
		return

	var index: int = _live_enemies.find(enemy)
	if index != -1:
		_live_enemies.remove_at(index)

	if _live_enemies.is_empty():
		_complete_battle()


func _complete_battle() -> void:
	if _completion_emitted or _current_group == null:
		return
	_completion_emitted = true
	battle_completed.emit(_current_group.id)


func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Event")
