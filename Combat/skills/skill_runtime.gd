extends RefCounted
class_name SkillRuntime

signal charges_changed(current: int, maximum: int)
signal recharge_progress_changed(progress: float)

var max_charges: int
var recharge_time: float
var current_charges: int
var recharge_elapsed: float = 0.0


func _init(p_max_charges: int = 1, p_recharge_time: float = 1.0) -> void:
	max_charges = maxi(1, p_max_charges)
	recharge_time = maxf(0.05, p_recharge_time)
	current_charges = max_charges


func can_activate() -> bool:
	return current_charges > 0


func try_consume_charge() -> bool:
	if not can_activate():
		return false
	current_charges -= 1
	if current_charges < max_charges and recharge_elapsed <= 0.0:
		recharge_elapsed = 0.0
	charges_changed.emit(current_charges, max_charges)
	recharge_progress_changed.emit(get_recharge_progress())
	return true


func advance_recharge(delta: float) -> bool:
	if current_charges >= max_charges or delta <= 0.0:
		return false
	recharge_elapsed += delta
	var restored_charge: bool = false
	while recharge_elapsed >= recharge_time and current_charges < max_charges:
		recharge_elapsed -= recharge_time
		current_charges += 1
		restored_charge = true
		charges_changed.emit(current_charges, max_charges)
	if current_charges >= max_charges:
		recharge_elapsed = 0.0
	recharge_progress_changed.emit(get_recharge_progress())
	return restored_charge


func get_recharge_progress() -> float:
	if current_charges >= max_charges:
		return 1.0
	return clampf(recharge_elapsed / recharge_time, 0.0, 1.0)

