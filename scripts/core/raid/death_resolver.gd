class_name DeathResolver
extends RefCounted
## 사망 처리: 보안 컨테이너(와 그 내용물)·스태시를 뺀 장비와 주머니 아이템을 모두 잃는다.


## 없어진 모든 아이템 id를 반환한다 (컨테이너 내용물 포함).
static func resolve(inventory: Inventory) -> Array[int]:
	var lost: Array[int] = []
	for slot: int in EquipmentSlots.Slot.values():
		if slot == EquipmentSlots.Slot.SECURE_CONTAINER:
			continue
		var item: ItemInstance = inventory.equipment.get_item(slot as EquipmentSlots.Slot)
		if item != null:
			_discard(inventory, item.id, lost)
	for i: int in range(Inventory.POCKET_COUNT):
		var grid: ItemGrid = inventory.get_grid(Inventory.pocket_key(i))
		if grid == null:
			continue
		for item: ItemInstance in grid.get_items():
			_discard(inventory, item.id, lost)
	return lost


static func _discard(inventory: Inventory, item_id: int, lost: Array[int]) -> void:
	var result: CommandResult = inventory.discard(item_id)
	if not result.ok:
		return
	for event: DomainEvent in result.events:
		for removed: int in event.data.get("removed_ids", []):
			lost.append(removed)
