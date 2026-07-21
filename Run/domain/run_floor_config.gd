extends Resource
class_name RunFloorConfig

## The floor that starts the final boss battle instead of presenting node choices.
@export_range(2, 99, 1) var boss_floor: int = 12

## Each entry guarantees one node type on its configured floor.
@export var guaranteed_node_rules: Array[RunFloorNodeRule] = []
