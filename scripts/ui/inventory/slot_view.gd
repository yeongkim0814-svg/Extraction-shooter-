class_name InventorySlotView
extends Control
## 장비 슬롯 하나. 라벨과, 장착된 아이템이 있으면 그 아이템을 슬롯 크기로 그린다.

signal item_pressed(view: InventorySlotView, item: ItemInstance, local_pos: Vector2, from_touch: bool)

const SLOT_SIZE := Vector2(196, 64)

var slot: EquipmentSlots.Slot = EquipmentSlots.Slot.PRIMARY_1
var label_text: String = ""
var inventory: Inventory
var dragging_item_id: int = 0

var _highlight_valid: bool = false
var _has_highlight: bool = false


func setup(p_inventory: Inventory, p_slot: EquipmentSlots.Slot, p_label: String) -> void:
	inventory = p_inventory
	slot = p_slot
	label_text = p_label
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_highlight(valid: bool) -> void:
	_highlight_valid = valid
	_has_highlight = true
	queue_redraw()


func clear_highlight() -> void:
	if _has_highlight:
		_has_highlight = false
		queue_redraw()


func visible_global_rect() -> Rect2:
	return get_global_rect()


## 터치가 에뮬레이션한 마우스 이벤트인지 (롱프레스로 집기 vs 마우스 즉시 드래그 구분).
static func _is_touch(event: InputEventMouse) -> bool:
	return event.device == InputEvent.DEVICE_ID_EMULATION


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var item: ItemInstance = inventory.equipment.get_item(slot)
	if item == null:
		return
	item_pressed.emit(self, item, button.position, _is_touch(button))
	accept_event()


func _draw() -> void:
	if inventory == null:
		return
	var font: Font = get_theme_default_font()
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.09, 0.1, 0.12))
	draw_rect(rect.grow(-0.5), Color(0.28, 0.3, 0.35), false, 1.0)
	var item: ItemInstance = inventory.equipment.get_item(slot)
	if item == null:
		draw_string(font, Vector2(8, 24), label_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 15,
				Color(0.55, 0.58, 0.64))
	else:
		var alpha: float = 0.3 if item.id == dragging_item_id else 1.0
		InventoryItemPainter.draw_item(self, font, item, rect.grow(-3), false, alpha, false)
		draw_string(font, Vector2(8, size.y - 8), label_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11,
				Color(1, 1, 1, 0.65 * alpha))
	if _has_highlight:
		var color: Color = Color(0.2, 0.9, 0.3, 0.45) if _highlight_valid else Color(0.95, 0.2, 0.2, 0.45)
		draw_rect(rect, color)
		draw_rect(rect.grow(-1), color.lightened(0.4), false, 2.0)
