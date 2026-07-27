class_name EnvironmentComponentShowcase
extends Node2D

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const RunWalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")

@export_enum("booster", "barrel", "coins", "loot_grace", "slingshot", "portal") var scenario: String = ""
@export_range(0.0, 10.0, 0.1) var showcase_start_delay_seconds: float = 0.0
@export var preserve_barrel_loot_for_capture: bool = false


func _ready() -> void:
	call_deferred("_start_showcase")


func _start_showcase() -> void:
	await get_tree().physics_frame
	if showcase_start_delay_seconds > 0.0:
		await get_tree().create_timer(showcase_start_delay_seconds).timeout
	match scenario:
		"booster":
			_start_booster()
		"barrel":
			_start_barrel()
		"coins":
			_start_coins()
		"loot_grace":
			_start_loot_grace()
		"slingshot":
			_start_slingshot()
		"portal":
			_start_portal()


func _start_booster() -> void:
	_launch_head("FrontHead", Vector2.DOWN * 220.0)
	_launch_head("BackHead", Vector2.UP * 220.0)


func _start_barrel() -> void:
	var director := get_node_or_null("CombatDropDirector") as CombatDropDirector
	var drops := get_node_or_null("CombatDrops") as Node2D
	var barrel := get_node_or_null("Barrel") as Barrel
	if director != null and drops != null and barrel != null:
		director.configure(BattleSession.new(), drops, RunWalletScript.new(0), RunRandomSource.new(1), [barrel.drop_anchor])
		# 桶现在每次碰撞都掉币：首次命中即冻住 Head，保住落地金币供截图。
		if preserve_barrel_loot_for_capture and not barrel.barrel_hit.is_connected(
			_on_showcase_barrel_hit
		):
			barrel.barrel_hit.connect(_on_showcase_barrel_hit)
		_launch_head("Head", Vector2.DOWN * 320.0)


func _on_showcase_barrel_hit(
	_barrel: Barrel,
	_drop_anchor: Marker2D
) -> void:
	var head := get_node_or_null("Head") as Marble
	if head == null:
		return
	head.linear_velocity = Vector2.ZERO
	head.freeze = true
	head.global_position = Vector2(24, 24)


func _start_coins() -> void:
	var collectible := get_node_or_null("CollectibleCoin") as CoinPickup
	var expiring := get_node_or_null("ExpiringCoin") as CoinPickup
	if collectible != null:
		collectible.flight_duration = 0.2
		collectible.lifetime_seconds = 4.0
		collectible.begin_spawn(self, collectible.global_position + Vector2.DOWN * 24.0, collectible.global_position)
	if expiring != null:
		expiring.flight_duration = 0.2
		expiring.lifetime_seconds = 1.0
		expiring.begin_spawn(self, expiring.global_position + Vector2.DOWN * 24.0, expiring.global_position)
	await get_tree().create_timer(0.45).timeout
	_launch_head("Head", Vector2.UP * 180.0)


func _start_loot_grace() -> void:
	var spawner := get_node_or_null("BattleSpawner") as BattleSpawner
	var enemies := get_node_or_null("Enemies") as Node2D
	var session := get_node_or_null("BattleSession") as BattleSession
	var director := get_node_or_null("CombatDropDirector") as CombatDropDirector
	var drops := get_node_or_null("CombatDrops") as Node2D
	if spawner == null or enemies == null or session == null or director == null or drops == null:
		return
	spawner.enemy_container = enemies
	if not session.configure(spawner):
		return
	director.enemy_drop_chance = 100
	director.final_pickup_grace_seconds = 3.0
	if not director.configure(session, drops, RunWalletScript.new(0), RunRandomSource.new(1), []):
		return
	if not session.configure_loot_settlement_gate(director.settlement_gate()):
		return
	var group := BattleGroupDef.new()
	group.id = "showcase_grace"
	var entry := BattleGroupDef.EnemyEntry.new()
	entry.scene = EnemyScene
	entry.position = Vector2(120, 88)
	entry.health = 1
	group.enemy_entries.append(entry)
	var plan := BattlePlan.new(&"showcase_grace", group, BattlePlan.Origin.NODE, BattlePlan.RewardPolicy.NORMAL)
	if not session.start(plan, RunFlowToken.new(1, 1, 1), SceneKillZone.new()):
		return
	var enemy := enemies.get_child(0) as Enemy
	if enemy != null:
		enemy.defeat(&"showcase")


func _start_slingshot() -> void:
	_launch_head("Head", Vector2.UP * 220.0)


func _start_portal() -> void:
	var registry := get_node_or_null("MarbleChainRegistry") as MarbleChainRegistry
	var chain := get_node_or_null("MarbleChain") as MarbleChain
	var head := get_node_or_null("MarbleChain/Head") as Marble
	var controller := get_node_or_null("PortalPair") as PortalPairController
	if registry == null or chain == null or head == null or controller == null:
		return
	head.is_head = true
	chain.head = head
	chain.set_chain_registry(registry)
	if controller.configure(registry, MarbleTeleportService.new()):
		head.gravity_scale = 0.0
		head.freeze = false
		head.linear_velocity = Vector2.UP * 220.0


func _launch_head(node_name: StringName, velocity: Vector2) -> void:
	var head := get_node_or_null(NodePath(node_name)) as Marble
	if head == null:
		return
	head.is_head = true
	head.gravity_scale = 0.0
	head.freeze = false
	head.linear_velocity = velocity
	head.set_sleeping(false)


class SceneKillZone extends Node:
	signal marble_fell(marble: RigidBody2D)
