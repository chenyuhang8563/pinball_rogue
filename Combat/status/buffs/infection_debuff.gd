extends BuffDef
class_name InfectionDebuff

## Permanent infection marker applied by PoisonDebuff once poison stacks reach
## INFECTION_THRESHOLD.
##
## Infection is irreversible while the host is alive: poison may later decay,
## but infection stays. When an infected host dies, the plague domain
## (EffectManager) releases a friendly fly. This buff owns no damage of its own
## — the poison DoT remains the damage source; infection is the control/payoff
## gate.

const INFECTION_ID: String = "infection_debuff"
## Poison stacks required to tip a host into infection.
const INFECTION_THRESHOLD: int = 4


func _init() -> void:
	id = INFECTION_ID
	display_name = "Infection"
	description = "Permanent. The host is infected; when it dies it releases a friendly fly."
	duration = -1.0
	stackable = false
	max_stacks = 1
	source = BuffSource.CHAIN_MECHANIC
	reapply_policy = ReapplyPolicy.IGNORE


func on_apply(host: Node, _state: Dictionary) -> void:
	if host.has_method("set_infection_visual"):
		host.call("set_infection_visual", true)


func on_remove(host: Node, _state: Dictionary) -> void:
	if host.has_method("set_infection_visual"):
		host.call("set_infection_visual", false)
