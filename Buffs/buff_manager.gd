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
const StatModifierScript: GDScript = preload("res://Stats/stat_modifier.gd")

const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_DAMAGE_MULTIPLIER: String = "damage_multiplier"
const STAT_MARBLE_SPEED_MULTIPLIER: String = "marble_speed_multiplier"
const STAT_DASH_SPEED_MULTIPLIER: String = "dash_speed_multiplier"
const STAT_SHIELD_CHARGES: String = "shield_charges"
const OP_ADD: int = 0
const OP_MULTIPLY: int = 1

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
var _battle_session: BattleSession = null
var _marble_chain: MarbleChain = null
var _enemy_defeated_callable: Callable = Callable()
var _chain_collision_callable: Callable = Callable()


func _ready() -> void:
	_registry = _get_registry()
	set_process(true)


func _exit_tree() -> void:
	reconfigure(null, null)


## Replaces the active typed battle sources. Both sources are optional during
## composition, but every non-null source must be live and expose its contract.
func configure(session: BattleSession, chain: MarbleChain) -> bool:
	return reconfigure(session, chain)


func reconfigure(session: BattleSession, chain: MarbleChain) -> bool:
	_disconnect_typed_sources()
	if session != null and not is_instance_valid(session):
		return false
	if chain != null and not is_instance_valid(chain):
		return false
	_battle_session = session
	_marble_chain = chain
	_enemy_defeated_callable = Callable(self, "_on_enemy_defeated")
	_chain_collision_callable = Callable(self, "_on_chain_collision")
	if _battle_session != null:
		if not _battle_session.enemy_defeated.is_connected(_enemy_defeated_callable):
			_battle_session.enemy_defeated.connect(_enemy_defeated_callable)
	if _marble_chain != null:
		if not _marble_chain.chain_collision.is_connected(_chain_collision_callable):
			_marble_chain.chain_collision.connect(_chain_collision_callable)
	return true


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
		_remove_stat_modifiers_for_buff(buff_id)
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
	_sync_stat_modifiers_for_buff(buff_id)
	buff_added.emit(buff_id, instance.stacks)


func remove_buff(buff_id: String) -> void:
	if not active_buffs.has(buff_id):
		return
	_remove_stat_modifiers_for_buff(buff_id)
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
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return float(stat_system.call("get_stat", STAT_DAMAGE_MULTIPLIER, STAT_ENTITY_MARBLE_CHAIN))

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
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return {
			"marble": float(stat_system.call("get_stat", STAT_MARBLE_SPEED_MULTIPLIER, STAT_ENTITY_MARBLE_CHAIN)),
			"dash": float(stat_system.call("get_stat", STAT_DASH_SPEED_MULTIPLIER, STAT_ENTITY_MARBLE_CHAIN)),
		}

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
	var stat_system: Node = _get_stat_system()
	if stat_system != null and stat_system.has_method("get_stat"):
		return int(stat_system.call("get_stat", STAT_SHIELD_CHARGES, STAT_ENTITY_MARBLE_CHAIN))

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
			_sync_stat_modifiers_for_buff(buff_id)
			buff_stack_changed.emit(buff_id, instance.stacks)
	else:
		instance.refresh_duration()
		_sync_stat_modifiers_for_buff(buff_id)
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


func _disconnect_typed_sources() -> void:
	if _battle_session != null and is_instance_valid(_battle_session) \
			and _enemy_defeated_callable.is_valid() \
			and _battle_session.enemy_defeated.is_connected(_enemy_defeated_callable):
		_battle_session.enemy_defeated.disconnect(_enemy_defeated_callable)
	if _marble_chain != null and is_instance_valid(_marble_chain) \
			and _chain_collision_callable.is_valid() \
			and _marble_chain.chain_collision.is_connected(_chain_collision_callable):
		_marble_chain.chain_collision.disconnect(_chain_collision_callable)
	_battle_session = null
	_marble_chain = null
	_enemy_defeated_callable = Callable()
	_chain_collision_callable = Callable()


func _on_enemy_defeated(
	_token: RunFlowToken,
	enemy: Enemy,
	_cause: StringName
) -> void:
	dispatch(&"on_enemy_killed", [enemy])


func _on_chain_collision(collider: Node, collision_type: String) -> void:
	dispatch(&"on_chain_collision", [collider, collision_type])


func _sync_stat_modifiers_for_buff(buff_id: String) -> void:
	_remove_stat_modifiers_for_buff(buff_id)

	var instance: BuffInstance = active_buffs.get(buff_id) as BuffInstance
	if instance == null:
		return

	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("add_modifier"):
		return
	if stat_system.has_method("register_entity"):
		stat_system.call("register_entity", STAT_ENTITY_MARBLE_CHAIN, [
			STAT_DAMAGE_MULTIPLIER,
			STAT_MARBLE_SPEED_MULTIPLIER,
			STAT_DASH_SPEED_MULTIPLIER,
			STAT_SHIELD_CHARGES,
		])

	var source: String = _get_stat_modifier_source(buff_id)
	var damage_bonus: float = float(instance.definition.params.get("damage_bonus", 0.0))
	if damage_bonus != 0.0:
		stat_system.call(
			"add_modifier",
			STAT_ENTITY_MARBLE_CHAIN,
			_make_stat_modifier(
				"%s:damage_multiplier" % source,
				STAT_DAMAGE_MULTIPLIER,
				OP_ADD,
				damage_bonus * float(instance.stacks),
				source
			)
		)

	var marble_speed_multiplier: float = float(instance.definition.params.get("marble_speed_multiplier", 1.0))
	if not is_equal_approx(marble_speed_multiplier, 1.0):
		stat_system.call(
			"add_modifier",
			STAT_ENTITY_MARBLE_CHAIN,
			_make_stat_modifier(
				"%s:marble_speed_multiplier" % source,
				STAT_MARBLE_SPEED_MULTIPLIER,
				OP_MULTIPLY,
				pow(marble_speed_multiplier, instance.stacks),
				source
			)
		)

	var dash_speed_multiplier: float = float(instance.definition.params.get("dash_speed_multiplier", 1.0))
	if not is_equal_approx(dash_speed_multiplier, 1.0):
		stat_system.call(
			"add_modifier",
			STAT_ENTITY_MARBLE_CHAIN,
			_make_stat_modifier(
				"%s:dash_speed_multiplier" % source,
				STAT_DASH_SPEED_MULTIPLIER,
				OP_MULTIPLY,
				pow(dash_speed_multiplier, instance.stacks),
				source
			)
		)

	var shield_charges: int = int(instance.definition.params.get("shield_charges", 0))
	if shield_charges != 0:
		stat_system.call(
			"add_modifier",
			STAT_ENTITY_MARBLE_CHAIN,
			_make_stat_modifier(
				"%s:shield_charges" % source,
				STAT_SHIELD_CHARGES,
				OP_ADD,
				float(shield_charges * instance.stacks),
				source
			)
		)


func _remove_stat_modifiers_for_buff(buff_id: String) -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null or not stat_system.has_method("remove_modifiers_by_source"):
		return
	stat_system.call("remove_modifiers_by_source", STAT_ENTITY_MARBLE_CHAIN, _get_stat_modifier_source(buff_id))


func _make_stat_modifier(
	modifier_id: String,
	stat_id: String,
	operation: int,
	value: float,
	source: String
) -> RefCounted:
	var modifier: RefCounted = StatModifierScript.new()
	modifier.set("id", modifier_id)
	modifier.set("stat_id", stat_id)
	modifier.set("operation", operation)
	modifier.set("value", value)
	modifier.set("source", source)
	return modifier


func _get_stat_modifier_source(buff_id: String) -> String:
	return "buff:%s" % buff_id


func _get_stat_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("StatSystem")
