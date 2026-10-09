class_name InventorySlotView
extends Control
## 장비 슬롯 하나. 한글 이름 + 작은 영문 태그를 그리고, 장착된 아이템이 있으면 슬롯 박스 안에 그린다.
## 입력은 받지 않는다 (InventoryScreen이 포인터 이벤트를 모아서 판정한다).

## 아이템이 박스에 이 비율 이상으로 들어가면 원래 비율로, 더 작아져야 하면 박스를 채워서 그린다.
const MIN_FIT_SCALE: float = 0.7

var slot: EquipmentSlots.Slot = EquipmentSlots.Slot.PRIMARY_1
var label_ko: String = ""
var label_en: String = ""
var inventory: Inventory
var cell: int = InventoryItemPainter.CELL_SIZE
var dragging_item_id: int = 0
var selected_item_id: int = 0
## 스크롤 컨테이너 안에 있을 때 실제로 보이는 영역을 판정하는 클립 컨트롤.
var clip_control: Control = null
## 컨테이너 구역용: 비어 있을 때 보이는 흐린 안내 이름. 비어 있지 않으면 일반 장비 슬롯 표시를 쓴다.
## 켜면 아이템 이름을 오른쪽 위에 그리고 알약 태그는 생략한다.
var corner_name: String = ""

var _highlight_valid: bool = false
var _has_highlight: bool = false
var _box_size: Vector2 = Vector2.ZERO
var _box_cells: Vector2 = Vector2.ZERO
var _extra_px: Vector2 = Vector2.ZERO


## 박스 크기 = box_cells(칸 단위) * cell + extra_px (칸 크기가 바뀌면 set_cell_size).
## extra_px는 옆 블록과 줄을 맞추려고 간격만큼 더하는 픽셀이다.
func setup(p_inventory: Inventory, p_slot: EquipmentSlots.Slot, p_ko: String, p_en: String,
		box_cells: Vector2, p_cell: int, extra_px: Vector2 = Vector2.ZERO) -> void:
	inventory = p_inventory
	slot = p_slot
	label_ko = p_ko
	label_en = p_en
	_box_cells = box_cells
	_extra_px = extra_px
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_cell_size(p_cell)


func set_cell_size(p_cell: int) -> void:
	cell = p_cell
	_box_size = _box_cells * float(cell) + _extra_px
	custom_minimum_size = _box_size
	size = _box_size
	queue_redraw()


func set_highlight(valid: bool) -> void:
	_highlight_valid = valid
	_has_highlight = true
	queue_redraw()


func clear_highlight() -> void:
	if _has_highlight:
		_has_highlight = false
		queue_redraw()


func visible_global_rect() -> Rect2:
	var rect: Rect2 = get_global_rect()
	if clip_control != null:
		rect = rect.intersection(clip_control.get_global_rect())
	return rect


func equipped_item() -> ItemInstance:
	return inventory.equipment.get_item(slot)


## 장착된 아이템이 박스 안에서 차지하는 지역 영역 (없으면 빈 Rect2).
func item_local_rect() -> Rect2:
	var item: ItemInstance = equipped_item()
	if item == null:
		return Rect2()
	var inner := Rect2(Vector2.ZERO, size).grow(-3)
	var natural := Vector2(item.def.width, item.def.height) * float(cell)
	var fit: float = minf(inner.size.x / natural.x, inner.size.y / natural.y)
	if fit < MIN_FIT_SCALE:
		return inner
	var shown: Vector2 = natural * minf(fit, 1.0)
	return Rect2(inner.position + (inner.size - shown) * 0.5, shown)


func item_global_rect() -> Rect2:
	var local: Rect2 = item_local_rect()
	return Rect2(global_position + local.position, local.size)


func _draw() -> void:
	if inventory == null:
		return
	var font: Font = get_theme_default_font()
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.09, 0.1, 0.12))
	draw_rect(rect.grow(-0.5), Color(0.36, 0.39, 0.46), false, 1.5)
	var item: ItemInstance = equipped_item()
	var corner: bool = not corner_name.is_empty()
	if item == null:
		if corner:
			_draw_placeholder(font)
		else:
			_draw_label(font, Color(0.78, 0.81, 0.88), Color(0.5, 0.54, 0.62), 1.0)
	else:
		var alpha: float = 0.3 if item.id == dragging_item_id else 1.0
		var item_rect: Rect2 = item_local_rect()
		InventoryItemPainter.draw_item(self, font, item, item_rect, false, alpha, false, not corner)
		if corner:
			_draw_corner_name(font, item.def.display_name, Color(0.95, 0.97, 1.0, alpha), alpha)
		else:
			_draw_tag(font, alpha)
		if item.id == selected_item_id:
			InventoryItemPainter.draw_selection(self, rect.grow(-1))
	if _has_highlight:
		var color: Color = Color(0.2, 0.9, 0.3, 0.45) if _highlight_valid else Color(0.95, 0.2, 0.2, 0.45)
		draw_rect(rect, color)
		draw_rect(rect.grow(-1), color.lightened(0.4), false, 2.0)


## 빈 슬롯: 왼쪽 위에 한글(크게) + 영문 태그(작게).
func _draw_label(font: Font, ko_color: Color, en_color: Color, alpha: float) -> void:
	var width: float = size.x - 10.0
	draw_string(font, Vector2(6, 17), label_ko, HORIZONTAL_ALIGNMENT_LEFT, width, 14, Color(ko_color, alpha))
	draw_string(font, Vector2(6, 30), label_en, HORIZONTAL_ALIGNMENT_LEFT, width, 10, Color(en_color, alpha))


## 아이템이 있을 때: 왼쪽 아래 작은 알약 모양 태그 (슬롯 이름을 잊지 않게).
func _draw_tag(font: Font, alpha: float) -> void:
	var text_width: float = font.get_string_size(label_ko, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var pill := Rect2(3, size.y - 17, minf(text_width + 10.0, size.x - 6.0), 14)
	draw_rect(pill, Color(0, 0, 0, 0.7 * alpha))
	draw_string(font, pill.position + Vector2(5, 11), label_ko, HORIZONTAL_ALIGNMENT_LEFT, pill.size.x - 6.0, 10,
			Color(0.9, 0.93, 1.0, alpha))


## 오른쪽 위 모서리에 오른쪽 정렬로 이름을 그린다.
func _draw_corner_name(font: Font, text: String, color: Color, alpha: float) -> void:
	var width: float = size.x - 10.0
	var pos := Vector2(5, 17)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_RIGHT, width, 13, Color(0, 0, 0, 0.9 * alpha))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, width, 13, color)


## 빈 컨테이너 슬롯: 흐린 안내 이름(오른쪽 위) + 흐린 단순 그림.
func _draw_placeholder(font: Font) -> void:
	var faint := Color(0.5, 0.54, 0.62, 0.55)
	_draw_corner_name(font, corner_name, faint, 1.0)
	var box := Rect2(Vector2(size.x * 0.2, size.y * 0.34), Vector2(size.x * 0.6, size.y * 0.52))
	var line := Color(faint, 0.35)
	match slot:
		EquipmentSlots.Slot.RIG:
			var points := PackedVector2Array([
				box.position + Vector2(box.size.x * 0.2, 0), box.position + Vector2(box.size.x * 0.4, 0),
				box.position + Vector2(box.size.x * 0.5, box.size.y * 0.25),
				box.position + Vector2(box.size.x * 0.6, 0), box.position + Vector2(box.size.x * 0.8, 0),
				box.end, box.position + Vector2(0, box.size.y),
				box.position + Vector2(box.size.x * 0.2, 0)])
			draw_polyline(points, line, 2.0)
		EquipmentSlots.Slot.BACKPACK:
			draw_rect(box, line, false, 2.0)
			draw_rect(Rect2(box.position + Vector2(box.size.x * 0.2, box.size.y * 0.5),
					Vector2(box.size.x * 0.6, box.size.y * 0.35)), line, false, 2.0)
		_:
			draw_rect(box, line, false, 2.0)
			draw_arc(box.get_center(), minf(box.size.x, box.size.y) * 0.18, 0.0, TAU, 20, line, 2.0)
