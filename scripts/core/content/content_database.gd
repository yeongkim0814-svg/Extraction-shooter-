class_name ContentDatabase
extends RefCounted
## 데이터 정의(아이템·무기 부품·탄종)를 id로 찾는 저장소. 저장 데이터 로드와 네트워크 동기화에서 id → 정의 변환에 쓴다.

var _items: Dictionary[StringName, ItemDef] = {}
var _parts: Dictionary[StringName, WeaponPartDef] = {}
var _ammo: Dictionary[StringName, AmmoDef] = {}


func add_item(def: ItemDef) -> void:
	assert(def.id != &"" and not _items.has(def.id), "duplicate or empty item id: %s" % def.id)
	_items[def.id] = def


func add_part(def: WeaponPartDef) -> void:
	assert(def.id != &"" and not _parts.has(def.id), "duplicate or empty part id: %s" % def.id)
	_parts[def.id] = def


func add_ammo(def: AmmoDef) -> void:
	assert(def.id != &"" and not _ammo.has(def.id), "duplicate or empty ammo id: %s" % def.id)
	_ammo[def.id] = def


func get_item(id: StringName) -> ItemDef:
	return _items.get(id)


func get_part(id: StringName) -> WeaponPartDef:
	return _parts.get(id)


func get_ammo(id: StringName) -> AmmoDef:
	return _ammo.get(id)
