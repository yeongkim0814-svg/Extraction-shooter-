class_name InventoryGridView
extends Control
## ItemGrid 하나를 그리는 뷰. 칸과 아이템을 _draw로 직접 그린다 (아이템마다 노드를 만들지 않음).
## 입력은 받지 않는다 (InventoryScreen이 포인터 이벤트를 모아서 이 뷰에 묻는다: cell_at_global / item_at_global).

var key: StringName = &""
var inventory: Inventory
## 한 칸의 한 변 (논리 픽셀).
var cell: int = InventoryItemPainter.CELL_SIZE
## 드래그 중인 아이템 id (원래 자리에 흐리게 그린다). 0이면 없음.
var dragging_item_id: int = 0
## 선택된 아이템 id (윤곽선으로 강조). 0이면 없음.
var selected_item_id: int = 0
## 스크롤 컨테이너 안에 있을 때, 포인터가 실제로 보이는 영역 안에 있는지 판정하는 데 쓰는 클립 컨트롤.
var clip_control: Control = null
## true면 그룹 테두리를 그린다 (컨테이너 내부 그리드).
var bordered: bool = false

var _highlight_cell: Vector2i = Vector2i.ZERO
var _highlight_size: Vector2i = Vector2i.ZERO
var _highlight_valid: bool = false
var _has_highlight: bool = false


func setup(p_inventory: Inventory, p_key: StringName, p_cell: int) -> void:
	inventory = p_inventory
	key = p_key
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_cell_size(p_cell)


func set_cell_size(p_cell: int) -> void:
	cell = p_cell
	var grid: ItemGrid = inventory.get_grid(key)
	if grid != null:
		custom_minimum_size = Vector2(grid.width * cell, grid.height * cell)
		size = custom_minimum_size
	queue_redraw()


func set_highlight(p_cell: Vector2i, cell_size: Vector2i, valid: bool) -> void:
	_highlight_cell = p_cell
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
	return Rect2(global_position + Vector2(item.position * cell), Vector2(item.size() * cell))


func cell_at_global(global_pos: Vector2) -> Vector2i:
	return Vector2i(((global_pos - global_position) / float(cell)).floor())


## 전역 좌표 아래의 아이템 (없으면 null).
func item_at_global(global_pos: Vector2) -> ItemInstance:
	var grid: ItemGrid = inventory.get_grid(key)
	if grid == null:
		return null
	return grid.get_item_at(cell_at_global(global_pos))


func _draw() -> void:
	var grid: ItemGrid = inventory.get_grid(key) if inventory != null else null
	if grid == null:
		return
	var font: Font = get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, Vector2(grid.width * cell, grid.height * cell)), Color(0.09, 0.1, 0.12))
	for y: int in range(grid.height):
		for x: int in range(grid.width):
			draw_rect(Rect2(x * cell, y * cell, cell, cell).grow(-0.5), Color(0.2, 0.22, 0.26), false, 1.0)
	if bordered:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), InventoryStyle.GROUP_BORDER, false, 2.0)
	var selected: ItemInstance = null
	for item: ItemInstance in grid.get_items():
		var rect := Rect2(Vector2(item.position * cell), Vector2(item.size() * cell))
		var alpha: float = 0.3 if item.id == dragging_item_id else 1.0
		InventoryItemPainter.draw_item(self, font, item, rect, item.rotated, alpha)
		if item.id == selected_item_id:
			selected = item
	if selected != null:
		InventoryItemPainter.draw_selection(self, Rect2(Vector2(selected.position * cell), Vector2(selected.size() * cell)))
	if _has_highlight:
		var color: Color = Color(0.2, 0.9, 0.3, 0.45) if _highlight_valid else Color(0.95, 0.2, 0.2, 0.45)
		var cells := Rect2(Vector2(_highlight_cell * cell), Vector2(_highlight_size * cell))
		var clipped: Rect2 = cells.intersection(Rect2(Vector2.ZERO, size))
		if clipped.has_area():
			draw_rect(clipped, color)
			draw_rect(clipped, color.lightened(0.4), false, 2.0)
