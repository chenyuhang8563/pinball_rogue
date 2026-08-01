extends BuffDef
class_name ArcDebuff

const ARC_ID: String = "arc_debuff"
const DURATION_SECONDS: float = 5.0
const HARD_MAX_STACKS: int = 6
const ARC_COLOR: Color = Color(0.45, 0.82, 1.0, 1.0)


func _init() -> void:
	id = ARC_ID
	display_name = "STATUS_ARC_NAME"
	description = "STATUS_ARC_DESC"
	duration = DURATION_SECONDS
	stackable = true
	max_stacks = HARD_MAX_STACKS
	source = BuffSource.CHAIN_MECHANIC
	reapply_policy = ReapplyPolicy.REFRESH


func on_apply(host: Node, state: Dictionary) -> void:
	state["hit_flash_color"] = ARC_COLOR
	_update_visual(host, state)


func on_process(host: Node, state: Dictionary, _delta: float) -> void:
	_update_visual(host, state)


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("clear_arc_visual"):
		host.call("clear_arc_visual")


func _update_visual(host: Node, state: Dictionary) -> void:
	if not host.has_method("set_arc_visual"):
		return
	host.call(
		"set_arc_visual",
		clampi(int(state.get("stacks", 1)), 1, HARD_MAX_STACKS),
		maxf(0.0, float(state.get("remaining_time", DURATION_SECONDS)))
	)
