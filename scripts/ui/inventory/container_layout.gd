class_name ContainerLayout
extends RefCounted
## 컨테이너 내부 그리드 그룹들의 배치 계산 (순수 로직, 노드 없음).
## 결과 rects는 그리드 영역 원점 기준 픽셀 영역이고 grids와 같은 순서다.
##  - offsets 길이가 grids와 같고 모두 0 이상이며 결과 너비가 available_width 이하면 그 배치를 쓴다
##    (칸 오프셋 * cell + 서로 다른 오프셋 순번만큼 그룹 간격).
##  - 아니면 왼쪽에서 오른쪽으로 자동 배치하고, 다음 그리드가 너비를 넘으면 줄바꿈한다 (줄 높이 = 가장 큰 그리드).

var rects: Array[Rect2] = []
## 전체 영역 크기 (모든 그룹을 감싸는 크기).
var size: Vector2 = Vector2.ZERO
## 지정한 배치를 썼으면 true, 자동 배치면 false.
var authored: bool = false


static func compute(grid_sizes: Array[Vector2i], offsets: Array[Vector2i], cell: int,
		available_width: float, gap: int) -> ContainerLayout:
	var layout := ContainerLayout.new()
	if grid_sizes.is_empty():
		return layout
	if offsets.size() == grid_sizes.size() and _compute_authored(layout, grid_sizes, offsets, cell, gap) \
			and layout.size.x <= available_width:
		layout.authored = true
		return layout
	layout.rects.clear()
	layout.size = Vector2.ZERO
	_compute_flow(layout, grid_sizes, cell, available_width, gap)
	return layout


static func _compute_authored(layout: ContainerLayout, grid_sizes: Array[Vector2i],
		offsets: Array[Vector2i], cell: int, gap: int) -> bool:
	var xs: Array[int] = []
	var ys: Array[int] = []
	for offset: Vector2i in offsets:
		if offset.x < 0 or offset.y < 0:
			return false
		if not xs.has(offset.x):
			xs.append(offset.x)
		if not ys.has(offset.y):
			ys.append(offset.y)
	xs.sort()
	ys.sort()
	var total := Vector2.ZERO
	for i: int in range(grid_sizes.size()):
		var pos := Vector2(offsets[i].x * cell + xs.find(offsets[i].x) * gap,
				offsets[i].y * cell + ys.find(offsets[i].y) * gap)
		var rect := Rect2(pos, Vector2(grid_sizes[i] * cell))
		layout.rects.append(rect)
		total = Vector2(maxf(total.x, rect.end.x), maxf(total.y, rect.end.y))
	layout.size = total
	return true


static func _compute_flow(layout: ContainerLayout, grid_sizes: Array[Vector2i], cell: int,
		available_width: float, gap: int) -> void:
	var x: float = 0.0
	var y: float = 0.0
	var row_height: float = 0.0
	var total := Vector2.ZERO
	for grid_size: Vector2i in grid_sizes:
		var extent := Vector2(grid_size * cell)
		if x > 0.0 and x + extent.x > available_width:
			x = 0.0
			y += row_height + gap
			row_height = 0.0
		var rect := Rect2(Vector2(x, y), extent)
		layout.rects.append(rect)
		x += extent.x + gap
		row_height = maxf(row_height, extent.y)
		total = Vector2(maxf(total.x, rect.end.x), maxf(total.y, rect.end.y))
	layout.size = total
