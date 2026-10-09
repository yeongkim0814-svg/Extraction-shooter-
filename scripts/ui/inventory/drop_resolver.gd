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
	## MOVE일 때 실제로 놓이는 그리드 키·좌상단 칸·회전 (탭 이동은 가장 가까운 자리로 보정되므로 UI가 미리보기에 쓴다).
	var key: StringName = &""
	var cell: Vector2i = Vector2i.ZERO
	var rotated: bool = false

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

	return _move_resolution(item, key, cell, p_rotated)


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


## 선택한 아이템을 탭한 칸(tapped) 쪽으로 옮기는 경우. 드래그와 달리 정확한 칸이 아니라 가장 가까운 자리로 보정한다.
##   - 탭한 칸이 합칠 수 있는 같은 종류 스택이면 병합 (가득 찼으면 NO_SPACE 무효)
##   - 아니면 ItemGrid.find_nearest_placement(item, tapped, prefer_rotated)의 결과로 이동
##   - 자리가 없으면 NO_SPACE 무효. 지금 자리·회전 그대로가 가장 가까우면 NONE + 유효 (실행할 것 없음).
## 탭한 칸에 합칠 수 없는 다른 아이템이 있는 경우의 처리(선택 전환 등)는 호출자(UI)가 먼저 결정한다.
static func resolve_tap_grid(inventory: Inventory, item_id: int, key: StringName, tapped: Vector2i,
		prefer_rotated: bool) -> Resolution:
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null:
		return Resolution.invalid(CommandResult.UNKNOWN_ITEM)
	var grid: ItemGrid = inventory.get_grid(key)
	if grid == null:
		return Resolution.invalid(CommandResult.UNKNOWN_CONTAINER)
	if _is_item_locked(inventory, item) or _is_key_locked(inventory, key):
		return Resolution.invalid(CommandResult.STASH_LOCKED)
	var occupant: ItemInstance = grid.get_item_at(tapped)
	if occupant != null and occupant != item and item.can_stack_with(occupant):
		if occupant.free_stack_space() <= 0:
			return Resolution.invalid(CommandResult.NO_SPACE)
		var merge := Resolution.new()
		merge.kind = Kind.MERGE
		merge.valid = true
		merge.command = MergeStacksCommand.new(item.id, occupant.id)
		return merge
	if item.def.is_container() and _item_id_of_grid_key(key) >= 0:
		return Resolution.invalid(CommandResult.NESTING_NOT_ALLOWED)
	var placement: ItemGrid.Placement = grid.find_nearest_placement(item, tapped, prefer_rotated)
	if placement == null:
		return Resolution.invalid(CommandResult.NO_SPACE)
	return _move_resolution(item, key, placement.cell, placement.rotated)


## 아이템을 어느 빈 장비 슬롯에든 장착하는 경우 (슬롯 enum 순서대로 첫 호환 빈 슬롯).
## 이미 장착 중이거나 잠겼거나 호환 슬롯이 없으면 무효 (모두 차 있으면 SLOT_OCCUPIED).
static func plan_equip(inventory: Inventory, item_id: int) -> Resolution:
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null:
		return Resolution.invalid(CommandResult.UNKNOWN_ITEM)
	if is_equipped(item):
		return Resolution.invalid(CommandResult.SLOT_OCCUPIED)
	if _is_item_locked(inventory, item):
		return Resolution.invalid(CommandResult.STASH_LOCKED)
	var error: StringName = CommandResult.SLOT_NOT_ALLOWED
	for slot: EquipmentSlots.Slot in EquipmentSlots.Slot.values():
		if not EquipmentSlots.accepts(slot, item.def):
			continue
		if inventory.equipment.get_item(slot) == null:
			var equip := Resolution.new()
			equip.kind = Kind.EQUIP
			equip.valid = true
			equip.command = EquipItemCommand.new(item.id, slot)
			return equip
		error = CommandResult.SLOT_OCCUPIED
	return Resolution.invalid(error)


## 장착 슬롯에 있는 아이템을 가까운 빈 자리로 옮기는 경우.
## 후보 순서: 스태시(있고 잠기지 않았으면) → 배낭 → 리그 → 주머니. 컨테이너 아이템은 컨테이너 안에 못 넣으므로
## 배낭·리그 그리드는 건너뛴다. 슬롯에 있지 않거나 자리가 없으면 무효 (NO_SPACE).
static func plan_unequip(inventory: Inventory, item_id: int) -> Resolution:
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null:
		return Resolution.invalid(CommandResult.UNKNOWN_ITEM)
	if not is_equipped(item):
		return Resolution.invalid(CommandResult.UNKNOWN_CONTAINER)
	for key: StringName in _unequip_candidate_keys(inventory, item):
		var grid: ItemGrid = inventory.get_grid(key)
		if grid == null or _is_key_locked(inventory, key):
			continue
		var placement: ItemGrid.Placement = grid.find_free_placement(item)
		if placement != null:
			return _move_resolution(item, key, placement.cell, placement.rotated)
	return Resolution.invalid(CommandResult.NO_SPACE)


## 제자리에서 회전하는 경우 (같은 칸, 반대 회전). 그리드 안의 아이템만 가능하고, 안 들어가면 null.
static func plan_rotate_in_place(inventory: Inventory, item_id: int, target_rotated: bool) -> MoveItemCommand:
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null or is_equipped(item) or _is_item_locked(inventory, item):
		return null
	var grid: ItemGrid = inventory.get_grid(item.container_key)
	if grid == null or not grid.can_place(item, item.position, target_rotated):
		return null
	return MoveItemCommand.new(item.id, item.container_key, item.position, target_rotated)


## 아이템을 지금 회전할 수 있는지 (정사각형·회전 불가 제외).
static func can_rotate(item: ItemInstance) -> bool:
	return item.def.can_rotate and item.def.width != item.def.height


static func is_equipped(item: ItemInstance) -> bool:
	return EquipmentSlots.slot_from_key(item.container_key) >= 0


# --- 내부 ---

static func _move_resolution(item: ItemInstance, key: StringName, cell: Vector2i,
		p_rotated: bool) -> Resolution:
	var move := Resolution.new()
	move.valid = true
	move.key = key
	move.cell = cell
	move.rotated = p_rotated
	if item.container_key == key and item.position == cell and item.rotated == p_rotated:
		return move
	move.kind = Kind.MOVE
	move.command = MoveItemCommand.new(item.id, key, cell, p_rotated)
	return move


static func _unequip_candidate_keys(inventory: Inventory, item: ItemInstance) -> Array[StringName]:
	var keys: Array[StringName] = [Inventory.STASH]
	if not item.def.is_container():
		for slot: EquipmentSlots.Slot in [EquipmentSlots.Slot.BACKPACK, EquipmentSlots.Slot.RIG]:
			var holder: ItemInstance = inventory.equipment.get_item(slot)
			if holder == null or holder == item:
				continue
			for i: int in range(holder.grids.size()):
				keys.append(Inventory.item_grid_key(holder.id, i))
	for i: int in range(Inventory.POCKET_COUNT):
		keys.append(Inventory.pocket_key(i))
	return keys


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
