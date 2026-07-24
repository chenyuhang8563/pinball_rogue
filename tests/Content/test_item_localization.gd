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


func test_burn_status_uses_translatable_name_and_description_keys() -> void:
	# Regression source: the burn tooltip was shown in English in a Chinese game.
	# Repair: BuffDef stores translation keys; boundary: both its name and description resolve in zh_CN.
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var burn := FireBurnDebuff.new()
	var translated_name := TranslationServer.translate(burn.display_name)
	var translated_description := TranslationServer.translate(burn.description)
	TranslationServer.set_locale(previous_locale)
	assert_eq(burn.display_name, "STATUS_BURN_NAME")
	assert_eq(burn.description, "STATUS_BURN_DESC")
	assert_eq(translated_name, "燃烧")
	assert_eq(translated_description, "每秒根据剩余燃料层数造成伤害，并消耗 1 层燃料；燃料归零时熄灭。")


func test_plague_relic_resources_match_the_appended_effect_type_enum_values() -> void:
	assert_eq(CarrionItem.effect_type, Item.EffectType.CARRION)
	assert_eq(ParasiteItem.effect_type, Item.EffectType.PARASITE)
	assert_eq(PustuleItem.effect_type, Item.EffectType.PUSTULE)
	assert_eq(VenomKnifeItem.effect_type, Item.EffectType.VENOM_KNIFE)
	assert_eq(ScorpionTailItem.effect_type, Item.EffectType.SCORPION_TAIL)
	assert_eq(WitchHatItem.effect_type, Item.EffectType.WITCH_HAT)
