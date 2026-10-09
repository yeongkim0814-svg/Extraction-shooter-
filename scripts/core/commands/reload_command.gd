class_name ReloadCommand
extends GameCommand
## 장착한 무기의 탄창을 몸에 지닌 같은 구경 탄약으로 채운다.
## 탄약을 찾는 순서: 조끼(군장) → 주머니 → 배낭. 스태시·보안 컨테이너는 쓰지 않는다.
## 탄종이 섞여도 된다 (탄창이 한 발씩 기록). 모든 검증을 먼저 끝낸 뒤 적용한다.

const WEAPON_SLOTS: Array[EquipmentSlots.Slot] = [
	EquipmentSlots.Slot.PRIMARY_1, EquipmentSlots.Slot.PRIMARY_2, EquipmentSlots.Slot.SECONDARY]

var weapon_item_id: int


func _init(p_weapon_item_id: int) -> void:
	weapon_item_id = p_weapon_item_id


func execute(authority: GameAuthority) -> CommandResult:
	var inv: Inventory = authority.inventory
	var weapon: ItemInstance = inv.get_item(weapon_item_id)
	if weapon == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	if weapon.magazine == null:
		return CommandResult.failure(CommandResult.NOT_A_WEAPON)
	if not _is_equipped(inv, weapon):
		return CommandResult.failure(CommandResult.WEAPON_NOT_EQUIPPED)
	var mag: Magazine = weapon.magazine
	var needed: int = mag.capacity - mag.count()
	if needed <= 0:
		return CommandResult.failure(CommandResult.MAGAZINE_FULL)
	if authority.content == null:
		return CommandResult.failure(CommandResult.NO_AMMO)

	# 계획: (탄약 아이템, 가져갈 수량)
	var plan_items: Array[ItemInstance] = []
	var plan_amounts: Array[int] = []
	for key: StringName in search_keys(inv):
		for item: ItemInstance in _row_major(inv.get_grid(key).get_items()):
			if needed <= 0:
				break
			var ammo: AmmoDef = authority.content.get_ammo(item.def.id)
			if ammo == null or ammo.caliber != mag.caliber:
				continue
			var take: int = mini(item.stack_count, needed)
			plan_items.append(item)
			plan_amounts.append(take)
			needed -= take
	if plan_items.is_empty():
		return CommandResult.failure(CommandResult.NO_AMMO)

	var events: Array[DomainEvent] = []
	for i: int in range(plan_items.size()):
		var item: ItemInstance = plan_items[i]
		mag.load_rounds(authority.content.get_ammo(item.def.id), plan_amounts[i])
		events.append_array(inv.consume(item.id, plan_amounts[i]).events)
	events.append(DomainEvent.new(DomainEvent.MAGAZINE_CHANGED,
			{"item_id": weapon.id, "count": mag.count()}))
	return CommandResult.success(events)


## 탄약을 찾을 그리드 키 (조끼 → 주머니 → 배낭 순).
static func search_keys(inv: Inventory) -> Array[StringName]:
	var keys: Array[StringName] = []
	var rig: ItemInstance = inv.equipment.get_item(EquipmentSlots.Slot.RIG)
	if rig != null:
		for i: int in range(rig.grids.size()):
			keys.append(Inventory.item_grid_key(rig.id, i))
	for i: int in range(Inventory.POCKET_COUNT):
		keys.append(Inventory.pocket_key(i))
	var pack: ItemInstance = inv.equipment.get_item(EquipmentSlots.Slot.BACKPACK)
	if pack != null:
		for i: int in range(pack.grids.size()):
			keys.append(Inventory.item_grid_key(pack.id, i))
	return keys


static func _is_equipped(inv: Inventory, weapon: ItemInstance) -> bool:
	for slot: EquipmentSlots.Slot in WEAPON_SLOTS:
		if inv.equipment.get_item(slot) == weapon:
			return true
	return false


static func _row_major(items: Array[ItemInstance]) -> Array[ItemInstance]:
	var sorted: Array[ItemInstance] = items.duplicate()
	sorted.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	return sorted
