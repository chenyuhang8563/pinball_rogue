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


func _init(
	p_source: StringName = &"untyped",
	p_base: float = 0.0,
	p_element: StringName = &"physical"
) -> void:
	source = p_source
	base = p_base
	element = p_element


## Deliberately source-based: metadata such as `is_marble` must not let future
## DOT/status packets accidentally inherit the marble-chain global multiplier.
func applies_global_multiplier() -> bool:
	return source == &"marble_head" \
		or source == &"chain_segment" \
		or source == &"bomb"
