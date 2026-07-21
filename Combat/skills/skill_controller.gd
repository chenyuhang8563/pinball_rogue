extends Node
class_name SkillController

signal skill_changed(item: Item)
signal state_changed(state: State)
signal runtime_changed(current_charges: int, max_charges: int, recharge_progress: float)

enum State {
	IDLE,
	AIMING,
	FIRING,
	RECHARGING,
	CANCELLED,
}

@export var active_skill_action: StringName = &"active_skill"

var state: State = State.IDLE
var equipped_item: Item = null
var definition: SkillDefinition = null
var runtime: SkillRuntime = null
var head_provider: Callable = Callable()
var projectile_parent_provider: Callable = Callable()

var _executor: Node = null
var _dash_damage_timer: Timer = null
var _loadout: RefCounted = null
var _progression: RefCounted = null
var _lifecycle_source: RunFlowController = null
var _battle_started_callable: Callable = Callable()
var _battle_completed_callable: Callable = Callable()
var _run_completed_callable: Callable = Callable()

const DASH_BUFF_SOURCE: String = "dash_skill_damage_buff"
const STAT_ENTITY_MARBLE_CHAIN: String = "marble_chain"
const STAT_DAMAGE_MULTIPLIER: String = "damage_multiplier"
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")


func configure(loadout: RefCounted, progression: RefCounted) -> bool:
	if not _has_port_api(loadout, [&"current_skill"]) \
			or not _has_port_api(progression, [&"get_skill_values"]):
		return false
	_disconnect_port_signals()
	_loadout = loadout
	_progression = progression
	_connect_port_signals()
	_sync_from_loadout(true)
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dash_damage_timer = Timer.new()
	_dash_damage_timer.one_shot = true
	_dash_damage_timer.timeout.connect(_clear_dash_damage_bonus)
	add_child(_dash_damage_timer)
	_connect_port_signals()
	_sync_from_loadout()


func _process(delta: float) -> void:
	if state == State.AIMING:
		if get_tree().paused or _executor == null or not _executor.has_method("has_valid_aim_target"):
			cancel_active_skill("paused_or_executor_missing")
		elif not bool(_executor.call("has_valid_aim_target")):
			cancel_active_skill("head_invalid")
	if get_tree().paused or runtime == null:
		return
	if runtime.advance_recharge(delta) and state == State.RECHARGING and runtime.can_activate():
		_set_state(State.IDLE)
	_emit_runtime_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(active_skill_action):
		return
	if event.is_action_pressed(active_skill_action) and not event.is_echo():
		if press_active_skill():
			get_viewport().set_input_as_handled()
	elif event.is_action_released(active_skill_action):
		if release_active_skill():
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_active_skill("focus_lost")


func _exit_tree() -> void:
	disconnect_lifecycle()
	_disconnect_port_signals()
	cancel_active_skill("exit_tree")
	clear_projectiles()


func equip_skill(item: Item) -> bool:
	if item == null or item.type != Item.ItemType.SKILL or item.skill_definition == null:
		return false
	var next_definition: SkillDefinition = item.skill_definition.duplicate() as SkillDefinition
	if next_definition == null or next_definition.executor_scene == null:
		return false
	_apply_skill_upgrade_values(next_definition)
	cancel_active_skill("skill_replaced")
	_free_executor()
	equipped_item = item
	definition = next_definition
	runtime = SkillRuntime.new(definition.max_charges, definition.recharge_time)
	_executor = definition.executor_scene.instantiate()
	if _executor == null:
		equipped_item = null
		definition = null
		runtime = null
		return false
	add_child(_executor)
	_set_state(State.IDLE)
	skill_changed.emit(equipped_item)
	_emit_runtime_changed()
	return true


func press_active_skill() -> bool:
	if get_tree().paused or runtime == null or definition == null or _executor == null:
		return false
	if state == State.AIMING or state == State.FIRING or not runtime.can_activate():
		return false
	if definition.activation_mode == SkillDefinition.ActivationMode.INSTANT:
		if not _executor.has_method("execute") or not bool(_executor.call("execute", self, definition)):
			return false
		runtime.try_consume_charge()
		_set_idle_or_recharging()
		_emit_runtime_changed()
		return true
	if not _executor.has_method("begin_aim") or not bool(_executor.call("begin_aim", self, definition)):
		return false
	_set_state(State.AIMING)
	return true


func release_active_skill() -> bool:
	if state != State.AIMING or _executor == null or definition == null or runtime == null:
		return false
	_set_state(State.FIRING)
	var fired: bool = _executor.has_method("release_aim") and bool(_executor.call("release_aim", self, definition))
	if fired:
		runtime.try_consume_charge()
	_set_idle_or_recharging()
	_emit_runtime_changed()
	return fired


func cancel_active_skill(_reason: String = "cancelled") -> void:
	if state != State.AIMING and (_executor == null or not _executor.has_method("is_aiming") or not bool(_executor.call("is_aiming"))):
		return
	_set_state(State.CANCELLED)
	if _executor != null and _executor.has_method("cancel_aim"):
		_executor.call("cancel_aim")
	_set_idle_or_recharging()
	_emit_runtime_changed()


func get_active_head() -> Node:
	if not head_provider.is_valid():
		return null
	var value: Variant = head_provider.call()
	return value as Node


func get_projectile_parent() -> Node:
	if projectile_parent_provider.is_valid():
		var provided: Variant = projectile_parent_provider.call()
		if provided is Node and is_instance_valid(provided):
			return provided as Node
	var tree := get_tree()
	return tree.current_scene if tree != null else null


func find_nearest_enemy(from_position: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for candidate: Node in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var enemy := candidate as Node2D
		var distance := from_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest


func get_current_charges() -> int:
	return runtime.current_charges if runtime != null else 0


func get_max_charges() -> int:
	return runtime.max_charges if runtime != null else 0


func get_recharge_progress() -> float:
	return runtime.get_recharge_progress() if runtime != null else 0.0


func get_aim_direction() -> Vector2:
	if state != State.AIMING or _executor == null or not _executor.has_method("get_aim_direction"):
		return Vector2.ZERO
	return _executor.call("get_aim_direction") as Vector2


func clear_projectiles(_unused: Variant = null) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for projectile: Node in tree.get_nodes_in_group("skill_projectiles"):
		if is_instance_valid(projectile):
			projectile.queue_free()


func apply_dash_damage_bonus(multiplier: float, duration: float) -> void:
	if multiplier <= 1.0 or duration <= 0.0:
		return
	var stat_system := _get_autoload_node(&"StatSystem")
	if stat_system == null or not stat_system.has_method("add_modifier"):
		return
	_clear_dash_damage_bonus()
	if stat_system.has_method("register_entity"):
		stat_system.call("register_entity", STAT_ENTITY_MARBLE_CHAIN, [STAT_DAMAGE_MULTIPLIER])
	stat_system.call("add_modifier", STAT_ENTITY_MARBLE_CHAIN, StatModifierScript.new(
		DASH_BUFF_SOURCE,
		STAT_DAMAGE_MULTIPLIER,
		StatModifier.ModOp.MULTIPLY,
		multiplier,
		DASH_BUFF_SOURCE
	))
	if _dash_damage_timer != null:
		_dash_damage_timer.start(duration)


func _set_idle_or_recharging() -> void:
	_set_state(State.RECHARGING if runtime != null and not runtime.can_activate() else State.IDLE)


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)


func _emit_runtime_changed() -> void:
	if runtime == null:
		runtime_changed.emit(0, 0, 0.0)
		return
	runtime_changed.emit(runtime.current_charges, runtime.max_charges, runtime.get_recharge_progress())


func _free_executor() -> void:
	if _executor == null or not is_instance_valid(_executor):
		_executor = null
		return
	remove_child(_executor)
	_executor.free()
	_executor = null


func _sync_from_loadout(force: bool = false) -> void:
	if _loadout == null or not is_instance_valid(_loadout):
		_clear_equipped_skill()
		return
	var item: Item = _loadout.call("current_skill") as Item
	if item == null:
		_clear_equipped_skill()
	elif force or equipped_item == null or equipped_item.id != item.id:
		equip_skill(item)


func _clear_equipped_skill() -> void:
	if equipped_item == null and definition == null and runtime == null and _executor == null:
		return
	cancel_active_skill("skill_removed")
	_free_executor()
	equipped_item = null
	definition = null
	runtime = null
	_set_state(State.IDLE)
	skill_changed.emit(null)
	_emit_runtime_changed()


func _connect_port_signals() -> void:
	var slot_callback := Callable(self, "_on_skill_slot_changed")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"skill_slot_changed") \
			and not _loadout.is_connected(&"skill_slot_changed", slot_callback):
		_loadout.connect(&"skill_slot_changed", slot_callback)
	var progression_callback := Callable(self, "_on_skill_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"skill_progressed") \
			and not _progression.is_connected(&"skill_progressed", progression_callback):
		_progression.connect(&"skill_progressed", progression_callback)


func _disconnect_port_signals() -> void:
	var slot_callback := Callable(self, "_on_skill_slot_changed")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"skill_slot_changed") \
			and _loadout.is_connected(&"skill_slot_changed", slot_callback):
		_loadout.disconnect(&"skill_slot_changed", slot_callback)
	var progression_callback := Callable(self, "_on_skill_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"skill_progressed") \
			and _progression.is_connected(&"skill_progressed", progression_callback):
		_progression.disconnect(&"skill_progressed", progression_callback)


func _on_skill_slot_changed(item: Item) -> void:
	if item == null:
		_clear_equipped_skill()
	else:
		equip_skill(item)


## Attaches lifecycle cleanup to the one typed run-flow owner. Reconfiguring
## always drops the previous source before accepting the replacement.
func configure_lifecycle(source: RunFlowController) -> bool:
	disconnect_lifecycle()
	if source == null:
		return true
	if not is_instance_valid(source):
		return false
	_lifecycle_source = source
	_battle_started_callable = Callable(self, "_on_battle_started")
	_battle_completed_callable = Callable(self, "_on_battle_completed")
	_run_completed_callable = Callable(self, "_on_run_completed")
	if _lifecycle_source.connect(&"battle_started", _battle_started_callable) != OK \
			or _lifecycle_source.connect(&"battle_completed", _battle_completed_callable) != OK \
			or _lifecycle_source.connect(&"run_completed", _run_completed_callable) != OK:
		disconnect_lifecycle()
		return false
	return true


func disconnect_lifecycle() -> void:
	if _lifecycle_source != null and is_instance_valid(_lifecycle_source):
		if _battle_started_callable.is_valid() \
				and _lifecycle_source.is_connected(&"battle_started", _battle_started_callable):
			_lifecycle_source.disconnect(&"battle_started", _battle_started_callable)
		if _battle_completed_callable.is_valid() \
				and _lifecycle_source.is_connected(&"battle_completed", _battle_completed_callable):
			_lifecycle_source.disconnect(&"battle_completed", _battle_completed_callable)
		if _run_completed_callable.is_valid() \
				and _lifecycle_source.is_connected(&"run_completed", _run_completed_callable):
			_lifecycle_source.disconnect(&"run_completed", _run_completed_callable)
	_lifecycle_source = null
	_battle_started_callable = Callable()
	_battle_completed_callable = Callable()
	_run_completed_callable = Callable()


func _on_battle_started(_token: RunFlowToken, _plan: BattlePlan) -> void:
	cancel_active_skill("battle_started")
	clear_projectiles()
	_clear_dash_damage_bonus()


func _on_battle_completed(
	_token: RunFlowToken,
	_battle_id: StringName,
	_plan: BattlePlan
) -> void:
	cancel_active_skill("battle_completed")
	clear_projectiles()
	_clear_dash_damage_bonus()


func _on_run_completed(_token: RunFlowToken) -> void:
	cancel_active_skill("run_completed")
	clear_projectiles()
	_clear_dash_damage_bonus()


func _clear_dash_damage_bonus() -> void:
	var stat_system := _get_autoload_node(&"StatSystem")
	if stat_system != null and stat_system.has_method("remove_modifiers_by_source"):
		stat_system.call("remove_modifiers_by_source", STAT_ENTITY_MARBLE_CHAIN, DASH_BUFF_SOURCE)


func _on_skill_progressed(skill_id: String, _level: int) -> void:
	if equipped_item != null and equipped_item.id == skill_id:
		equip_skill(equipped_item)


func _apply_skill_upgrade_values(target: SkillDefinition) -> void:
	if _progression == null or not is_instance_valid(_progression):
		return
	var values: Variant = _progression.call("get_skill_values", target.id)
	if not values is Dictionary:
		return
	for property_name: String in (values as Dictionary).keys():
		match property_name:
			"recharge_time", "base_damage", "projectile_lifetime", "dash_damage_multiplier", "dash_damage_duration":
				target.set(property_name, values[property_name])


func _has_port_api(port: RefCounted, methods: Array[StringName]) -> bool:
	if port == null or not is_instance_valid(port):
		return false
	for method: StringName in methods:
		if not port.has_method(method):
			return false
	return true


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))
