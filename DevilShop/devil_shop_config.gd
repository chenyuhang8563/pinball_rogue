extends Resource
class_name DevilShopConfig

@export var item_pool: Array[Item] = []
@export var stock_count: int = 3
@export var health_to_gold: int = 5
@export var minimum_remaining_health: int = 1
@export var level_weights: Dictionary = {2: 3, 3: 4, 4: 3}
@export var level_price_multipliers: Dictionary = {2: 1.5, 3: 2.0, 4: 3.0}
@export var long_press_delay: float = 0.35
@export var long_press_interval: float = 0.08
