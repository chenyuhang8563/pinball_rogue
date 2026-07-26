extends Resource
class_name BattleRewardConfig

@export_group("Item Category Weights (Gold Is Guaranteed)")
@export var marble_weight: int = 35
@export var skill_weight: int = 15

# 兼容已有资源；普通战斗金币已改为固定选项，不再参与类别抽取。
@export_storage var gold_weight: int = 50

@export_group("Normal Battle Gold")
@export var gold_min: int = 15
@export var gold_max: int = 20

@export_group("Item Pools")
@export var marble_item_paths: PackedStringArray = []
@export var skill_item_paths: PackedStringArray = []
