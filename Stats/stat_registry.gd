extends RefCounted
class_name StatRegistry

const BASE_DAMAGE: String = "base_damage"
const SEGMENT_DAMAGE: String = "segment_damage"
const MAX_SPEED: String = "max_speed"
const DASH_IMPULSE: String = "dash_impulse"
const DASH_MAX_SPEED: String = "dash_max_speed"
const DASH_DURATION: String = "dash_duration"
const ECHO_STACKS: String = "echo_stacks"
const ECHO_BONUS_DAMAGE: String = "echo_bonus_damage"
const EXPLOSION_RADIUS: String = "explosion_radius"
const EXPLOSION_DAMAGE: String = "explosion_damage"

const DAMAGE_MULTIPLIER: String = "damage_multiplier"
const FINAL_DAMAGE: String = "final_damage"
const DAMAGE_RECEIVED: String = "damage_received"
const CRIT_RATE: String = "crit_rate"
const CRIT_DAMAGE: String = "crit_damage"
const ARMOR: String = "armor"
const ARMOR_PENETRATION: String = "armor_penetration"

const MAX_HEALTH: String = "max_health"
const CURRENT_HEALTH: String = "current_health"
const MOVE_SPEED: String = "move_speed"

const MARBLE_SPEED_MULTIPLIER: String = "marble_speed_multiplier"
const DASH_SPEED_MULTIPLIER: String = "dash_speed_multiplier"

const BOUNCELESS_WALL_BOUNCE: String = "bounceless_wall_bounce"

const SHIELD_CHARGES: String = "shield_charges"
const DODGE_RATE: String = "dodge_rate"

const SELL_PRICE_MULTIPLIER: String = "sell_price_multiplier"
const BUY_PRICE_MULTIPLIER: String = "buy_price_multiplier"

const MARBLE_SLOT_COUNT: String = "marble_slot_count"
const RELIC_SLOT_COUNT: String = "relic_slot_count"

const DEFAULT_STAT_PATHS: Array[String] = [
	"res://Resources/stats/marble/base_damage.tres",
	"res://Resources/stats/marble/segment_damage.tres",
	"res://Resources/stats/marble/max_speed.tres",
	"res://Resources/stats/marble/dash_impulse.tres",
	"res://Resources/stats/marble/dash_max_speed.tres",
	"res://Resources/stats/marble/dash_duration.tres",
	"res://Resources/stats/marble/echo_stacks.tres",
	"res://Resources/stats/marble/echo_bonus_damage.tres",
	"res://Resources/stats/marble/explosion_radius.tres",
	"res://Resources/stats/marble/explosion_damage.tres",
	"res://Resources/stats/combat/damage_multiplier.tres",
	"res://Resources/stats/combat/final_damage.tres",
	"res://Resources/stats/combat/damage_received.tres",
	"res://Resources/stats/combat/crit_rate.tres",
	"res://Resources/stats/combat/crit_damage.tres",
	"res://Resources/stats/combat/armor.tres",
	"res://Resources/stats/combat/armor_penetration.tres",
	"res://Resources/stats/enemy/max_health.tres",
	"res://Resources/stats/enemy/current_health.tres",
	"res://Resources/stats/enemy/move_speed.tres",
	"res://Resources/stats/movement/marble_speed_multiplier.tres",
	"res://Resources/stats/movement/dash_speed_multiplier.tres",
	"res://Resources/stats/physics/bounceless_wall_bounce.tres",
	"res://Resources/stats/defense/shield_charges.tres",
	"res://Resources/stats/defense/dodge_rate.tres",
	"res://Resources/stats/economy/sell_price_multiplier.tres",
	"res://Resources/stats/economy/buy_price_multiplier.tres",
	"res://Resources/stats/capacity/marble_slot_count.tres",
	"res://Resources/stats/capacity/relic_slot_count.tres",
]


static func get_default_stat_paths() -> Array[String]:
	return DEFAULT_STAT_PATHS.duplicate()
