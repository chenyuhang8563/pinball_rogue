class_name AllEnvironmentComponentsBattle
extends Node2D

const LevelScene: PackedScene = preload("res://tests/Combat/table_components/scenes/all_environment_components_level.tscn")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const BlackMarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")
const RunWalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")

@onready var battle_gateway: BattleGateway = $BattleGateway
@onready var battle_spawner: BattleSpawner = $BattleSpawner
@onready var base_enemies: Node2D = $BaseEnemies
@onready var level_parent: Node2D = $LevelParent
@onready var marble_chain_registry: MarbleChainRegistry = $MarbleChainRegistry
@onready var marble_chain: MarbleChain = $MarbleChain

var _wallet: RefCounted = RunWalletScript.new(0)
var _random_source: RefCounted = RunRandomSource.new(2026)
var _scene_head: Marble = null
var _scene_head_spawn_position := Vector2.ZERO


func _ready() -> void:
	call_deferred("_start_battle")


func _exit_tree() -> void:
	if battle_gateway != null and is_instance_valid(battle_gateway):
		battle_gateway.dispose()


func _start_battle() -> void:
	marble_chain.set_chain_registry(marble_chain_registry)
	if not battle_gateway.configure(
		battle_spawner,
		base_enemies,
		level_parent,
		_reset_chain,
		Callable(),
		Callable(),
		_wallet,
		_random_source,
		marble_chain_registry
	):
		push_error("AllEnvironmentComponentsBattle failed to configure BattleGateway")
		return
	if not battle_gateway.marble_fell.is_connected(_on_marble_fell):
		battle_gateway.marble_fell.connect(_on_marble_fell)
	if not battle_gateway.start(_battle_plan(), RunFlowToken.new(31, 1, 1)):
		push_error("AllEnvironmentComponentsBattle failed to start BattleGateway")


func _reset_chain() -> void:
	if _scene_head == null or not is_instance_valid(_scene_head):
		_scene_head = battle_gateway.active_level_scene.get_node_or_null(
			"TableBase/BlackMarble"
		) as Marble
		if _scene_head != null:
			_scene_head_spawn_position = _scene_head.global_position
		elif not _scene_head_spawn_position.is_zero_approx():
			_scene_head = BlackMarbleScene.instantiate() as Marble
	if _scene_head == null or not marble_chain.adopt_scene_head(_scene_head):
		push_error("AllEnvironmentComponentsBattle requires TableBase/BlackMarble")
		return
	_scene_head.global_position = _scene_head_spawn_position
	_scene_head.linear_velocity = Vector2.ZERO
	_scene_head.angular_velocity = 0.0
	_scene_head.set_sleeping(false)


func _battle_plan() -> BattlePlan:
	var level_def := LevelDef.new()
	level_def.level_scene = LevelScene
	var group := BattleGroupDef.new()
	group.id = "all_environment_components_sandbox"
	group.level_def = level_def
	for enemy_position: Vector2 in [Vector2(120, 56), Vector2(46, 158), Vector2(194, 92)]:
		var entry := BattleGroupDef.EnemyEntry.new()
		entry.scene = EnemyScene
		entry.position = enemy_position
		entry.health = 2
		group.enemy_entries.append(entry)
	return BattlePlan.new(
		&"all_environment_components_sandbox",
		group,
		BattlePlan.Origin.NODE,
		BattlePlan.RewardPolicy.NORMAL
	)


func _on_marble_fell(_token: RunFlowToken, marble: RigidBody2D) -> void:
	if marble == marble_chain.head:
		call_deferred("_reset_chain")
