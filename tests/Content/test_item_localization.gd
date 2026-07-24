extends GutTest

const PustuleItem: Item = preload("res://Content/data/pustule.tres")
const CarrionItem: Item = preload("res://Content/data/carrion.tres")
const ParasiteItem: Item = preload("res://Content/data/parasite.tres")
const VenomKnifeItem: Item = preload("res://Content/data/venom_knife.tres")
const ScorpionTailItem: Item = preload("res://Content/data/scorpion_tail.tres")
const WitchHatItem: Item = preload("res://Content/data/witch_hat.tres")


func test_pustule_description_is_chinese_in_chinese_locale() -> void:
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	assert_eq(
		TranslationServer.translate("ITEM_PUSTULE_DESC"),
		"感染的敌人死亡时爆裂，额外释放瘟疫苍蝇。"
	)
	assert_eq(PustuleItem.description, "ITEM_PUSTULE_DESC")
	TranslationServer.set_locale(previous_locale)


func test_plague_relic_resources_match_the_appended_effect_type_enum_values() -> void:
	assert_eq(CarrionItem.effect_type, Item.EffectType.CARRION)
	assert_eq(ParasiteItem.effect_type, Item.EffectType.PARASITE)
	assert_eq(PustuleItem.effect_type, Item.EffectType.PUSTULE)
	assert_eq(VenomKnifeItem.effect_type, Item.EffectType.VENOM_KNIFE)
	assert_eq(ScorpionTailItem.effect_type, Item.EffectType.SCORPION_TAIL)
	assert_eq(WitchHatItem.effect_type, Item.EffectType.WITCH_HAT)
