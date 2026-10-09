class_name InventoryItemDialog
extends Control
## 화면 중앙의 작은 대화상자: 아이템 정보(닫기) 또는 버리기 확인(취소 / 버리기).
## 뒤쪽 입력을 막는 반투명 배경을 깔고, 열려 있는 동안 화면은 포인터 입력을 무시한다.

signal discard_confirmed(item_id: int)
signal closed

var _item_id: int = 0
var _panel: PanelContainer
var _title: Label
var _body: Label
var _cancel_button: Button
var _discard_button: Button


func _init() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 340
	_panel.add_theme_stylebox_override("panel", InventoryStyle.panel_style())
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", InventoryStyle.TEXT)
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", InventoryStyle.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_cancel_button = Button.new()
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InventoryStyle.style_button(_cancel_button)
	_cancel_button.pressed.connect(close)
	buttons.add_child(_cancel_button)
	_discard_button = Button.new()
	_discard_button.text = "버리기"
	_discard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	InventoryStyle.style_button(_discard_button, Color(0.9, 0.35, 0.35))
	_discard_button.pressed.connect(_on_discard_pressed)
	buttons.add_child(_discard_button)


func show_info(item: ItemInstance) -> void:
	_item_id = item.id
	_title.text = item.def.display_name
	var lines: PackedStringArray = ["크기: %d×%d" % [item.def.width, item.def.height]]
	if item.def.max_stack > 1:
		lines.append("수량: %d / %d" % [item.stack_count, item.def.max_stack])
	lines.append("종류: %s" % ItemDef.Category.keys()[item.def.category])
	_body.text = "\n".join(lines)
	_cancel_button.text = "닫기"
	_discard_button.visible = false
	visible = true


func show_discard_confirm(item: ItemInstance) -> void:
	_item_id = item.id
	_title.text = "버리시겠습니까?"
	var count: String = " ×%d" % item.stack_count if item.stack_count > 1 else ""
	var extra: String = "\n안에 든 아이템도 함께 사라집니다." if item.def.is_container() else ""
	_body.text = "%s%s%s\n되돌릴 수 없습니다." % [item.def.display_name, count, extra]
	_cancel_button.text = "취소"
	_discard_button.visible = true
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	_item_id = 0
	closed.emit()


func button_rects() -> Dictionary[String, Rect2]:
	var rects: Dictionary[String, Rect2] = {}
	if visible:
		rects["cancel"] = _cancel_button.get_global_rect()
		if _discard_button.visible:
			rects["confirm_discard"] = _discard_button.get_global_rect()
	return rects


func _on_discard_pressed() -> void:
	var item_id: int = _item_id
	visible = false
	_item_id = 0
	discard_confirmed.emit(item_id)
	closed.emit()
