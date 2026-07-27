extends GutTest

const MarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")
const BoosterScene: PackedScene = preload("res://Combat/table_components/one_way_booster/one_way_booster.tscn")
const BarrelScene: PackedScene = preload("res://Combat/table_components/barrel/barrel.tscn")
const CoinScene: PackedScene = preload("res://Combat/drops/coin_pickup.tscn")
const SlingshotScene: PackedScene = preload("res://Combat/table_components/slingshot/slingshot.tscn")
const PortalPairScene: PackedScene = preload("res://Combat/table_components/portal_pair/portal_pair.tscn")
const PortalVisualScene: PackedScene = preload("res://Combat/table_components/portal_pair/portal_visual.tscn")
const EnvironmentDropLevel: PackedScene = preload("res://tests/Combat/table_components/scenes/environment_drop_integration.tscn")
const UnsafeBarrelEnvironmentLevel: PackedScene = preload("res://tests/Combat/table_components/scenes/environment_unsafe_barrel_integration.tscn")
const UnsafePortalEnvironmentLevel: PackedScene = preload("res://tests/Combat/table_components/scenes/environment_unsafe_portal_integration.tscn")
const RunWalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")


class FakeKillZone extends Node:
	signal marble_fell(marble: RigidBody2D)


class FakeCoinKillZone extends Node:
	func contains_global_point(_point: Vector2) -> bool:
		return true


class SelectiveCoinKillZone extends Node:
	func contains_global_point(point: Vector2) -> bool:
		return point.x < 0.0


class FirstIndexRandom extends RefCounted:
	func range_int(minimum: int, _maximum: int) -> int:
		return minimum


func test_one_way_booster_only_accepts_front_hit_and_applies_cooldown() -> void:
	var booster := add_child_autofree(BoosterScene.instantiate()) as OneWayBooster
	var marble := _head_marble(Vector2.DOWN * 180.0)
	watch_signals(booster)
	assert_true(booster.can_activate(marble))
	assert_true(booster.activate(marble))
	assert_signal_emitted_with_parameters(booster, "component_activated", [StringName(), marble])
	assert_false(booster.can_activate(marble), "同一 Head 的二次冲量必须进入冷却")
	marble.linear_velocity = Vector2.UP * 180.0
	booster._physics_process(1.0)
	assert_false(booster.can_activate(marble), "背面命中只保留实体反弹，不施加额外冲量")


func test_one_way_booster_returns_front_hit_along_forward_with_added_speed_cap() -> void:
	# 问题来源：设计文档 3.1 规定正面命中沿 forward 拍回，并额外获得 180 px/s、上限 520 px/s。
	# 修复契约：正面下落 Head 的结果速度必须改为 forward 方向；边界是 500 px/s 入射仍受 520 上限约束。
	var booster := add_child_autofree(BoosterScene.instantiate()) as OneWayBooster
	var marble := _head_marble(Vector2.DOWN * 500.0)
	marble.gravity_scale = 0.0
	marble.global_position = Vector2(0, 80)
	assert_true(booster.activate(marble))
	await wait_physics_frames(2)
	assert_almost_eq(marble.linear_velocity.angle(), Vector2.UP.angle(), 0.001)
	assert_almost_eq(marble.linear_velocity.length(), 520.0, 1.0, "刚体阻尼后仍应紧贴 520 px/s 上限")


func test_barrel_counts_each_head_hit_and_breaks_once_after_twenty_hits() -> void:
	# 问题来源：木桶机制改为“每次 Head 碰撞掉一枚币，累计 20 次破碎”，取消高速/正面角度门槛。
	# 修复契约：低速碰撞也计数；前 19 次保持 intact 且每次发 barrel_hit；第 20 次转 BROKEN
	# 并恰好发一次 barrel_broken；破碎后再碰撞不计数、不掉币。
	var barrel := add_child_autofree(BarrelScene.instantiate()) as Barrel
	var marble := _head_marble(Vector2.DOWN * 50.0)
	watch_signals(barrel)
	for _index: int in range(19):
		assert_true(barrel.register_hit(marble))
	assert_eq(barrel.state(), Barrel.State.INTACT)
	assert_eq(barrel.hits_taken(), 19)
	assert_signal_emit_count(barrel, "barrel_hit", 19)
	assert_signal_not_emitted(barrel, "barrel_broken")
	assert_true(barrel.register_hit(marble))
	assert_eq(barrel.state(), Barrel.State.BROKEN)
	assert_signal_emit_count(barrel, "barrel_hit", 20)
	assert_signal_emit_count(barrel, "barrel_broken", 1)
	assert_eq(barrel.get_node("BreakAnimation").assigned_animation, &"break")
	assert_false(barrel.register_hit(marble), "破碎后不再计数或掉落")


func test_coin_is_not_wallet_credit_until_head_collects() -> void:
	var coin := add_child_autofree(CoinScene.instantiate()) as CoinPickup
	var marble := _head_marble(Vector2.ZERO)
	coin.flight_duration = 0.0
	coin.begin_spawn(self, Vector2.ZERO, Vector2(8, 0))
	watch_signals(coin)
	assert_true(coin.is_available())
	assert_true(coin.collect_from(marble))
	assert_signal_emitted_with_parameters(coin, "coin_collected", [coin, 1, self])
	assert_false(coin.collect_from(marble), "金币状态必须原子地从 available 变为 collected")


func test_coin_expiry_never_emits_collection() -> void:
	var coin := add_child_autofree(CoinScene.instantiate()) as CoinPickup
	coin.flight_duration = 0.0
	coin.begin_spawn(self, Vector2.ZERO, Vector2.ZERO)
	watch_signals(coin)
	assert_true(coin.expire(&"kill_zone"))
	assert_signal_emitted_with_parameters(coin, "coin_expired", [coin, &"kill_zone"])
	assert_signal_not_emitted(coin, "coin_collected")


func test_drop_director_credits_wallet_exactly_once_after_collection() -> void:
	var director: CombatDropDirector = add_child_autofree(CombatDropDirector.new()) as CombatDropDirector
	var drops: Node2D = add_child_autofree(Node2D.new()) as Node2D
	var session: BattleSession = add_child_autofree(BattleSession.new()) as BattleSession
	var wallet: RefCounted = RunWalletScript.new(10)
	var random := RunRandomSource.new(1)
	assert_true(director.configure(session, drops, wallet, random, []))
	director.spawn_from_source(self, Vector2.ZERO, 1)
	assert_eq(wallet.balance(), 10, "生成掉落本身不得入账")
	var coin: CoinPickup = director._active_coins.values()[0]
	coin.flight_duration = 0.0
	coin.begin_spawn(self, Vector2.ZERO, Vector2.ZERO)
	assert_true(coin.collect_from(_head_marble(Vector2.ZERO)))
	assert_eq(wallet.balance(), 11)
	assert_eq(director.settlement_gate().pending_count(), 0)
	# 生成入树对物理回调安全而延迟一帧；等待 flush 完成，避免孤儿节点误计。
	await wait_physics_frames(1)


func test_drop_director_expires_coin_in_kill_zone_without_credit() -> void:
	var director := add_child_autofree(CombatDropDirector.new()) as CombatDropDirector
	var drops := add_child_autofree(Node2D.new()) as Node2D
	var session := add_child_autofree(BattleSession.new()) as BattleSession
	var wallet: RefCounted = RunWalletScript.new(10)
	assert_true(director.configure(session, drops, wallet, RunRandomSource.new(1), []))
	director.spawn_from_source(self, Vector2.ZERO, 1)
	var coin: CoinPickup = director._active_coins.values()[0]
	coin.flight_duration = 0.0
	coin.begin_spawn(self, Vector2.ZERO, Vector2.ZERO)
	director.configure_kill_zone(add_child_autofree(FakeCoinKillZone.new()))
	director._physics_process(0.016)
	assert_eq(wallet.balance(), 10)
	assert_true(director._active_coins.is_empty())
	# 生成入树对物理回调安全而延迟一帧；等待 flush 完成，避免孤儿节点误计。
	await wait_physics_frames(1)


func test_drop_director_merges_when_capacity_is_full_during_spawn() -> void:
	var director := add_child_autofree(CombatDropDirector.new()) as CombatDropDirector
	var drops := add_child_autofree(Node2D.new()) as Node2D
	var session := add_child_autofree(BattleSession.new()) as BattleSession
	director.max_active_coins = 1
	assert_true(director.configure(session, drops, RunWalletScript.new(0), RunRandomSource.new(1), []))
	director.spawn_from_source(self, Vector2.ZERO, 2)
	assert_eq(director._active_coins.size(), 1)
	var coin: CoinPickup = director._active_coins.values()[0]
	assert_eq(coin.amount, 2)
	# 生成入树对物理回调安全而延迟一帧；等待 flush 完成，避免孤儿节点误计。
	await wait_physics_frames(1)


func test_drop_director_skips_kill_zone_anchor_for_standard_drop() -> void:
	# 问题来源：设计文档 3.3 要求掉落导演只选择合法的预置 CoinDropAnchor。
	# 修复契约：随机源先选中非法锚点时仍落到安全锚点；边界是 kill zone 覆盖第一个候选。
	var director := add_child_autofree(CombatDropDirector.new()) as CombatDropDirector
	var drops := add_child_autofree(Node2D.new()) as Node2D
	var session := add_child_autofree(BattleSession.new()) as BattleSession
	var unsafe_anchor := add_child_autofree(Marker2D.new()) as Marker2D
	unsafe_anchor.global_position = Vector2(-48, 0)
	var safe_anchor := add_child_autofree(Marker2D.new()) as Marker2D
	safe_anchor.global_position = Vector2(48, 0)
	assert_true(director.configure(session, drops, RunWalletScript.new(0), FirstIndexRandom.new(), [unsafe_anchor, safe_anchor]))
	director.configure_kill_zone(add_child_autofree(SelectiveCoinKillZone.new()))
	director.spawn_from_source(self, Vector2.ZERO, 1)
	await wait_physics_frames(45)
	assert_eq(director._active_coins.size(), 1)
	var coin: CoinPickup = director._active_coins.values()[0]
	assert_almost_eq(coin.global_position.x, safe_anchor.global_position.x, 0.001)
	assert_almost_eq(coin.global_position.y, safe_anchor.global_position.y, 0.001)


func test_barrel_hit_drops_single_coin_at_rotated_drop_anchor() -> void:
	# 问题来源：木桶改为每次碰撞经 barrel_hit 掉一枚币，落点为 DropAnchor；多枚扇形散布随旧机制移除。
	# 修复契约：旋转桶后单次碰撞的金币仍落在旋转后的 DropAnchor 世界位置；边界是锚点随桶旋转 90°。
	var director := add_child_autofree(CombatDropDirector.new()) as CombatDropDirector
	var drops := add_child_autofree(Node2D.new()) as Node2D
	var session := add_child_autofree(BattleSession.new()) as BattleSession
	var barrel := add_child_autofree(BarrelScene.instantiate()) as Barrel
	barrel.rotation = PI * 0.5
	assert_true(director.configure(session, drops, RunWalletScript.new(0), RunRandomSource.new(1), []))
	# Head 远离桶感应区，只通过 register_hit 直调计数，避免物理重叠额外触发 body_entered。
	var head := _head_marble(Vector2.LEFT * 60.0)
	head.global_position = Vector2(0, 80)
	assert_true(barrel.register_hit(head))
	await wait_physics_frames(45)
	assert_eq(director._active_coins.size(), 1)
	var coin: CoinPickup = director._active_coins.values()[0]
	var anchor_position := barrel.drop_anchor.global_position
	assert_almost_eq(coin.global_position.x, anchor_position.x, 0.001)
	assert_almost_eq(coin.global_position.y, anchor_position.y, 0.001)


func test_coin_landing_animation_and_slingshot_activation_animation_are_real_scene_contracts() -> void:
	# 问题来源：设计文档 3.3/3.4 要求金币落地反馈与弹弓 0.08 秒视觉激活。
	# 修复契约：动画在场景资源中定义，并分别由落地与成功反作用触发；边界是仅凭节点存在不能视为视觉反馈。
	var coin := add_child_autofree(CoinScene.instantiate()) as CoinPickup
	var coin_animation := coin.get_node("AnimationPlayer") as AnimationPlayer
	assert_true(coin_animation.has_animation(&"land"))
	coin.flight_duration = 0.0
	coin.begin_spawn(self, Vector2.ZERO, Vector2.ZERO)
	assert_eq(coin_animation.current_animation, &"land")
	var slingshot := add_child_autofree(SlingshotScene.instantiate()) as Slingshot
	var slingshot_animation := slingshot.get_node("AnimationPlayer") as AnimationPlayer
	assert_true(slingshot_animation.has_animation(&"activate"))
	var marble := _head_marble(Vector2.UP * 120.0)
	marble.global_position = Vector2(0, 12)
	assert_true(slingshot.activate(marble))
	assert_eq(slingshot_animation.current_animation, &"activate")


func test_slingshot_returns_direct_entry_at_target_speed() -> void:
	# 问题来源：设计文档 3.4 规定直射核心后沿 KickOrigin → Head 方向以 420 px/s 推出。
	# 修复契约：成功触发后速度应为反作用方向的目标速度；边界是输入速度只用于入射判定，不稀释反作用结果。
	var slingshot := add_child_autofree(SlingshotScene.instantiate()) as Slingshot
	var marble := _head_marble(Vector2.UP * 120.0)
	marble.gravity_scale = 0.0
	marble.global_position = Vector2(0, 12)
	assert_true(slingshot.activate(marble))
	await wait_physics_frames(2)
	assert_almost_eq(marble.linear_velocity.angle(), Vector2.DOWN.angle(), 0.001)
	assert_almost_eq(marble.linear_velocity.length(), 420.0, 1.0)


func test_slingshot_visual_activation_duration_scales_scene_animation() -> void:
	# Problem source: visual_activation_seconds was exported but did not affect the activate animation.
	# Repair contract: a 0.04 s duration plays the authored 0.08 s clip at 2x speed.
	var slingshot := add_child_autofree(SlingshotScene.instantiate()) as Slingshot
	slingshot.visual_activation_seconds = 0.04
	var marble := _head_marble(Vector2.UP * 120.0)
	marble.global_position = Vector2(0, 12)
	assert_true(slingshot.activate(marble))
	var animation := slingshot.get_node("AnimationPlayer") as AnimationPlayer
	assert_almost_eq(animation.get_playing_speed(), 2.0, 0.001)


func test_slingshot_requires_direct_entry_and_has_per_head_cooldown() -> void:
	var slingshot := add_child_autofree(SlingshotScene.instantiate()) as Slingshot
	var marble := _head_marble(Vector2.UP * 100.0)
	marble.global_position = Vector2(0, 16)
	watch_signals(slingshot)
	assert_true(slingshot.can_activate(marble))
	assert_true(slingshot.activate(marble))
	assert_signal_emit_count(slingshot, "component_activated", 1)
	assert_false(slingshot.can_activate(marble))
	slingshot._physics_process(1.0)
	marble.linear_velocity = Vector2.DOWN * 100.0
	assert_false(slingshot.can_activate(marble), "远离 KickOrigin 的运动不能触发")


func test_last_enemy_drop_holds_battle_completion_until_coin_is_resolved() -> void:
	var container := add_child_autofree(Node2D.new()) as Node2D
	var spawner := add_child_autofree(BattleSpawner.new()) as BattleSpawner
	spawner.enemy_container = container
	var session := add_child_autofree(BattleSession.new()) as BattleSession
	assert_true(session.configure(spawner))
	var director := add_child_autofree(CombatDropDirector.new()) as CombatDropDirector
	director.enemy_drop_chance = 100
	var drops := add_child_autofree(Node2D.new()) as Node2D
	var wallet: RefCounted = RunWalletScript.new(0)
	assert_true(director.configure(session, drops, wallet, RunRandomSource.new(4), []))
	assert_true(session.configure_loot_settlement_gate(director.settlement_gate()))
	var kill_zone := add_child_autofree(FakeKillZone.new()) as FakeKillZone
	watch_signals(session)
	assert_true(session.start(_single_enemy_plan(), RunFlowToken.new(9, 1, 1), kill_zone))
	var enemy := container.get_child(0) as Enemy
	assert_true(enemy.defeat(&"test"))
	assert_signal_not_emitted(session, "completed")
	var coin: CoinPickup = director._active_coins.values()[0]
	coin.flight_duration = 0.0
	coin.begin_spawn(enemy, enemy.global_position, enemy.global_position)
	assert_true(coin.collect_from(_head_marble(Vector2.ZERO)))
	assert_signal_emit_count(session, "completed", 1)
	assert_eq(wallet.balance(), 1)
	# 生成入树对物理回调安全而延迟一帧；等待 flush 完成，避免孤儿节点误计。
	await wait_physics_frames(1)


func test_gateway_injects_real_level_drop_director_before_session_completion() -> void:
	var level_parent := add_child_autofree(Node2D.new()) as Node2D
	var base_enemies := add_child_autofree(Node2D.new()) as Node2D
	var spawner := add_child_autofree(BattleSpawner.new()) as BattleSpawner
	var gateway := add_child_autofree(BattleGateway.new()) as BattleGateway
	var wallet: RefCounted = RunWalletScript.new(0)
	assert_true(gateway.configure(
		spawner, base_enemies, level_parent, func() -> void: pass,
		Callable(), Callable(), wallet, RunRandomSource.new(1)
	))
	watch_signals(gateway)
	assert_true(gateway.start(_integration_level_plan(), RunFlowToken.new(10, 1, 1)))
	var director := gateway.active_level_scene.get_node("CombatDropDirector") as CombatDropDirector
	assert_not_null(director)
	var enemy := spawner.enemy_container.get_child(0) as Enemy
	assert_true(enemy.defeat(&"gateway_drop"))
	assert_signal_not_emitted(gateway, "battle_completed")
	var coin: CoinPickup = director._active_coins.values()[0]
	coin.flight_duration = 0.0
	coin.begin_spawn(enemy, enemy.global_position, enemy.global_position)
	assert_true(coin.collect_from(_head_marble(Vector2.ZERO)))
	assert_signal_emit_count(gateway, "battle_completed", 1)
	assert_eq(wallet.balance(), 1)
	# 生成入树对物理回调安全而延迟一帧；等待 flush 完成，避免孤儿节点误计。
	await wait_physics_frames(1)


func test_gateway_rejects_unsafe_barrels_and_disables_unsafe_portal_pairs() -> void:
	# Problem source: design sections 3.2 and 3.5 prohibit barrel/portal exits in the kill zone.
	# Repair contract: unsafe barrels abort the level, while unsafe portal pairs are disabled only.
	var barrel_result := _start_level_scene(UnsafeBarrelEnvironmentLevel)
	assert_false(barrel_result[&"started"] as bool)
	assert_push_error("Barrel DropAnchor is missing or inside the kill zone")
	var portal_result := _start_level_scene(UnsafePortalEnvironmentLevel)
	var portal_started: bool = portal_result[&"started"] as bool
	assert_true(portal_started)
	if portal_started:
		var gateway: BattleGateway = portal_result[&"gateway"] as BattleGateway
		var portal_pair := gateway.active_level_scene.get_node(
			"TableBase/TableComponents/UnsafePortalPair"
		) as PortalPairController
		assert_false(portal_pair.is_enabled())
		assert_push_warning("Portal exit is inside the kill zone")
		gateway.clear()


func test_all_environment_components_battle_starts_with_every_component_enabled() -> void:
	# Problem source: manual verification needs one real battle scene containing all 3.1–3.5 components.
	# Repair contract: BattleGateway starts its level and all five component categories are available together.
	var sandbox_scene := load(
		"res://tests/Combat/table_components/scenes/all_environment_components_battle.tscn"
	) as PackedScene
	assert_not_null(sandbox_scene)
	if sandbox_scene == null:
		return
	var sandbox := add_child_autofree(sandbox_scene.instantiate()) as Node2D
	await wait_physics_frames(2)
	var gateway := sandbox.get_node_or_null("BattleGateway") as BattleGateway
	assert_not_null(gateway)
	assert_not_null(gateway.active_level_scene)
	var level := gateway.active_level_scene
	assert_not_null(level.get_node_or_null("TableBase/TableComponents/OneWayBooster") as OneWayBooster)
	assert_not_null(level.get_node_or_null("TableBase/TableComponents/Barrel") as Barrel)
	assert_not_null(level.get_node_or_null("TableBase/TableComponents/Slingshot") as Slingshot)
	var portal_pair := level.get_node_or_null(
		"TableBase/TableComponents/PortalPair"
	) as PortalPairController
	assert_not_null(portal_pair)
	assert_true(portal_pair.is_enabled())
	assert_not_null(level.get_node_or_null("CombatDropDirector") as CombatDropDirector)
	# 问题来源：手动验证反馈测试战斗没有可用的初始弹珠。
	# 修复：沙盒开局固定构建一颗默认（黑色）头珠；边界：不附带任何尾段。
	var chain := sandbox.get_node_or_null("MarbleChain") as MarbleChain


func test_teleport_service_rotates_speed_repositions_chain_and_locks_pair() -> void:
	var chain: MarbleChain = add_child_autofree(MarbleChain.new()) as MarbleChain
	var head := MarbleScene.instantiate() as Marble
	head.is_head = true
	head.gravity_scale = 0.0
	head.linear_velocity = Vector2.RIGHT * 300.0
	chain.head = head
	chain.add_child(head)
	var service := MarbleTeleportService.new()
	var commit := {&"destination": Vector2.ZERO, &"velocity": Vector2.ZERO}
	head.portal_teleport_applied.connect(func(destination: Vector2, velocity: Vector2) -> void:
		commit[&"destination"] = destination
		commit[&"velocity"] = velocity
	)
	assert_true(service.transfer(chain, Vector2.RIGHT, Vector2(100, 50), Vector2.DOWN, &"pair_a"))
	await wait_physics_frames(1)
	var committed_destination: Vector2 = commit[&"destination"] as Vector2
	var committed_velocity: Vector2 = commit[&"velocity"] as Vector2
	assert_almost_eq(committed_destination.x, 100.0, 0.001)
	assert_almost_eq(committed_destination.y, 50.0 + service.exit_offset, 0.001)
	assert_almost_eq(committed_velocity.length(), 300.0, 0.001)
	assert_almost_eq(committed_velocity.angle(), Vector2.DOWN.angle(), 0.001)
	assert_true(service.is_locked(chain, &"pair_a"))
	service.tick(0.36)
	assert_false(service.is_locked(chain, &"pair_a"))


func test_teleport_service_moves_zero_speed_head_with_minimum_exit_speed() -> void:
	# 问题来源：设计文档 3.5 要求零速 Head 也必须以至少 140 px/s 完成整链传送。
	# 修复契约：零速度分支仍调用整链搬运；边界是速度方向回退为出口朝向。
	var chain: MarbleChain = add_child_autofree(MarbleChain.new()) as MarbleChain
	var head := MarbleScene.instantiate() as Marble
	head.is_head = true
	head.gravity_scale = 0.0
	head.linear_velocity = Vector2.ZERO
	chain.head = head
	chain.add_child(head)
	var service := MarbleTeleportService.new()
	var commit := {&"destination": Vector2.ZERO, &"velocity": Vector2.ZERO}
	head.portal_teleport_applied.connect(func(destination: Vector2, velocity: Vector2) -> void:
		commit[&"destination"] = destination
		commit[&"velocity"] = velocity
	)
	assert_true(service.transfer(chain, Vector2.RIGHT, Vector2(100, 50), Vector2.DOWN, &"pair_zero_speed"))
	await wait_physics_frames(1)
	var committed_destination: Vector2 = commit[&"destination"] as Vector2
	var committed_velocity: Vector2 = commit[&"velocity"] as Vector2
	assert_almost_eq(committed_destination.x, 100.0, 0.001)
	assert_almost_eq(committed_destination.y, 50.0 + service.exit_offset, 0.001)
	assert_almost_eq(committed_velocity.length(), service.minimum_speed, 0.001)
	assert_almost_eq(committed_velocity.angle(), Vector2.DOWN.angle(), 0.001)


func test_portal_scene_routes_endpoint_signal_through_registry_to_chain_transfer() -> void:
	var registry := add_child_autofree(MarbleChainRegistry.new()) as MarbleChainRegistry
	var chain := add_child_autofree(MarbleChain.new()) as MarbleChain
	var head := MarbleScene.instantiate() as Marble
	head.is_head = true
	head.gravity_scale = 0.0
	head.linear_velocity = Vector2.DOWN * 200.0
	chain.head = head
	chain.add_child(head)
	assert_true(registry.register_chain(chain))
	var controller := add_child_autofree(PortalPairScene.instantiate()) as PortalPairController
	assert_true(controller.configure(registry, MarbleTeleportService.new()))
	var entry := controller.get_node("EndpointA") as PortalEndpoint
	entry.portal_transfer_requested.emit(entry.pair_id, head)
	await wait_physics_frames(1)
	assert_almost_eq(head.global_position.x, 96.0, 0.001)
	assert_almost_eq(head.global_position.y, -24.0, 0.001)


func test_portal_visual_is_an_eight_frame_looping_animated_sprite() -> void:
	# 素材来源：美术提供的 PORTAL BLUE-Sheet.png（512×64）。
	# 表现契约：复用场景仅循环播放 8 帧 idle，不参与 PortalEndpoint 的传送逻辑。
	var visual := add_child_autofree(PortalVisualScene.instantiate()) as AnimatedSprite2D
	await wait_physics_frames(1)
	assert_eq(visual.animation, &"idle")
	assert_true(visual.is_playing())
	assert_true(visual.sprite_frames.has_animation(&"idle"))
	assert_eq(visual.sprite_frames.get_frame_count(&"idle"), 8)
	assert_true(visual.sprite_frames.get_animation_loop(&"idle"))


func test_portal_activation_is_emitted_after_head_physics_commit() -> void:
	# 问题来源：传送请求排队时就触发组件效果，若物理提交失败会产生假激活。
	# 修复契约：激活事件观察到的 Head 已在出口；边界是入门的初始坐标不能被当作成功位置。
	var fixture := _registered_portal_fixture()
	var controller: PortalPairController = fixture[&"controller"] as PortalPairController
	var activation := {&"received": false, &"position": Vector2.ZERO}
	controller.component_activated.connect(func(_component_id: StringName, marble: Marble) -> void:
		activation[&"received"] = true
		activation[&"position"] = marble.global_position
	)
	await wait_physics_frames(3)
	assert_true(activation[&"received"] as bool)
	var activation_position: Vector2 = activation[&"position"] as Vector2
	assert_almost_eq(activation_position.x, 96.0, 0.001)
	assert_almost_eq(activation_position.y, -24.0, 0.001)


func test_portal_commit_updates_exit_physics_overlap_after_next_frame() -> void:
	# 问题来源：玩家报告 Head 从 A 进入后只在 B 闪现一帧，下一物理步又回到 A。
	# 修复契约：传送提交必须写入刚体物理状态；边界是冻结 Head 会进入 B 的物理检测区而非只改显示坐标。
	var fixture := _registered_portal_fixture()
	var controller: PortalPairController = fixture[&"controller"] as PortalPairController
	var head: Marble = fixture[&"head"] as Marble
	var exit: PortalEndpoint = fixture[&"exit"] as PortalEndpoint
	var exit_shape := exit.get_node("CollisionShape2D") as CollisionShape2D
	var expanded_shape := (exit_shape.shape as CircleShape2D).duplicate() as CircleShape2D
	expanded_shape.radius = 64.0
	exit_shape.shape = expanded_shape
	watch_signals(controller)
	await wait_physics_frames(3)
	assert_signal_emit_count(controller, "component_activated", 1)
	assert_almost_eq(head.global_position.x, 96.0, 0.001)
	assert_lt(head.global_position.y, -24.0, "离开出口后 Head 必须沿出口朝向继续运动")
	await wait_physics_frames(1)
	assert_true(exit.is_overlapping_head(head), "Head 必须被物理世界登记在 B 门，而非只修改 Node2D 坐标")


func test_portal_locked_exit_entry_is_discarded_without_reverse_replay() -> void:
	# 问题来源：A → B 后 B 门的进入事件被错误写入 pending，锁定到期会重放为 B → A。
	# 修复契约：锁定期事件必须丢弃；边界是 Head 在 B 内持续超过锁定期且 pending 窗口更长。
	var fixture := _registered_portal_fixture()
	var controller: PortalPairController = fixture[&"controller"] as PortalPairController
	var head: Marble = fixture[&"head"] as Marble
	var exit: PortalEndpoint = fixture[&"exit"] as PortalEndpoint
	controller.pending_timeout_seconds = 1.0
	var exit_shape := exit.get_node("CollisionShape2D") as CollisionShape2D
	var expanded_shape := (exit_shape.shape as CircleShape2D).duplicate() as CircleShape2D
	expanded_shape.radius = 80.0
	exit_shape.shape = expanded_shape
	watch_signals(controller)
	await wait_physics_frames(3)
	assert_signal_emit_count(controller, "component_activated", 1)
	assert_true(exit.is_overlapping_head(head))
	exit.portal_transfer_requested.emit(exit.pair_id, head)
	await wait_physics_frames(50)
	assert_signal_emit_count(controller, "component_activated", 1)
	assert_gt(head.global_position.x, 48.0, "锁定到期后仍不得回传至 A 门")


func test_portal_waits_for_busy_exit_then_transfers_once_while_head_remains_in_entry() -> void:
	# 问题来源：设计文档 3.5 要求出口占用时最多等待 0.2 秒。
	# 修复契约：在窗口内清空出口应经真实 Area2D 重叠路径整链传送一次；边界是入口仍被 Head 占用。
	var fixture := _registered_portal_fixture()
	var controller: PortalPairController = fixture[&"controller"] as PortalPairController
	var head: Marble = fixture[&"head"] as Marble
	var exit: PortalEndpoint = fixture[&"exit"] as PortalEndpoint
	var blocker := _frozen_marble(exit.global_position + Vector2.UP * 32.0)
	watch_signals(controller)
	await wait_physics_frames(2)
	assert_signal_not_emitted(controller, "component_activated")
	assert_almost_eq(head.global_position.x, 0.0, 0.001)
	assert_almost_eq(head.global_position.y, 0.0, 0.001)
	blocker.queue_free()
	await wait_physics_frames(3)
	assert_signal_emit_count(controller, "component_activated", 1)
	assert_almost_eq(head.global_position.x, 96.0, 0.001)
	assert_lt(head.global_position.y, -24.0, "传送后速度应沿出口朝向生效")
	assert_almost_eq(head.linear_velocity.angle(), Vector2.UP.angle(), 0.001)


func test_portal_discards_busy_exit_request_after_timeout_until_head_reenters() -> void:
	# 问题来源：设计文档 3.5 的 0.2 秒出口安全等待上限。
	# 修复契约：超时请求必须取消而非在出口稍后清空时迟发；边界是新的入门事件可再次申请传送。
	var fixture := _registered_portal_fixture()
	var controller: PortalPairController = fixture[&"controller"] as PortalPairController
	var head: Marble = fixture[&"head"] as Marble
	var entry: PortalEndpoint = fixture[&"entry"] as PortalEndpoint
	var exit: PortalEndpoint = fixture[&"exit"] as PortalEndpoint
	var blocker := _frozen_marble(exit.global_position + Vector2.UP * 32.0)
	watch_signals(controller)
	await wait_physics_frames(27)
	blocker.queue_free()
	await wait_physics_frames(2)
	assert_signal_not_emitted(controller, "component_activated")
	assert_true(exit.is_exit_safe(head, exit.anchor_position() + exit.forward() * 24.0))
	assert_almost_eq(head.global_position.x, 0.0, 0.001)
	assert_true(head.queue_portal_teleport(Vector2.LEFT * 30.0, Vector2.ZERO))
	await wait_physics_frames(2)
	assert_false(entry.is_overlapping_head(head))
	head.freeze = false
	head.linear_velocity = Vector2.RIGHT * 600.0
	await wait_physics_frames(8)
	assert_signal_emit_count(controller, "component_activated", 1)


func test_portal_cancels_busy_exit_request_when_head_leaves_entry() -> void:
	# 问题来源：设计文档 3.5 指定 Head 离开入口时取消等待。
	# 修复契约：离开入口会撤销待传送请求；边界是出口随后在原等待窗口内恢复安全。
	var fixture := _registered_portal_fixture()
	var controller: PortalPairController = fixture[&"controller"] as PortalPairController
	var head: Marble = fixture[&"head"] as Marble
	var exit: PortalEndpoint = fixture[&"exit"] as PortalEndpoint
	var blocker := _frozen_marble(exit.global_position + Vector2.UP * 32.0)
	watch_signals(controller)
	await wait_physics_frames(2)
	assert_true(head.queue_portal_teleport(Vector2.LEFT * 30.0, Vector2.ZERO))
	await wait_physics_frames(2)
	blocker.queue_free()
	await wait_physics_frames(2)
	assert_signal_not_emitted(controller, "component_activated")
	assert_almost_eq(head.global_position.x, -30.0, 0.001)


func test_portal_controller_disables_invalid_pair() -> void:
	var controller := add_child_autofree(PortalPairController.new()) as PortalPairController
	var registry := add_child_autofree(MarbleChainRegistry.new()) as MarbleChainRegistry
	assert_false(controller.configure(registry, MarbleTeleportService.new()))
	assert_ne(controller.validation_error, "")


func test_portal_controller_rejects_exit_offset_that_cannot_clear_trigger_geometry() -> void:
	# 问题来源：出口偏移小于 Head 半径、出口检测半径与安全间隙之和时，会立即重叠 B 门。
	# 修复契约：边界值 22 px 必须禁用该对；默认的合格偏移仍由其他 Portal 场景测试覆盖。
	var registry := add_child_autofree(MarbleChainRegistry.new()) as MarbleChainRegistry
	var controller := add_child_autofree(PortalPairScene.instantiate()) as PortalPairController
	var service := MarbleTeleportService.new()
	service.exit_offset = 22.0
	assert_false(controller.configure(registry, service))
	assert_ne(controller.validation_error, "")


func _head_marble(velocity: Vector2) -> Marble:
	var marble := add_child_autofree(MarbleScene.instantiate()) as Marble
	marble.is_head = true
	marble.linear_velocity = velocity
	return marble


func _registered_portal_fixture() -> Dictionary:
	var registry := add_child_autofree(MarbleChainRegistry.new()) as MarbleChainRegistry
	var chain := add_child_autofree(MarbleChain.new()) as MarbleChain
	var head := MarbleScene.instantiate() as Marble
	head.is_head = true
	head.freeze = false
	head.gravity_scale = 0.0
	head.linear_velocity = Vector2.ZERO
	chain.head = head
	chain.add_child(head)
	assert_true(registry.register_chain(chain))
	var controller := add_child_autofree(PortalPairScene.instantiate()) as PortalPairController
	assert_true(controller.configure(registry, MarbleTeleportService.new()))
	return {
		&"controller": controller,
		&"head": head,
		&"entry": controller.get_node("EndpointA") as PortalEndpoint,
		&"exit": controller.get_node("EndpointB") as PortalEndpoint,
	}


func _frozen_marble(position: Vector2) -> Marble:
	var marble := add_child_autofree(MarbleScene.instantiate()) as Marble
	marble.freeze = true
	marble.gravity_scale = 0.0
	marble.global_position = position
	return marble


func _single_enemy_plan() -> BattlePlan:
	var group := BattleGroupDef.new()
	group.id = "loot_grace"
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = EnemyScene
	entry.position = Vector2(32, 32)
	entry.health = 1
	group.enemy_entries.append(entry)
	return BattlePlan.new(&"loot_grace", group, BattlePlan.Origin.NODE, BattlePlan.RewardPolicy.NORMAL)


func _integration_level_plan(level_scene: PackedScene = EnvironmentDropLevel) -> BattlePlan:
	var group := BattleGroupDef.new()
	group.id = "gateway_loot_grace"
	var level := LevelDef.new()
	level.level_scene = level_scene
	group.level_def = level
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = EnemyScene
	entry.position = Vector2(120, 96)
	entry.health = 1
	group.enemy_entries.append(entry)
	return BattlePlan.new(&"gateway_loot_grace", group, BattlePlan.Origin.NODE, BattlePlan.RewardPolicy.NORMAL)
func _start_level_scene(level_scene: PackedScene) -> Dictionary:
	var level_parent := add_child_autofree(Node2D.new()) as Node2D
	var base_enemies := add_child_autofree(Node2D.new()) as Node2D
	var spawner := add_child_autofree(BattleSpawner.new()) as BattleSpawner
	var gateway := add_child_autofree(BattleGateway.new()) as BattleGateway
	var registry := add_child_autofree(MarbleChainRegistry.new()) as MarbleChainRegistry
	assert_true(gateway.configure(
		spawner, base_enemies, level_parent, func() -> void: pass,
		Callable(), Callable(), RunWalletScript.new(0), RunRandomSource.new(1), registry
	))
	var started := gateway.start(_integration_level_plan(level_scene), RunFlowToken.new(11, 1, 1))
	return {&"started": started, &"gateway": gateway}
