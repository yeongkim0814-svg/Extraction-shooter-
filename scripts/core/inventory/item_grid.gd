class_name ItemGrid
extends RefCounted
## 테트리스형 인벤토리 그리드 하나 (주머니·배낭·스태시 공통).
## 모든 변경 연산은 원자적이다: 실패하면 상태가 바뀌지 않는다.

const EMPTY := 0


## 배치 후보: 좌상단 칸 + 회전 여부.
class Placement:
	var cell: Vector2i
	var rotated: bool

	func _init(p_cell: Vector2i, p_rotated: bool) -> void:
		cell = p_cell
		rotated = p_rotated


var width: int
var height: int
## 칸마다 점유한 아이템 id (EMPTY = 빈 칸). 행 우선: index = y * width + x
var _cells: PackedInt32Array = PackedInt32Array()
var _items: Dictionary[int, ItemInstance] = {}


func _init(p_width: int, p_height: int) -> void:
	assert(p_width > 0 and p_height > 0, "grid size must be positive")
	width = p_width
	height = p_height
	_cells.resize(width * height)
	_cells.fill(EMPTY)


func has_item(item: ItemInstance) -> bool:
	return _items.get(item.id) == item


func get_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	result.assign(_items.values())
	return result


func get_item_at(cell: Vector2i) -> ItemInstance:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return null
	var item_id: int = _cells[cell.y * width + cell.x]
	if item_id == EMPTY:
		return null
	return _items[item_id]


## 경계 안이고, 겹치는 칸이 비었거나 item 자신이 차지한 칸이면 true.
func can_place(item: ItemInstance, cell: Vector2i, p_rotated: bool) -> bool:
	if p_rotated and not item.def.can_rotate:
		return false
	var size: Vector2i = item.size_for(p_rotated)
	if cell.x < 0 or cell.y < 0 or cell.x + size.x > width or cell.y + size.y > height:
		return false
	for y: int in range(cell.y, cell.y + size.y):
		for x: int in range(cell.x, cell.x + size.x):
			var occupant: int = _cells[y * width + x]
			if occupant != EMPTY and occupant != item.id:
				return false
	return true


func try_place(item: ItemInstance, cell: Vector2i, p_rotated: bool) -> bool:
	if _items.has(item.id) or not can_place(item, cell, p_rotated):
		return false
	item.position = cell
	item.rotated = p_rotated
	_items[item.id] = item
	_fill(item, item.id)
	return true


## 같은 그리드 안에서 위치·회전 변경. 자기 자신이 차지했던 칸과 겹쳐도 된다.
func move(item: ItemInstance, cell: Vector2i, p_rotated: bool) -> bool:
	if not has_item(item) or not can_place(item, cell, p_rotated):
		return false
	_fill(item, EMPTY)
	item.position = cell
	item.rotated = p_rotated
	_fill(item, item.id)
	return true


func remove(item: ItemInstance) -> bool:
	if not has_item(item):
		return false
	_fill(item, EMPTY)
	_items.erase(item.id)
	item.position = ItemInstance.NOT_PLACED
	return true


## 행 우선으로 첫 빈 자리를 찾는다. 회전하지 않은 방향을 먼저 전부 시도한 뒤 회전 방향을 시도.
## 자리가 없으면 null.
func find_free_placement(item: ItemInstance) -> Placement:
	var orientations: Array[bool] = [false]
	if item.def.can_rotate and item.def.width != item.def.height:
		orientations.append(true)
	for p_rotated: bool in orientations:
		var size: Vector2i = item.size_for(p_rotated)
		for y: int in range(height - size.y + 1):
			for x: int in range(width - size.x + 1):
				var cell := Vector2i(x, y)
				if can_place(item, cell, p_rotated):
					return Placement.new(cell, p_rotated)
	return null


## target 칸에 가장 가까운 배치를 찾는다 (탭으로 옮길 때). 없으면 null.
## 우선순위: ① 아이템이 target 칸을 덮는 배치 → 덮지 않으면 target과 아이템 영역 사이 거리가 짧은 배치
## ② prefer_rotated와 같은 방향 ③ 아이템 중심이 target에 가까운 배치 ④ 행 우선 순서.
## 이 그리드에 이미 있는 아이템이면 자기 자리와 겹쳐도 된다 (can_place 규칙).
func find_nearest_placement(item: ItemInstance, target: Vector2i, prefer_rotated: bool) -> Placement:
	var orientations: Array[bool] = [prefer_rotated]
	if item.def.can_rotate and item.def.width != item.def.height:
		orientations.append(not prefer_rotated)
	elif prefer_rotated and not item.def.can_rotate:
		orientations = [false]
	var best: Placement = null
	var best_score := Vector3(INF, INF, INF)
	for p_rotated: bool in orientations:
		var size: Vector2i = item.size_for(p_rotated)
		for y: int in range(height - size.y + 1):
			for x: int in range(width - size.x + 1):
				var cell := Vector2i(x, y)
				if not can_place(item, cell, p_rotated):
					continue
				var dx: int = maxi(maxi(x - target.x, 0), target.x - (x + size.x - 1))
				var dy: int = maxi(maxi(y - target.y, 0), target.y - (y + size.y - 1))
				var center := Vector2(x + (size.x - 1) * 0.5, y + (size.y - 1) * 0.5)
				var score := Vector3(dx * dx + dy * dy,
						0.0 if p_rotated == prefer_rotated else 1.0,
						center.distance_squared_to(Vector2(target)))
				if score < best_score:
					best_score = score
					best = Placement.new(cell, p_rotated)
	return best


func try_auto_place(item: ItemInstance) -> bool:
	if _items.has(item.id):
		return false
	var placement: Placement = find_free_placement(item)
	if placement == null:
		return false
	return try_place(item, placement.cell, placement.rotated)


## source의 수량을 이 그리드 안의 target 스택으로 옮기고 옮긴 수량을 반환한다.
## source가 이 그리드에 있고 비게 되면 제거한다. 다른 컨테이너의 source는 호출자가 정리한다.
func merge(source: ItemInstance, target: ItemInstance) -> int:
	if not has_item(target) or not source.can_stack_with(target):
		return 0
	var amount: int = mini(source.stack_count, target.free_stack_space())
	if amount <= 0:
		return 0
	target.stack_count += amount
	source.stack_count -= amount
	if source.stack_count == 0 and has_item(source):
		remove(source)
	return amount


## item에서 amount만큼 떼어 new_id로 새 스택을 만들고 빈 자리에 자동 배치한다.
## 자리가 없거나 amount가 유효하지 않으면 null을 반환하고 아무것도 바꾸지 않는다.
func split(item: ItemInstance, amount: int, new_id: int) -> ItemInstance:
	if not has_item(item) or amount <= 0 or amount >= item.stack_count:
		return null
	var part := ItemInstance.new(new_id, item.def, amount)
	if not try_auto_place(part):
		return null
	item.stack_count -= amount
	return part


## 점유맵이 아이템 목록에서 다시 계산한 맵과 같은지 검사한다 (테스트·디버그용 불변식).
func is_consistent() -> bool:
	var expected := PackedInt32Array()
	expected.resize(width * height)
	expected.fill(EMPTY)
	for item: ItemInstance in _items.values():
		var size: Vector2i = item.size()
		if item.position.x < 0 or item.position.y < 0 \
				or item.position.x + size.x > width or item.position.y + size.y > height:
			return false
		for y: int in range(item.position.y, item.position.y + size.y):
			for x: int in range(item.position.x, item.position.x + size.x):
				var index: int = y * width + x
				if expected[index] != EMPTY:
					return false
				expected[index] = item.id
	return expected == _cells


func _fill(item: ItemInstance, value: int) -> void:
	var size: Vector2i = item.size()
	for y: int in range(item.position.y, item.position.y + size.y):
		for x: int in range(item.position.x, item.position.x + size.x):
			_cells[y * width + x] = value
