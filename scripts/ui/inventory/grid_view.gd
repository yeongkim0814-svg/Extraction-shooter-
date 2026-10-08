class_name InventoryGridView
extends Control
## ItemGrid 하나를 그리는 뷰. 칸과 아이템을 _draw로 직접 그린다 (아이템마다 노드를 만들지 않음).
## 입력은 직접 처리하지 않고 아이템을 눌렀다는 사실만 화면(InventoryScreen)에 알린다.

signal item_pressed(view: InventoryGridView, item: ItemInstance, local_pos: Vector2, from_touch: bool)

const CELL: int = InventoryItemPainter.CELL_SIZE

var key: StringName = &""
var inventory: Inventory
## 드래그 중인 아이템 id (원래 자리에 흐리게 그린다). 0이면 없음.
var dragging_item_id: int = 0
## 스크롤 컨테이너 안에 있을 때, 포인터가 실제로 보이는 영역 안에 있는지 판정하는 데 쓰는 클립 컨트롤.
var clip_control: Control = null

var _highlight_cell: Vector2i = Vector2i.ZERO
var _highlight_size: Vector2i = Vector2i.ZERO
var _highlight_valid: bool = false
var _has_highlight: bool = false


func setup(p_inventory: Inventory, p_key: StringName) -> void:
	inventory = p_inventory
	key = p_key
	var grid: ItemGrid = inventory.get_grid(key)
	custom_minimum_size = Vector2(grid.width * CELL, grid.height * CELL)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_highlight(cell: Vector2i, cell_size: Vector2i, valid: bool) -> void:
	_highlight_cell = cell
	_highlight_size = cell_size
	_highlight_valid = valid
	_has_highlight = true
	queue_redraw()


func clear_highlight() -> void:
	if _has_highlight:
		_has_highlight = false
		queue_redraw()


## 이 뷰에서 보이는(클립된) 전역 영역.
func visible_global_rect() -> Rect2:
	var rect: Rect2 = get_global_rect()
	if clip_control != null:
		rect = rect.intersection(clip_control.get_global_rect())
	return rect


## 아이템의 전역 화면 영역 (회전 반영).
func item_global_rect(item: ItemInstance) -> Rect2:
	return Rect2(global_position + Vector2(item.position * CELL), Vector2(item.size() * CELL))


func cell_at_local(local_pos: Vector2) -> Vector2i:
	return Vector2i((local_pos / float(CELL)).floor())


## 터치가 에뮬레이션한 마우스 이벤트인지 (롱프레스로 집기 vs 마우스 즉시 드래그 구분).
static func _is_touch(event: InputEventMouse) -> bool:
	return event.device == InputEvent.DEVICE_ID_EMULATION


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var grid: ItemGrid = inventory.get_grid(key)
	if grid == null:
		return
	var item: ItemInstance = grid.get_item_at(cell_at_local(button.position))
	if item == null:
		return
	item_pressed.emit(self, item, button.position, _is_touch(button))
	accept_event()


func _draw() -> void:
	var grid: ItemGrid = inventory.get_grid(key) if inventory != null else null
	if grid == null:
		return
	var font: Font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid.width * CELL, grid.height * CELL)), Color(0.09, 0.1, 0.12))
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL).grow(-0.5), Color(0.2, 0.22, 0.26), false, 1.0)
	for item: ItemInstance in grid.get_items():
		var rect := Rect2(Vector2(item.position * CELL), Vector2(item.size() * CELL))
		var alpha: float = 0.3 if item.id == dragging_item_id else 1.0
		InventoryItemPainter.draw_item(self, font, item, rect, item.rotated, alpha)
	if _has_highlight:
		var color: Color = Color(0.2, 0.9, 0.3, 0.45) if _highlight_valid else Color(0.95, 0.2, 0.2, 0.45)
		var cells := Rect2(Vector2(_highlight_cell * CELL), Vector2(_highlight_size * CELL))
		var clipped: Rect2 = cells.intersection(Rect2(Vector2.ZERO, size))
		if clipped.has_area():
			draw_rect(clipped, color)
			draw_rect(clipped, color.lightened(0.4), false, 2.0)
