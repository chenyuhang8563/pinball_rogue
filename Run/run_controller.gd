extends Node
class_name RunController

signal run_node_completed(node_kind: String)
signal battle_started(group_id: String)
signal battle_completed(group_id: String)
signal run_health_changed(health: int)
signal floor_changed(floor_number: int)
signal run_completed
signal run_failed

const BattleGroupDefScript: GDScript = preload("res://Run/battle_group_def.gd")
const RunNodeOptionScript: GDScript = preload("res://Run/run_node_option.gd")
const BattleSpawnerScript: GDScript = preload("res://Run/battle_spawner.gd")
const StatRegistryScript: GDScript = preload("res://Stats/stat_registry.gd")
const MarbleUpgradeSystemScript: GDScript = preload("res://Run/marble_upgrade_system.gd")
const BattleRewardOptionScript: GDScript = preload("res://Run/battle_reward_option.gd")
const DefaultBattleRewardConfig: Resource = preload("res://Run/default_battle_reward_config.tres")
const DefaultRunFloorConfig: RunFloorConfig = preload("res://Run/default_run_floor_config.tres")
const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")
const WEAK_LEVEL_DEF_PATH: String = "res://Levels/level_001_weak.tres"
const STRONG_LEVEL_DEF_PATH: String = "res://Levels/level_strong_normal.tres"
const ELITE_LEVEL_DEF_PATH: String = "res://Levels/level_elite.tres"
const BOSS_LEVEL_DEF_PATH: String = "res://Levels/level_boss.tres"
const STAT_ENTITY_PINBALL_TABLE: String = "pinball_table"
const DEFAULT_REWARD_ITEM_PATHS: PackedStringArray = [
	"res://Resources/brown_marble.tres",
	"res://Resources/green_marble.tres",
	"res://Resources/bomb_marble.tres",
	"res://Resources/fire_marble.tres",
	"res://Resources/lightning.tres",
	"res://Resources/fire_bellows.tres",
	"res://Resources/poison_culture.tres",
	"res://Resources/ice_hammer.tres",
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
const WEAK_ENEMY_BASE_HEALTH: int = 15
const STRONG_ENEMY_BASE_HEALTH: int = 40
const ENEMY_HEALTH_PER_NODE: int = 5
const EVENT_DICE_ID: String = "dice_gamble"
const EVENT_CROSSROADS_ID: String = "crossroads"
const BOSS_FLOOR: int = 12

@export var floor_config: RunFloorConfig = DefaultRunFloorConfig
@export var enemy_container: Node2D
@export var battle_spawner: BattleSpawner
@export var node_choice_panel: Control
@export var draft_reward_panel: Control
@export var devil_shop: DevilShop
@export var upgrade_inventory_panel: Node
@export var event_panel: Control
@export var level_parent: Node
@export var battle_reward_config: BattleRewardConfig = DefaultBattleRewardConfig

var current_node_index: int = 0
var choice_wave_index: int = 0
var run_is_complete: bool = false
var run_is_failed: bool = false
var reset_battle_state_callable: Callable = Callable()
var battle_is_active: bool = false
var marble_upgrade_system: Node
var active_level_scene: Node = null
var event_roll_callable: Callable = Callable()
var dice_roll_callable: Callable = Callable()

var _active_event_id: String = ""
var _event_wager_resolved: bool = false


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
	run_is_failed = false
	battle_is_active = false
	_active_event_id = ""
	_event_wager_resolved = false
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
	var floor_number: int = wave_index + 1
	_append_guaranteed_node_options(options, floor_number)

	var require_unique_kinds: bool = _get_enabled_node_option_kind_count() >= 3
	while options.size() < 3:
		var option: RunNodeOption = _make_weighted_node_option()
		if not require_unique_kinds or not _options_have_kind_id(options, option.kind_id):
			options.append(option)
	return options


func get_boss_floor() -> int:
	if floor_config != null:
		return floor_config.boss_floor
	return BOSS_FLOOR


func _append_guaranteed_node_options(options: Array[RunNodeOption], floor_number: int) -> void:
	if floor_config == null:
		return
	for rule: RunFloorNodeRule in floor_config.guaranteed_node_rules:
		if rule == null or rule.floor_number != floor_number:
			continue
		var option: RunNodeOption = _make_node_option_for_kind(rule.node_kind)
		if option != null and not _options_have_kind_id(options, option.kind_id):
			options.append(option)


func _make_node_option_for_kind(kind: RunNodeOption.Kind) -> RunNodeOption:
	match kind:
		RunNodeOption.Kind.BATTLE:
			return _make_normal_battle_option()
		RunNodeOption.Kind.EVENT:
			return _make_event_option()
		RunNodeOption.Kind.REWARD:
			return _make_option(RunNodeOption.Kind.REWARD, "reward", "RUN_REWARD_TITLE", "", null)
		RunNodeOption.Kind.ELITE:
			return _make_elite_option()
		RunNodeOption.Kind.UPGRADE:
			return _make_upgrade_option()
		RunNodeOption.Kind.SHOP:
			return _make_shop_option()
		RunNodeOption.Kind.DEVIL_SHOP:
			return _make_devil_shop_option()
	return null


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
	if option == null or run_is_complete or run_is_failed:
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
			_show_random_event()
		RunNodeOption.Kind.REWARD:
			_show_reward_draft()
		RunNodeOption.Kind.UPGRADE:
			_show_upgrade_choices()
		RunNodeOption.Kind.SHOP:
			_show_shop()
		RunNodeOption.Kind.DEVIL_SHOP:
			_show_devil_shop()
		_:
			_show_node_choices()


func continue_after_draft() -> void:
	_start_next_node()


func _start_next_node() -> void:
	if run_is_complete or run_is_failed:
		return

	current_node_index += 1
	floor_changed.emit(current_node_index)
	if current_node_index >= get_boss_floor():
		_begin_battle(_make_boss_group())
		return

	if current_node_index == 1:
		_begin_battle(_make_weak_group())
	else:
		_show_node_choices()


func _begin_battle(group: BattleGroupDef) -> void:
	if group == null or run_is_failed:
		return

	# Destroy any lingering floating damage texts from the previous battle
	# before spawning new enemies. The pool persists across battle transitions
	# (it's an autoload), so texts whose animation hadn't finished when the
	# last enemy died would otherwise remain visible in the new battle.
	_release_all_floating_texts()

	_activate_level_scene_for_group(group)
	_ensure_battle_spawner()
	battle_is_active = true
	run_health_changed.emit(_get_run_health())
	battle_started.emit(group.id)
	_reset_battle_state()
	if battle_spawner != null:
		battle_spawner.start_battle(group)


func _on_battle_completed(group_id: String) -> void:
	if run_is_failed or not battle_is_active:
		return
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


func _show_random_event() -> void:
	if event_panel == null:
		_start_next_node()
		return

	_active_event_id = _roll_event_id()
	_event_wager_resolved = false
	if _active_event_id == EVENT_DICE_ID:
		var shop: Node = _get_autoload_node(&"Shop")
		if shop == null or not event_panel.has_method("show_dice_event"):
			_active_event_id = ""
			_start_next_node()
			return
		event_panel.call("show_dice_event", int(shop.get("gold")))
		return

	if event_panel.has_method("show_crossroads_event"):
		event_panel.call("show_crossroads_event")
		return

	_active_event_id = ""
	_start_next_node()


func _roll_event_id() -> String:
	var roll: int = int(event_roll_callable.call()) if event_roll_callable.is_valid() else randi_range(0, 1)
	return EVENT_DICE_ID if clampi(roll, 0, 1) == 0 else EVENT_CROSSROADS_ID


func _roll_dice() -> int:
	var roll: int = int(dice_roll_callable.call()) if dice_roll_callable.is_valid() else randi_range(1, 6)
	return clampi(roll, 1, 6)


func _on_event_wager_requested(cost: int, reward: int) -> void:
	if _active_event_id != EVENT_DICE_ID or _event_wager_resolved:
		return
	if cost <= 0 or reward < 0:
		return

	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null:
		_on_event_finished()
		return

	var gold_before: int = int(shop.get("gold"))
	if gold_before < cost:
		if event_panel != null and event_panel.has_method("show_dice_event"):
			event_panel.call("show_dice_event", gold_before)
		return

	_event_wager_resolved = true
	shop.set("gold", gold_before - cost)
	var roll: int = _roll_dice()
	var granted_reward: int = reward if roll > 3 else 0
	if granted_reward > 0:
		_add_gold(granted_reward)
	var gold_delta: int = int(shop.get("gold")) - gold_before
	if event_panel != null and event_panel.has_method("reveal_dice_result"):
		event_panel.call("reveal_dice_result", roll, gold_delta, granted_reward)


func _on_event_fight_requested() -> void:
	if _active_event_id != EVENT_CROSSROADS_ID:
		return
	_active_event_id = ""
	_dismiss_event_panel()
	var group: BattleGroupDef = _make_event_strong_group()
	if group == null:
		_start_next_node()
		return
	_begin_battle(group)


func _on_event_finished() -> void:
	if _active_event_id.is_empty():
		return
	_active_event_id = ""
	_dismiss_event_panel()
	_start_next_node()


func _dismiss_event_panel() -> void:
	if event_panel != null and event_panel.has_method("dismiss"):
		event_panel.call("dismiss")


func _show_battle_rewards(group_id: String) -> void:
	if group_id.contains("normal"):
		var options: Array[BattleRewardOption] = _pick_normal_battle_reward_options()
		if draft_reward_panel == null or not draft_reward_panel.has_method("show_normal_battle_rewards"):
			_start_next_node()
			return
		draft_reward_panel.call("show_normal_battle_rewards", options)
		return
	var gold_amount: int = _roll_battle_gold(group_id)
	var items: Array[Item] = _pick_battle_reward_items(group_id)
	if draft_reward_panel == null or not draft_reward_panel.has_method("show_battle_rewards"):
		_start_next_node()
		return
	draft_reward_panel.call("show_battle_rewards", items, gold_amount)


func _show_run_completed_message() -> void:
	if node_choice_panel != null and node_choice_panel.has_method("show_message"):
		node_choice_panel.call("show_message", "RUN_COMPLETED_TITLE", "RUN_COMPLETED_DESC")


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
	var raw_items: Variant = marble_upgrade_system.call("get_upgradable_items", inventory)
	if not raw_items is Array or (raw_items as Array).is_empty():
		_show_no_upgrade_message()
		return
	if upgrade_inventory_panel != null and upgrade_inventory_panel.has_method("show_upgrade_selection"):
		upgrade_inventory_panel.call("show_upgrade_selection")
		return
	_show_no_upgrade_message()


func _show_no_upgrade_message() -> void:
	if node_choice_panel != null and node_choice_panel.has_method("show_message"):
		if node_choice_panel.has_signal(&"message_dismissed"):
			var continue_callable: Callable = Callable(self, "continue_after_draft")
			if not node_choice_panel.is_connected(&"message_dismissed", continue_callable):
				node_choice_panel.connect(&"message_dismissed", continue_callable, CONNECT_ONE_SHOT)
		node_choice_panel.call("show_message", "RUN_UPGRADE_UNAVAILABLE_TITLE", "RUN_UPGRADE_UNAVAILABLE_DESC")
	else:
		_start_next_node()


func _on_upgrade_selected(item: Item) -> void:
	_ensure_marble_upgrade_system()
	var inventory: Node = _get_autoload_node(&"Inventory")
	if bool(marble_upgrade_system.call("upgrade_item", item, inventory)):
		if upgrade_inventory_panel != null and upgrade_inventory_panel.has_method("finish_upgrade_selection"):
			upgrade_inventory_panel.call("finish_upgrade_selection")
		_start_next_node()


func _show_shop() -> void:
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null:
		_start_next_node()
		return

	_set_battle_scene_visible(false)
	shop.set("mode", SHOP_MODE_ON)
	_watch_shop_close(shop)


func _show_devil_shop() -> void:
	if devil_shop == null:
		_start_next_node()
		return
	_ensure_marble_upgrade_system()
	devil_shop.open_for_run(marble_upgrade_system)


func _pick_reward_items() -> Array[Item]:
	var default_items: Array[Item] = _get_available_reward_items()
	var result: Array[Item] = []
	for index: int in range(mini(3, default_items.size())):
		result.append(default_items[index])
	return result


func _pick_event_items() -> Array[Item]:
	var default_items: Array[Item] = _get_available_reward_items()
	var result: Array[Item] = []
	for index: int in range(default_items.size() - 1, -1, -1):
		result.append(default_items[index])
		if result.size() >= 3:
			break
	return result


func _get_available_reward_items() -> Array[Item]:
	var result: Array[Item] = []
	for item: Item in _get_default_reward_items():
		if _is_reward_item_available(item):
			result.append(item)
	return result


func _is_reward_item_available(item: Item) -> bool:
	if item == null:
		return false
	if item.type == Item.ItemType.MARBLE:
		return not _inventory_has_marble(item)
	if item.type == Item.ItemType.SKILL:
		return not _inventory_has_skill(item)
	return true


func _inventory_has_skill(item: Item) -> bool:
	var inventory := _get_autoload_node(&"Inventory")
	if inventory == null or item == null:
		return false
	var current: Item = inventory.get("skill_item") as Item
	return current != null and current.id == item.id


func _inventory_has_marble(item: Item) -> bool:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or item == null:
		return false
	if item.id != "" and inventory.has_method("has_item_id") and bool(inventory.call("has_item_id", item.id)):
		return true

	var raw_marble_items: Variant = inventory.get("marble_items")
	if not raw_marble_items is Array:
		return false

	var marble_items: Array = raw_marble_items
	for owned_item: Item in marble_items:
		if _is_same_marble_reward(owned_item, item):
			return true
	return false


func _is_same_marble_reward(owned_item: Item, reward_item: Item) -> bool:
	if owned_item == null or reward_item == null:
		return false
	if owned_item.id != "" and reward_item.id != "" and owned_item.id == reward_item.id:
		return true
	return owned_item.marble_type == reward_item.marble_type


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
		var minimum := battle_reward_config.gold_min if battle_reward_config != null else NORMAL_BATTLE_GOLD_MIN
		var maximum := battle_reward_config.gold_max if battle_reward_config != null else NORMAL_BATTLE_GOLD_MAX
		return randi_range(minimum, maximum)
	return 0


func get_normal_reward_weights() -> Dictionary:
	if battle_reward_config == null:
		return {"gold": 50, "marble": 35, "skill": 15}
	return {
		"gold": battle_reward_config.gold_weight,
		"marble": battle_reward_config.marble_weight,
		"skill": battle_reward_config.skill_weight,
	}


func _pick_normal_battle_reward_options() -> Array[BattleRewardOption]:
	var result: Array[BattleRewardOption] = []
	var marble_pool := _load_receivable_items(battle_reward_config.marble_item_paths, Item.ItemType.MARBLE)
	var skill_pool := _load_receivable_items(battle_reward_config.skill_item_paths, Item.ItemType.SKILL)
	var categories: Array[Dictionary] = []
	var weights := get_normal_reward_weights()
	categories.append({"id": "gold", "weight": int(weights.gold)})
	if not marble_pool.is_empty():
		categories.append({"id": "marble", "weight": int(weights.marble)})
	if not skill_pool.is_empty():
		categories.append({"id": "skill", "weight": int(weights.skill)})

	while result.size() < 2 and not categories.is_empty():
		var category_index := _roll_weighted_category_index(categories)
		var category: Dictionary = categories[category_index]
		categories.remove_at(category_index)
		match String(category.id):
			"gold":
				result.append(BattleRewardOptionScript.gold(_roll_battle_gold("normal")))
			"marble":
				result.append(BattleRewardOptionScript.item_reward(marble_pool.pick_random()))
			"skill":
				result.append(BattleRewardOptionScript.item_reward(skill_pool.pick_random()))

	if result.size() < 2 and not _has_gold_option(result):
		result.append(BattleRewardOptionScript.gold(_roll_battle_gold("normal")))
	return result


func _load_receivable_items(paths: PackedStringArray, expected_type: Item.ItemType) -> Array[Item]:
	var result: Array[Item] = []
	var inventory := _get_autoload_node(&"Inventory")
	for path: String in paths:
		var item := load(path) as Item
		if item == null or item.type != expected_type or not _is_reward_item_available(item):
			continue
		if item.type == Item.ItemType.MARBLE and inventory != null and inventory.has_method("can_add_item"):
			if not bool(inventory.call("can_add_item", item)):
				continue
		result.append(item)
	return result


func _roll_weighted_category_index(categories: Array[Dictionary]) -> int:
	var total := 0
	for category: Dictionary in categories:
		total += maxi(0, int(category.weight))
	if total <= 0:
		return 0
	var roll := randi_range(1, total)
	for index: int in range(categories.size()):
		roll -= maxi(0, int(categories[index].weight))
		if roll <= 0:
			return index
	return categories.size() - 1


func _has_gold_option(options: Array[BattleRewardOption]) -> bool:
	for option: BattleRewardOption in options:
		if option != null and option.kind == BattleRewardOption.Kind.GOLD:
			return true
	return false


func _add_gold(amount: int) -> void:
	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null:
		return
	shop.set("gold", int(shop.get("gold")) + amount)


func _pick_normal_battle_group() -> BattleGroupDef:
	if current_node_index <= 1:
		return _make_weak_group()
	return _make_strong_group()


func _load_level_def(path: String) -> LevelDef:
	var resource: Resource = load(path) as Resource
	return resource as LevelDef


func _get_enemy_health(base_health: int) -> int:
	var node_index: int = maxi(1, current_node_index)
	return base_health + (node_index - 1) * ENEMY_HEALTH_PER_NODE


func _get_weak_enemy_health() -> int:
	return _get_enemy_health(WEAK_ENEMY_BASE_HEALTH)


func _get_strong_enemy_health() -> int:
	return _get_enemy_health(STRONG_ENEMY_BASE_HEALTH)


func _get_pool_health(enemy_pool: LevelDef.EnemyPool) -> int:
	match enemy_pool:
		LevelDef.EnemyPool.STRONG:
			return _get_strong_enemy_health()
		_:
			return _get_weak_enemy_health()


func _get_spawn_pool(level_def: LevelDef, spawn: LevelEnemySpawn) -> LevelDef.EnemyPool:
	if spawn.pool_override == LevelEnemySpawn.PoolOverride.STRONG:
		return LevelDef.EnemyPool.STRONG
	if spawn.pool_override == LevelEnemySpawn.PoolOverride.WEAK:
		return LevelDef.EnemyPool.WEAK
	return level_def.enemy_pool


func _get_spawn_health(level_def: LevelDef, spawn: LevelEnemySpawn) -> int:
	if spawn.health_override >= 0:
		return spawn.health_override

	var base_health: int = _get_pool_health(_get_spawn_pool(level_def, spawn))
	match spawn.role:
		LevelEnemySpawn.Role.ELITE:
			return floori(base_health * 1.5)
		LevelEnemySpawn.Role.BOSS:
			return 240
		_:
			return base_health


func _make_group_from_level_def(level_def: LevelDef) -> BattleGroupDef:
	if level_def == null or level_def.level_scene == null:
		return null

	var level_scene: Node = level_def.level_scene.instantiate()
	var entries: Array[BattleGroupDef.EnemyEntry] = _build_enemy_entries_from_level_scene(level_def, level_scene)
	level_scene.free()
	if entries.is_empty():
		return null

	var group_id: String = "%s_%d" % [level_def.id, current_node_index]
	var group: BattleGroupDef = _make_group(group_id, level_def.title, level_def.kind, entries)
	group.level_def = level_def
	return group


func _build_enemy_entries_from_level_scene(level_def: LevelDef, level_scene: Node) -> Array[BattleGroupDef.EnemyEntry]:
	var entries: Array[BattleGroupDef.EnemyEntry] = []
	if level_scene == null:
		return entries

	var spawn_root: Node = level_scene.get_node_or_null("EnemySpawns")
	if spawn_root == null:
		return entries

	for child: Node in spawn_root.get_children():
		var spawn: LevelEnemySpawn = child as LevelEnemySpawn
		if spawn == null:
			continue
		var enemy_scene: PackedScene = spawn.enemy_scene if spawn.enemy_scene != null else EnemyScene
		entries.append(_enemy_entry_with_scene(
			enemy_scene,
			spawn.global_position,
			_get_spawn_health(level_def, spawn)
		))
	return entries


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
	return _make_option(RunNodeOption.Kind.BATTLE, "battle", "RUN_BATTLE_TITLE", "", _make_strong_group())


func _make_event_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.EVENT, "event", "RUN_EVENT_TITLE", "", null)


func _make_elite_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.ELITE, "elite", "RUN_ELITE_FIGHT_TITLE", "", _make_elite_group())


func _make_upgrade_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.UPGRADE, "upgrade", "RUN_UPGRADE_TITLE", "", null)


func _make_shop_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.SHOP, "shop", "RUN_SHOP_TITLE", "", null)


func _make_devil_shop_option() -> RunNodeOption:
	return _make_option(RunNodeOption.Kind.DEVIL_SHOP, "devil_shop", "RUN_DEVIL_SHOP_TITLE", "", null)


func _make_weak_group() -> BattleGroupDef:
	var level_group: BattleGroupDef = _make_group_from_level_def(_load_level_def(WEAK_LEVEL_DEF_PATH))
	if level_group != null:
		return level_group

	var weak_enemy_health: int = _get_weak_enemy_health()
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(72, 48), weak_enemy_health),
		_enemy_entry(Vector2(120, 72), weak_enemy_health),
		_enemy_entry(Vector2(168, 48), weak_enemy_health),
	]
	return _make_group("weak_normal_%d" % current_node_index, "RUN_WEAK_FIGHT_TITLE", BattleGroupDef.Kind.WEAK_NORMAL, entries)


func _make_strong_group() -> BattleGroupDef:
	var level_group: BattleGroupDef = _make_group_from_level_def(_load_level_def(STRONG_LEVEL_DEF_PATH))
	if level_group != null:
		return level_group

	var strong_enemy_health: int = _get_strong_enemy_health()
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(64, 48), strong_enemy_health),
		_enemy_entry(Vector2(104, 88), strong_enemy_health),
		_enemy_entry(Vector2(144, 48), strong_enemy_health),
		_enemy_entry(Vector2(184, 88), strong_enemy_health),
		_enemy_entry(Vector2(120, 132), strong_enemy_health),
	]
	return _make_group("strong_normal_%d" % current_node_index, "RUN_STRONG_FIGHT_TITLE", BattleGroupDef.Kind.STRONG_NORMAL, entries)


func _make_event_strong_group() -> BattleGroupDef:
	var group: BattleGroupDef = _make_strong_group()
	if group == null:
		return null
	group.id = "event_elite_%d" % current_node_index
	group.title = "EVENT_CROSSROADS_FIGHT_TITLE"
	group.kind = BattleGroupDef.Kind.ELITE
	return group


func _make_elite_group() -> BattleGroupDef:
	var level_group: BattleGroupDef = _make_group_from_level_def(_load_level_def(ELITE_LEVEL_DEF_PATH))
	if level_group != null:
		return level_group

	var strong_enemy_health: int = _get_strong_enemy_health()
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(120, 64), floori(strong_enemy_health * 1.5)),
		_enemy_entry(Vector2(80, 124), strong_enemy_health),
		_enemy_entry(Vector2(160, 124), strong_enemy_health),
	]
	return _make_group("elite_%d" % current_node_index, "RUN_ELITE_FIGHT_TITLE", BattleGroupDef.Kind.ELITE, entries)


func _make_boss_group() -> BattleGroupDef:
	var level_group: BattleGroupDef = _make_group_from_level_def(_load_level_def(BOSS_LEVEL_DEF_PATH))
	if level_group != null:
		return level_group

	var weak_enemy_health: int = _get_weak_enemy_health()
	var entries: Array[BattleGroupDef.EnemyEntry] = [
		_enemy_entry(Vector2(120, 64), 240),
		_enemy_entry(Vector2(72, 128), weak_enemy_health),
		_enemy_entry(Vector2(168, 128), weak_enemy_health),
	]
	return _make_group("boss_%d" % current_node_index, "RUN_BOSS_FIGHT_TITLE", BattleGroupDef.Kind.BOSS, entries)


func _make_group(id: String, title: String, kind: BattleGroupDef.Kind, entries: Array[BattleGroupDef.EnemyEntry]) -> BattleGroupDef:
	var group: BattleGroupDef = BattleGroupDefScript.new()
	group.id = id
	group.title = title
	group.kind = kind
	group.enemy_entries = entries
	return group


func _enemy_entry(position: Vector2, health: int) -> BattleGroupDef.EnemyEntry:
	return _enemy_entry_with_scene(EnemyScene, position, health)


func _enemy_entry_with_scene(scene: PackedScene, position: Vector2, health: int) -> BattleGroupDef.EnemyEntry:
	var entry: BattleGroupDef.EnemyEntry = BattleGroupDef.EnemyEntry.new()
	entry.scene = scene
	entry.position = position
	entry.health = health
	return entry


func _activate_level_scene_for_group(group: BattleGroupDef) -> void:
	var level_def: LevelDef = group.level_def as LevelDef
	if level_def == null or level_def.level_scene == null:
		return

	var parent: Node = _get_level_scene_parent()
	if parent == null:
		return

	var previous_enemy_container: Node2D = enemy_container
	_clear_active_level_scene()

	var scene: Node = level_def.level_scene.instantiate()
	scene.name = "ActiveLevel"
	parent.add_child(scene)
	active_level_scene = scene
	_apply_level_bounceless_wall_material(scene)

	var scene_enemy_container: Node2D = scene.get_node_or_null("Enemies") as Node2D
	if scene_enemy_container == null:
		return

	_clear_legacy_enemy_container(previous_enemy_container, scene_enemy_container)
	enemy_container = scene_enemy_container
	if battle_spawner != null:
		battle_spawner.enemy_container = enemy_container


func _get_level_scene_parent() -> Node:
	if level_parent != null and is_instance_valid(level_parent):
		return level_parent
	if active_level_scene != null and is_instance_valid(active_level_scene) and active_level_scene.get_parent() != null:
		return active_level_scene.get_parent()
	if enemy_container != null and is_instance_valid(enemy_container):
		var container_parent: Node = enemy_container.get_parent()
		if container_parent != null:
			if container_parent == active_level_scene and active_level_scene.get_parent() != null:
				return active_level_scene.get_parent()
			return container_parent
	return self


func _clear_active_level_scene() -> void:
	if active_level_scene == null or not is_instance_valid(active_level_scene):
		active_level_scene = null
		return
	var parent: Node = active_level_scene.get_parent()
	if parent != null:
		parent.remove_child(active_level_scene)
	active_level_scene.queue_free()
	active_level_scene = null


func _clear_legacy_enemy_container(previous_enemy_container: Node2D, next_enemy_container: Node2D) -> void:
	if previous_enemy_container == null or previous_enemy_container == next_enemy_container:
		return
	if not is_instance_valid(previous_enemy_container):
		return

	for child: Node in previous_enemy_container.get_children():
		child.free()
	previous_enemy_container.visible = false


func _apply_level_bounceless_wall_material(level_scene: Node) -> void:
	if level_scene == null:
		return
	var wall: StaticBody2D = level_scene.find_child("BouncelessWall", true, false) as StaticBody2D
	if wall == null:
		return

	var stat_system: Node = _get_stat_system()
	if stat_system == null:
		return

	var physics_material: PhysicsMaterial = wall.physics_material_override
	if physics_material == null:
		physics_material = PhysicsMaterial.new()
	else:
		physics_material = physics_material.duplicate()
	physics_material.bounce = float(stat_system.call(
		"get_stat",
		StatRegistryScript.BOUNCELESS_WALL_BOUNCE,
		STAT_ENTITY_PINBALL_TABLE
	))
	wall.physics_material_override = physics_material


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


## Clears all active floating damage texts from the autoload pool.
## Prevents texts from a previous battle (whose animations hadn't finished
## when the last enemy died) from persisting into the next battle.
func _release_all_floating_texts() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var pool: Node = tree.root.get_node_or_null("FloatDamageTextPool")
	if pool != null and pool.has_method("release_all_active"):
		pool.call("release_all_active")


func _on_marble_fell(marble: RigidBody2D) -> void:
	if run_is_failed or not battle_is_active:
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
	var updated_health: int = _get_run_health()
	run_health_changed.emit(updated_health)
	if updated_health == 0:
		_fail_run()


func _fail_run() -> void:
	if run_is_complete or run_is_failed:
		return
	run_is_failed = true
	battle_is_active = false
	run_failed.emit()


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
			_set_battle_scene_visible(true)
			_start_next_node()
			return
		if int(shop.get("mode")) != SHOP_MODE_OFF:
			return
		timer.queue_free()
		_set_battle_scene_visible(true)
		_start_next_node()
	)
	timer.start()


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


## Hides/shows the battle scene (parent's CanvasLayer and Marbles children)
## when the shop opens/closes, so the shop overlays a clean background —
## matching the behavior of other branch nodes whose Backdrop ColorRect
## visually occludes the battle view.
##
## Kept here (rather than in Shop) per the UI rule that forbids GDScript
## from mutating `visible` properties; the flow orchestrator owns scene
## visibility transitions between branch nodes.
func _set_battle_scene_visible(visible: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var canvas_layer: Node = parent_node.get_node_or_null("CanvasLayer")
	if canvas_layer != null:
		canvas_layer.visible = visible
	var marbles: Node = parent_node.get_node_or_null("Marbles")
	if marbles != null:
		marbles.visible = visible


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

	if upgrade_inventory_panel != null and upgrade_inventory_panel.has_signal(&"upgrade_item_selected"):
		var inventory_upgrade_callable := Callable(self, "_on_upgrade_selected")
		if not upgrade_inventory_panel.is_connected(&"upgrade_item_selected", inventory_upgrade_callable):
			upgrade_inventory_panel.connect(&"upgrade_item_selected", inventory_upgrade_callable)

	if event_panel != null:
		_connect_event_panel_signal(&"wager_requested", Callable(self, "_on_event_wager_requested"))
		_connect_event_panel_signal(&"fight_requested", Callable(self, "_on_event_fight_requested"))
		_connect_event_panel_signal(&"escape_requested", Callable(self, "_on_event_finished"))
		_connect_event_panel_signal(&"continued", Callable(self, "_on_event_finished"))


func _connect_event_panel_signal(signal_name: StringName, callable: Callable) -> void:
	if not event_panel.has_signal(signal_name) or event_panel.is_connected(signal_name, callable):
		return
	event_panel.connect(signal_name, callable)

	if devil_shop != null:
		var close_callable: Callable = Callable(self, "_on_devil_shop_closed")
		if not devil_shop.closed.is_connected(close_callable):
			devil_shop.closed.connect(close_callable)
		var health_callable: Callable = Callable(self, "_on_devil_shop_health_changed")
		if not devil_shop.health_changed.is_connected(health_callable):
			devil_shop.health_changed.connect(health_callable)


func _on_devil_shop_closed() -> void:
	_set_battle_scene_visible(true)
	_start_next_node()


func _on_devil_shop_health_changed(value: int) -> void:
	run_health_changed.emit(value)


func _ensure_marble_upgrade_system() -> void:
	if marble_upgrade_system != null and is_instance_valid(marble_upgrade_system):
		return
	marble_upgrade_system = get_node_or_null("MarbleUpgradeSystem")
	if marble_upgrade_system == null:
		marble_upgrade_system = MarbleUpgradeSystemScript.new()
		marble_upgrade_system.name = "MarbleUpgradeSystem"
		add_child(marble_upgrade_system)
