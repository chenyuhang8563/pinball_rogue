extends Resource
class_name BattleRewardOption

enum Kind {
	GOLD,
	ITEM,
}

@export var kind: Kind = Kind.GOLD
@export var item: Item
@export var gold_amount: int = 0


static func gold(amount: int) -> BattleRewardOption:
	var option := BattleRewardOption.new()
	option.kind = Kind.GOLD
	option.gold_amount = maxi(0, amount)
	return option


static func item_reward(value: Item) -> BattleRewardOption:
	var option := BattleRewardOption.new()
	option.kind = Kind.ITEM
	option.item = value
	return option

