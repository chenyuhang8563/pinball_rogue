extends Resource
class_name RelicLevelConfig

## 遗物等级数据配置。
## level_values 按等级索引（index = level - 1）存放每级的主数值。
## extra 存放遗物特有的非等级/觉醒行为参数。

@export var max_level: int = 3
@export var level_values: Array[int] = []
@export var extra: Dictionary = {}


## 安全读取指定等级的主数值，越界时 clamp 到数组末尾。
func get_value(level: int) -> int:
	if level_values.is_empty():
		return 0
	var index: int = clampi(level - 1, 0, level_values.size() - 1)
	return level_values[index]
