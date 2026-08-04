# ExplosionContext —— 一次爆炸的事务上下文（RefCounted）。
#
# 多遗物组合不依赖字典遍历顺序：各遗物在 EffectManager.modify_explosion 分发中
# 只对 context 发出"请求"，finalize() 按固定组合层结算：
#   base + flat → × multiplier；radius × radius_multiplier
# 弹药消耗在 finalize() 中确定：min(ammo_before, 1 + extra)。
#
# ammo_before 为扣弹前的快照，由 MarbleChain 在构建 context 时写入；
# 背水/弹药倾泻在扣弹前判定即依赖该快照。

extends RefCounted
class_name ExplosionContext

var center: Vector2 = Vector2.ZERO
var base_damage: int = 0
var base_radius: float = 0.0
## 扣弹前弹药快照。
var ammo_before: int = 0

var _flat_damage: int = 0
var _damage_multiplier: float = 1.0
var _radius_multiplier: float = 1.0
var _extra_ammo: int = 0
var _finalized: bool = false
var _resolved: Dictionary = {}


func add_flat_damage(amount: int) -> void:
	_flat_damage += amount


func multiply_damage(multiplier: float) -> void:
	_damage_multiplier *= maxf(0.0, multiplier)


func multiply_radius(multiplier: float) -> void:
	_radius_multiplier *= maxf(0.0, multiplier)


## 请求额外消耗的弹药（如高爆 +1）。
func request_extra_ammo(amount: int) -> void:
	_extra_ammo = maxi(_extra_ammo, maxi(0, amount))


## 固定组合层结算，幂等（只结算一次）。返回 {"damage", "radius", "ammo_cost"}。
func finalize() -> Dictionary:
	if _finalized:
		return _resolved
	_finalized = true
	var damage: int = roundi(float(base_damage + _flat_damage) * _damage_multiplier)
	var radius: float = base_radius * _radius_multiplier
	var ammo_cost: int = mini(ammo_before, 1 + _extra_ammo)
	_resolved = {
		"damage": maxi(0, damage),
		"radius": radius,
		"ammo_cost": ammo_cost,
	}
	return _resolved
