class_name DropResolver
extends RefCounted
## 드래그 중인 아이템을 놓았을 때 무슨 일이 일어날지 판정하는 순수 로직 (UI는 이 결과만 따른다).
## 판정만 하고 상태는 바꾸지 않는다. 실행은 UI가 command를 권한자에 넘겨서 한다.
##
## Inventory의 비공개 규칙 중 최소한만 복제했다 (실제 실행은 항상 Inventory가 다시 검증한다):
##   - 스태시 잠금 판정 (컨테이너 키를 따라 최상위 컨테이너를 찾는 부분)
##   - 중첩 금지 (내부 그리드를 가진 아이템은 다른 아이템의 그리드에 넣을 수 없음)

enum Kind { NONE, MOVE, MERGE, EQUIP }

## 판정 결과. valid는 미리보기 하이라이트(초록/빨강)용이고, command가 null이면 실행할 것이 없다.
class Resolution:
	var kind: Kind = Kind.NONE
	var command: GameCommand = null
	var valid: bool = false
	## 무효일 때의 이유 (CommandResult 오류 코드). 유효하면 &"".
	var error: StringName = &""

	static func invalid(p_error: StringName) -> Resolution:
		var r := Resolution.new()
		r.error = p_error
		return r


## 그리드(key)의 cell에 놓는 경우. cell은 아이템 좌상단 칸, p_rotated는 놓을 때의 회전 상태.
## 점유 칸 중 하나라도 같은 종류의 스택 가능한 아이템이 있으면 병합을 먼저 시도한다.
## 병합 대상이 가득 찼으면 병합할 수 없고, 칸이 겹치므로 이동도 불가: NONE + 무효 (NO_SPACE).
## 자기 위치·회전 그대로 놓으면 NONE + 유효 (실행할 것 없음, 하이라이트만 초록).
static func resolve_grid(inventory: Inventory, item_id: int, key: StringName, cell: Vector2i,
		p_rotated: bool) -> Resolution:
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null:
		return Resolution.invalid(CommandResult.UNKNOWN_ITEM)
	var grid: ItemGrid = inventory.get_grid(key)
	if grid == null:
		return Resolution.invalid(CommandResult.UNKNOWN_CONTAINER)
	if _is_item_locked(inventory, item) or _is_key_locked(inventory, key):
		return Resolution.invalid(CommandResult.STASH_LOCKED)

	var merge_target: ItemInstance = _find_merge_target(grid, item, cell, p_rotated)
	if merge_target != null:
		if merge_target.free_stack_space() <= 0:
			return Resolution.invalid(CommandResult.NO_SPACE)
		var merge := Resolution.new()
		merge.kind = Kind.MERGE
		merge.valid = true
		merge.command = MergeStacksCommand.new(item.id, merge_target.id)
		return merge

	if item.def.is_container() and _item_id_of_grid_key(key) >= 0:
		return Resolution.invalid(CommandResult.NESTING_NOT_ALLOWED)
	if not grid.can_place(item, cell, p_rotated):
		return Resolution.invalid(CommandResult.NO_SPACE)

	var move := Resolution.new()
	move.valid = true
	if item.container_key == key and item.position == cell and item.rotated == p_rotated:
		return move
	move.kind = Kind.MOVE
	move.command = MoveItemCommand.new(item.id, key, cell, p_rotated)
	return move


## 장비 슬롯에 놓는 경우. 이미 다른 아이템이 있으면 무효 (교체는 지원하지 않음).
## 이미 그 슬롯에 있는 아이템이면 NONE + 무효.
static func resolve_slot(inventory: Inventory, item_id: int, slot: EquipmentSlots.Slot) -> Resolution:
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null:
		return Resolution.invalid(CommandResult.UNKNOWN_ITEM)
	if _is_item_locked(inventory, item):
		return Resolution.invalid(CommandResult.STASH_LOCKED)
	var occupant: ItemInstance = inventory.equipment.get_item(slot)
	if occupant == item:
		return Resolution.invalid(CommandResult.SLOT_OCCUPIED)
	if not EquipmentSlots.accepts(slot, item.def):
		return Resolution.invalid(CommandResult.SLOT_NOT_ALLOWED)
	if occupant != null:
		return Resolution.invalid(CommandResult.SLOT_OCCUPIED)
	var equip := Resolution.new()
	equip.kind = Kind.EQUIP
	equip.valid = true
	equip.command = EquipItemCommand.new(item.id, slot)
	return equip


## 스택을 반으로 나눌 명령. 같은 그리드의 첫 빈 자리(행 우선, 회전 안 함 → 회전 순)에 새 스택을 둔다.
## 나눌 수 없으면(스택 1, 장비 슬롯 안, 잠김, 빈자리 없음) null.
static func plan_split(inventory: Inventory, item_id: int) -> SplitStackCommand:
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null or item.stack_count < 2 or _is_item_locked(inventory, item):
		return null
	var grid: ItemGrid = inventory.get_grid(item.container_key)
	if grid == null:
		return null
	# 탐색용 임시 아이템: 실제 아이템 id와 겹치지 않는 id를 쓴다 (can_place는 id로 자기 칸을 구분).
	var probe := ItemInstance.new(2147483647, item.def, 1)
	var placement: ItemGrid.Placement = grid.find_free_placement(probe)
	if placement == null:
		return null
	return SplitStackCommand.new(item.id, item.stack_count / 2, item.container_key,
			placement.cell, placement.rotated)


# --- 내부 ---

static func _find_merge_target(grid: ItemGrid, item: ItemInstance, cell: Vector2i,
		p_rotated: bool) -> ItemInstance:
	if item.def.max_stack <= 1:
		return null
	var size: Vector2i = item.size_for(p_rotated)
	for y: int in range(cell.y, cell.y + size.y):
		for x: int in range(cell.x, cell.x + size.x):
			var occupant: ItemInstance = grid.get_item_at(Vector2i(x, y))
			if occupant != null and occupant != item and item.can_stack_with(occupant):
				return occupant
	return null


## "item_<id>_<n>" 형태의 컨테이너 아이템 그리드 키에서 아이템 id를 꺼낸다. 아니면 -1.
static func _item_id_of_grid_key(key: StringName) -> int:
	var parts: PackedStringArray = String(key).split("_")
	if parts.size() != 3 or parts[0] != "item" or not parts[1].is_valid_int():
		return -1
	var item_id: int = parts[1].to_int()
	return item_id if item_id > 0 else -1


## 키가 속한 최상위 컨테이너 키 (스태시·주머니·슬롯). 알 수 없으면 &"".
static func _root_container_of_key(inventory: Inventory, key: StringName) -> StringName:
	var current: StringName = key
	for _depth: int in range(8):
		var owner_id: int = _item_id_of_grid_key(current)
		if owner_id < 0:
			return current
		var owner: ItemInstance = inventory.get_item(owner_id)
		if owner == null:
			return &""
		current = owner.container_key
	return &""


static func _is_key_locked(inventory: Inventory, key: StringName) -> bool:
	return inventory.stash_locked and _root_container_of_key(inventory, key) == Inventory.STASH


static func _is_item_locked(inventory: Inventory, item: ItemInstance) -> bool:
	return _is_key_locked(inventory, item.container_key)
