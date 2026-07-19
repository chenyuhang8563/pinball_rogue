extends RefCounted
class_name BattlePlanFactory

const BattlePlanScript: GDScript = preload("res://Run/domain/battle_plan.gd")
const BattlePlanResultScript: GDScript = preload("res://Run/domain/battle_plan_result.gd")
const BattleGroupDefScript: GDScript = preload("res://Run/battle_group_def.gd")
const DefaultEnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")

const WEAK_LEVEL_DEF_PATH: String = "res://Levels/level_001_weak.tres"
const STRONG_LEVEL_DEF_PATH: String = "res://Levels/level_strong_normal.tres"
const ELITE_LEVEL_DEF_PATH: String = "res://Levels/level_elite.tres"
const BOSS_LEVEL_DEF_PATH: String = "res://Levels/level_boss.tres"

const WEAK_ENEMY_BASE_HEALTH: int = 15
const STRONG_ENEMY_BASE_HEALTH: int = 40
const ENEMY_HEALTH_PER_FLOOR: int = 5
const BOSS_HEALTH: int = 240

const CONTENT_KEYS: PackedStringArray = [&"weak", &"normal", &"elite", &"boss", &"enemy_scene"]

var _content: Dictionary = {
	&"weak": WEAK_LEVEL_DEF_PATH,
	&"normal": STRONG_LEVEL_DEF_PATH,
	&"elite": ELITE_LEVEL_DEF_PATH,
	&"boss": BOSS_LEVEL_DEF_PATH,
	&"enemy_scene": DefaultEnemyScene,
}
var _content_is_valid: bool = true


## Values for weak/normal/elite/boss may be a LevelDef, a resource path, or an
## Array containing either. Multiple definitions are selected by RunRandomSource.
func configure(content: Dictionary) -> bool:
	_content_is_valid = true
	for key: Variant in content.keys():
		var content_key := StringName(key)
		if not CONTENT_KEYS.has(content_key) or not _is_supported_content(content_key, content[key]):
			_content_is_valid = false
			continue
		_content[content_key] = content[key]
	return _content_is_valid


func create(
	floor_number: int,
	origin: BattlePlanOrigin,
	floor_config: RunFloorConfig,
	random_source: RunRandomSource
) -> BattlePlanResult:
	if floor_number < 1:
		return BattlePlanResultScript.failure(BattlePlanResult.Code.INVALID_FLOOR, "floor must be positive")
	if origin == null or not origin.is_valid():
		return BattlePlanResultScript.failure(BattlePlanResult.Code.INVALID_ORIGIN, "unsupported battle origin")
	if floor_config == null or floor_config.boss_floor < 2:
		return BattlePlanResultScript.failure(BattlePlanResult.Code.INVALID_FLOOR_CONFIG, "floor config is required")
	if random_source == null:
		return BattlePlanResultScript.failure(BattlePlanResult.Code.INVALID_RANDOM_SOURCE, "random source is required")
	if not _content_is_valid:
		return BattlePlanResultScript.failure(BattlePlanResult.Code.INVALID_CONTENT, "configured battle content is invalid")
	if origin.context == BattlePlanOrigin.Context.RUN_START and floor_number != 1:
		return BattlePlanResultScript.failure(BattlePlanResult.Code.INVALID_FLOOR, "run-start battle must be floor 1")
	if origin.context == BattlePlanOrigin.Context.BOSS and floor_number != floor_config.boss_floor:
		return BattlePlanResultScript.failure(BattlePlanResult.Code.INVALID_FLOOR, "boss battle must use configured boss floor")

	var content_key: StringName = _content_key_for(origin)
	var level_def: LevelDef = _pick_level_def(_content.get(content_key), random_source)
	var group: BattleGroupDef = _make_group_from_level_def(level_def, floor_number)
	if group == null:
		group = _make_fallback_group(content_key, floor_number)
	if group == null:
		return BattlePlanResultScript.failure(BattlePlanResult.Code.BUILD_FAILED, "could not build battle group")

	var plan_origin: BattlePlan.Origin = _plan_origin_for(origin)
	var reward_policy: BattlePlan.RewardPolicy = _reward_policy_for(origin)
	var battle_id := StringName("%s:%s:%d" % [
		_context_id(origin.context), _encounter_id(origin.encounter), floor_number
	])
	group.id = String(battle_id)
	if origin.context == BattlePlanOrigin.Context.EVENT:
		group.title = "EVENT_CROSSROADS_FIGHT_TITLE"
		group.kind = BattleGroupDef.Kind.ELITE
	var plan: BattlePlan = BattlePlanScript.new(battle_id, group, plan_origin, reward_policy)
	return BattlePlanResultScript.ok(plan)


func _content_key_for(origin: BattlePlanOrigin) -> StringName:
	if origin.context == BattlePlanOrigin.Context.RUN_START:
		return &"weak"
	if origin.context == BattlePlanOrigin.Context.BOSS:
		return &"boss"
	if origin.context == BattlePlanOrigin.Context.EVENT:
		return &"normal"
	return &"elite" if origin.encounter == BattlePlanOrigin.Encounter.ELITE else &"normal"


func _plan_origin_for(origin: BattlePlanOrigin) -> BattlePlan.Origin:
	match origin.context:
		BattlePlanOrigin.Context.RUN_START:
			return BattlePlan.Origin.RUN_START
		BattlePlanOrigin.Context.EVENT:
			return BattlePlan.Origin.EVENT
		BattlePlanOrigin.Context.BOSS:
			return BattlePlan.Origin.BOSS
	return BattlePlan.Origin.NODE


func _reward_policy_for(origin: BattlePlanOrigin) -> BattlePlan.RewardPolicy:
	if origin.context == BattlePlanOrigin.Context.BOSS:
		return BattlePlan.RewardPolicy.NONE
	if origin.encounter == BattlePlanOrigin.Encounter.ELITE:
		return BattlePlan.RewardPolicy.ELITE
	return BattlePlan.RewardPolicy.NORMAL


func _pick_level_def(value: Variant, random_source: RunRandomSource) -> LevelDef:
	if value is Array:
		var choices: Array = value
		if choices.is_empty():
			return null
		return _resolve_level_def(choices[random_source.range_int(0, choices.size() - 1)])
	return _resolve_level_def(value)


func _resolve_level_def(value: Variant) -> LevelDef:
	if value is LevelDef:
		return value as LevelDef
	if value is String or value is StringName:
		return load(String(value)) as LevelDef
	return null


func _make_group_from_level_def(level_def: LevelDef, floor_number: int) -> BattleGroupDef:
	if level_def == null or level_def.level_scene == null:
		return null
	var level_scene: Node = level_def.level_scene.instantiate()
	if level_scene == null:
		return null
	var entries: Array[BattleGroupDef.EnemyEntry] = _build_enemy_entries(level_def, level_scene, floor_number)
	level_scene.free()
	if entries.is_empty():
		return null
	var group: BattleGroupDef = _make_group(level_def.title, level_def.kind, entries)
	group.level_def = level_def
	return group


func _build_enemy_entries(
	level_def: LevelDef,
	level_scene: Node,
	floor_number: int
) -> Array[BattleGroupDef.EnemyEntry]:
	var entries: Array[BattleGroupDef.EnemyEntry] = []
	var spawn_root: Node = level_scene.get_node_or_null("EnemySpawns")
	if spawn_root == null:
		return entries
	for child: Node in spawn_root.get_children():
		var spawn: LevelEnemySpawn = child as LevelEnemySpawn
		if spawn == null:
			continue
		var enemy_scene: PackedScene = spawn.enemy_scene
		if enemy_scene == null:
			enemy_scene = _content.get(&"enemy_scene") as PackedScene
		if enemy_scene == null:
			continue
		entries.append(_enemy_entry(enemy_scene, spawn.global_position, _spawn_health(level_def, spawn, floor_number)))
	return entries


func _spawn_health(level_def: LevelDef, spawn: LevelEnemySpawn, floor_number: int) -> int:
	if spawn.health_override >= 0:
		return spawn.health_override
	var pool: LevelDef.EnemyPool = level_def.enemy_pool
	if spawn.pool_override == LevelEnemySpawn.PoolOverride.WEAK:
		pool = LevelDef.EnemyPool.WEAK
	elif spawn.pool_override == LevelEnemySpawn.PoolOverride.STRONG:
		pool = LevelDef.EnemyPool.STRONG
	var health: int = _scaled_health(
		STRONG_ENEMY_BASE_HEALTH if pool == LevelDef.EnemyPool.STRONG else WEAK_ENEMY_BASE_HEALTH,
		floor_number
	)
	match spawn.role:
		LevelEnemySpawn.Role.ELITE:
			return floori(health * 1.5)
		LevelEnemySpawn.Role.BOSS:
			return BOSS_HEALTH
	return health


func _make_fallback_group(content_key: StringName, floor_number: int) -> BattleGroupDef:
	var enemy_scene: PackedScene = _content.get(&"enemy_scene") as PackedScene
	if enemy_scene == null:
		return null
	var weak_health := _scaled_health(WEAK_ENEMY_BASE_HEALTH, floor_number)
	var strong_health := _scaled_health(STRONG_ENEMY_BASE_HEALTH, floor_number)
	match content_key:
		&"weak":
			return _make_group("RUN_WEAK_FIGHT_TITLE", BattleGroupDef.Kind.WEAK_NORMAL, [
				_enemy_entry(enemy_scene, Vector2(72, 48), weak_health),
				_enemy_entry(enemy_scene, Vector2(120, 72), weak_health),
				_enemy_entry(enemy_scene, Vector2(168, 48), weak_health),
			])
		&"normal":
			return _make_group("RUN_STRONG_FIGHT_TITLE", BattleGroupDef.Kind.STRONG_NORMAL, [
				_enemy_entry(enemy_scene, Vector2(64, 48), strong_health),
				_enemy_entry(enemy_scene, Vector2(104, 88), strong_health),
				_enemy_entry(enemy_scene, Vector2(144, 48), strong_health),
				_enemy_entry(enemy_scene, Vector2(184, 88), strong_health),
				_enemy_entry(enemy_scene, Vector2(120, 132), strong_health),
			])
		&"elite":
			return _make_group("RUN_ELITE_FIGHT_TITLE", BattleGroupDef.Kind.ELITE, [
				_enemy_entry(enemy_scene, Vector2(120, 64), floori(strong_health * 1.5)),
				_enemy_entry(enemy_scene, Vector2(80, 124), strong_health),
				_enemy_entry(enemy_scene, Vector2(160, 124), strong_health),
			])
		&"boss":
			return _make_group("RUN_BOSS_FIGHT_TITLE", BattleGroupDef.Kind.BOSS, [
				_enemy_entry(enemy_scene, Vector2(120, 64), BOSS_HEALTH),
				_enemy_entry(enemy_scene, Vector2(72, 128), weak_health),
				_enemy_entry(enemy_scene, Vector2(168, 128), weak_health),
			])
	return null


func _scaled_health(base_health: int, floor_number: int) -> int:
	return base_health + (maxi(1, floor_number) - 1) * ENEMY_HEALTH_PER_FLOOR


func _make_group(
	title: String,
	kind: BattleGroupDef.Kind,
	entries: Array[BattleGroupDef.EnemyEntry]
) -> BattleGroupDef:
	var group: BattleGroupDef = BattleGroupDefScript.new()
	group.title = title
	group.kind = kind
	group.enemy_entries = entries
	return group


func _enemy_entry(scene: PackedScene, position: Vector2, health: int) -> BattleGroupDef.EnemyEntry:
	var entry: BattleGroupDef.EnemyEntry = BattleGroupDef.EnemyEntry.new()
	entry.scene = scene
	entry.position = position
	entry.health = health
	return entry


func _is_supported_content(key: StringName, value: Variant) -> bool:
	if key == &"enemy_scene":
		return value is PackedScene
	if value is LevelDef or value is String or value is StringName:
		return true
	if value is Array:
		var values: Array = value
		if values.is_empty():
			return false
		for item: Variant in values:
			if not (item is LevelDef or item is String or item is StringName):
				return false
		return true
	return false


func _context_id(context: BattlePlanOrigin.Context) -> String:
	match context:
		BattlePlanOrigin.Context.RUN_START:
			return "run_start"
		BattlePlanOrigin.Context.EVENT:
			return "event"
		BattlePlanOrigin.Context.BOSS:
			return "boss"
	return "node"


func _encounter_id(encounter: BattlePlanOrigin.Encounter) -> String:
	match encounter:
		BattlePlanOrigin.Encounter.ELITE:
			return "elite"
		BattlePlanOrigin.Encounter.BOSS:
			return "boss"
	return "normal"
