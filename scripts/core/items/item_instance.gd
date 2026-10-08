class_name ItemInstance
extends RefCounted
## 게임 세계에 존재하는 아이템 1개(또는 1스택).
## id는 권한자(GameAuthority)가 발급하며 0은 "빈 칸"을 뜻하므로 쓰지 않는다.

const NOT_PLACED := Vector2i(-1, -1)

var id: int
var def: ItemDef
var stack_count: int
var found_in_raid: bool = false
## 그리드 안에서의 좌상단 칸과 회전 여부. 그리드에 없으면 NOT_PLACED.
var position: Vector2i = NOT_PLACED
var rotated: bool = false
## 현재 들어 있는 그리드 또는 장비 슬롯의 키 (Inventory가 관리). 어디에도 없으면 &"".
var container_key: StringName = &""
## def.grids에 대응하는 내부 그리드 (컨테이너 아이템만).
var grids: Array[ItemGrid] = []


func _init(p_id: int, p_def: ItemDef, p_stack_count: int = 1) -> void:
	assert(p_id > 0, "item id must be positive")
	id = p_id
	def = p_def
	stack_count = clampi(p_stack_count, 1, p_def.max_stack)
	for size: Vector2i in p_def.grids:
		grids.append(ItemGrid.new(size.x, size.y))


## 회전 여부에 따른 점유 크기 (가로, 세로).
func size_for(p_rotated: bool) -> Vector2i:
	if p_rotated:
		return Vector2i(def.height, def.width)
	return Vector2i(def.width, def.height)


func size() -> Vector2i:
	return size_for(rotated)


func free_stack_space() -> int:
	return def.max_stack - stack_count


func can_stack_with(other: ItemInstance) -> bool:
	return other != self and def.max_stack > 1 and other.def.id == def.id
