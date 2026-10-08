class_name InventoryItemPainter
extends RefCounted
## 아이템 하나를 CanvasItem 위에 그리는 공용 도우미 (그리드 뷰·장비 슬롯·드래그 고스트가 함께 쓴다).
## def.icon이 있으면 아이콘, 없으면 카테고리 색 블록 + 이름.

## 그리드 한 칸의 한 변 (논리 픽셀). 1280x720 기준 48 → 화면이 커지면 stretch로 같이 커진다.
## 터치 최소 크기 44dp 이상을 유지한다.
const CELL_SIZE: int = 48

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
		p_rotated: bool, alpha: float = 1.0, show_count: bool = true) -> void:
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
	_draw_label(canvas, font, item.def.display_name, inner, alpha)
	if show_count and item.def.max_stack > 1:
		var text: String = str(item.stack_count)
		var pos := Vector2(inner.position.x + 2.0, inner.end.y - 4.0)
		var width: float = inner.size.x - 6.0
		canvas.draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_RIGHT, width, 13,
				Color(0, 0, 0, 0.9 * alpha))
		canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_RIGHT, width, 13,
				Color(1, 1, 0.8, alpha))


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
