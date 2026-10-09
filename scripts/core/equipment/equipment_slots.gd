class_name EquipmentSlots
extends RefCounted
## 플레이어 장비 슬롯. 슬롯마다 허용 카테고리가 정해져 있고 한 칸에 아이템 1개.
## 화면 표기: PRIMARY_1 = ON SLING, PRIMARY_2 = ON BACK, SECONDARY = HOLSTER, MELEE = SHEATH.
## 슬롯 키(저장 데이터)는 enum 이름에서 만들어지므로 이름을 바꾸지 말고 새 슬롯은 끝에 추가한다.

enum Slot {
	PRIMARY_1,
	PRIMARY_2,
	SECONDARY,
	HELMET,
	ARMOR,
	RIG,
	BACKPACK,
	SECURE_CONTAINER,
	MELEE,
	FACE,
	EAR,
	EYE,
}

const _ACCEPTS: Dictionary[Slot, ItemDef.Category] = {
	Slot.PRIMARY_1: ItemDef.Category.WEAPON,
	Slot.PRIMARY_2: ItemDef.Category.WEAPON,
	Slot.SECONDARY: ItemDef.Category.PISTOL,
	Slot.HELMET: ItemDef.Category.HELMET,
	Slot.ARMOR: ItemDef.Category.ARMOR,
	Slot.RIG: ItemDef.Category.RIG,
	Slot.BACKPACK: ItemDef.Category.BACKPACK,
	Slot.SECURE_CONTAINER: ItemDef.Category.SECURE_CONTAINER,
	Slot.MELEE: ItemDef.Category.MELEE,
	Slot.FACE: ItemDef.Category.FACE_COVER,
	Slot.EAR: ItemDef.Category.HEADSET,
	Slot.EYE: ItemDef.Category.EYEWEAR,
}

var _equipped: Dictionary[Slot, ItemInstance] = {}


static func key_of(slot: Slot) -> StringName:
	return StringName("slot_" + String(Slot.keys()[slot]).to_lower())


## 슬롯 키(&"slot_rig" 등)를 슬롯으로. 슬롯 키가 아니면 -1.
static func slot_from_key(key: StringName) -> int:
	for slot: Slot in _ACCEPTS:
		if key_of(slot) == key:
			return slot
	return -1


static func accepts(slot: Slot, def: ItemDef) -> bool:
	return _ACCEPTS[slot] == def.category


func get_item(slot: Slot) -> ItemInstance:
	return _equipped.get(slot)


func get_all() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	result.assign(_equipped.values())
	return result


func try_equip(item: ItemInstance, slot: Slot) -> bool:
	if _equipped.has(slot) or not accepts(slot, item.def):
		return false
	_equipped[slot] = item
	return true


func unequip(slot: Slot) -> ItemInstance:
	var item: ItemInstance = _equipped.get(slot)
	_equipped.erase(slot)
	return item
