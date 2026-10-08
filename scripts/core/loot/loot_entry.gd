class_name LootEntry
extends Resource
## 루팅 테이블의 한 항목: 어떤 아이템이 얼마나 자주, 몇 개씩 나오는지.

@export var def: ItemDef
## 상대 가중치. 0 이하이면 절대 뽑히지 않는다.
@export var weight: float = 1.0
@export_range(1, 9999) var min_stack: int = 1
@export_range(1, 9999) var max_stack: int = 1


static func create(p_def: ItemDef, p_weight: float = 1.0, p_min_stack: int = 1,
		p_max_stack: int = 1) -> LootEntry:
	var entry := LootEntry.new()
	entry.def = p_def
	entry.weight = p_weight
	entry.min_stack = p_min_stack
	entry.max_stack = p_max_stack
	return entry
