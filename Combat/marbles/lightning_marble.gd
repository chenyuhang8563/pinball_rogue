extends Marble
class_name LightningMarble

const ARC_DEBUFF_ID: String = "arc_debuff"
const META_DIRECT_HIT: StringName = &"lightning.direct_hit"
const META_ARC_STACKS_BEFORE: StringName = &"lightning.arc_stacks_before"
const META_ORIGIN_POSITION: StringName = &"lightning.origin_position"


## Captures the state before the marble-chain's physical hit resolves. The
## EffectManager consumes this snapshot from on_enemy_hit_resolved, after the
## target has taken the base collision damage.
static func prepare_direct_hit(enemy: Node, packet: DamagePacket) -> void:
	if enemy == null or packet == null:
		return
	# A loadout cannot contain duplicate marble identities, but keeping the first
	# snapshot makes this safe if a test or future mode constructs one manually.
	if bool(packet.metadata.get(META_DIRECT_HIT, false)):
		return
	var stacks_before: int = 0
	if enemy.has_method("get_buff_stacks"):
		stacks_before = int(enemy.call("get_buff_stacks", ARC_DEBUFF_ID))
	packet.metadata[META_DIRECT_HIT] = true
	packet.metadata[META_ARC_STACKS_BEFORE] = stacks_before


func _ready() -> void:
	marble_type = MARBLE_TYPE.LIGHTNING
	super()


func get_hit_damage(target: Node, packet: DamagePacket = null) -> int:
	prepare_direct_hit(target, packet)
	return super(target, packet)
