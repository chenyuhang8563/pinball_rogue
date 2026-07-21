extends Resource
class_name LevelDef

enum EnemyPool {
	WEAK,
	STRONG,
}

@export var id: String = ""
@export var title: String = ""
@export var level_index: int = 1
@export var kind: BattleGroupDef.Kind = BattleGroupDef.Kind.WEAK_NORMAL
@export var enemy_pool: EnemyPool = EnemyPool.WEAK
@export var level_scene: PackedScene
@export var gold_min: int = 0
@export var gold_max: int = 0
@export var reward_pool: Array[Item] = []
