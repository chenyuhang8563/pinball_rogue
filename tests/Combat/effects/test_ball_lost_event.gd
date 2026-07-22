extends GutTest

## Stage 2 本发边界事件：EffectManager.on_ball_lost 鸭子类型分发给实现了
## on_ball_lost 的活动 Effect（每发一次、可重复），未实现者不受影响。
## Main 接线（Head 落入 KillZone 时调用）见 Game/Bootstrap/main.gd
## _on_accepted_marble_fell（主场景难以单测，以代码审阅 + 运行时验证）。

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")


class BallLostRecorder:
	extends RefCounted
	var ball_lost_calls: int = 0

	func on_ball_lost() -> void:
		ball_lost_calls += 1


class UnrelatedEffect:
	extends RefCounted
	# 刻意不实现 on_ball_lost：验证鸭子类型分发跳过无此方法的 Effect。
	var on_frozen_body_impact_calls: int = 0

	func on_frozen_body_impact(
		_enemy: Node2D, _hit_body: Node2D, _velocity: Vector2, _kind: StringName, _was_ice_ball: bool
	) -> void:
		on_frozen_body_impact_calls += 1


var _effect_manager: Node = null
var _recorder: BallLostRecorder = null


func before_each() -> void:
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	_configure_empty_loadout()
	_recorder = BallLostRecorder.new()
	_effect_manager._active_effects[&"ball_lost_recorder"] = _recorder


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		_configure_empty_loadout()
	_effect_manager = null
	_recorder = null


func test_on_ball_lost_dispatches_once_to_implementing_effect() -> void:
	var unrelated := UnrelatedEffect.new()
	_effect_manager._active_effects[&"unrelated_effect"] = unrelated

	_effect_manager.on_ball_lost()

	assert_eq(_recorder.ball_lost_calls, 1, "implementing effect receives exactly one ball-lost event")
	assert_eq(unrelated.on_frozen_body_impact_calls, 0, "duck-typed dispatch leaves other effects alone")


func test_on_ball_lost_dispatches_independently_per_ball() -> void:
	_effect_manager.on_ball_lost()
	_effect_manager.on_ball_lost()
	_effect_manager.on_ball_lost()
	assert_eq(_recorder.ball_lost_calls, 3, "each ball end dispatches independently")


func _configure_empty_loadout() -> void:
	var empty_loadout: RefCounted = LoadoutScript.new()
	var empty_progression: RefCounted = ProgressionScript.new(empty_loadout)
	_effect_manager.configure(empty_loadout, empty_progression)
