class_name LootTable
extends Resource
## 가중치 기반 루팅 테이블. 무작위는 항상 주입받은 RandomNumberGenerator로만 만든다.

@export var entries: Array[LootEntry] = []
@export var min_items: int = 1
@export var max_items: int = 3


## min~max개를 가중치대로 뽑아 새 아이템(FIR)으로 만든다. 인벤토리에는 넣지 않는다.
func roll(rng: RandomNumberGenerator, authority: GameAuthority) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	var total: float = _total_weight()
	if total <= 0.0:
		return result
	var lo: int = maxi(min_items, 0)
	var count: int = rng.randi_range(lo, maxi(max_items, lo))
	for _i: int in range(count):
		var entry: LootEntry = _pick(rng, total)
		var stack: int = _roll_stack(rng, entry)
		var item: ItemInstance = authority.create_item(entry.def, stack)
		item.found_in_raid = true
		result.append(item)
	return result


## roll한 뒤 그리드의 빈 자리에 자동 배치한다. 들어간 아이템만 반환하고 못 넣은 것은 버린다.
func fill_grid(grid: ItemGrid, rng: RandomNumberGenerator, authority: GameAuthority) -> Array[ItemInstance]:
	var placed: Array[ItemInstance] = []
	for item: ItemInstance in roll(rng, authority):
		if grid.try_auto_place(item):
			placed.append(item)
	return placed


func _is_pickable(entry: LootEntry) -> bool:
	return entry != null and entry.def != null and entry.weight > 0.0


func _total_weight() -> float:
	var total: float = 0.0
	for entry: LootEntry in entries:
		if _is_pickable(entry):
			total += entry.weight
	return total


func _pick(rng: RandomNumberGenerator, total: float) -> LootEntry:
	var target: float = rng.randf() * total
	var last: LootEntry = null
	var acc: float = 0.0
	for entry: LootEntry in entries:
		if not _is_pickable(entry):
			continue
		last = entry
		acc += entry.weight
		if target < acc:
			return entry
	return last


## 스택 수량은 [min,max]에서 뽑고 def.max_stack으로 제한한다.
func _roll_stack(rng: RandomNumberGenerator, entry: LootEntry) -> int:
	var cap: int = entry.def.max_stack
	var lo: int = clampi(entry.min_stack, 1, cap)
	var hi: int = clampi(entry.max_stack, lo, cap)
	return rng.randi_range(lo, hi)
