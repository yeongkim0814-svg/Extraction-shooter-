class_name CombatLoadout
extends RefCounted
## 전투 테스트용 로드아웃: 소총(연사)·샷건(단발)·권총(단발)을 장착하고 탄창을 채우며,
## 조끼에 예비 탄약을 넣는다. 스태시 없음. 콘텐츠(탄종 정의)가 들어간 LocalAuthority를 만든다.

const AMMO_556: StringName = &"ammo_556_fmj"
const AMMO_9MM: StringName = &"ammo_9mm"
const AMMO_12GA: StringName = &"ammo_12ga_buck"


static func build() -> LocalAuthority:
	var authority := LocalAuthority.new(Inventory.new(Vector2i.ZERO))
	var content := ContentDatabase.new()
	authority.content = content

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
			EquipmentSlots.Slot.PRIMARY_1, 30,
			{WeaponStats.FIRE_RATE: 600.0, WeaponStats.AUTO: 1.0, WeaponStats.DAMAGE_MULT: 1.0,
			WeaponStats.RECOIL: 30.0, WeaponStats.SPREAD: 1.2, WeaponStats.RANGE: 200.0})
	_weapon(authority, content, a12, &"shotgun", "샷건", ItemDef.Category.WEAPON, Vector2i(5, 2),
			EquipmentSlots.Slot.PRIMARY_2, 6,
			{WeaponStats.FIRE_RATE: 70.0, WeaponStats.AUTO: 0.0, WeaponStats.DAMAGE_MULT: 1.0,
			WeaponStats.RECOIL: 80.0, WeaponStats.SPREAD: 4.0, WeaponStats.RANGE: 60.0})
	_weapon(authority, content, a9, &"pistol", "권총", ItemDef.Category.PISTOL, Vector2i(2, 1),
			EquipmentSlots.Slot.SECONDARY, 15,
			{WeaponStats.FIRE_RATE: 400.0, WeaponStats.AUTO: 0.0, WeaponStats.DAMAGE_MULT: 1.0,
			WeaponStats.RECOIL: 20.0, WeaponStats.SPREAD: 1.5, WeaponStats.RANGE: 100.0})
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
	content.add_item(def)
	var result: CommandResult = authority.inventory.add_item(authority.create_item(def, count), key, cell, false)
	assert(result.ok, "loadout ammo placement failed: %s" % ammo.id)


static func _weapon(authority: LocalAuthority, content: ContentDatabase, ammo: AmmoDef, id: StringName,
		display_name: String, category: ItemDef.Category, size: Vector2i, slot: EquipmentSlots.Slot,
		capacity: int, stats: Dictionary[StringName, float]) -> void:
	var def: ItemDef = _item(id, display_name, category, size.x, size.y, 1)
	content.add_item(def)
	var item: ItemInstance = authority.create_item(def)
	var receiver: WeaponPartDef = WeaponPartDef.create(StringName(String(id) + "_receiver"), &"receiver")
	receiver.base_stats = stats
	content.add_part(receiver)
	item.weapon = WeaponAssembly.new(receiver)
	item.magazine = Magazine.new(ammo.caliber, capacity)
	item.magazine.load_rounds(ammo, capacity)
	var result: CommandResult = authority.inventory.add_equipped(item, slot)
	assert(result.ok, "loadout weapon equip failed: %s" % id)
