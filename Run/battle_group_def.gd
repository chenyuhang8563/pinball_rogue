extends Resource
class_name BattleGroupDef

enum Kind {
	WEAK_NORMAL,
	STRONG_NORMAL,
	ELITE,
	BOSS,
}

class EnemyEntry:
	extends Resource

	@export var scene: PackedScene
	@export var position: Vector2 = Vector2.ZERO
	@export var health: int = 10


@export var id: String = ""
@export var title: String = ""
@export var kind: Kind = Kind.WEAK_NORMAL
@export var enemy_entries: Array[EnemyEntry] = []


func is_boss() -> bool:
	return kind == Kind.BOSS
