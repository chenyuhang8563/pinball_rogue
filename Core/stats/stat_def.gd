extends Resource
class_name StatDef

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = ""
@export var base_value: float = 0.0
@export var min_value: float = -1.0e20
@export var max_value: float = 1.0e20
@export var integer: bool = false
@export var formula: Resource = null
