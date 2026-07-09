extends BuffDef
class_name FrozenDebuff

const FROZEN_COLOR: Color = Color(0.78, 0.94, 1.0, 1.0)
const DEFAULT_DURATION: float = 4.0


func _init() -> void:
	id = "frozen_debuff"
	display_name = "BUFF_FROZEN_TITLE"
	description = "BUFF_FROZEN_DESC"
	duration = DEFAULT_DURATION
	stackable = false
	max_stacks = 1
	source = BuffSource.CHAIN_MECHANIC
	params = {
		"flash_color": FROZEN_COLOR,
	}


func on_apply(host: Node, state: Dictionary) -> void:
	state["hit_flash_color"] = FROZEN_COLOR
	if host.has_method("set_frozen_visual"):
		host.call("set_frozen_visual", true)
	if host.has_method("begin_frozen_physics"):
		host.call("begin_frozen_physics")
	if host.has_method("flash_hit_mask"):
		host.call("flash_hit_mask", FROZEN_COLOR)


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("end_frozen_physics"):
		host.call("end_frozen_physics")
	if host.has_method("set_frozen_visual"):
		host.call("set_frozen_visual", false)
