class_name InventoryItemPainter
extends RefCounted
## 아이템 하나를 CanvasItem 위에 그리는 공용 도우미 (그리드 뷰·장비 슬롯·드래그 고스트가 함께 쓴다).
## def.icon이 있으면 아이콘, 없으면 카테고리 색 블록 + 이름.

## 그리드 한 칸의 기본 한 변 (논리 픽셀). 실제 화면(InventoryScreen)은 가용 너비에서 칸 크기를 계산해 쓰며
## MIN_CELL_SIZE 아래로는 줄이지 않는다. 터치 최소 크기 44dp 근처를 유지한다.
const CELL_SIZE: int = 48
const MIN_CELL_SIZE: int = 40
const MAX_CELL_SIZE: int = 56
## 선택한 아이템의 윤곽선 색.
const SELECT_COLOR := Color(1.0, 0.86, 0.15)
## 수색 진행 표시 색 (채움 / 고리).
const SEARCH_FILL := Color(0.3, 0.6, 0.95, 0.35)
const SEARCH_RING := Color(0.55, 0.8, 1.0)

const _CATEGORY_COLORS: Dictionary[ItemDef.Category, Color] = {
	ItemDef.Category.MISC: Color("6b7280"),
	ItemDef.Category.WEAPON: Color("b45309"),
	ItemDef.Category.MAGAZINE: Color("a16207"),
	ItemDef.Category.AMMO: Color("ca8a04"),
	ItemDef.Category.ATTACHMENT: Color("78716c"),
	ItemDef.Category.MEDICAL: Color("dc2626"),
	ItemDef.Category.FOOD: Color("65a30d"),
	ItemDef.Category.VALUABLE: Color("d4a017"),
	ItemDef.Category.HELMET: Color("2563eb"),
	ItemDef.Category.ARMOR: Color("1d4ed8"),
	ItemDef.Category.RIG: Color("0f766e"),
	ItemDef.Category.BACKPACK: Color("7c3aed"),
	ItemDef.Category.SECURE_CONTAINER: Color("be185d"),
}


static func color_of(category: ItemDef.Category) -> Color:
	return _CATEGORY_COLORS.get(category, Color("6b7280"))


## rect 안에 아이템을 그린다. rotated면 아이콘을 90도 돌려 그린다 (색 블록은 영향 없음).
static func draw_item(canvas: CanvasItem, font: Font, item: ItemInstance, rect: Rect2,
		p_rotated: bool, alpha: float = 1.0, show_count: bool = true, show_name: bool = true) -> void:
	var inner: Rect2 = rect.grow(-1.5)
	var base: Color = color_of(item.def.category)
	base.a = alpha
	if item.def.icon != null:
		canvas.draw_rect(inner, Color(0.1, 0.11, 0.13, 0.9 * alpha))
		if p_rotated:
			canvas.draw_set_transform(Vector2(inner.end.x, inner.position.y), PI * 0.5)
			canvas.draw_texture_rect(item.def.icon, Rect2(Vector2.ZERO, Vector2(inner.size.y, inner.size.x)),
					false, Color(1, 1, 1, alpha))
			canvas.draw_set_transform(Vector2.ZERO, 0.0)
		else:
			canvas.draw_texture_rect(item.def.icon, inner, false, Color(1, 1, 1, alpha))
	else:
		canvas.draw_rect(inner, base.darkened(0.25))
		canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 4.0)), base.lightened(0.15))
	canvas.draw_rect(inner, base.lightened(0.35), false, 1.5)
	if show_name:
		_draw_label(canvas, font, item.def.display_name, inner, alpha)
	if show_count and item.def.max_stack > 1:
		var text: String = str(item.stack_count)
		var pos := Vector2(inner.position.x + 2.0, inner.end.y - 4.0)
		var width: float = inner.size.x - 6.0
		canvas.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_RIGHT, width, 13,
				Color(0, 0, 0, 0.9 * alpha))
		canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, width, 13,
				Color(1, 1, 0.8, alpha))


## 선택 표시: 아이템 영역을 굵은 윤곽선과 옅은 색으로 강조한다.
static func draw_selection(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect.grow(-1.5), Color(SELECT_COLOR, 0.14))
	canvas.draw_rect(rect.grow(-1.5), Color(0, 0, 0, 0.8), false, 5.0)
	canvas.draw_rect(rect.grow(-1.5), SELECT_COLOR, false, 3.0)


static func _draw_label(canvas: CanvasItem, font: Font, text: String, inner: Rect2, alpha: float) -> void:
	var font_size: int = 12
	var width: float = inner.size.x - 6.0
	var max_lines: int = maxi(1, int((inner.size.y - 14.0) / 15.0))
	var flags: int = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND
	var pos := Vector2(inner.position.x + 3.0, inner.position.y + 16.0)
	canvas.draw_multiline_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, width,
			font_size, max_lines, Color(0, 0, 0, 0.9 * alpha), flags)
	canvas.draw_multiline_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width,
			font_size, max_lines, Color(1, 1, 1, alpha), flags)


## 아직 수색하지 않은 아이템: 실제 크기의 어두운 블록에 "?"만 그린다 (이름·색 없음).
## progress가 0 이상이면 지금 수색 중인 아이템이라 아래에서 차오르는 채움과 둥근 진행 고리를 겹쳐 그린다.
static func draw_hidden(canvas: CanvasItem, font: Font, rect: Rect2, progress: float = -1.0) -> void:
	var inner: Rect2 = rect.grow(-1.5)
	canvas.draw_rect(inner, Color(0.07, 0.075, 0.09))
	canvas.draw_rect(inner, Color(0.3, 0.33, 0.4), false, 1.5)
	var center: Vector2 = inner.get_center()
	var radius: float = clampf(minf(inner.size.x, inner.size.y) * 0.34, 8.0, 22.0)
	if progress >= 0.0:
		var fill_h: float = inner.size.y * clampf(progress, 0.0, 1.0)
		canvas.draw_rect(Rect2(inner.position.x, inner.end.y - fill_h, inner.size.x, fill_h), SEARCH_FILL)
		canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.55), 5.0, true)
		canvas.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 32, SEARCH_RING, 4.0, true)
	var font_size: int = 22
	var size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(center.x - size.x * 0.5, center.y + size.y * 0.28)
	canvas.draw_string(font, pos + Vector2(1, 1), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
	canvas.draw_string(font, pos, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.75, 0.8, 0.9))
