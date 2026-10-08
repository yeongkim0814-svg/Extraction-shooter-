class_name SearchState
extends RefCounted
## 루팅 컨테이너 하나의 수색 진행 상태. 아이템은 위에서부터(행 우선) 하나씩 공개된다.
## 공개되지 않은 아이템은 UI에 "?"로 보이고 집을 수 없다.
## 중단(이동·피격·사격)되면 진행 중이던 아이템의 진행도만 잃고, 이미 공개된 아이템은 유지된다.

## 수색 중 초당 소음 크기 (AI 청각 감지용, 1 = 걷는 발소리 수준).
const NOISE_PER_SECOND := 0.6


class TickResult:
	var revealed: Array[ItemInstance] = []
	## 이번 tick 동안 발생한 소음량 (NOISE_PER_SECOND × 실제 수색한 시간).
	var noise: float = 0.0


var grid: ItemGrid
var calculator: SearchTimeCalculator
var searching: bool = false
var _revealed: Dictionary[int, bool] = {}
var _current_id: int = 0
var _progress: float = 0.0


func _init(p_grid: ItemGrid, p_calculator: SearchTimeCalculator = SearchTimeCalculator.new()) -> void:
	grid = p_grid
	calculator = p_calculator


func is_revealed(item: ItemInstance) -> bool:
	return _revealed.has(item.id)


## 플레이어가 직접 넣은 아이템 등, 수색 없이 공개 처리.
func mark_revealed(item: ItemInstance) -> void:
	_revealed[item.id] = true
	if _current_id == item.id:
		_current_id = 0
		_progress = 0.0


## 아직 공개되지 않은 아이템 (공개될 순서: 위 → 아래, 왼쪽 → 오른쪽).
func pending_items() -> Array[ItemInstance]:
	var pending: Array[ItemInstance] = []
	for item: ItemInstance in grid.get_items():
		if not _revealed.has(item.id):
			pending.append(item)
	pending.sort_custom(_reveal_order)
	return pending


func is_complete() -> bool:
	return pending_items().is_empty()


func start() -> void:
	searching = true


## 수색 중단. 진행 중이던 아이템의 진행도를 잃는다.
func interrupt() -> void:
	searching = false
	_current_id = 0
	_progress = 0.0


## 수색 진행 중인 아이템의 진행도 0~1 (없으면 0).
func current_progress() -> float:
	var item: ItemInstance = _current_item()
	if item == null:
		return 0.0
	return clampf(_progress / calculator.time_for(item.def), 0.0, 1.0)


func current_item_id() -> int:
	var item: ItemInstance = _current_item()
	return item.id if item != null else 0


## delta초 동안 수색을 진행한다. 시간이 남으면 다음 아이템으로 이어서 진행한다.
func tick(delta: float) -> TickResult:
	var result := TickResult.new()
	if not searching or delta <= 0.0:
		return result
	var remaining: float = delta
	while remaining > 0.0:
		var item: ItemInstance = _current_item()
		if item == null:
			searching = false
			break
		var needed: float = calculator.time_for(item.def) - _progress
		if remaining < needed:
			_progress += remaining
			result.noise += remaining * NOISE_PER_SECOND
			remaining = 0.0
		else:
			remaining -= needed
			result.noise += needed * NOISE_PER_SECOND
			_revealed[item.id] = true
			result.revealed.append(item)
			_current_id = 0
			_progress = 0.0
	return result


## 진행 중인 아이템. 그 아이템이 사라졌으면(다른 플레이어가 가져감 등) 다음 순서로 넘어간다.
func _current_item() -> ItemInstance:
	if _current_id != 0:
		for item: ItemInstance in grid.get_items():
			if item.id == _current_id and not _revealed.has(item.id):
				return item
		_current_id = 0
		_progress = 0.0
	var pending: Array[ItemInstance] = pending_items()
	if pending.is_empty():
		return null
	_current_id = pending[0].id
	return pending[0]


static func _reveal_order(a: ItemInstance, b: ItemInstance) -> bool:
	if a.position.y != b.position.y:
		return a.position.y < b.position.y
	return a.position.x < b.position.x
