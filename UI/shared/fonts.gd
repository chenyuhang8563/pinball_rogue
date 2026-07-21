extends RefCounted
class_name UIFonts
## Central font manager. Composite resources use Quaver for Latin/digits and
## the matching Fusion Pixel face as the CJK fallback.
##
## Integer-ratio rule: font_size must be an integer multiple of the fusion design size.
##   8px fusion → render at  8, 16, 24 ...
##  10px fusion → render at 10, 20, 30 ...
##  12px fusion → render at 12, 24, 36 ...

const QUAVER_FUSION_10: FontVariation = preload("res://Themes/Fonts/quaver_fusion_10.tres")
const QUAVER_FUSION_12: FontVariation = preload("res://Themes/Fonts/quaver_fusion_12.tres")

const DESIGN_SIZES: Dictionary = {
	10: QUAVER_FUSION_10,
	12: QUAVER_FUSION_12,
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
