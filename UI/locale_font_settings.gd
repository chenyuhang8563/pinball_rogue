extends RefCounted
class_name LocaleFontSettings

const EN_FONT: FontFile = preload("res://Assets/Fonts/quaver.ttf")
const UI_FONT_SIZE: int = 12

const MAIN_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const LABEL_SETTINGS_8: LabelSettings = preload("res://Themes/label_settings_8.tres")
const LABEL_SETTINGS_10: LabelSettings = preload("res://Themes/label_settings_10.tres")
const LABEL_SETTINGS_11: LabelSettings = preload("res://Themes/label_settings_11.tres")
const LABEL_SETTINGS_12: LabelSettings = preload("res://Themes/label_settings_12.tres")
const BUTTON_THEME: Theme = preload("res://Themes/button.tres")


static func apply_locale(_locale_code: String = "") -> void:
	_configure_label_settings(MAIN_LABEL_SETTINGS)
	_configure_label_settings(LABEL_SETTINGS_8)
	_configure_label_settings(LABEL_SETTINGS_10)
	_configure_label_settings(LABEL_SETTINGS_11)
	_configure_label_settings(LABEL_SETTINGS_12)
	BUTTON_THEME.set_font(&"font", &"Button", EN_FONT)
	BUTTON_THEME.set_font_size(&"font_size", &"Button", UI_FONT_SIZE)


static func font_for_size(_font_size: int, _locale_code: String = "") -> FontFile:
	return EN_FONT


static func label_settings_for_size(font_size: int) -> LabelSettings:
	if font_size <= 9:
		return LABEL_SETTINGS_8
	if font_size <= 10:
		return LABEL_SETTINGS_10
	if font_size <= 11:
		return LABEL_SETTINGS_11
	return LABEL_SETTINGS_12


static func apply_button_font(button: Button, _font_size: int) -> void:
	if button == null:
		return
	button.add_theme_font_override(&"font", EN_FONT)
	button.add_theme_font_size_override(&"font_size", UI_FONT_SIZE)


static func apply_option_button_font(button: OptionButton, _font_size: int) -> void:
	if button == null:
		return
	button.add_theme_font_override(&"font", EN_FONT)
	button.add_theme_font_size_override(&"font_size", UI_FONT_SIZE)
	button.get_popup().add_theme_font_override(&"font", EN_FONT)
	button.get_popup().add_theme_font_size_override(&"font_size", UI_FONT_SIZE)


static func _configure_label_settings(settings: LabelSettings) -> void:
	settings.font = EN_FONT
	settings.font_size = UI_FONT_SIZE
