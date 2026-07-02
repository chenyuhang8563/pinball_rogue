extends Node

## Runtime owner for active buffs.
##
## This autoload is independent from EffectManager, but exposes query and
## dispatch hooks that gameplay systems can call when they need buff data.

signal buff_added(buff_id: String, stacks: int)
signal buff_removed(buff_id: String)
signal buff_stack_changed(buff_id: String, new_stacks: int)
signal buff_expired(buff_id: String)

const BuffRegistryScript: GDScript = preload("res://Buffs/buff_registry.gd")

class BuffInstance:
	var definition: BuffDef
	var remaining_time: float
	var stacks: int
	var effect: RefCounted

	func _init(buff_def: BuffDef, initial_stacks: int) -> void:
		definition = buff_def
		remaining_time = buff_def.duration
		stacks = clampi(initial_stacks, 1, max(1, buff_def.max_stacks))
		if buff_def.effect_script != null:
			effect = buff_def.effect_script.new()

	func refresh_duration() -> void:
		remaining_time = definition.duration

	func is_permanent() -> bool:
		return definition.is_permanent()

var active_buffs: Dictionary = {}

var _registry: Node


func _ready() -> void:
	_registry = _get_registry()
	set_process(true)

	var event_bus: Node = get_node_or_null("/root/Event")
	if event_bus != null:
		_connect_event_bus(event_bus)


func _process(delta: float) -> void:
	var expired_ids: Array[String] = []

	for buff_id: String in active_buffs.keys():
		var instance: BuffInstance = active_buffs[buff_id] as BuffInstance
		if instance == null or instance.is_permanent():
			continue
		instance.remaining_time -= delta
		if instance.remaining_time <= 0.0:
			expired_ids.append(buff_id)

	for buff_id: String in expired_ids:
		active_buffs.erase(buff_id)
		buff_expired.emit(buff_id)
		buff_removed.emit(buff_id)


func add_buff(buff_id: String, stacks: int = 1) -> void:
	var buff_def: BuffDef = _get_buff_def(buff_id)
	if buff_def == null:
		push_warning("BuffManager.add_buff: unknown buff '%s'" % buff_id)
		return

	var requested_stacks: int = max(1, stacks)
	if active_buffs.has(buff_id):
		_apply_existing_buff(buff_id, requested_stacks)
		return

	var instance: BuffInstance = BuffInstance.new(buff_def, requested_stacks)
	active_buffs[buff_id] = instance
	buff_added.emit(buff_id, instance.stacks)


func remove_buff(buff_id: String) -> void:
	if not active_buffs.has(buff_id):
		return
	active_buffs.erase(buff_id)
	buff_removed.emit(buff_id)


func has_buff(buff_id: String) -> bool:
	return active_buffs.has(buff_id)


func get_buff_stacks(buff_id: String) -> int:
	if not active_buffs.has(buff_id):
		return 0
	var instance: BuffInstance = active_buffs[buff_id] as BuffInstance
	return instance.stacks if instance != null else 0


func get_damage_multiplier() -> float:
	var multiplier: float = 1.0
	for value: Variant in active_buffs.values():
		var instance: BuffInstance = value as BuffInstance
		if instance == null:
			continue
		var bonus: float = float(instance.definition.params.get("damage_bonus", 0.0))
		if bonus != 0.0:
			multiplier += bonus * float(instance.stacks)
	return multiplier


func get_speed_multiplier() -> Dictionary:
	var multipliers: Dictionary = {
		"marble": 1.0,
		"dash": 1.0,
	}
	for value: Variant in active_buffs.values():
		var instance: BuffInstance = value as BuffInstance
		if instance == null:
			continue
		var marble_multiplier: float = float(instance.definition.params.get("marble_speed_multiplier", 1.0))
		var dash_multiplier: float = float(instance.definition.params.get("dash_speed_multiplier", 1.0))
		multipliers["marble"] *= pow(marble_multiplier, instance.stacks)
		multipliers["dash"] *= pow(dash_multiplier, instance.stacks)
	return multipliers


func get_shield_charges() -> int:
	var total: int = 0
	for value: Variant in active_buffs.values():
		var instance: BuffInstance = value as BuffInstance
		if instance == null:
			continue
		total += int(instance.definition.params.get("shield_charges", 0)) * instance.stacks
	return total


func dispatch(method_name: StringName, args: Array = []) -> void:
	for value: Variant in active_buffs.values():
		var instance: BuffInstance = value as BuffInstance
		if instance == null or instance.effect == null:
			continue
		if instance.effect.has_method(method_name):
			instance.effect.callv(method_name, args)


func _apply_existing_buff(buff_id: String, requested_stacks: int) -> void:
	var instance: BuffInstance = active_buffs[buff_id] as BuffInstance
	if instance == null:
		active_buffs.erase(buff_id)
		add_buff(buff_id, requested_stacks)
		return

	if instance.definition.stackable:
		var old_stacks: int = instance.stacks
		instance.stacks = clampi(instance.stacks + requested_stacks, 1, max(1, instance.definition.max_stacks))
		if instance.stacks != old_stacks:
			buff_stack_changed.emit(buff_id, instance.stacks)
	else:
		instance.refresh_duration()
		buff_stack_changed.emit(buff_id, instance.stacks)


func _get_buff_def(buff_id: String) -> BuffDef:
	if _registry == null:
		_registry = _get_registry()
	if _registry == null or not _registry.has_method("get_buff_def"):
		return null
	return _registry.call("get_buff_def", buff_id) as BuffDef


func _get_registry() -> Node:
	var autoload_registry: Node = get_node_or_null("/root/BuffRegistry")
	if autoload_registry != null:
		return autoload_registry
	return BuffRegistryScript.new()


func _connect_event_bus(event_bus: Node) -> void:
	var enemy_killed_callable := Callable(self, "_on_enemy_killed")
	if event_bus.has_signal(&"enemy_killed") and not event_bus.is_connected(&"enemy_killed", enemy_killed_callable):
		event_bus.connect(&"enemy_killed", enemy_killed_callable)

	var wave_completed_callable := Callable(self, "_on_wave_completed")
	if event_bus.has_signal(&"wave_completed") and not event_bus.is_connected(&"wave_completed", wave_completed_callable):
		event_bus.connect(&"wave_completed", wave_completed_callable)

	var chain_collision_callable := Callable(self, "_on_chain_collision")
	if event_bus.has_signal(&"chain_collision") and not event_bus.is_connected(&"chain_collision", chain_collision_callable):
		event_bus.connect(&"chain_collision", chain_collision_callable)


func _on_enemy_killed(enemy: Node2D) -> void:
	dispatch(&"on_enemy_killed", [enemy])


func _on_wave_completed(wave: int) -> void:
	dispatch(&"on_wave_completed", [wave])


func _on_chain_collision(collider: Node, collision_type: String) -> void:
	dispatch(&"on_chain_collision", [collider, collision_type])
