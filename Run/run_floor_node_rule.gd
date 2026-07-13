extends Resource
class_name RunFloorNodeRule

## One node type that must be offered when the run reaches floor_number.
@export_range(2, 99, 1) var floor_number: int = 2
@export var node_kind: RunNodeOption.Kind = RunNodeOption.Kind.SHOP
