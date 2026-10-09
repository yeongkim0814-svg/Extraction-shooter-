class_name InventoryActionBar
extends PanelContainer
## 아이템을 선택했을 때 화면 아래에 뜨는 액션 바: 아이템 이름·회전 미리보기 + 버튼들.
## 어떤 버튼을 보일지는 InventoryActions가 정하고, 이 클래스는 그리기와 신호만 맡는다.

signal action_pressed(action: InventoryActions.Action)

const BAR_HEIGHT: float = 76.0
const _LABELS: Dictionary[InventoryActions.Action, String] = {
	InventoryActions.Action.ROTATE: "회전",
	InventoryActions.Action.INFO: "정보",
	InventoryActions.Action.MOD: "모딩",
	InventoryActions.Action.SPLIT: "나누기",
	InventoryActions.Action.EQUIP: "장착",
	InventoryActions.Action.UNEQUIP: "해제",
	InventoryActions.Action.SELL: "판매",
	InventoryActions.Action.DISCARD: "버리기",
}
const _KEYS: Dictionary[InventoryActions.Action, String] = {
	InventoryActions.Action.ROTATE: "rotate",
	InventoryActions.Action.INFO: "info",
	InventoryActions.Action.MOD: "mod",
	InventoryActions.Action.SPLIT: "split",
	InventoryActions.Action.EQUIP: "equip",
	InventoryActions.Action.UNEQUIP: "unequip",
	InventoryActions.Action.SELL: "sell",
	InventoryActions.Action.DISCARD: "discard",
}


## 다음 이동에 쓸 회전 상태의 발자국(칸 모양) 미리보기.
class FootprintHint extends Control:
	var footprint: Vector2i = Vector2i.ZERO
	var tint: Color = InventoryItemPainter.SELECT_COLOR

	func _init() -> void:
		custom_minimum_size = Vector2(52, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if footprint == Vector2i.ZERO:
			return
		var unit: float = minf(48.0 / float(maxi(footprint.x, footprint.y)), 12.0)
		var box := Vector2(footprint) * unit
		var origin: Vector2 = (size - box) * 0.5
		draw_rect(Rect2(origin, box), Color(tint, 0.35))
		for x: int in range(footprint.x):
			for y: int in range(footprint.y):
				draw_rect(Rect2(origin + Vector2(x, y) * unit, Vector2(unit, unit)).grow(-0.5), tint, false, 1.0)


var _buttons: Dictionary[InventoryActions.Action, Button] = {}
var _hint: FootprintHint
var _title: Label
var _subtitle: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", InventoryStyle.panel_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_hint = FootprintHint.new()
	row.add_child(_hint)
	var texts := VBoxContainer.new()
	texts.custom_minimum_size.x = 200
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", InventoryStyle.TEXT)
	_title.clip_text = true
	texts.add_child(_title)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 14)
	_subtitle.add_theme_color_override("font_color", InventoryStyle.TEXT_DIM)
	_subtitle.clip_text = true
	texts.add_child(_subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	for action: InventoryActions.Action in _LABELS:
		var button := Button.new()
		button.text = _LABELS[action]
		button.custom_minimum_size.x = 104
		button.visible = false
		var accent := Color(0.9, 0.35, 0.35) if action == InventoryActions.Action.DISCARD else Color(0.45, 0.62, 0.95)
		InventoryStyle.style_button(button, accent)
		button.pressed.connect(func() -> void: action_pressed.emit(action))
		row.add_child(button)
		_buttons[action] = button


## 선택한 아이템에 맞게 버튼과 설명을 갱신하고 보인다.
## next_rotated는 다음 이동·놓기에 적용될 회전 상태.
func show_for(item: ItemInstance, entries: Array[InventoryActions.Entry], next_rotated: bool) -> void:
	_title.text = item.def.display_name
	update_rotation(item, next_rotated)
	for action: InventoryActions.Action in _buttons:
		_buttons[action].visible = false
	for entry: InventoryActions.Entry in entries:
		var button: Button = _buttons[entry.action]
		button.visible = true
		button.disabled = not entry.enabled
	visible = true


func update_rotation(item: ItemInstance, next_rotated: bool) -> void:
	var footprint: Vector2i = item.size_for(next_rotated)
	_hint.footprint = footprint
	_hint.queue_redraw()
	var shape: String = "세로" if footprint.y > footprint.x else ("가로" if footprint.x > footprint.y else "정사각")
	_subtitle.text = "다음 이동: %s %d×%d" % [shape, footprint.x, footprint.y]
	if not DropResolver.can_rotate(item):
		var base: Vector2i = item.size_for(false)
		_subtitle.text = "크기 %d×%d (회전 불가)" % [base.x, base.y]


func hide_bar() -> void:
	visible = false


## 보이는 버튼의 전역 영역 (스모크 테스트가 좌표를 읽는다). 키: rotate/info/split/equip/unequip/sell/discard.
func button_rects() -> Dictionary[String, Rect2]:
	var rects: Dictionary[String, Rect2] = {}
	for action: InventoryActions.Action in _buttons:
		var button: Button = _buttons[action]
		if button.is_visible_in_tree():
			rects[_KEYS[action]] = button.get_global_rect()
	return rects
