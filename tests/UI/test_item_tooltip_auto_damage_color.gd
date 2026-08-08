extends GutTest

## 属性伤害数字自动着色：format_description_bbcode 对"数字 + 点 + 属性词 + 伤害"
## （中/英）自动把数字包进 [damage_<type>]，最终渲染成对应属性色。
## 手写 [damage_x] 标记优先，自动规则不会命中已被标记包裹的数字；
## 无属性词的伤害（物理/奥术/回响）不自动上色。

const TooltipScript: GDScript = preload("res://UI/shared/item_tooltip.gd")


func _render(value: String) -> String:
	return String(TooltipScript.call("format_description_bbcode", value))


func test_zh_explosion_auto_colors_number() -> void:
	var out := _render("造成3点爆炸伤害，半径70")
	assert_true(out.contains("[color=#f49c4e]3[/color]"), "爆炸数字自动上橙：%s" % out)
	assert_false(out.contains("[damage_"), "标记全部替换为 color")


func test_zh_blast_alias_auto_colors_number() -> void:
	var out := _render("抛射炸弹，2.6秒后引爆，造成24点爆破伤害")
	assert_true(out.contains("[color=#f49c4e]24[/color]"), "爆破别名同款上色：%s" % out)


func test_zh_poison_auto_colors_number() -> void:
	var out := _render("苍蝇每次叮咬额外造成 1 点毒素伤害")
	assert_true(out.contains("[color=#8bc76a]1[/color]"), "毒素数字自动上绿：%s" % out)


func test_en_poison_auto_colors_number() -> void:
	var out := _render("flies deal 1 more poison damage")
	assert_true(out.contains("[color=#8bc76a]1[/color]"), "英文 poison 数字上绿：%s" % out)


func test_zh_fire_and_lightning_auto_color() -> void:
	# 自动规则：属性词紧跟数字时上色。
	assert_true(_render("每燃料造成 3 点燃烧伤害").contains("[color=#ef6a4c]3[/color]"))
	assert_true(_render("复击放电造成 4 点闪电伤害").contains("[color=#e6d36a]4[/color]"))
	# 手写标记（UPGRADE 描述"数字前属性词分离"的兜底）：同样渲染成色。
	assert_true(_render("每燃料造成 [damage_fire]3[/damage_fire] 点伤害").contains("[color=#ef6a4c]3[/color]"))
	assert_true(_render("复击放电提升至每层电弧 [damage_lightning]4[/damage_lightning] 点伤害").contains("[color=#e6d36a]4[/color]"))


func test_manual_tag_is_not_double_wrapped() -> void:
	# 手写 [damage_explosion] 已包裹，自动规则不得再包。
	var out := _render("造成[damage_explosion]12[/damage_explosion]点爆破伤害")
	assert_true(out.contains("[color=#f49c4e]12[/color]"), "手写数字单次上色：%s" % out)
	assert_eq(out.count("[color=#f49c4e]"), 1, "不得重复包裹")


func test_non_element_damage_stays_uncolored() -> void:
	# 物理 / 奥术 / 无属性——不属于五种属性，数字不上伤害色。
	assert_false(_contains_damage_color(_render("每次碰撞造成 2 点物理伤害")), "物理数字不上伤害色")
	assert_false(_contains_damage_color(_render("魔法飞弹，造成 10 点伤害")), "奥术数字不上伤害色")
	# 回响是术语（金色 #cead4a），但数字不得被伤害色包裹。
	var echo := _render("附加 2 点回响伤害")
	assert_false(_contains_damage_color(echo), "回响数字不上伤害色：%s" % echo)
	assert_true(echo.contains("[color=#cead4a]回响[/color]"), "回响术语色仍生效")


func test_zh_poison_without_number_does_not_color() -> void:
	# 只有属性词没有数字时不应产生任何伤害色标记。
	assert_false(_contains_damage_color(_render("毒素持续 5 秒")))


func _contains_damage_color(value: String) -> bool:
	for color: String in ["#ef6a4c", "#77cfff", "#e6d36a", "#8bc76a", "#f49c4e"]:
		if value.contains(color):
			return true
	return false
