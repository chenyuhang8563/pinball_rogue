extends Resource
class_name RunNodeOption

enum Kind {
	BATTLE,
	EVENT,
	REWARD,
	ELITE,
	UPGRADE,
	SHOP,
	DEVIL_SHOP,
}

@export var kind: Kind = Kind.BATTLE
@export var kind_id: String = "battle"
@export var title: String = ""
@export var description: String = ""
@export var battle_group: BattleGroupDef
