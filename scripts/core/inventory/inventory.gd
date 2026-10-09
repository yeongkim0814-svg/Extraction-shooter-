class_name Inventory
extends RefCounted
## 플레이어 한 명의 소지품 전체: 스태시(은신처에서만)·주머니·장비 슬롯, 그리고 컨테이너 아이템의 내부 그리드.
## 모든 변경은 검증을 먼저 끝낸 뒤 적용하므로 원자적이다: 실패하면 아무것도 바뀌지 않는다.
##
## 컨테이너 키
##   그리드: &"stash", &"pocket_0"~&"pocket_3", &"item_<아이템 id>_<그리드 번호>"
##   슬롯:   EquipmentSlots.key_of(slot)  (예: &"slot_backpack")
##   외부:   &"loot_<번호>"  시체·상자 등 월드 컨테이너. 열려 있는 동안만 루트 그리드로 붙는다 (attach_external).
##
## 중첩 규칙: 내부 그리드를 가진 아이템(배낭·리그 등)은 다른 아이템의 그리드에 넣을 수 없다.
## 이 규칙 하나로 "배낭 안 배낭"과 "자기 자신 안에 넣기"가 모두 막힌다.

const STASH := &"stash"
const POCKET_COUNT := 4
const EXTERNAL_PREFIX := "loot_"

var equipment := EquipmentSlots.new()
## 레이드 중에는 true: 스태시(와 그 안의 컨테이너 내용물)에 넣기·꺼내기·변경이 모두 막힌다.
var stash_locked: bool = false
var _root_grids: Dictionary[StringName, ItemGrid] = {}
## 이 인벤토리 어딘가에 들어 있는 모든 아이템 (중첩 포함).
var _items: Dictionary[int, ItemInstance] = {}
## 열려 있는 외부 컨테이너의 수색 상태 (수색이 필요한 컨테이너만).
var _searches: Dictionary[StringName, SearchState] = {}


## stash_size가 0이면 스태시 없음 (레이드 중).
func _init(stash_size: Vector2i = Vector2i.ZERO) -> void:
	if stash_size.x > 0 and stash_size.y > 0:
		_root_grids[STASH] = ItemGrid.new(stash_size.x, stash_size.y)
	for i: int in range(POCKET_COUNT):
		_root_grids[pocket_key(i)] = ItemGrid.new(1, 1)


static func pocket_key(index: int) -> StringName:
	return StringName("pocket_%d" % index)


static func item_grid_key(item_id: int, index: int) -> StringName:
	return StringName("item_%d_%d" % [item_id, index])


static func external_key(number: int) -> StringName:
	return StringName(EXTERNAL_PREFIX + str(number))


## 정규 형태의 외부 컨테이너 키인지 (&"loot_7"; &"loot_07"·&"loot_-1"은 아님).
static func is_external_key(key: StringName) -> bool:
	var text := String(key)
	if not text.begins_with(EXTERNAL_PREFIX):
		return false
	var number: String = text.substr(EXTERNAL_PREFIX.length())
	return number.is_valid_int() and number.to_int() > 0 and str(number.to_int()) == number


## 지금 붙어 있는 외부 컨테이너 키 목록.
func external_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for key: StringName in _root_grids:
		if is_external_key(key):
			keys.append(key)
	return keys


# --- 조회 ---

func get_item(item_id: int) -> ItemInstance:
	return _items.get(item_id)


func get_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	result.assign(_items.values())
	return result


func get_grid(key: StringName) -> ItemGrid:
	if _root_grids.has(key):
		return _root_grids[key]
	var parsed: Vector2i = _parse_item_grid_key(key)
	if parsed.x < 0:
		return null
	var owner: ItemInstance = _items.get(parsed.x)
	if owner == null or parsed.y >= owner.grids.size():
		return null
	return owner.grids[parsed.y]


## 현재 접근 가능한 모든 그리드 키 (루트 그리드 → 컨테이너 아이템 그리드 순).
func grid_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(_root_grids.keys())
	for item: ItemInstance in _items.values():
		for i: int in range(item.grids.size()):
			keys.append(item_grid_key(item.id, i))
	return keys


# --- 변경 ---

## 새 아이템(이 인벤토리에 없던 것)을 그리드의 지정 위치에 넣는다. 내부 내용물도 함께 등록된다.
func add_item(item: ItemInstance, key: StringName, cell: Vector2i, p_rotated: bool) -> CommandResult:
	if _items.has(item.id):
		return CommandResult.failure(CommandResult.ALREADY_ADDED)
	if _has_nested_container(item):
		return CommandResult.failure(CommandResult.NESTING_NOT_ALLOWED)
	var error: StringName = _check_grid_target(item, key)
	if error != &"":
		return CommandResult.failure(error)
	if not get_grid(key).try_place(item, cell, p_rotated):
		return CommandResult.failure(CommandResult.NO_SPACE)
	item.container_key = key
	_register(item)
	_mark_entered(item)
	return CommandResult.success(_events_added(item))


## 새 아이템을 keys 순서대로 첫 빈 자리에 넣는다 (루팅 시 주머니 → 리그 → 배낭 등).
func auto_add_item(item: ItemInstance, keys: Array[StringName]) -> CommandResult:
	if _items.has(item.id):
		return CommandResult.failure(CommandResult.ALREADY_ADDED)
	for key: StringName in keys:
		if _check_grid_target(item, key) != &"":
			continue
		var placement: ItemGrid.Placement = get_grid(key).find_free_placement(item)
		if placement != null:
			return add_item(item, key, placement.cell, placement.rotated)
	return CommandResult.failure(CommandResult.NO_SPACE)


## 새 아이템을 장비 슬롯에 바로 넣는다 (로드아웃 생성용).
func add_equipped(item: ItemInstance, slot: EquipmentSlots.Slot) -> CommandResult:
	if _items.has(item.id):
		return CommandResult.failure(CommandResult.ALREADY_ADDED)
	if _has_nested_container(item):
		return CommandResult.failure(CommandResult.NESTING_NOT_ALLOWED)
	var error: StringName = _check_slot_target(item, slot)
	if error != &"":
		return CommandResult.failure(error)
	equipment.try_equip(item, slot)
	item.container_key = EquipmentSlots.key_of(slot)
	_register(item)
	return CommandResult.success(_events_added(item))


## 인벤토리 안의 아이템을 그리드의 지정 위치로 옮긴다 (같은 그리드·다른 그리드·슬롯에서 꺼내기 모두).
func move_item(item_id: int, key: StringName, cell: Vector2i, p_rotated: bool) -> CommandResult:
	var item: ItemInstance = get_item(item_id)
	if item == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	var access: StringName = _access_error(item)
	if access != &"":
		return CommandResult.failure(access)
	var error: StringName = _check_grid_target(item, key)
	if error != &"":
		return CommandResult.failure(error)
	var target: ItemGrid = get_grid(key)
	var from: Dictionary = _location_of(item)
	if item.container_key == key:
		if not target.move(item, cell, p_rotated):
			return CommandResult.failure(CommandResult.NO_SPACE)
	else:
		# 원래 자리를 비워도 다른 그리드의 배치 가능 여부는 바뀌지 않으므로 먼저 검증하고 적용한다.
		if not target.can_place(item, cell, p_rotated):
			return CommandResult.failure(CommandResult.NO_SPACE)
		_detach(item)
		target.try_place(item, cell, p_rotated)
		item.container_key = key
		_mark_entered(item)
	return CommandResult.success(_events_moved(item, from))


func equip(item_id: int, slot: EquipmentSlots.Slot) -> CommandResult:
	var item: ItemInstance = get_item(item_id)
	if item == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	var access: StringName = _access_error(item)
	if access != &"":
		return CommandResult.failure(access)
	if equipment.get_item(slot) == item:
		return CommandResult.success()
	var error: StringName = _check_slot_target(item, slot)
	if error != &"":
		return CommandResult.failure(error)
	var from: Dictionary = _location_of(item)
	_detach(item)
	equipment.try_equip(item, slot)
	item.container_key = EquipmentSlots.key_of(slot)
	return CommandResult.success(_events_moved(item, from))


## source 스택을 target 스택에 합친다. source가 비면 인벤토리에서 사라진다.
func merge(source_id: int, target_id: int) -> CommandResult:
	var source: ItemInstance = get_item(source_id)
	var target: ItemInstance = get_item(target_id)
	if source == null or target == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	var access: StringName = _access_error(source)
	if access == &"":
		access = _access_error(target)
	if access != &"":
		return CommandResult.failure(access)
	if not source.can_stack_with(target):
		return CommandResult.failure(CommandResult.NOT_STACKABLE)
	var amount: int = mini(source.stack_count, target.free_stack_space())
	if amount <= 0:
		return CommandResult.failure(CommandResult.NO_SPACE)
	target.stack_count += amount
	source.stack_count -= amount
	var events: Array[DomainEvent] = [_event_stack(target)]
	if source.stack_count == 0:
		events.append_array(_remove(source))
	else:
		events.append(_event_stack(source))
	return CommandResult.success(events)


## item에서 amount만큼 떼어 new_id 스택으로 만들어 지정 위치에 넣는다.
func split(item_id: int, amount: int, new_id: int, key: StringName, cell: Vector2i,
		p_rotated: bool) -> CommandResult:
	var item: ItemInstance = get_item(item_id)
	if item == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	var access: StringName = _access_error(item)
	if access != &"":
		return CommandResult.failure(access)
	if amount <= 0 or amount >= item.stack_count:
		return CommandResult.failure(CommandResult.INVALID_AMOUNT)
	var part := ItemInstance.new(new_id, item.def, amount)
	part.found_in_raid = item.found_in_raid
	var result: CommandResult = add_item(part, key, cell, p_rotated)
	if not result.ok:
		return result
	item.stack_count -= amount
	result.events.append(_event_stack(item))
	return result


## 스택에서 amount만큼 소비한다 (탄약 장전·약품 사용). 0이 되면 아이템이 사라진다.
func consume(item_id: int, amount: int) -> CommandResult:
	var item: ItemInstance = get_item(item_id)
	if item == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	var access: StringName = _access_error(item)
	if access != &"":
		return CommandResult.failure(access)
	if amount <= 0 or amount > item.stack_count:
		return CommandResult.failure(CommandResult.INVALID_AMOUNT)
	item.stack_count -= amount
	if item.stack_count == 0:
		return CommandResult.success(_remove(item))
	return CommandResult.success([_event_stack(item)])


## 아이템과 그 안의 내용물을 인벤토리에서 없앤다 (버리기·사망 소실·판매).
func discard(item_id: int) -> CommandResult:
	var item: ItemInstance = get_item(item_id)
	if item == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	var access: StringName = _access_error(item)
	if access != &"":
		return CommandResult.failure(access)
	return CommandResult.success(_remove(item))


## 아이템 모양을 바꾸는 변경(무기 부품 장착 등)을 그리드 공간을 검증하며 적용한다.
## apply()로 바꾼 뒤 같은 자리에 들어가지 않으면 revert()로 되돌리고 false. 슬롯에 있으면 항상 적용.
func try_reshape(item_id: int, apply: Callable, revert: Callable) -> bool:
	var item: ItemInstance = get_item(item_id)
	if item == null:
		return false
	var grid: ItemGrid = get_grid(item.container_key)
	if grid == null:
		apply.call()
		return true
	var cell: Vector2i = item.position
	var was_rotated: bool = item.rotated
	grid.remove(item)
	apply.call()
	if grid.try_place(item, cell, was_rotated):
		return true
	revert.call()
	grid.try_place(item, cell, was_rotated)
	return false


## 외부 컨테이너(시체·상자)의 그리드를 루트 그리드로 붙인다. 안의 아이템이 등록되어 일반 이동 명령으로 옮길 수 있다.
## 그리드 객체는 월드(권한자)가 계속 소유하므로, 떼어 낸 뒤에도 남은 아이템은 그리드에 그대로 있다.
## search가 있으면 공개되지 않은 아이템은 옮기기·장착·합치기 등이 NOT_REVEALED로 막힌다.
func attach_external(key: StringName, grid: ItemGrid, search: SearchState = null) -> CommandResult:
	if not is_external_key(key) or grid == null:
		return CommandResult.failure(CommandResult.UNKNOWN_CONTAINER)
	if _root_grids.has(key):
		return CommandResult.failure(CommandResult.ALREADY_ADDED)
	for item: ItemInstance in grid.get_items():
		if _has_nested_container(item):
			return CommandResult.failure(CommandResult.NESTING_NOT_ALLOWED)
		if _contains_registered(item):
			return CommandResult.failure(CommandResult.ALREADY_ADDED)
	_root_grids[key] = grid
	if search != null:
		_searches[key] = search
	for item: ItemInstance in grid.get_items():
		item.container_key = key
		_register(item)
	return CommandResult.success([DomainEvent.new(DomainEvent.CONTAINER_OPENED, {"container": key})])


## 외부 컨테이너를 뗀다. 남은 아이템은 등록만 풀리고 그리드(와 위치)는 그대로 남는다.
func detach_external(key: StringName) -> CommandResult:
	if not is_external_key(key) or not _root_grids.has(key):
		return CommandResult.failure(CommandResult.UNKNOWN_CONTAINER)
	var removed_ids: Array[int] = []
	for item: ItemInstance in _root_grids[key].get_items():
		_unregister(item, removed_ids)
	_root_grids.erase(key)
	_searches.erase(key)
	return CommandResult.success([DomainEvent.new(DomainEvent.CONTAINER_CLOSED,
			{"container": key, "removed_ids": removed_ids})])


## 레이드 중 스태시 잠금에 걸리는 아이템인지 (명령 검증용).
func is_locked(item: ItemInstance) -> bool:
	return _is_locked(item)


## 아이템을 건드릴 수 없는 이유 코드 (STASH_LOCKED·NOT_REVEALED). 건드릴 수 있으면 &"".
func access_error(item: ItemInstance) -> StringName:
	return _access_error(item)


## 수색이 끝나지 않아 아직 "?"인 아이템인지 (외부 컨테이너에 직접 들어 있고 공개 전).
func is_hidden(item: ItemInstance) -> bool:
	var search: SearchState = _searches.get(item.container_key)
	return search != null and not search.is_revealed(item)


# --- 불변식 ---

## 모든 그리드가 일관되고, 등록된 아이템 = 그리드·슬롯을 따라가며 찾은 아이템이며,
## 각 아이템의 container_key가 실제 위치와 일치하는지 검사한다 (테스트·디버그용).
func is_consistent() -> bool:
	var found: Dictionary[int, bool] = {}
	for key: StringName in grid_keys():
		var grid: ItemGrid = get_grid(key)
		if not grid.is_consistent():
			return false
		for item: ItemInstance in grid.get_items():
			if item.container_key != key or found.has(item.id) or get_item(item.id) != item:
				return false
			found[item.id] = true
	for slot: int in EquipmentSlots.Slot.values():
		var item: ItemInstance = equipment.get_item(slot as EquipmentSlots.Slot)
		if item == null:
			continue
		if item.container_key != EquipmentSlots.key_of(slot as EquipmentSlots.Slot) \
				or found.has(item.id) or get_item(item.id) != item:
			return false
		found[item.id] = true
	return found.size() == _items.size()


# --- 내부 ---

func _check_grid_target(item: ItemInstance, key: StringName) -> StringName:
	if get_grid(key) == null:
		return CommandResult.UNKNOWN_CONTAINER
	if stash_locked and _root_container_of_key(key) == STASH:
		return CommandResult.STASH_LOCKED
	if item.def.is_container() and _parse_item_grid_key(key).x >= 0:
		return CommandResult.NESTING_NOT_ALLOWED
	return &""


## 미리 채워진 컨테이너(루팅 스폰 등)가 중첩 규칙을 어기는 내용물을 갖고 있는지.
func _has_nested_container(item: ItemInstance) -> bool:
	for grid: ItemGrid in item.grids:
		for child: ItemInstance in grid.get_items():
			if child.def.is_container():
				return true
	return false


## 키가 가리키는 컨테이너를 따라 올라가 최상위 컨테이너 키(스태시·주머니·슬롯)를 돌려준다.
func _root_container_of_key(key: StringName) -> StringName:
	var current: StringName = key
	for _depth: int in range(8):
		var parsed: Vector2i = _parse_item_grid_key(current)
		if parsed.x < 0:
			return current
		var owner: ItemInstance = _items.get(parsed.x)
		if owner == null:
			return &""
		current = owner.container_key
	return &""


func _access_error(item: ItemInstance) -> StringName:
	if _is_locked(item):
		return CommandResult.STASH_LOCKED
	if is_hidden(item):
		return CommandResult.NOT_REVEALED
	return &""


## 플레이어가 수색 대상 컨테이너에 직접 넣은 아이템은 바로 공개 처리한다.
func _mark_entered(item: ItemInstance) -> void:
	var search: SearchState = _searches.get(item.container_key)
	if search != null:
		search.mark_revealed(item)


func _is_locked(item: ItemInstance) -> bool:
	return stash_locked and _root_container_of_key(item.container_key) == STASH


func _check_slot_target(item: ItemInstance, slot: EquipmentSlots.Slot) -> StringName:
	if not EquipmentSlots.accepts(slot, item.def):
		return CommandResult.SLOT_NOT_ALLOWED
	if equipment.get_item(slot) != null:
		return CommandResult.SLOT_OCCUPIED
	return &""


func _parse_item_grid_key(key: StringName) -> Vector2i:
	var parts: PackedStringArray = String(key).split("_")
	if parts.size() != 3 or parts[0] != "item" \
			or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return Vector2i(-1, -1)
	var item_id: int = parts[1].to_int()
	var index: int = parts[2].to_int()
	# 정규 형태만 허용: 음수·앞자리 0("item_05_0") 등은 거부해 키 하나가 그리드 하나에만 대응하게 한다.
	if item_id <= 0 or index < 0 or str(item_id) != parts[1] or str(index) != parts[2]:
		return Vector2i(-1, -1)
	return Vector2i(item_id, index)


## 현재 컨테이너(그리드 또는 슬롯)에서 꺼낸다. 등록은 유지한다.
func _detach(item: ItemInstance) -> void:
	var slot: int = EquipmentSlots.slot_from_key(item.container_key)
	if slot >= 0:
		equipment.unequip(slot as EquipmentSlots.Slot)
	else:
		var grid: ItemGrid = get_grid(item.container_key)
		if grid != null:
			grid.remove(item)
	item.container_key = &""


## item 또는 그 내용물 중 이미 이 인벤토리에 등록된 id가 있는지.
func _contains_registered(item: ItemInstance) -> bool:
	if _items.has(item.id):
		return true
	for grid: ItemGrid in item.grids:
		for child: ItemInstance in grid.get_items():
			if _contains_registered(child):
				return true
	return false


func _register(item: ItemInstance) -> void:
	_items[item.id] = item
	for i: int in range(item.grids.size()):
		for child: ItemInstance in item.grids[i].get_items():
			child.container_key = item_grid_key(item.id, i)
			_register(child)


func _unregister(item: ItemInstance, removed_ids: Array[int]) -> void:
	_items.erase(item.id)
	removed_ids.append(item.id)
	for grid: ItemGrid in item.grids:
		for child: ItemInstance in grid.get_items():
			_unregister(child, removed_ids)


func _remove(item: ItemInstance) -> Array[DomainEvent]:
	var from: Dictionary = _location_of(item)
	_detach(item)
	var removed_ids: Array[int] = []
	_unregister(item, removed_ids)
	return [DomainEvent.new(DomainEvent.ITEM_REMOVED,
			{"item_id": item.id, "from": from, "removed_ids": removed_ids})]


func _location_of(item: ItemInstance) -> Dictionary:
	return {"container": item.container_key, "cell": item.position, "rotated": item.rotated}


func _events_added(item: ItemInstance) -> Array[DomainEvent]:
	return [DomainEvent.new(DomainEvent.ITEM_ADDED,
			{"item_id": item.id, "to": _location_of(item)})]


func _events_moved(item: ItemInstance, from: Dictionary) -> Array[DomainEvent]:
	return [DomainEvent.new(DomainEvent.ITEM_MOVED,
			{"item_id": item.id, "from": from, "to": _location_of(item)})]


func _event_stack(item: ItemInstance) -> DomainEvent:
	return DomainEvent.new(DomainEvent.STACK_CHANGED,
			{"item_id": item.id, "stack_count": item.stack_count})
