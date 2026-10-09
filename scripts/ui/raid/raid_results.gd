class_name RaidResults
extends Control
## 레이드 결과 화면 (인벤토리와 같은 어두운 전술 스타일): 결과 제목, 레이드 시간·처치·수색한 컨테이너·반출 가치
## (사망 시엔 잃은 아이템 수), "다시 출격" / "메뉴로" 버튼. 어떤 씬으로 갈지는 화면을 띄운 쪽이 정한다.

signal retry_requested
signal menu_requested

const SUCCESS_COLOR := Color(0.4, 0.9, 0.5)
const FAIL_COLOR := Color(1.0, 0.4, 0.35)

var _retry_button: Button
var _menu_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## 요약을 받아 화면을 구성한다. 한 번만 부른다.
func show_report(report: RaidSummary.Report) -> void:
	for child: Node in get_children():
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color(0.055, 0.063, 0.078, 0.97)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", InventoryStyle.panel_style())
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var success: bool = report.outcome == RaidSession.Outcome.EXTRACTED
	var title := Label.new()
	title.text = RaidSummary.outcome_title(report.outcome)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", SUCCESS_COLOR if success else FAIL_COLOR)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "은신처 저장은 M11에서 연결됩니다"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", InventoryStyle.TEXT_DIM)
	box.add_child(subtitle)
	box.add_child(_divider())

	_add_row(box, "레이드 시간", RaidSummary.format_time(report.elapsed))
	_add_row(box, "처치한 적", "%d명" % report.kills)
	_add_row(box, "수색한 컨테이너", "%d개" % report.containers_searched)
	if report.outcome == RaidSession.Outcome.EXTRACTED:
		_add_row(box, "반출한 FIR 아이템 가치", "%s ₩" % _thousands(report.value))
	else:
		_add_row(box, "잃은 아이템", "%d개" % report.lost_count)
	box.add_child(_divider())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_retry_button = _make_button("다시 출격")
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	buttons.add_child(_retry_button)
	_menu_button = _make_button("메뉴로")
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	buttons.add_child(_menu_button)


## 버튼 중심 전역 좌표 (스모크·로그용). 아직 만들어지지 않았으면 빈 Rect2.
func retry_button_rect() -> Rect2:
	return _retry_button.get_global_rect() if _retry_button != null else Rect2()


func menu_button_rect() -> Rect2:
	return _menu_button.get_global_rect() if _menu_button != null else Rect2()


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InventoryStyle.style_button(button)
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size.y = 60.0
	return button


func _add_row(parent: Control, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", InventoryStyle.TEXT_DIM)
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", InventoryStyle.TEXT)
	row.add_child(value)
	parent.add_child(row)


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = InventoryStyle.SECTION_DIVIDER
	line.custom_minimum_size.y = 1.0
	return line


static func _thousands(value: int) -> String:
	var text: String = str(absi(value))
	var out: String = ""
	for i: int in range(text.length()):
		if i > 0 and (text.length() - i) % 3 == 0:
			out += ","
		out += text[i]
	return ("-" if value < 0 else "") + out
