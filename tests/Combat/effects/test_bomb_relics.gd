extends GutTest

## 5 个炸弹系遗物数值与事件行为：弹药袋 max_ammo 与觉醒加成、
## 回收器概率补弹（固定 seed）、高爆条件产出、背水 1 弹药倍率、
## 弹药倾泻按弹药存量附加伤害。

const AmmoPouchScript: GDScript = preload("res://Combat/effects/ammo_pouch/ammo_pouch.gd")
const AmmoRecyclerScript: GDScript = preload("res://Combat/effects/ammo_recycler/ammo_recycler.gd")
const HighExplosiveScript: GDScript = preload("res://Combat/effects/high_explosive/high_explosive.gd")
const LastShotScript: GDScript = preload("res://Combat/effects/last_shot/last_shot.gd")
const AmmoDumpScript: GDScript = preload("res://Combat/effects/ammo_dump/ammo_dump.gd")
const ExplosionContextScript: GDScript = preload("res://Combat/explosion/explosion_context.gd")
const AmmoStateScript: GDScript = preload("res://Combat/ammo/ammo_state.gd")
const EffectManagerScript: GDScript = preload("res://Combat/effects/effect_manager.gd")
const ProducedMarbleSpawnerScript: GDScript = preload("res://Combat/marbles/produced_marble_spawner.gd")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")
const SmallBombScene: PackedScene = preload("res://Combat/marbles/small_bomb_marble.tscn")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


class FakeLifecycle extends Node:
	signal battle_started(token, plan)

	func emit_start() -> void:
		battle_started.emit(null, null)


class SpySpawner extends Node:
	var spawn_calls: int = 0
	var last_position: Vector2 = Vector2.ZERO
	var last_max_active: int = 0
	var return_null: bool = false
	var spawns: Array[Node] = []


	func spawn(scene: PackedScene, position: Vector2, max_active: int) -> Node:
		spawn_calls += 1
		last_position = position
		last_max_active = max_active
		if return_null:
			return null
		var instance: Node = scene.instantiate()
		add_child(instance)
		instance.global_position = position
		spawns.append(instance)
		return instance


func _ammo_state() -> Node:
	var stats: Node = autofree(FakeStatSystemScript.new())
	var ammo: Node = autofree(AmmoStateScript.new())
	var lifecycle := FakeLifecycle.new()
	add_child_autofree(lifecycle)
	ammo.configure(stats, lifecycle)
	return ammo


## 静态 modifier 遗物写真实 StatSystem autoload（与 test_poison_stat_relics 同模式）。
func _stat(stat_id: String) -> Variant:
	var stats := _stat_system()
	assert_not_null(stats)
	return stats.call("get_stat", stat_id, "player")


func _stat_system() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null


func after_each() -> void:
	var stats := _stat_system()
	if stats == null:
		return
	stats.call("remove_modifier", "player", "relic_upgrade:ammo_pouch")


func _context(ammo_before: int, base_damage: int = 4, radius: float = 75.0) -> ExplosionContext:
	var ctx: ExplosionContext = ExplosionContextScript.new() as ExplosionContext
	ctx.base_damage = base_damage
	ctx.base_radius = radius
	ctx.ammo_before = ammo_before
	ctx.center = Vector2(30, 40)
	return ctx


# ---- 弹药袋 ----

func test_ammo_pouch_raises_max_ammo_by_level_and_dispose_removes() -> void:
	var pouch: RefCounted = AmmoPouchScript.new()
	pouch.set_level(1)
	assert_eq(float(_stat("max_ammo")), 6.0, "Lv1：max_ammo = 5 + 1")
	pouch.set_level(2)
	assert_eq(float(_stat("max_ammo")), 7.0, "Lv2 = 5 + 2")
	pouch.set_level(3)
	assert_eq(float(_stat("max_ammo")), 8.0, "Lv3 = 5 + 3")
	pouch.dispose()
	assert_eq(float(_stat("max_ammo")), 5.0, "dispose 移除 modifier")


func test_ammo_pouch_awakened_sets_battle_start_bonus() -> void:
	var lifecycle := FakeLifecycle.new()
	add_child_autofree(lifecycle)
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(_stat_system(), lifecycle)
	var pouch: RefCounted = AmmoPouchScript.new()
	pouch.set_awakened(true)
	pouch.configure_runtime(ammo)
	assert_eq(ammo.get_max_ammo(), 6, "觉醒不增加上限（仍 Lv1 +1）")
	lifecycle.emit_start()
	assert_eq(ammo.get_ammo(), 8, "觉醒战斗开始弹药 = max + 2")
	pouch.dispose()
	lifecycle.emit_start()
	assert_eq(ammo.get_ammo(), 5, "dispose 清除 bonus 后回到默认")


# ---- 弹药回收器 ----

func test_ammo_recycler_chances_follow_levels_and_awakened() -> void:
	var recycler: RefCounted = AmmoRecyclerScript.new()
	recycler.set_level(1)
	assert_eq(int(recycler.call("_chance")), 10)
	recycler.set_level(2)
	assert_eq(int(recycler.call("_chance")), 20)
	recycler.set_level(3)
	assert_eq(int(recycler.call("_chance")), 30)
	recycler.set_awakened(true)
	assert_eq(int(recycler.call("_chance")), 45, "觉醒 45%")


func test_ammo_recycler_seeded_rng_is_deterministic_and_never_exceeds_max() -> void:
	var ammo := _ammo_state()
	ammo.consume(5)
	var recycler: RefCounted = AmmoRecyclerScript.new()
	recycler.set_level(3)
	recycler.configure_runtime(ammo)

	recycler.seed_rng(20260802)
	for _i: int in range(200):
		recycler.call("on_explosion_resolved", _context(0))
	var after_200: int = ammo.get_ammo()
	assert_eq(after_200, 5, "30% 概率连掷 200 次必然回满，且不超 ceiling")

	ammo.consume(5)
	recycler.seed_rng(20260802)
	for _i: int in range(200):
		recycler.call("on_explosion_resolved", _context(0))
	assert_eq(ammo.get_ammo(), after_200, "相同 seed 序列结果一致")


# ---- 高爆弹头（概率产出小炸弹弹珠）----

func test_high_explosive_chances_follow_levels_and_awakened_unchanged() -> void:
	var he: RefCounted = HighExplosiveScript.new()
	he.set_level(1)
	assert_eq(int(he.call("_chance")), 15, "Lv1 15%")
	he.set_level(2)
	assert_eq(int(he.call("_chance")), 25, "Lv2 25%")
	he.set_level(3)
	assert_eq(int(he.call("_chance")), 35, "Lv3 35%")
	he.set_awakened(true)
	assert_eq(int(he.call("_chance")), 35, "觉醒不改概率")


func test_high_explosive_seeded_rng_is_deterministic() -> void:
	var spy := SpySpawner.new()
	spy.return_null = true
	add_child_autofree(spy)
	var he: RefCounted = HighExplosiveScript.new()
	he.set_level(3)
	he.configure_spawner(spy)

	he.seed_rng(20260803)
	for _i: int in range(200):
		he.call("on_explosion_resolved", _context(0))
	var first_run: int = spy.spawn_calls
	assert_true(first_run > 0, "35% 概率连掷 200 次必然产出过")
	assert_lt(first_run, 200, "并非每次命中（概率 < 100%）")

	spy.spawn_calls = 0
	he.seed_rng(20260803)
	for _i: int in range(200):
		he.call("on_explosion_resolved", _context(0))
	assert_eq(spy.spawn_calls, first_run, "相同 seed 序列结果一致")


func test_high_explosive_sets_damage_ratio_from_awakened() -> void:
	var spy := SpySpawner.new()
	add_child_autofree(spy)
	var he: RefCounted = HighExplosiveScript.new()
	he.set_level(3)
	he.configure_spawner(spy)
	he.seed_rng(20260803)

	var normal: Variant = null
	for _i: int in range(200):
		he.call("on_explosion_resolved", _context(0))
		if spy.spawns.size() > 0:
			normal = spy.spawns[0]
			break
	assert_not_null(normal, "连掷必然产出过")
	assert_eq(float(normal.damage_ratio), 0.5, "非觉醒小炸弹 50% 伤害")
	assert_eq(float(normal.lifetime), 3.0, "超时 3s（config.extra.lifetime）")

	var awakened: RefCounted = HighExplosiveScript.new()
	awakened.set_level(3)
	awakened.set_awakened(true)
	awakened.configure_spawner(spy)
	awakened.seed_rng(20260803)
	spy.spawns.clear()
	var full: Variant = null
	for _i: int in range(200):
		awakened.call("on_explosion_resolved", _context(0))
		if spy.spawns.size() > 0:
			full = spy.spawns[0]
			break
	assert_not_null(full, "觉醒连掷必然产出过")
	assert_eq(float(full.damage_ratio), 1.0, "觉醒小炸弹 100% 伤害")


func test_high_explosive_hands_null_spawn_result_silently() -> void:
	var spy := SpySpawner.new()
	spy.return_null = true
	add_child_autofree(spy)
	var he: RefCounted = HighExplosiveScript.new()
	he.set_level(3)
	he.configure_spawner(spy)
	he.seed_rng(20260803)
	for _i: int in range(100):
		he.call("on_explosion_resolved", _context(0))
	assert_true(spy.spawn_calls > 0, "服务被调用")
	assert_eq(spy.last_max_active, 3, "传入 max_spawned=3")
	assert_eq(spy.last_position, Vector2(30, 40), "传入爆炸中心")


func test_high_explosive_silent_without_spawner() -> void:
	var he: RefCounted = HighExplosiveScript.new()
	he.set_level(3)
	he.seed_rng(1)
	for _i: int in range(10):
		he.call("on_explosion_resolved", _context(0))
	# 无 spawner 时静默安全：不崩溃、不产出
	assert_null(he.get("_spawner"), "无 spawner 时内部引用仍为空")
	# 之后再注入 spawner 可恢复正常产出，证明无 spawner 路径未污染状态
	var spy := SpySpawner.new()
	add_child_autofree(spy)
	he.configure_spawner(spy)
	he.seed_rng(1)
	for _i: int in range(200):
		he.call("on_explosion_resolved", _context(0))
	assert_true(spy.spawn_calls > 0, "注入 spawner 后恢复产出")


func test_high_explosive_spawns_via_real_spawner_up_to_cap() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var spawner: Node = ProducedMarbleSpawnerScript.new()
	spawner.call("configure", Callable(func() -> Node: return parent))
	add_child_autofree(spawner)
	var he: RefCounted = HighExplosiveScript.new()
	he.set_level(3)
	he.configure_spawner(spawner)
	he.seed_rng(20260803)
	for _i: int in range(200):
		he.call("on_explosion_resolved", _context(0))
	await wait_frames(1)  # 产出实例挂载被 call_deferred 延迟到帧末，先挂载再断言计数
	assert_eq(int(spawner.call("active_count")), 3, "真实服务达上限 3 后不再产出")
	assert_null(spawner.call("spawn", SmallBombScene, Vector2.ZERO, 3), "达上限再请求返回 null")


func test_effect_manager_injects_spawner_into_high_explosive() -> void:
	var effect_manager: Node = EffectManagerScript.new()
	add_child_autofree(effect_manager)
	var spawner: Node = ProducedMarbleSpawnerScript.new()
	add_child_autofree(spawner)
	var ammo := _ammo_state()

	var ammo_relic_ids: Array[StringName] = [
		&"ammo_pouch", &"ammo_recycler", &"ammo_dump", &"high_explosive", &"last_shot"
	]
	var loadout: RefCounted = LoadoutScript.new(
		func(_type: int, _fallback: int) -> int: return ammo_relic_ids.size()
	)
	for relic_id: StringName in ammo_relic_ids:
		var relic := Item.new()
		relic.id = relic_id
		relic.type = Item.ItemType.RELIC
		loadout.call("add", relic)
	var progression: RefCounted = ProgressionScript.new(loadout)

	assert_true(effect_manager.configure(loadout, progression, ammo, spawner))
	var active: Dictionary = effect_manager.get("_active_effects")
	var he: Variant = active.get("high_explosive")
	assert_not_null(he)
	assert_same(he.get("_spawner"), spawner, "四参 configure 注入产出服务")
	var recycler: Variant = active.get("ammo_recycler")
	assert_not_null(recycler)
	assert_same(recycler.get("_ammo_state"), ammo, "现有 configure_runtime 单参注入不受影响")

	assert_true(effect_manager.configure(loadout, progression))
	assert_null(he.get("_spawner"), "双参 configure 清空产出服务")
	assert_null(recycler.get("_ammo_state"), "双参 configure 清空 ammo_state")


# ---- 背水一击 ----

func test_last_shot_multiplies_damage_only_at_exactly_one_ammo() -> void:
	var last_shot: RefCounted = LastShotScript.new()

	var one_ammo: ExplosionContext = _context(1)
	last_shot.set_level(1)
	last_shot.call("modify_explosion", one_ammo)
	assert_eq(int(one_ammo.finalize()["damage"]), 6, "Lv1 ×1.5：roundi(4 × 1.5) = 6")

	var two_ammo: ExplosionContext = _context(2)
	last_shot.set_level(2)
	last_shot.call("modify_explosion", two_ammo)
	assert_eq(int(two_ammo.finalize()["damage"]), 4, "弹药 2 不生效")

	var level_three: ExplosionContext = _context(1)
	last_shot.set_level(3)
	last_shot.call("modify_explosion", level_three)
	assert_eq(int(level_three.finalize()["damage"]), 10, "Lv3 ×2.5：roundi(4 × 2.5) = 10")


func test_last_shot_awakened_multiplies_radius() -> void:
	var last_shot: RefCounted = LastShotScript.new()
	last_shot.set_level(2)
	last_shot.set_awakened(true)
	var ctx: ExplosionContext = _context(1)
	last_shot.call("modify_explosion", ctx)
	var resolved: Dictionary = ctx.finalize()
	assert_eq(float(resolved["radius"]), 112.5, "觉醒半径 ×1.5")


# ---- 弹药倾泻 ----

func test_ammo_dump_adds_flat_damage_by_ammo_times_level_multiplier() -> void:
	var dump: RefCounted = AmmoDumpScript.new()
	dump.set_level(1)
	var lv1: ExplosionContext = _context(4)
	dump.call("modify_explosion", lv1)
	assert_eq(int(lv1.finalize()["damage"]), 8, "Lv1：4 + 4×1.0 = 8")

	dump.set_level(2)
	var lv2: ExplosionContext = _context(4)
	dump.call("modify_explosion", lv2)
	assert_eq(int(lv2.finalize()["damage"]), 10, "Lv2：4 + 4×1.5 = 10")

	dump.set_level(3)
	var lv3: ExplosionContext = _context(4)
	dump.call("modify_explosion", lv3)
	assert_eq(int(lv3.finalize()["damage"]), 12, "Lv3：4 + 4×2.0 = 12")


func test_ammo_dump_awakened_multiplies_radius() -> void:
	var dump: RefCounted = AmmoDumpScript.new()
	dump.set_level(2)
	dump.set_awakened(true)
	var ctx: ExplosionContext = _context(4)
	dump.call("modify_explosion", ctx)
	var resolved: Dictionary = ctx.finalize()
	assert_eq(float(resolved["radius"]), 112.5, "觉醒半径 ×1.5：75 × 1.5 = 112.5")


func test_ammo_dump_at_zero_ammo_adds_nothing() -> void:
	var dump: RefCounted = AmmoDumpScript.new()
	dump.set_level(3)
	var ctx: ExplosionContext = _context(0)
	dump.call("modify_explosion", ctx)
	var resolved: Dictionary = ctx.finalize()
	assert_eq(int(resolved["damage"]), 4, "ammo_before=0 附加 0，damage 仍为基础值")
	assert_eq(int(resolved["ammo_cost"]), 0, "弹药 0 不消耗弹药")


func test_ammo_dump_does_not_change_ammo_cost() -> void:
	var dump: RefCounted = AmmoDumpScript.new()
	dump.set_level(1)
	var ctx: ExplosionContext = _context(4)
	dump.call("modify_explosion", ctx)
	assert_eq(int(ctx.finalize()["ammo_cost"]), 1, "ammo_before>0 时 ammo_cost 仍为 1")
