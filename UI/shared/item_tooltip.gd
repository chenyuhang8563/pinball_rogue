extends VBoxContainer
class_name ItemTooltip

const TERM_COLOR := "#cead4a"
const DAMAGE_COLORS := {
	"fire": "#ef6a4c",
	"frost": "#77cfff",
	"lightning": "#e6d36a",
	"poison": "#8bc76a",
	"explosion": "#f49c4e",
}
const TERM_DATA := {
	"BURN": ["燃烧", "Burn"],
	"LIGHTNING_CHAIN": ["闪电链", "Lightning Chain"],
	"ARC": ["电弧", "Arc"],
	"ECHO": ["回响", "Echo"],
	"POWER_STRIKE": ["强力击", "Power Strike"],
	"POISON": ["中毒", "Poison"],
	"INFECTION": ["感染", "Infection"],
	"PLAGUE": ["瘟疫", "Plague"],
	"FLY": ["苍蝇", "Fly"],
	"FROST": ["冰霜", "Frost"],
	"FROZEN": ["冻结", "Frozen"],
	"WEAK_POINT": ["破绽", "Weak Point"],
	"PERFECT_CRIT": ["完美暴击", "Perfect Crit"],
	"CRIT": ["暴击", "Crit"],
	"EXPLOSION": ["爆炸", "Explosion"],
}
const TERM_REPLACEMENT_ORDER: Array[String] = [
	"PERFECT_CRIT", "LIGHTNING_CHAIN", "WEAK_POINT", "INFECTION", "EXPLOSION", "ARC",
	"FROZEN", "FROST", "PLAGUE", "POISON", "BURN", "ECHO", "POWER_STRIKE", "FLY", "CRIT",
]

# 与场景里 RichTextLabel 的 custom_minimum_size.x 保持一致，作为预算换行高度的固定宽度。
const TOOLTIP_CONTENT_WIDTH := 120.0
# 两个 RichTextLabel 没有字体 override，继承主题 ui_font_10.tres 的 default_font（quaver_fusion_10）
# 与 default_font_size（10）。预算换行高度必须用同一字体/字号，否则会系统性算高、撑出黑底空白。
const _BodyLabelSettings: LabelSettings = preload("res://Themes/Fonts/text_10.tres")

var _title_label: Label
var _description_label: RichTextLabel
var _term_definition_label: RichTextLabel
var _term_card_player: AnimationPlayer


func set_item(item: Item, level: int = 1) -> void:
	if item == null:
		set_text("")
		return
	set_text(
		item_title(item),
		level_description(item, level)
	)


func set_text(title: String, description: String = "") -> void:
	_bind_nodes()
	if _title_label != null:
		_title_label.text = title
	_set_rtl_text(_description_label, format_description_bbcode(description))
	_populate_term_card(description)
	_apply_fit_heights()


func _bind_nodes() -> void:
	if _title_label != null:
		return
	_title_label = get_node_or_null("MainPanel/TooltipMargin/TooltipLayout/TooltipLabel") as Label
	_description_label = get_node_or_null("MainPanel/TooltipMargin/TooltipLayout/DescriptionLabel") as RichTextLabel
	_term_definition_label = get_node_or_null("TermPanel/TermMargin/TermLayout/TermDefinitionLabel") as RichTextLabel
	_term_card_player = get_node_or_null("VisibilityPlayer") as AnimationPlayer


static func item_title(item: Item) -> String:
	if item == null:
		return ""
	return _translated_item_text(item, "TITLE", item.title)


static func level_description(item: Item, level: int) -> String:
	if item == null:
		return ""
	if item.id.is_empty():
		return TranslationServer.translate(item.description)
	var safe_level := clampi(level, 1, 4)
	var key := "ITEM_%s_DESC_LV%d" % [item.id.to_upper(), safe_level]
	var translated := TranslationServer.translate(key)
	return translated if translated != key else _translated_item_text(item, "DESC", item.description)


static func description_bbcode(item: Item, level: int) -> String:
	return format_description_bbcode(level_description(item, level))


static func _translated_item_text(item: Item, suffix: String, fallback: String) -> String:
	if item.id.is_empty():
		return TranslationServer.translate(fallback)
	var key := "ITEM_%s_%s" % [item.id.to_upper(), suffix]
	var translated := TranslationServer.translate(key)
	return translated if translated != key else TranslationServer.translate(fallback)


static func format_description_bbcode(value: String) -> String:
	var formatted := value
	for damage_type: String in DAMAGE_COLORS:
		formatted = formatted.replace("[damage_%s]" % damage_type, "[color=%s]" % DAMAGE_COLORS[damage_type])
		formatted = formatted.replace("[/damage_%s]" % damage_type, "[/color]")
	for term_id: String in TERM_REPLACEMENT_ORDER:
		for term: String in TERM_DATA[term_id]:
			formatted = formatted.replace(
				term,
				"[color=%s]%s[/color]" % [TERM_COLOR, term]
			)
	return formatted


## 术语卡：每个术语一块——术语名称（术语色，作小标题）独占一行，下一行写简介；
## 多个术语按出现顺序用换行依次向下堆叠。整段仍交给 _set_rtl_text 预算高度，
## 名称行的颜色标签不影响排版高度。
func _populate_term_card(description: String) -> void:
	var term_ids := _term_ids_in(description)
	if term_ids.is_empty():
		_set_rtl_text(_term_definition_label, "")
		_set_term_card_visible(false)
		return
	_set_term_card_visible(true)
	var blocks := PackedStringArray()
	for term_id: String in term_ids:
		blocks.append("[color=%s]%s[/color]\n%s" % [
			TERM_COLOR,
			tr("TERM_%s_NAME" % term_id),
			tr("TERM_%s_DESC" % term_id),
		])
	_set_rtl_text(_term_definition_label, "\n".join(blocks))


func _set_term_card_visible(should_show: bool) -> void:
	if _term_card_player == null:
		return
	var animation_name: StringName = &"show" if should_show else &"hide"
	_term_card_player.play(animation_name)
	_term_card_player.advance(0.0)


static func _term_ids_in(description: String) -> Array[String]:
	var result: Array[String] = []
	for term_id: String in TERM_REPLACEMENT_ORDER:
		for term: String in TERM_DATA[term_id]:
			if description.contains(term):
				result.append(term_id)
				break
	return result


## 设置 RichTextLabel 文本并预算其换行高度。
## Godot 4.6 的自定义 tooltip 在显示第一帧、控件宽度仍为 0 时查询 minimum size，
## 此时 fit_content 会按 0 宽逐字排版得到虚高的高度；而 tooltip 所在的 Popup 窗口
## 只扩不缩（Window::_update_window_size 用 size.max(size_limit)），虚高一旦撑开就
## 缩不回，表现为内容下方的黑底空白。这里在文本确定后、按设计宽度预算真实高度并写入
## custom_minimum_size.y，使第一帧 minimum 即正确，从而消除空白。
func _set_rtl_text(label: RichTextLabel, value: String) -> void:
	if label == null:
		return
	label.text = value
	label.custom_minimum_size.y = _bbcode_height(value, TOOLTIP_CONTENT_WIDTH)


func _apply_fit_heights() -> void:
	if _description_label != null:
		_description_label.custom_minimum_size.y = _bbcode_height(
			_description_label.text, TOOLTIP_CONTENT_WIDTH
		)
	if _term_definition_label != null:
		_term_definition_label.custom_minimum_size.y = _bbcode_height(
			_term_definition_label.text, TOOLTIP_CONTENT_WIDTH
		)


## 用 TextParagraph 按指定宽度排版文本，返回与 RichTextLabel(fit_content) 对齐的高度。
## 颜色标签不影响字形高度，故先剔除 [color=..]/[/color] 用纯文本排版即可。
## 注意：TextParagraph 没有暴露 layout()，排版由 get_line_count()/get_line_size() 内部的
## _shape_lines() 自动触发（add_string/set_width 会置脏）。字体/字号必须与 RichTextLabel
## 实际继承的主题字体一致（见 _BodyLabelSettings，quaver_fusion_10 @ 10px），否则会算高。
## 描述文本通过 .text 以 \n 连接，按“多行单段”排版，行间只加 line_separation，不加段距。
func _bbcode_height(bbcode: String, width: float) -> float:
	if bbcode.is_empty():
		return 0.0
	var font: Font = _BodyLabelSettings.font
	var font_size: int = _BodyLabelSettings.font_size
	if font == null:
		return 0.0
	var plain := _strip_color_tags(bbcode)
	var para := TextParagraph.new()
	para.set_width(width)
	para.set_break_flags(
		TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND
	)
	para.set_alignment(HORIZONTAL_ALIGNMENT_LEFT)
	para.add_string(plain, font, font_size)
	var line_count: int = para.get_line_count()
	var total := 0.0
	for line_idx: int in range(line_count):
		total += para.get_line_size(line_idx).y
		if line_idx < line_count - 1:
			total += 3.0  # RichTextLabel 默认 line_separation
	return ceil(total)


## 剔除 [color=..] 与 [/color] 标签，返回纯文本（颜色不影响排版高度）。
func _strip_color_tags(text: String) -> String:
	var result := text
	var open_tag := "[color="
	var close_tag := "[/color]"
	var search_from := 0
	while true:
		var open_idx := result.find(open_tag, search_from)
		if open_idx == -1:
			break
		var close_bracket := result.find("]", open_idx)
		if close_bracket == -1:
			break
		result = result.substr(0, open_idx) + result.substr(close_bracket + 1)
		search_from = open_idx
	return result.replace(close_tag, "")
