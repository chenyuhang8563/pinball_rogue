extends GutTest

const CRIT_SCENE: PackedScene = preload("res://Combat/presentation/crit_floating_text.tscn")
const PERFECT_SCENE: PackedScene = preload("res://Combat/presentation/perfect_floating_text.tscn")
const TRANSLATION_CSV: String = "res://translations/game.csv"


func test_crit_and_perfect_tags_use_translation_keys() -> void:
	var crit: Node2D = autofree(CRIT_SCENE.instantiate())
	var perfect: Node2D = autofree(PERFECT_SCENE.instantiate())
	assert_eq((crit.get_node("CritTag") as Label).text, "FLOATING_CRIT_TAG",
			"crit tag must be a translation key, not hardcoded Chinese")
	assert_eq((perfect.get_node("PerfectTag") as Label).text, "FLOATING_PERFECT_TAG",
			"perfect tag must be a translation key, not hardcoded Chinese")


func test_translation_csv_defines_floating_tag_keys() -> void:
	var rows: Dictionary = {}
	var file := FileAccess.open(TRANSLATION_CSV, FileAccess.READ)
	assert_not_null(file, "game.csv must be readable")
	if file == null:
		return
	var _header: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty() or String(row[0]).is_empty():
			continue
		rows[String(row[0])] = row
	file.close()

	assert_true(rows.has("FLOATING_CRIT_TAG"), "game.csv must define FLOATING_CRIT_TAG")
	assert_true(rows.has("FLOATING_PERFECT_TAG"), "game.csv must define FLOATING_PERFECT_TAG")
	if not rows.has("FLOATING_CRIT_TAG") or not rows.has("FLOATING_PERFECT_TAG"):
		return
	var crit_row: PackedStringArray = rows["FLOATING_CRIT_TAG"]
	assert_eq(String(crit_row[1]), "Crit", "FLOATING_CRIT_TAG en column")
	assert_eq(String(crit_row[2]), "暴击", "FLOATING_CRIT_TAG zh_CN column")
	var perfect_row: PackedStringArray = rows["FLOATING_PERFECT_TAG"]
	assert_eq(String(perfect_row[1]), "Perfect", "FLOATING_PERFECT_TAG en column")
	assert_eq(String(perfect_row[2]), "完美", "FLOATING_PERFECT_TAG zh_CN column")
