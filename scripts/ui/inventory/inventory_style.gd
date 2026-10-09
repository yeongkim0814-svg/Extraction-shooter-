class_name InventoryStyle
extends RefCounted
## 인벤토리 UI 공용 스타일 (어두운 테마, 밝은 글씨). 버튼은 터치용으로 높이 44px 이상.

const PANEL_BG := Color(0.09, 0.1, 0.13, 0.97)
const PANEL_BORDER := Color(0.45, 0.5, 0.62, 1.0)
const TEXT := Color(0.94, 0.96, 1.0)
const TEXT_DIM := Color(0.62, 0.66, 0.74)
const SECTION_HEADER_BG := Color(0.13, 0.145, 0.185, 1.0)
const SECTION_DIVIDER := Color(0.3, 0.33, 0.41, 0.7)
const GROUP_BORDER := Color(0.42, 0.46, 0.56, 1.0)
const BUTTON_MIN_HEIGHT: float = 52.0


static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## 버튼 하나를 어두운 배경 + 밝은 글씨로 꾸민다. accent는 테두리·눌림 색 (버리기는 빨강).
static func style_button(button: Button, accent: Color = Color(0.45, 0.62, 0.95)) -> void:
	button.custom_minimum_size.y = BUTTON_MIN_HEIGHT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _button_box(Color(0.17, 0.19, 0.25), accent.darkened(0.2)))
	button.add_theme_stylebox_override("hover", _button_box(Color(0.22, 0.25, 0.33), accent))
	button.add_theme_stylebox_override("pressed", _button_box(accent.darkened(0.45), accent.lightened(0.3)))
	button.add_theme_stylebox_override("disabled", _button_box(Color(0.11, 0.12, 0.15), Color(0.25, 0.27, 0.32)))
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.55))


## 컨테이너 구역 머리글 띠: 어두운 배경 + 얇은 띠 높이.
static func section_header_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SECTION_HEADER_BG
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
