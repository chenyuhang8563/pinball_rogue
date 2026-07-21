class_name BattleSpawner
extends Node

signal enemy_spawned(batch_id: int, entry_index: int, enemy: Enemy)
signal spawn_batch_sealed(batch_id: int, enemy_count: int)
signal spawn_batch_failed(batch_id: int, entry_index: int, reason: StringName)

enum BatchTerminal {
	SEALED,
	FAILED,
}

@export var enemy_container: Node2D

var _live_enemies: Array[Enemy] = []
var _last_batch_id: int = -1
var _last_batch_terminal: BatchTerminal = BatchTerminal.FAILED
var _disposed: bool = false



## Atomic typed batch path. Every Enemy remains outside the SceneTree until the
## whole batch has been prepared and synchronously accepted by register_enemy.
func start_batch(
	group: BattleGroupDef,
	batch_id: int,
	register_enemy: Callable
) -> bool:
	if batch_id <= _last_batch_id:
		return batch_id == _last_batch_id \
			and _last_batch_terminal == BatchTerminal.SEALED
	if _disposed:
		return _fail_batch(batch_id, -1, &"disposed", [])
	if group == null:
		return _fail_batch(batch_id, -1, &"invalid_group", [])
	if not _has_valid_container():
		return _fail_batch(batch_id, -1, &"invalid_container", [])
	if not register_enemy.is_valid():
		return _fail_batch(batch_id, -1, &"invalid_register_callable", [])
	if not _live_enemies.is_empty():
		return _fail_batch(batch_id, -1, &"batch_already_active", [])

	var prepared: Array[Enemy] = []
	if group.enemy_entries.is_empty():
		_record_batch_terminal(batch_id, BatchTerminal.SEALED)
		spawn_batch_sealed.emit(batch_id, 0)
		return true

	# Phase one: instantiate, type-check, and configure every entry.
	for entry_index: int in range(group.enemy_entries.size()):
		var entry: BattleGroupDef.EnemyEntry = group.enemy_entries[entry_index]
		if entry == null:
			return _fail_batch(batch_id, entry_index, &"null_entry", prepared)
		if entry.scene == null:
			return _fail_batch(batch_id, entry_index, &"null_scene", prepared)
		if entry.scene.get_state().get_node_count() == 0:
			return _fail_batch(batch_id, entry_index, &"instantiate_failed", prepared)
		var instance: Node = entry.scene.instantiate()
		if instance == null:
			return _fail_batch(batch_id, entry_index, &"instantiate_failed", prepared)
		if not instance is Enemy:
			instance.free()
			return _fail_batch(batch_id, entry_index, &"root_not_enemy", prepared)
		var enemy: Enemy = instance as Enemy
		_configure_enemy(enemy, entry, entry_index)
		prepared.append(enemy)

	# Phase two: Session must connect defeated and record every live identity.
	for entry_index: int in range(prepared.size()):
		var registration_result: Variant = register_enemy.call(
			batch_id, entry_index, prepared[entry_index]
		)
		if registration_result != true:
			return _fail_batch(batch_id, entry_index, &"registration_rejected", prepared)

	# Commit only after all registrations succeed.
	if not _has_valid_container():
		return _fail_batch(batch_id, -1, &"container_invalidated", prepared)
	for entry_index: int in range(prepared.size()):
		var enemy: Enemy = prepared[entry_index]
		var entry: BattleGroupDef.EnemyEntry = group.enemy_entries[entry_index]
		_live_enemies.append(enemy)
		enemy_container.add_child(enemy)
		enemy.global_position = entry.position
		enemy_spawned.emit(batch_id, entry_index, enemy)

	_record_batch_terminal(batch_id, BatchTerminal.SEALED)
	spawn_batch_sealed.emit(batch_id, prepared.size())
	return true


func clear_enemies() -> void:
	_live_enemies.clear()
	if not _has_valid_container():
		return
	for child: Node in enemy_container.get_children():
		child.free()


func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	clear_enemies()
	_last_batch_id = -1
	_last_batch_terminal = BatchTerminal.FAILED


func _configure_enemy(
	enemy: Enemy,
	entry: BattleGroupDef.EnemyEntry,
	entry_index: int
) -> void:
	enemy.position = entry.position
	enemy.health = entry.health
	enemy.name = "Enemy_%d" % entry_index


func _fail_batch(
	batch_id: int,
	entry_index: int,
	reason: StringName,
	prepared: Array[Enemy]
) -> bool:
	_record_batch_terminal(batch_id, BatchTerminal.FAILED)
	spawn_batch_failed.emit(batch_id, entry_index, reason)
	for enemy: Enemy in prepared:
		_live_enemies.erase(enemy)
		if is_instance_valid(enemy):
			enemy.free()
	return false


func _record_batch_terminal(batch_id: int, terminal: BatchTerminal) -> void:
	_last_batch_id = batch_id
	_last_batch_terminal = terminal


func _has_valid_container() -> bool:
	return enemy_container != null and is_instance_valid(enemy_container) \
		and not enemy_container.is_queued_for_deletion()
