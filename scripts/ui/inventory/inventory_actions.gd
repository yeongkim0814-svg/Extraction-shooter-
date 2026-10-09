class_name InventoryActions
extends RefCounted
## 선택한 아이템에 대해 액션 바에 어떤 버튼을 보여 줄지 정하는 순수 로직.

enum Action { ROTATE, INFO, SPLIT, EQUIP, UNEQUIP, SELL, DISCARD, MOD }

## 판매(상인) 기능이 생기면 true로 바꾸면 버튼이 나타난다 (M6 이후). 실제 판매 명령은 그때 연결한다.
const SELL_ENABLED: bool = false


class Entry:
	var action: Action
	## false면 버튼은 보이지만 눌러도 동작하지 않는다 (회색).
	var enabled: bool = true

	func _init(p_action: Action, p_enabled: bool = true) -> void:
		action = p_action
		enabled = p_enabled


## 보여 줄 버튼 목록 (표시 순서). 아이템이 없으면 빈 배열.
static func for_item(inventory: Inventory, item_id: int) -> Array[Entry]:
	var entries: Array[Entry] = []
	var item: ItemInstance = inventory.get_item(item_id)
	if item == null:
		return entries
	entries.append(Entry.new(Action.ROTATE))
	entries.append(Entry.new(Action.INFO))
	if item.weapon != null:
		# 부품 트리가 있는 무기: 모딩 화면. 레이드 중 잠긴 스태시 안의 무기는 만질 수 없다.
		entries.append(Entry.new(Action.MOD, not inventory.is_locked(item)))
	if item.stack_count > 1:
		entries.append(Entry.new(Action.SPLIT, DropResolver.plan_split(inventory, item_id) != null))
	if DropResolver.is_equipped(item):
		entries.append(Entry.new(Action.UNEQUIP, DropResolver.plan_unequip(inventory, item_id).valid))
	elif DropResolver.plan_equip(inventory, item_id).valid:
		entries.append(Entry.new(Action.EQUIP))
	if SELL_ENABLED and item.def.tradeable:
		entries.append(Entry.new(Action.SELL))
	entries.append(Entry.new(Action.DISCARD))
	return entries


static func has_action(entries: Array[Entry], action: Action) -> bool:
	for entry: Entry in entries:
		if entry.action == action:
			return true
	return false
