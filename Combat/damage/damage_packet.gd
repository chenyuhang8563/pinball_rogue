class_name DamagePacket
extends RefCounted

## Immutable-by-convention payload shared by the damage pipeline and neutral
## combat hooks.  Only `target` and `final_amount` are written by resolution.

var source: StringName = &"untyped"
var element: StringName = &"physical"
var base: float = 0.0
var flat: float = 0.0
var is_dot: bool = false
var is_skill: bool = false
var is_relic: bool = false
var is_crit_eligible: bool = false
var is_echo: bool = false
var is_marble: bool = false
## 环境/规则型固定伤害使用此标记绕过全局倍率、护甲与受伤修正。
var bypasses_damage_modifiers: bool = false
var proc_coefficient: float = 1.0
var generation: int = 0
var target: Node2D = null
var final_amount: int = 0
var flash_color: Color = Color.WHITE
var floating_style: StringName = &"default"
# Weak-point crit metadata. Resolved on the enemy side (it owns the contact
# direction); the pipeline applies `crit_multiplier` after the legacy formula.
# Defaults keep non-crit packets bit-identical to the pre-crit behavior.
var is_crit: bool = false
var crit_multiplier: float = 1.0
var crit_source: StringName = &""
var is_perfect_crit: bool = false
# Immediate-damage multiplier supplied by relic effects. Defaults preserve every
# existing packet's rounding behaviour.
var damage_multiplier: float = 1.0
# A non-zero id groups a multi-target hit into one logical event.  Zero means a
# self-contained single-target event.
var event_id: int = 0
var is_event_main: bool = true
# Direction of the consumed weak point, used by prism generation to avoid it.
var crit_direction: int = -1

static var _next_event_id: int = 1


func _init(
	p_source: StringName = &"untyped",
	p_base: float = 0.0,
	p_element: StringName = &"physical"
) -> void:
	source = p_source
	base = p_base
	element = p_element


static func next_event_id() -> int:
	var result: int = _next_event_id
	_next_event_id += 1
	if _next_event_id <= 0:
		_next_event_id = 1
	return result


## Deliberately source-based: metadata such as `is_marble` must not let future
## DOT/status packets accidentally inherit the marble-chain global multiplier.
func applies_global_multiplier() -> bool:
	return source == &"marble_head" \
		or source == &"chain_segment" \
		or source == &"bomb"
