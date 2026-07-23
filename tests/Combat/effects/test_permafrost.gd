extends GutTest

## 问题来源：永冻与 Frozen 的“冰球”语义重复，设计改为仅延长冻结时间。
## 修复策略：等级在一次新的冻结上各追加 1/2/3 秒；边界覆盖重复刷新不重复追加。

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

var _effect_manager: Node = null
var _loadout: RefCounted = null
var _progression: RefCounted = null


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		_configure_relics([])
	_effect_manager = null
	_loadout = null
	_progression = null


func test_levels_extend_each_new_freeze_by_configured_seconds_without_ice_ball_side_effects() -> void:
	# 问题来源：永冻此前放大并登记“冰球”。修复应只追加 1/2/3 秒到 Frozen。
	# 边界：同一 Frozen 被刷新时不能重复追加，且不改变 scale/meta。
	for level: int in [1, 2, 3]:
		_configure_relics(["permafrost"])
		_permafrost().set_level(level)
		var enemy: Enemy = _enemy()
		var base_scale: Vector2 = enemy.scale
		_freeze(enemy)
		assert_almost_eq(
			enemy.buff_host.get_buff_remaining_time("frozen_debuff"), 4.0 + float(level), 0.01,
			"level %d appends exactly its configured freeze duration" % level
		)
		assert_eq(enemy.scale, base_scale, "permafrost must not resize a frozen enemy")
		assert_false(enemy.has_meta(&"ice_ball"), "permafrost must not create an ice-ball marker")
		enemy.add_buff(_frozen_def())
		assert_almost_eq(
			enemy.buff_host.get_buff_remaining_time("frozen_debuff"), 4.0 + float(level), 0.01,
			"refreshing Frozen restores the same level-adjusted duration"
		)
		_configure_relics([])


func test_awakened_impact_extends_current_freeze_by_two_point_five_seconds() -> void:
	# 问题来源：觉醒效果原本给被撞目标施 Frost。修复应延长碰撞者当前 Frozen。
	# 边界：非觉醒碰撞不延时；延时必须追加而非重新应用 Frozen。
	_configure_relics(["permafrost"])
	var enemy: Enemy = _enemy()
	var target: Enemy = _enemy()
	_freeze(enemy)
	var before: float = enemy.buff_host.get_buff_remaining_time("frozen_debuff")
	_effect_manager.on_frozen_body_impact(enemy, target, Vector2.ZERO, &"enemy")
	assert_almost_eq(
		enemy.buff_host.get_buff_remaining_time("frozen_debuff"), before, 0.01,
		"non-awakened permafrost does not extend freeze on impact"
	)
	_permafrost().set_awakened(true)
	_effect_manager.on_frozen_body_impact(enemy, target, Vector2.ZERO, &"enemy")
	_effect_manager.on_frozen_body_impact(enemy, target, Vector2.ZERO, &"enemy")
	assert_almost_eq(
		enemy.buff_host.get_buff_remaining_time("frozen_debuff"), before + 5.0, 0.01,
		"each awakened impact adds 2.5 seconds to the current Frozen duration"
	)
	assert_true(enemy.has_buff("frozen_debuff"), "extending duration keeps the same Frozen instance active")


func test_ball_lost_does_not_clear_permafrost_freeze() -> void:
	# 问题来源：永冻曾在本发结束时清理全部冰球。修复后冻结只受自己的持续时间控制。
	# 边界：全局 on_ball_lost 仍可供其他遗物清理投射物，但不得解冻永冻目标。
	_configure_relics(["permafrost"])
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	_effect_manager.on_ball_lost()
	assert_true(enemy.has_buff("frozen_debuff"), "ball loss does not remove permafrost-extended Frozen")


func _configure_relics(relic_ids: Array) -> void:
	_loadout = LoadoutScript.new()
	for relic_id: String in relic_ids:
		var relic := Item.new()
		relic.id = relic_id
		relic.type = Item.ItemType.RELIC
		assert_true(_loadout.call("add", relic), "loadout accepts relic %s" % relic_id)
	_progression = ProgressionScript.new(_loadout)
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	assert_true(_effect_manager.configure(_loadout, _progression))


func _permafrost() -> RefCounted:
	var effect: RefCounted = _effect_manager._active_effects.get(&"permafrost")
	assert_not_null(effect, "permafrost effect should be active")
	return effect


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy


func _frozen_def() -> BuffDef:
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry)
	var frozen_def: BuffDef = registry.call("get_buff_def", "frozen_debuff") as BuffDef
	assert_not_null(frozen_def)
	return frozen_def


func _freeze(enemy: Enemy) -> void:
	enemy.add_buff(_frozen_def())
	assert_true(enemy.has_buff("frozen_debuff"))
