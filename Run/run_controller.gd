extends Node
class_name RunController

signal run_node_completed(node_kind: String)
signal battle_started(group_id: String)
signal battle_completed(group_id: String)
signal run_health_changed(health: int)
signal run_completed

const BattleGroupDefScript: GDScript = preload("res://Run/battle_group_def.gd")
const RunNodeOptionScript: GDScript = preload("res://Run/run_node_option.gd")
const BattleSpawnerScript: GDScript = preload("res://Run/battle_spawner.gd")
const StatRegistryScript: GDScript = preload("res://Stats/stat_registry.gd")
const MarbleUpgradeSystemScript: GDScript = preload("res://Run/marble_upgrade_system.gd")
const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")
const DEFAULT_REWARD_ITEM_PATHS: PackedStringArray = [
	"res://Resources/brown_marble.tres",
	"res://Resources/green_marble.tres",
	"res://Resources/bomb_marble.tres",
	"res://Resources/lightning.tres",
]
const NORMAL_BATTLE_OPTION_WEIGHT: int = 30
const EVENT_OPTION_WEIGHT: int = 30
const ELITE_OPTION_WEIGHT: int = 20
const UPGRADE_OPTION_WEIGHT: int = 20
const SHOP_MODE_ON: int = 0
const SHOP_MODE_OFF: int = 1
const NORMAL_BATTLE_GOLD_MIN: int = 15
const NORMAL_BATTLE_GOLD_MAX: int = 20
const ELITE_BATTLE_GOLD_MIN: int = 35
const ELITE_BATTLE_GOLD_MAX: int = 40
const RUN_HEALTH_ENTITY_ID: String = "run:current"

@export var boss_node_index: int = 6
@export var enemy_container: Node2D
@export var battle_spawner: BattleSpawner
@export var node_choice_panel: Control
@export var draft_reward_panel: Control
@export var upgrade_panel: Control

var current_node_index: int = 0
var choice_wave_index: int = 0
var run_is_complete: bool = false
var reset_battle_state_callable: Callable = Callable()
var battle_is_active: bool = false
var marble_upgrade_system: Node


func _ready() -> void:
	_ensure_battle_spawner()
	_ensure_marble_upgrade_system()
	_connect_event_bus()
	_connect_panels()


func start_run() -> void:
	_ensure_battle_spawner()
	_ensure_marble_upgrade_system()
	_connect_panels()
	current_node_index = 0
	choice_wave_index = 0
	run_is_complete = false
	battle_is_active = false
	marble_upgrade_system.call("reset_upgrades")
	_connect_event_bus()
	_reset_run_health()
	run_health_changed.emit(_get_run_health())
	_start_next_node()


func build_node_options() -> Array[RunNodeOption]:
	choice_wave_index += 1
	return build_node_options_for_wave(choice_wave_index)


func build_node_options_for_wave(wave_index: int) -> Array[RunNodeOption]:
	var options: Array[RunNodeOption] = []
	if wave_index == 4:
		options.append(_make_shop_option())

	var require_unique_kinds: bool = _get_enabled_node_option_kind_count() >= 3
	while options.size() < 3:
		var option: RunNodeOption = _make_weighted_node_option()
		if not require_unique_kinds or not _options_have_kind_id(options, option.kind_id):
			options.append(option)
	return options


func get_option_weights() -> Dictionary:
	return {
		"battle": NORMAL_BATTLE_OPTION_WEIGHT,
		"event": EVENT_OPTION_WEIGHT,
		"elite": ELITE_OPTION_WEIGHT,
		"upgrade": UPGRADE_OPTION_WEIGHT,
	}


func _get_enabled_node_option_kind_count() -> int:
	var count: int = 0
	for weight: int in get_option_weights().values():
		if weight > 0:
			count += 1
	return count


func choose_option(option: RunNodeOption) -> void:
	if option == null or run_is_complete:
		return

	run_node_completed.emit(option.kind_id)
	if node_choice_panel != null:
		node_choice_panel.hide()

	match option.kind:
		RunNodeOption.Kind.BATTLE:
			_begin_battle(option.battle_group)
		RunNodeOption.Kind.ELITE:
			_begin_battle(option.battle_group)
		RunNodeOption.Kind.EVENT:
			_show_event_draft()
		RunNodeOption.Kind.REWARD:
			_show_reward_draft()
		RunNodeOption.Kind.UPGRADE:
			_show_upgrade_choices()
		RunNodeOption.Kind.SHOP:
			_show_shop()
		_:
			_show_node_choices()


func continue_after_draft() -> void:
	_start_next_node()


func _start_next_node() -> void:
	if run_is_complete:
		return

	current_node_index += 1
	if current_node_index >= boss_node_index:
		_begin_battle(_make_boss_group())
		return

	if current_node_index == 1:
		_begin_battle(_make_weak_group())
	else:
		_show_node_choices()


func _begin_battle(group: BattleGroupDef) -> void:
	if group == null:
		return

	_ensure_battle_spawner()
	battle_is_active = true
	run_health_changed.emit(_get_run_health())
	battle_started.emit(group.id)
	_reset_battle_state()
	if battle_spawner != null:
		battle_spawner.start_battle(group)


func _on_battle_completed(group_id: String) -> void:
	battle_is_active = false
	run_health_changed.emit(_get_run_health())
	battle_completed.emit(group_id)

	if group_id.contains("boss"):
		run_is_complete = true
		run_completed.emit()
		_show_run_completed_message()
		return

	_show_battle_rewards(group_id)


func _show_node_choices() -> void:
	if node_choice_panel == null:
		return
	if node_choice_panel.has_method("show_options"):
		node_choice_panel.call("show_options", build_node_options())


func _show_reward_draft() -> void:
	if draft_reward_panel == null:
		_start_next_node()
		return
	if draft_reward_panel.has_method("show_item_draft"):
		draft_reward_panel.call("show_item_draft", _pick_reward_items())


func _show_event_draft() -> void:
	if draft_reward_panel == null:
		_start_next_node()
		return
	if draft_reward_panel.has_method("show_item_draft"):
		draft_reward_panel.call("show_item_draft", _pick_event_items())


func _show_battle_rewards(group_id: String) -> void:
	var gold_amount: int = _roll_battle_gold(group_id)
	var items: Array[Item] = _pick_battle_reward_items(group_id)
	if draft_reward_panel == null or not draft_reward_panel.has_method("show_battle_rewards"):
		_start_next_node()
		return
	draft_reward_panel.call("show_battle_rewards", items, gold_amount)


func _show_run_completed_message() -> void:
	if node_choice_panel != null and node_choice_panel.has_method("show_message"):
		node_choice_panel.call("show_message", "Run Complete", "Boss defeated. This v1 flow is complete.")


func _show_upgrade_placeholder() -> void:
	if node_choice_panel != null and node_choice_panel.has_method("show_message"):
		if node_choice_panel.has_signal(&"message_dismissed"):
			var continue_callable: Callable = Callable(self, "continue_after_draft")
			if not node_choice_panel.is_connected(&"message_dismissed", continue_callable):
				node_choice_panel.connect(&"message_dismissed", continue_callable, CONNECT_ONE_SHOT)
		node_choice_panel.call("show_message", "Upgrade", "Placeholder")
	else:
		_start_next_node()


func _show_upgrade_choices() -> void:
	_ensure_marble_upgrade_system()
	_connect_panels()
	var inventory: Node = _get_autoload_node(&"Inventory")
	var raw_options: Variant = marble_upgrade_system.call("get_upgrade_options", inventory, 3)
	var options: Array[Dictionary] = raw_options if raw_options is Array else []
	if options.is_empty():
		_show_no_upgrade_message()
		return
	if upgrade_panel != null and upgrade_panel.has_method("show_upgrades"):
		upgrade_panel.call("show_upgrades", options)
		return
	_show_no_upgrade_message()


func _show_no_upgrade_message() -> void:
	if node_choice_panel != null and node_choice_panel.has_method("show_message"):
		if node_choice_panel.has_signal(&"message_dismissed"):
			var continue_callable: Callable = Callable(self, "continue_after_draft")
			if not node_choice_panel.is_connected(&"message_dismissed", continue_callable):
				node_choice_panel.connect(&"message_dismissed", continue_callable, CONNECT_ONE_SHOT)
		node_choice_panel.call("show_message", "Upgrade", "No marble upgrades available.")
	else:
		_start_next_node()


func _on_upgrade_selected(option: Dictionary) -> void:
	_ensure_marble_upgrade_system()
	var marble_type: Marble.MARBLE_TYPE = int(option.get("marble_type", Marble.MARBLE_TYPE.DEFAULT)) as Marble.MARBLE_TYPE
	marble_upgrade_system.call("upgrade_marble", marble_type)
	_start_next_node()


func _show_shop() -> void:
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null:
		_start_next_node()
		return

	shop.set("mode", SHOP_MODE_ON)
	_watch_shop_close(shop)


func _pick_reward_items() -> Array[Item]:
	var default_items: Array[Item] = _get_default_reward_items()
	var result: Array[Item] = []
	for index: int in range(mini(3, default_items.size())):
		result.append(default_items[index])
	return result


func _pick_event_items() -> Array[Item]:
	var default_items: Array[Item] = _get_default_reward_items()
	var result: Array[Item] = []
	for index: int in range(default_items.size() - 1, -1, -1):
		result.append(default_items[index])
		if result.size() >= 3:
			break
	return result


func _get_default_reward_items() -> Array[Item]:
	var result: Array[Item] = []
	for path: String in DEFAULT_REWARD_ITEM_PATHS:
		var item: Item = load(path) as Item
		if item != null:
			result.append(item)
	return result


func _pick_battle_reward_items(group_id: String) -> Array[Item]:
	var result: Array[Item] = []
	if not group_id.contains("elite"):
		return result

	for item: Item in _get_default_reward_items():
		if item != null and item.type == Item.ItemType.RELIC:
			result.append(item)
			break
	return result


func _roll_battle_gold(group_id: String) -> int:
	if group_id.contains("elite"):
		return randi_range(ELITE_BATTLE_GOLD_MIN, ELITE_BATTLE_GOLD_MAX)
	if group_id.contains("normal"):
		return randi_range(NORMAL_BATTLE_GOLD_MIN, NORMAL_BATTLE_GOLD_MAX)
	return 0


func _add_gold(amount: int) -> void:
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null:
		return
	shop.set("gold", int(shop.get("gold")) + amount)


func _pick_normal_battle_group() -> BattleGroupDef:
	if current_node_index <= 1:
		return _make_weak_group()
	return _make_strong_group()


func _make_weighted_node_option() -> RunNodeOption:
	var total_weight: int = NORMAL_BATTLE_OPTION_WEIGHT + EVENT_OPTION_WEIGHT + ELITE_OPTION_WEIGHT + UPGRADE_OPTION_WEIGHT
	var roll: int = randi_range(1, total_weight)
	if roll <= NORMAL_BATTLE_OPTION_WEIGHT:
		return _make_normal_battle_option()
	if roll <= NORMAL_BATTLE_OPTION_WEIGHT + EVENT_OPTION_WEIGHT:
		return _make_event_option()
	if roll <= NORMAL_BATTLE_OPTION_WEIGHT + EVENT_OPTION_WEIGHT + ELITE_OPTION_WEIGHT:
		return _make_elite_option()
	return _make_upgrade_option()


func _make_normal_battle_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.BATTLE, "battle", "Battle", "", _make_strong_group())


func _make_event_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.EVENT, "event", "Event", "", null)


func _make_elite_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.ELITE, "elite", "Elite", "", _make_elite_group())


func _make_upgrade_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.UPGRADE, "upgrade", "Upgrade", "", null)


func _make_shop_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.SHOP, "shop", "Shop", "", null)


func _make_weak_group() -> BattleGroupDef:
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(72, 48), 30),
		_enemy_entry(Vector2(120, 72), 30),
		_enemy_entry(Vector2(168, 48), 30),
	]
	return _make_group("weak_normal_%d" % current_node_index, "Weak Fight", BattleGroupDef.Kind.WEAK_NORMAL, entries)


func _make_strong_group() -> BattleGroupDef:
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(64, 48), 42),
		_enemy_entry(Vector2(104, 88), 42),
		_enemy_entry(Vector2(144, 48), 42),
		_enemy_entry(Vector2(184, 88), 42),
		_enemy_entry(Vector2(120, 132), 42),
	]
	return _make_group("strong_normal_%d" % current_node_index, "Strong Fight", BattleGroupDef.Kind.STRONG_NORMAL, entries)


func _make_elite_group() -> BattleGroupDef:
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(120, 64), 120),
		_enemy_entry(Vector2(80, 124), 36),
		_enemy_entry(Vector2(160, 124), 36),
	]
	return _make_group("elite_%d" % current_node_index, "Elite Fight", BattleGroupDef.Kind.ELITE, entries)


func _make_boss_group() -> BattleGroupDef:
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(120, 64), 240),
		_enemy_entry(Vector2(72, 128), 50),
		_enemy_entry(Vector2(168, 128), 50),
	]
	return _make_group("boss_%d" % current_node_index, "Boss Fight", BattleGroupDef.Kind.BOSS, entries)


func _make_group(id: String, title: String, kind: BattleGroupDef.Kind, entries: Array[BattleGroupDef.EnemyEntry]) -> BattleGroupDef:
	var group: BattleGroupDef = BattleGroupDefScript.new()
	group.id = id
	group.title = title
	group.kind = kind
	group.enemy_entries = entries
	return group


func _enemy_entry(position: Vector2, health: int) -> BattleGroupDef.EnemyEntry:
	var entry: BattleGroupDef.EnemyEntry = BattleGroupDef.EnemyEntry.new()
	entry.scene = EnemyScene
	entry.position = position
	entry.health = health
	return entry


func _make_option(
	kind: RunNodeOption.Kind,
	kind_id: String,
	title: String,
	description: String,
	battle_group: BattleGroupDef
) -> RunNodeOption:
	var option: RunNodeOption = RunNodeOptionScript.new()
	option.kind = kind
	option.kind_id = kind_id
	option.title = title
	option.description = description
	option.battle_group = battle_group
	return option


func _options_have_kind_id(options: Array[RunNodeOption], kind_id: String) -> bool:
	for option: RunNodeOption in options:
		if option.kind_id == kind_id:
			return true
	return false


func _reset_battle_state() -> void:
	if reset_battle_state_callable.is_valid():
		reset_battle_state_callable.call()


func _on_marble_fell(marble: RigidBody2D) -> void:
	if not battle_is_active:
		return
	if marble == null or not marble.is_in_group("marbles"):
		return

	var stat_system: Node = _get_stat_system()
	if stat_system == null:
		return

	var current_health: int = int(stat_system.call(
		"get_stat",
		StatRegistryScript.RUN_HEALTH,
		RUN_HEALTH_ENTITY_ID
	))
	stat_system.call(
		"set_stat_base",
		RUN_HEALTH_ENTITY_ID,
		StatRegistryScript.RUN_HEALTH,
		float(maxi(0, current_health - 1))
	)
	run_health_changed.emit(_get_run_health())


func _watch_shop_close(shop: Node) -> void:
	var timer: Timer = Timer.new()
	timer.name = "ShopCloseWatcher"
	timer.wait_time = 0.1
	timer.one_shot = false
	timer.process_callback = Timer.TIMER_PROCESS_IDLE
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(shop):
			timer.queue_free()
			_start_next_node()
			return
		if int(shop.get("mode")) != SHOP_MODE_OFF:
			return
		timer.queue_free()
		_start_next_node()
	)
	timer.start()


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _reset_run_health() -> void:
	var stat_system: Node = _get_stat_system()
	if stat_system == null:
		return
	if stat_system.has_method("unregister_entity"):
		stat_system.call("unregister_entity", RUN_HEALTH_ENTITY_ID)
	if stat_system.has_method("register_entity"):
		stat_system.call("register_entity", RUN_HEALTH_ENTITY_ID, [StatRegistryScript.RUN_HEALTH])


func _get_run_health() -> int:
	var stat_system: Node = _get_stat_system()
	if stat_system == null:
		return 0
	return int(stat_system.call(
		"get_stat",
		StatRegistryScript.RUN_HEALTH,
		RUN_HEALTH_ENTITY_ID
	))


func _get_stat_system() -> Node:
	var stat_system: Node = _get_autoload_node(&"StatSystem")
	if stat_system == null or not stat_system.has_method("get_stat") or not stat_system.has_method("set_stat_base"):
		return null
	return stat_system


func _connect_event_bus() -> void:
	var event_bus: Node = _get_autoload_node(&"Event")
	if event_bus == null or not event_bus.has_signal(&"marble_fell"):
		return

	var callable: Callable = Callable(self, "_on_marble_fell")
	if not event_bus.is_connected(&"marble_fell", callable):
		event_bus.connect(&"marble_fell", callable)


func _ensure_battle_spawner() -> void:
	if battle_spawner == null:
		battle_spawner = get_node_or_null("BattleSpawner") as BattleSpawner
	if battle_spawner == null:
		battle_spawner = BattleSpawnerScript.new()
		battle_spawner.name = "BattleSpawner"
		add_child(battle_spawner)
	if battle_spawner.enemy_container == null:
		battle_spawner.enemy_container = enemy_container

	var callable: Callable = Callable(self, "_on_battle_completed")
	if not battle_spawner.battle_completed.is_connected(callable):
		battle_spawner.battle_completed.connect(callable)


func _connect_panels() -> void:
	if node_choice_panel != null and node_choice_panel.has_signal(&"option_selected"):
		var option_callable: Callable = Callable(self, "choose_option")
		if not node_choice_panel.is_connected(&"option_selected", option_callable):
			node_choice_panel.connect(&"option_selected", option_callable)

	if draft_reward_panel != null and draft_reward_panel.has_signal(&"draft_closed"):
		var draft_callable: Callable = Callable(self, "continue_after_draft")
		if not draft_reward_panel.is_connected(&"draft_closed", draft_callable):
			draft_reward_panel.connect(&"draft_closed", draft_callable)

	if upgrade_panel != null and upgrade_panel.has_signal(&"upgrade_selected"):
		var upgrade_callable: Callable = Callable(self, "_on_upgrade_selected")
		if not upgrade_panel.is_connected(&"upgrade_selected", upgrade_callable):
			upgrade_panel.connect(&"upgrade_selected", upgrade_callable)


func _ensure_marble_upgrade_system() -> void:
	if marble_upgrade_system != null and is_instance_valid(marble_upgrade_system):
		return
	marble_upgrade_system = get_node_or_null("MarbleUpgradeSystem")
	if marble_upgrade_system == null:
		marble_upgrade_system = MarbleUpgradeSystemScript.new()
		marble_upgrade_system.name = "MarbleUpgradeSystem"
		add_child(marble_upgrade_system)
