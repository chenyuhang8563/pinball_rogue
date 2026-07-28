# all_environment_components_level —— 沙盒关卡的独立运行驱动。
#
# 本场景被直接作为主场景运行（编辑器 F6）时，补齐战斗网关才会提供的装配：
#   弹珠链注册表、传送门配置、掉落导演配置、Head 掉入死亡区后的重生。
# 被 all_environment_components_battle 等战斗场景实例化时 current_scene 不是自身，
# 脚本不做任何事情，装配权完全交给战斗网关。

extends Node2D

const BlackMarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")
const RunWalletScript: GDScript = preload("res://Commerce/application/run_wallet.gd")

@onready var _chain: MarbleChain = $MarbleChain
@onready var _registry: MarbleChainRegistry = $MarbleChainRegistry
@onready var _portal_pair: PortalPairController = $TableBase/TableComponents/PortalPair
@onready var _drop_director: CombatDropDirector = $CombatDropDirector
@onready var _combat_drops: Node2D = $TableBase/CombatDrops
@onready var _table_base: Node2D = $TableBase
@onready var _kill_zone: Node = $TableBase/KillZone

## Head 重生位置：独立运行开局时从场景摆放的 BlackMarble 捕获。
var _head_spawn_position := Vector2.ZERO


func _ready() -> void:
	call_deferred("_setup_standalone_sandbox")


func _setup_standalone_sandbox() -> void:
	if get_tree() == null or get_tree().current_scene != self:
		return
	if _chain == null or _registry == null:
		return
	if _chain.head != null and is_instance_valid(_chain.head):
		_head_spawn_position = _chain.head.global_position
	_chain.set_chain_registry(_registry)
	if _portal_pair != null:
		_portal_pair.configure(_registry, MarbleTeleportService.new())
	_configure_drop_director()
	if _kill_zone != null and _kill_zone.has_signal(&"marble_fell") \
			and not _kill_zone.is_connected(&"marble_fell", _on_marble_fell):
		_kill_zone.connect(&"marble_fell", _on_marble_fell)


func _configure_drop_director() -> void:
	if _drop_director == null or _combat_drops == null:
		return
	var anchors: Array[Marker2D] = []
	for anchor: Node in get_tree().get_nodes_in_group(&"coin_drop_anchors"):
		if anchor is Marker2D and is_ancestor_of(anchor):
			anchors.append(anchor as Marker2D)
	if not _drop_director.configure(
		BattleSession.new(),
		_combat_drops,
		RunWalletScript.new(0),
		RunRandomSource.new(2026),
		anchors
	):
		return
	_drop_director.configure_kill_zone(_kill_zone)


func _on_marble_fell(marble: RigidBody2D) -> void:
	if _chain == null or marble != _chain.head:
		return
	call_deferred("_respawn_head")


func _respawn_head() -> void:
	if _chain == null or _table_base == null:
		return
	var new_head: Marble = BlackMarbleScene.instantiate() as Marble
	if new_head == null:
		return
	_table_base.add_child(new_head)
	if not _chain.adopt_scene_head(new_head):
		new_head.queue_free()
		return
	new_head.global_position = _head_spawn_position
	new_head.linear_velocity = Vector2.ZERO
	new_head.angular_velocity = 0.0
	new_head.set_sleeping(false)
