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
const DARK_MARBLE_DAMAGE: String = "dark_marble_damage"
const BLUE_FROST_DURATION: String = "blue_frost_duration"
const BLUE_FROST_BONUS_DAMAGE_ENABLED: String = "blue_frost_bonus_damage_enabled"
const BLUE_FROST_STACKS_PER_HIT: String = "blue_frost_stacks_per_hit"
const POISON_DAMAGE_PER_LAYER: String = "poison_damage_per_layer"
const POISON_MAX_STACKS: String = "poison_max_stacks"
const POISON_STACKS_PER_HIT: String = "poison_stacks_per_hit"
const POISON_TICK_SECONDS: String = "poison_tick_seconds"
const ECHO_TIMEOUT: String = "echo_timeout"
const EXPLOSION_EFFECT_SCALE: String = "explosion_effect_scale"
const FIRE_BURN_MAX_STACKS: String = "fire_burn_max_stacks"
const FIRE_BURN_DAMAGE_PER_LAYER: String = "fire_burn_damage_per_layer"
const FIRE_BURN_TICK_SECONDS: String = "fire_burn_tick_seconds"

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

const RUN_HEALTH: String = "run_health"
const LIGHTNING_CHAIN_DAMAGE: String = "lightning_chain_damage"

const DEFAULT_STAT_PATHS: Array[String] = [
	"res://Core/stats/data/marble/base_damage.tres",
	"res://Core/stats/data/marble/segment_damage.tres",
	"res://Core/stats/data/marble/max_speed.tres",
	"res://Core/stats/data/marble/dash_impulse.tres",
	"res://Core/stats/data/marble/dash_max_speed.tres",
	"res://Core/stats/data/marble/dash_duration.tres",
	"res://Core/stats/data/marble/echo_stacks.tres",
	"res://Core/stats/data/marble/echo_bonus_damage.tres",
	"res://Core/stats/data/marble/explosion_radius.tres",
	"res://Core/stats/data/marble/explosion_damage.tres",
	"res://Core/stats/data/marble/dark_marble_damage.tres",
	"res://Core/stats/data/marble/blue_frost_duration.tres",
	"res://Core/stats/data/marble/blue_frost_bonus_damage_enabled.tres",
	"res://Core/stats/data/marble/blue_frost_stacks_per_hit.tres",
	"res://Core/stats/data/marble/poison_damage_per_layer.tres",
	"res://Core/stats/data/marble/poison_max_stacks.tres",
	"res://Core/stats/data/marble/poison_stacks_per_hit.tres",
	"res://Core/stats/data/marble/poison_tick_seconds.tres",
	"res://Core/stats/data/marble/echo_timeout.tres",
	"res://Core/stats/data/marble/explosion_effect_scale.tres",
	"res://Core/stats/data/marble/fire_burn_max_stacks.tres",
	"res://Core/stats/data/marble/fire_burn_damage_per_layer.tres",
	"res://Core/stats/data/marble/fire_burn_tick_seconds.tres",
	"res://Core/stats/data/combat/damage_multiplier.tres",
	"res://Core/stats/data/combat/final_damage.tres",
	"res://Core/stats/data/combat/damage_received.tres",
	"res://Core/stats/data/combat/crit_rate.tres",
	"res://Core/stats/data/combat/crit_damage.tres",
	"res://Core/stats/data/combat/armor.tres",
	"res://Core/stats/data/combat/armor_penetration.tres",
	"res://Core/stats/data/enemy/max_health.tres",
	"res://Core/stats/data/enemy/current_health.tres",
	"res://Core/stats/data/enemy/move_speed.tres",
	"res://Core/stats/data/movement/marble_speed_multiplier.tres",
	"res://Core/stats/data/movement/dash_speed_multiplier.tres",
	"res://Core/stats/data/physics/bounceless_wall_bounce.tres",
	"res://Core/stats/data/defense/shield_charges.tres",
	"res://Core/stats/data/defense/dodge_rate.tres",
	"res://Core/stats/data/economy/sell_price_multiplier.tres",
	"res://Core/stats/data/economy/buy_price_multiplier.tres",
	"res://Core/stats/data/capacity/marble_slot_count.tres",
	"res://Core/stats/data/capacity/relic_slot_count.tres",
	"res://Core/stats/data/run/run_health.tres",
	"res://Core/stats/data/relic/lightning_chain_damage.tres",
]


static func get_default_stat_paths() -> Array[String]:
	return DEFAULT_STAT_PATHS.duplicate()
