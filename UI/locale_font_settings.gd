extends RefCounted
class_name LocaleFontSettings

const EN_FONT: FontFile = preload("res://Assets/Fonts/quaver.ttf")
const ZH_FONT_8: FontFile = preload("res://Assets/Fonts/fusion-pixel-8px-proportional-zh_hans.ttf")
const ZH_FONT_10: FontFile = preload("res://Assets/Fonts/fusion-pixel-10px-proportional-zh_hans.ttf")
const ZH_FONT_12: FontFile = preload("res://Assets/Fonts/fusion-pixel-12px-proportional-zh_hans.ttf")

const MAIN_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const LABEL_SETTINGS_8: LabelSettings = preload("res://Themes/label_settings_8.tres")
const LABEL_SETTINGS_10: LabelSettings = preload("res://Themes/label_settings_10.tres")
const LABEL_SETTINGS_11: LabelSettings = preload("res://Themes/label_settings_11.tres")
const LABEL_SETTINGS_12: LabelSettings = preload("res://Themes/label_settings_12.tres")
const BUTTON_THEME: Theme = preload("res://Themes/button.tres")


static func apply_locale(locale_code: String = "") -> void:
	var locale := locale_code if not locale_code.is_empty() else TranslationServer.get_locale()
	_configure_label_settings(MAIN_LABEL_SETTINGS, 12, locale)
	_configure_label_settings(LABEL_SETTINGS_8, 8, locale)
	_configure_label_settings(LABEL_SETTINGS_10, 10, locale)
	_configure_label_settings(LABEL_SETTINGS_11, 11, locale)
	_configure_label_settings(LABEL_SETTINGS_12, 12, locale)
	BUTTON_THEME.set_font(&"font", &"Button", font_for_size(8, locale))
	BUTTON_THEME.set_font_size(&"font_size", &"Button", 8)


static func font_for_size(font_size: int, locale_code: String = "") -> FontFile:
	var locale := locale_code if not locale_code.is_empty() else TranslationServer.get_locale()
	if not _is_chinese_locale(locale):
		return EN_FONT
	if font_size <= 9:
		return ZH_FONT_8
	if font_size <= 11:
		return ZH_FONT_10
	return ZH_FONT_12


static func label_settings_for_size(font_size: int) -> LabelSettings:
	if font_size <= 9:
		return LABEL_SETTINGS_8
	if font_size <= 10:
		return LABEL_SETTINGS_10
	if font_size <= 11:
		return LABEL_SETTINGS_11
	return LABEL_SETTINGS_12


static func apply_button_font(button: Button, font_size: int) -> void:
	if button == null:
		return
	button.add_theme_font_override(&"font", font_for_size(font_size))
	button.add_theme_font_size_override(&"font_size", font_size)


static func apply_option_button_font(button: OptionButton, font_size: int) -> void:
	if button == null:
		return
	button.add_theme_font_override(&"font", font_for_size(font_size))
	button.add_theme_font_size_override(&"font_size", font_size)
	button.get_popup().add_theme_font_override(&"font", font_for_size(font_size))
	button.get_popup().add_theme_font_size_override(&"font_size", font_size)


static func _configure_label_settings(settings: LabelSettings, font_size: int, locale_code: String) -> void:
	settings.font = font_for_size(font_size, locale_code)
	settings.font_size = font_size


static func _is_chinese_locale(locale_code: String) -> bool:
	return locale_code.begins_with("zh")
