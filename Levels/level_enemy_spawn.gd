extends Marker2D
class_name LevelEnemySpawn

enum Role {
	NORMAL,
	ELITE,
	BOSS,
}

enum PoolOverride {
	LEVEL_DEFAULT,
	WEAK,
	STRONG,
}

@export var enemy_scene: PackedScene
@export var role: Role = Role.NORMAL
@export var pool_override: PoolOverride = PoolOverride.LEVEL_DEFAULT
@export var health_override: int = -1
