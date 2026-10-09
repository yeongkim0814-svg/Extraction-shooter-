class_name CombatLoadout
extends RefCounted
## 전투 테스트용 로드아웃: 소총(연사)·샷건(단발)·권총(단발)을 장착하고 탄창을 채우며,
## 조끼에 예비 탄약을, 조끼·배낭·주머니에 모딩용 여분 부품을 넣는다. 스태시 없음.
## 콘텐츠(탄종·무기 부품 정의)가 들어간 LocalAuthority를 만든다. 부품 정의는 DemoWeapons.

const AMMO_556: StringName = &"ammo_556_fmj"
const AMMO_9MM: StringName = &"ammo_9mm"
const AMMO_12GA: StringName = &"ammo_12ga_buck"


static func build() -> LocalAuthority:
	var authority := LocalAuthority.new(Inventory.new(Vector2i.ZERO))
	var content := ContentDatabase.new()
	authority.content = content
	DemoWeapons.register(content)

	var a556: AmmoDef = AmmoDef.create(AMMO_556, &"5.56", 45.0, 30.0)
	var a9: AmmoDef = AmmoDef.create(AMMO_9MM, &"9mm", 35.0, 15.0)
	var a12: AmmoDef = AmmoDef.create(AMMO_12GA, &"12ga", 12.0, 5.0)
	a12.projectile_count = 8
	for ammo: AmmoDef in [a556, a9, a12]:
		content.add_ammo(ammo)

	var rig_def: ItemDef = _item(&"combat_rig", "전술 조끼", ItemDef.Category.RIG, 3, 2, 1)
	rig_def.grids = [Vector2i(4, 2)]
	var rig: ItemInstance = authority.create_item(rig_def)
	authority.inventory.add_equipped(rig, EquipmentSlots.Slot.RIG)
	var rig_grid: StringName = Inventory.item_grid_key(rig.id, 0)
	_stack(authority, content, a556, "5.56 FMJ", 60, rig_grid, Vector2i(0, 0))
	_stack(authority, content, a9, "9mm", 30, rig_grid, Vector2i(1, 0))
	_stack(authority, content, a12, "12ga 벅샷", 16, rig_grid, Vector2i(2, 0))

	_weapon(authority, content, a556, &"rifle", "소총", ItemDef.Category.WEAPON, Vector2i(5, 2),
			EquipmentSlots.Slot.PRIMARY_1, 30)
	_weapon(authority, content, a12, &"shotgun", "샷건", ItemDef.Category.WEAPON, Vector2i(5, 2),
			EquipmentSlots.Slot.PRIMARY_2, 6)
	_weapon(authority, content, a9, &"pistol", "권총", ItemDef.Category.PISTOL, Vector2i(2, 1),
			EquipmentSlots.Slot.SECONDARY, 15)
	_spare_parts(authority, content)
	return authority


static func _item(id: StringName, display_name: String, category: ItemDef.Category,
		width: int, height: int, max_stack: int) -> ItemDef:
	var def: ItemDef = ItemDef.create(id, width, height, max_stack)
	def.display_name = display_name
	def.category = category
	return def


static func _stack(authority: LocalAuthority, content: ContentDatabase, ammo: AmmoDef,
		display_name: String, count: int, key: StringName, cell: Vector2i) -> void:
	var def: ItemDef = _item(ammo.id, display_name, ItemDef.Category.AMMO, 1, 1, 60)
	def.base_price = 60   # 레이드에서 주운 탄약도 반출 가치가 있다
	content.add_item(def)
	var result: CommandResult = authority.inventory.add_item(authority.create_item(def, count), key, cell, false)
	assert(result.ok, "loadout ammo placement failed: %s" % ammo.id)


static func _weapon(authority: LocalAuthority, content: ContentDatabase, ammo: AmmoDef, id: StringName,
		display_name: String, category: ItemDef.Category, size: Vector2i, slot: EquipmentSlots.Slot,
		capacity: int) -> void:
	var def: ItemDef = _item(id, display_name, category, size.x, size.y, 1)
	content.add_item(def)
	var item: ItemInstance = authority.create_item(def)
	item.weapon = DemoWeapons.assemble(content, id)
	item.magazine = Magazine.new(ammo.caliber, capacity)
	item.magazine.load_rounds(ammo, capacity)
	var result: CommandResult = authority.inventory.add_equipped(item, slot)
	assert(result.ok, "loadout weapon equip failed: %s" % id)


## 모딩 시험용 여분 부품: 배낭(5×4)에 대부분, 조끼 남는 칸과 주머니에 몇 개. 소총 기준 모두 달아 볼 수 있다.
static func _spare_parts(authority: LocalAuthority, content: ContentDatabase) -> void:
	var pack_def: ItemDef = _item(&"combat_pack", "배낭", ItemDef.Category.BACKPACK, 4, 5, 1)
	pack_def.grids = [Vector2i(5, 4)]
	var pack: ItemInstance = authority.create_item(pack_def)
	authority.inventory.add_equipped(pack, EquipmentSlots.Slot.BACKPACK)
	var rig: ItemInstance = authority.inventory.equipment.get_item(EquipmentSlots.Slot.RIG)
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var rig_key: StringName = Inventory.item_grid_key(rig.id, 0)
	var everywhere: Array[StringName] = [pack_key, rig_key]
	for i: int in range(Inventory.POCKET_COUNT):
		everywhere.append(Inventory.pocket_key(i))
	# 부품 목록(DemoWeapons.spare_part_ids)과 같은 순서: 긴 총열·수직 손잡이·접이식 개머리판·4배율 조준경 = 배낭,
	# 소음기 = 조끼 남는 칸, 두 번째 소음기 = 배낭, 레드 도트 = 마지막 주머니
	var targets: Array[StringName] = [pack_key, pack_key, pack_key, pack_key, rig_key, pack_key,
			Inventory.pocket_key(3)]
	var ids: Array[StringName] = DemoWeapons.spare_part_ids()
	for i: int in range(ids.size()):
		var item: ItemInstance = authority.create_item(content.get_item(ids[i]))
		var keys: Array[StringName] = [targets[i]]
		keys.append_array(everywhere)
		var result: CommandResult = authority.inventory.auto_add_item(item, keys)
		assert(result.ok, "loadout spare part placement failed: %s" % ids[i])
