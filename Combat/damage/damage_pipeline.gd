class_name DamagePipeline
extends RefCounted

const STAT_DAMAGE_MULTIPLIER: StringName = &"damage_multiplier"
const MARBLE_CHAIN_ENTITY: StringName = &"marble_chain"
const StatContextScript: GDScript = preload("res://Core/stats/stat_context.gd")


## Resolves only the pre-armor amount. Enemy remains the sole owner of the
## existing damage_received/armor path so legacy mitigation is unchanged.
static func resolve_pre_armor(packet: DamagePacket, stat_system: Node = null) -> int:
	if packet == null:
		return 0
	var raw_amount: float = packet.base + packet.flat
	var resolved: int
	if not packet.applies_global_multiplier() or stat_system == null or not stat_system.has_method("get_stat"):
		resolved = max(0, roundi(raw_amount))
	else:
		# Keep the legacy marble-hit formula boundary intact.  Apart from the current
		# damage_multiplier, formula implementations may inspect the target and event.
		var target_id: String = packet.target.name if packet.target != null else ""
		var context: RefCounted = StatContextScript.new(
			MARBLE_CHAIN_ENTITY,
			target_id,
			"marble_hit",
			{"base_damage": raw_amount, "damage_source": packet.source}
		)
		resolved = max(0, int(stat_system.call("get_stat", "final_damage", MARBLE_CHAIN_ENTITY, context)))

	# Weak-point crits are resolved on the enemy side and expressed as a packet
	# multiplier applied after the legacy result. crit_multiplier defaults to 1.0,
	# so non-crit packets keep the exact legacy rounding boundary.
	return max(0, roundi(float(resolved) * packet.crit_multiplier * packet.damage_multiplier))
