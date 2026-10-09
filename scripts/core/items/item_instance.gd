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
## 무기 아이템의 부품 트리 (무기만, 아니면 null).
var weapon: WeaponAssembly = null
## 탄창 아이템의 장전 상태 (탄창만, 아니면 null).
var magazine: Magazine = null


func _init(p_id: int, p_def: ItemDef, p_stack_count: int = 1) -> void:
	assert(p_id > 0, "item id must be positive")
	id = p_id
	def = p_def
	stack_count = clampi(p_stack_count, 1, p_def.max_stack)
	for size: Vector2i in p_def.grids:
		grids.append(ItemGrid.new(size.x, size.y))


## 회전 여부에 따른 점유 크기 (가로, 세로). 무기는 장착한 부품에 따라 커진다.
func size_for(p_rotated: bool) -> Vector2i:
	var base := Vector2i(def.width, def.height)
	if weapon != null:
		base = weapon.compute_size(base)
	if p_rotated:
		return Vector2i(base.y, base.x)
	return base


func size() -> Vector2i:
	return size_for(rotated)


func free_stack_space() -> int:
	return def.max_stack - stack_count


func can_stack_with(other: ItemInstance) -> bool:
	return other != self and def.max_stack > 1 and other.def.id == def.id
