extends RefCounted
class_name UIFonts
## Central font manager. Composite resources use Quaver for Latin/digits and
## the matching Fusion Pixel face as the CJK fallback.
##
## Integer-ratio rule: font_size must be an integer multiple of the fusion design size.
##   8px fusion → render at  8, 16, 24 ...
##  10px fusion → render at 10, 20, 30 ...
##  12px fusion → render at 12, 24, 36 ...

const QUAVER: FontFile = preload("res://Assets/Fonts/quaver.ttf")

const FUSION_8: FontFile = preload("res://Assets/Fonts/fusion-pixel-8px-proportional-zh_hans.ttf")
const FUSION_10: FontFile = preload("res://Assets/Fonts/fusion-pixel-10px-proportional-zh_hans.ttf")
const FUSION_12: FontFile = preload("res://Assets/Fonts/fusion-pixel-12px-proportional-zh_hans.ttf")

const QUAVER_FUSION_8: FontVariation = preload("res://Themes/Fonts/quaver_fusion_8.tres")
const QUAVER_FUSION_10: FontVariation = preload("res://Themes/Fonts/quaver_fusion_10.tres")
const QUAVER_FUSION_12: FontVariation = preload("res://Themes/Fonts/quaver_fusion_12.tres")

const DESIGN_SIZES: Dictionary = {
	8: QUAVER_FUSION_8,
	9: QUAVER_FUSION_10,
	10: QUAVER_FUSION_10,
	11: QUAVER_FUSION_10,
	12: QUAVER_FUSION_12,
	16: QUAVER_FUSION_8,
	20: QUAVER_FUSION_10,
	24: QUAVER_FUSION_12,
}


## True when the current locale is Chinese (zh*).
static func is_zh() -> bool:
	return TranslationServer.get_locale().begins_with("zh")


## Return a composite font for *font_size*. Quaver remains the primary face, so
## English and digits never switch to Fusion when the locale is Chinese.
static func font_for_size(font_size: int) -> Font:
	var design_size: int = _closest_design_size(font_size)
	return DESIGN_SIZES.get(design_size, QUAVER_FUSION_12)


static func _closest_design_size(font_size: int) -> int:
	var best: int = 12
	var best_dist: int = 999
	for size: int in DESIGN_SIZES.keys():
		var dist: int = absi(font_size - size)
		if dist < best_dist:
			best = size
			best_dist = dist
	return best


## Convenience: create a locale-aware LabelSettings at *font_size*.
static func make_label_settings(font_size: int) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font_for_size(font_size)
	ls.font_size = font_size
	return ls


## Apply locale-aware font + size overrides to a Button.
static func apply_button_font(button: Button, font_size: int) -> void:
	button.add_theme_font_override(&"font", font_for_size(font_size))
	button.add_theme_font_size_override(&"font_size", font_size)


## Apply locale-aware font + size overrides to an OptionButton including its popup.
static func apply_option_button_font(button: OptionButton, font_size: int) -> void:
	var font := font_for_size(font_size)
	button.add_theme_font_override(&"font", font)
	button.get_popup().add_theme_font_override(&"font", font)
	button.add_theme_font_size_override(&"font_size", font_size)
	button.get_popup().add_theme_font_size_override(&"font_size", font_size)


## Apply locale-aware font + size overrides to a Label's label_settings.
static func apply_label_settings(label: Label, font_size: int) -> void:
	label.label_settings = make_label_settings(font_size)


## Apply quaver.ttf to a Label that displays numeric values (health, gold, counts).
## Numbers always render in quaver regardless of locale.
static func apply_number_label(label: Label, font_size: int) -> void:
	var ls := LabelSettings.new()
	ls.font = QUAVER
	ls.font_size = font_size
	label.label_settings = ls
