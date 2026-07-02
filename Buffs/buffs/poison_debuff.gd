extends BuffDef
class_name PoisonDebuff

## Poison debuff applied by GreenMarble.
##
## The debuff owns poison timing, damage, and visual color. Hosts only need to
## expose generic `take_damage()` and `flash_hit_mask()` methods.

const POISON_COLOR: Color = Color(0.2, 1.0, 0.2, 1.0)
const DAMAGE_PER_SECOND: int = 2
const TICK_SECONDS: float = 1.0


func _init() -> void:
	id = "poison_debuff"
	display_name = "Poison"
	description = "Takes 2 damage per second for 10 seconds."
	duration = 10.0
	stackable = false
	max_stacks = 1
	source = BuffSource.CHAIN_MECHANIC
	params = {
		"damage_per_second": DAMAGE_PER_SECOND,
		"flash_color": POISON_COLOR,
	}


func on_apply(host: Node, state: Dictionary) -> void:
	state["tick_accumulator"] = 0.0
	state["hit_flash_color"] = POISON_COLOR
	_flash_host(host)


func on_process(host: Node, state: Dictionary, delta: float) -> void:
	var tick_accumulator: float = float(state.get("tick_accumulator", 0.0)) + delta

	while tick_accumulator >= TICK_SECONDS:
		tick_accumulator -= TICK_SECONDS
		if host.has_method("take_damage"):
			host.call("take_damage", int(params.get("damage_per_second", DAMAGE_PER_SECOND)), _get_flash_color())

	state["tick_accumulator"] = tick_accumulator


func _flash_host(host: Node) -> void:
	if host.has_method("flash_hit_mask"):
		host.call("flash_hit_mask", _get_flash_color())


func _get_flash_color() -> Color:
	var color: Variant = params.get("flash_color", POISON_COLOR)
	return color if color is Color else POISON_COLOR
