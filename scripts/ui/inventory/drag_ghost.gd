class_name InventoryDragGhost
extends Control
## 드래그 중 포인터를 따라다니는 아이템 모양. 입력은 받지 않는다.

var _item: ItemInstance = null
var _rotated: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_item(item: ItemInstance, p_rotated: bool) -> void:
	_item = item
	_rotated = p_rotated
	size = Vector2(item.size_for(p_rotated) * InventoryItemPainter.CELL_SIZE)
	visible = true
	queue_redraw()


func set_rotated(p_rotated: bool) -> void:
	if _item != null:
		show_item(_item, p_rotated)


func hide_ghost() -> void:
	_item = null
	visible = false


func _draw() -> void:
	if _item != null:
		InventoryItemPainter.draw_item(self, get_theme_default_font(), _item, Rect2(Vector2.ZERO, size),
				_rotated, 0.85)
