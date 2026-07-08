extends Node
class_name BuffHost

## Runtime component that owns active buffs for a single host node.
##
## Buff definitions own their effect logic. The host node only needs to expose
## the methods those buffs call, such as `take_damage()` or `flash_hit_mask()`.

class ActiveBuff:
	var definition: BuffDef
	var remaining_time: float
	var stacks: int
	var state: Dictionary

	func _init(buff_def: BuffDef, initial_stacks: int = 1) -> void:
		definition = buff_def
		remaining_time = buff_def.duration
		stacks = clampi(initial_stacks, 1, max(1, buff_def.max_stacks))
		state = {}

	func is_permanent() -> bool:
		return definition.is_permanent()

var _active_buffs: Dictionary = {}

@onready var _host: Node = get_parent()


func _process(delta: float) -> void:
	_process_active_buffs(delta)


func add_buff(buff: BuffDef, stacks: int = 1) -> void:
	if buff == null or buff.id == "":
		return

	var requested_stacks: int = max(1, stacks)
	if _active_buffs.has(buff.id):
		var existing: ActiveBuff = _active_buffs[buff.id] as ActiveBuff
		if existing == null:
			_active_buffs.erase(buff.id)
		else:
			_refresh_buff(existing, requested_stacks)
			return

	var active_buff: ActiveBuff = ActiveBuff.new(buff, requested_stacks)
	_active_buffs[buff.id] = active_buff
	active_buff.state["stacks"] = active_buff.stacks
	active_buff.definition.on_apply(_host, active_buff.state)


func remove_buff(buff_id: String) -> void:
	if not _active_buffs.has(buff_id):
		return
	var active_buff: ActiveBuff = _active_buffs[buff_id] as ActiveBuff
	if active_buff != null:
		active_buff.definition.on_remove(_host, active_buff.state)
	_active_buffs.erase(buff_id)


func has_buff(buff_id: String) -> bool:
	return _active_buffs.has(buff_id)


func get_buff_stacks(buff_id: String) -> int:
	var active_buff: ActiveBuff = _active_buffs.get(buff_id) as ActiveBuff
	return active_buff.stacks if active_buff != null else 0


func get_active_flash_color() -> Color:
	for value: Variant in _active_buffs.values():
		var active_buff: ActiveBuff = value as ActiveBuff
		if active_buff == null:
			continue
		var color: Variant = active_buff.state.get("hit_flash_color", null)
		if color is Color:
			return color
	return Color.WHITE


func _refresh_buff(active_buff: ActiveBuff, stacks: int) -> void:
	if active_buff.definition.stackable:
		active_buff.stacks = clampi(active_buff.stacks + stacks, 1, max(1, active_buff.definition.max_stacks))
	active_buff.remaining_time = active_buff.definition.duration
	active_buff.state["stacks"] = active_buff.stacks
	active_buff.definition.on_apply(_host, active_buff.state)


func _process_active_buffs(delta: float) -> void:
	var expired_buff_ids: Array[String] = []

	for buff_id: String in _active_buffs.keys():
		var active_buff: ActiveBuff = _active_buffs[buff_id] as ActiveBuff
		if active_buff == null:
			expired_buff_ids.append(buff_id)
			continue

		active_buff.state["stacks"] = active_buff.stacks
		active_buff.definition.on_process(_host, active_buff.state, delta)
		if active_buff.is_permanent():
			continue

		active_buff.remaining_time -= delta
		if active_buff.remaining_time <= 0.0:
			expired_buff_ids.append(buff_id)

	for buff_id: String in expired_buff_ids:
		remove_buff(buff_id)
