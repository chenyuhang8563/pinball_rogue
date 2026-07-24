extends GutTest

const PustuleItem: Item = preload("res://Content/data/pustule.tres")


func test_pustule_description_is_chinese_in_chinese_locale() -> void:
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	assert_eq(
		TranslationServer.translate("ITEM_PUSTULE_DESC"),
		"感染的敌人死亡时爆裂，额外释放瘟疫苍蝇。"
	)
	assert_eq(PustuleItem.description, "ITEM_PUSTULE_DESC")
	TranslationServer.set_locale(previous_locale)
