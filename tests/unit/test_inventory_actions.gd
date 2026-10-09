extends GutTest
## InventoryActions (M5): 선택한 아이템에 보여 줄 액션 버튼 판정.

const A := InventoryActions.Action

var _inv: Inventory
var _auth: LocalAuthority


func before_each() -> void:
	_inv = Inventory.new(Vector2i(10, 10))
	_auth = LocalAuthority.new(_inv)


func _def(id: StringName, category: ItemDef.Category, w: int, h: int, stack: int = 1) -> ItemDef:
	var def: ItemDef = ItemDef.create(id, w, h, stack)
	def.category = category
	return def


func _stash(def: ItemDef, cell: Vector2i, count: int = 1) -> ItemInstance:
	var item: ItemInstance = _auth.create_item(def, count)
	assert_true(_inv.add_item(item, Inventory.STASH, cell, false).ok)
	return item


func _actions(item: ItemInstance) -> Array[InventoryActions.Entry]:
	return InventoryActions.for_item(_inv, item.id)


func test_unknown_item_has_no_actions() -> void:
	assert_eq(InventoryActions.for_item(_inv, 4242).size(), 0)


func test_plain_item_gets_rotate_info_discard() -> void:
	var gpu: ItemInstance = _stash(_def(&"gpu", ItemDef.Category.VALUABLE, 2, 1), Vector2i.ZERO)
	var entries: Array[InventoryActions.Entry] = _actions(gpu)
	assert_true(InventoryActions.has_action(entries, A.ROTATE))
	assert_true(InventoryActions.has_action(entries, A.INFO))
	assert_true(InventoryActions.has_action(entries, A.DISCARD))
	assert_false(InventoryActions.has_action(entries, A.SPLIT))
	assert_false(InventoryActions.has_action(entries, A.EQUIP))
	assert_false(InventoryActions.has_action(entries, A.UNEQUIP))
	assert_false(InventoryActions.has_action(entries, A.SELL), "판매 버튼은 아직 숨김")
	assert_eq(entries[0].action, A.ROTATE)
	assert_eq(entries[entries.size() - 1].action, A.DISCARD)


func test_split_only_for_stacks_and_disabled_without_space() -> void:
	var ammo_def: ItemDef = _def(&"ammo", ItemDef.Category.AMMO, 1, 1, 60)
	var single: ItemInstance = _stash(ammo_def, Vector2i(0, 0), 1)
	assert_false(InventoryActions.has_action(_actions(single), A.SPLIT))
	var stack: ItemInstance = _stash(ammo_def, Vector2i(3, 3), 20)
	var split: InventoryActions.Entry = null
	for entry: InventoryActions.Entry in _actions(stack):
		if entry.action == A.SPLIT:
			split = entry
	assert_not_null(split)
	assert_true(split.enabled)
	# 1x1 주머니 안 스택은 나눌 자리가 없어 비활성
	var pocket_stack: ItemInstance = _auth.create_item(ammo_def, 10)
	assert_true(_inv.add_item(pocket_stack, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	for entry: InventoryActions.Entry in _actions(pocket_stack):
		if entry.action == A.SPLIT:
			assert_false(entry.enabled)


func test_equip_shown_only_when_a_compatible_slot_is_free() -> void:
	var pistol_def: ItemDef = _def(&"pistol", ItemDef.Category.PISTOL, 2, 1)
	var first: ItemInstance = _stash(pistol_def, Vector2i(0, 0))
	var second: ItemInstance = _stash(pistol_def, Vector2i(0, 2))
	assert_true(InventoryActions.has_action(_actions(first), A.EQUIP))
	assert_true(_auth.execute(DropResolver.plan_equip(_inv, first.id).command).ok)
	assert_false(InventoryActions.has_action(_actions(second), A.EQUIP), "권총집 사용 중")
	var entries: Array[InventoryActions.Entry] = _actions(first)
	assert_true(InventoryActions.has_action(entries, A.UNEQUIP))
	assert_false(InventoryActions.has_action(entries, A.EQUIP))


func test_unequip_disabled_without_room() -> void:
	var inv := Inventory.new()
	var auth := LocalAuthority.new(inv)
	var pistol: ItemInstance = auth.create_item(_def(&"pistol", ItemDef.Category.PISTOL, 2, 1))
	assert_true(inv.add_equipped(pistol, EquipmentSlots.Slot.SECONDARY).ok)
	# 스태시·배낭·리그 없음, 주머니는 1x1 → 자리 없음
	for entry: InventoryActions.Entry in InventoryActions.for_item(inv, pistol.id):
		if entry.action == A.UNEQUIP:
			assert_false(entry.enabled)
			return
	fail_test("UNEQUIP entry missing")


func _weapon_item(with_assembly: bool) -> ItemInstance:
	var item: ItemInstance = _stash(_def(&"rifle", ItemDef.Category.WEAPON, 5, 2), Vector2i.ZERO)
	if with_assembly:
		item.weapon = WeaponAssembly.new(WeaponPartDef.create(&"rifle_receiver", &"receiver"))
	return item


func test_weapon_with_assembly_gets_enabled_mod_button() -> void:
	var entries: Array[InventoryActions.Entry] = _actions(_weapon_item(true))
	assert_true(InventoryActions.has_action(entries, A.MOD))
	for entry: InventoryActions.Entry in entries:
		if entry.action == A.MOD:
			assert_true(entry.enabled)


func test_weapon_without_assembly_and_plain_items_have_no_mod_button() -> void:
	assert_false(InventoryActions.has_action(_actions(_weapon_item(false)), A.MOD))
	var gpu: ItemInstance = _stash(_def(&"gpu", ItemDef.Category.VALUABLE, 2, 1), Vector2i(0, 5))
	assert_false(InventoryActions.has_action(_actions(gpu), A.MOD))


func test_mod_button_sits_right_after_info_and_is_disabled_when_stash_is_locked() -> void:
	var rifle: ItemInstance = _weapon_item(true)
	var entries: Array[InventoryActions.Entry] = _actions(rifle)
	assert_eq(entries[1].action, A.INFO)
	assert_eq(entries[2].action, A.MOD)
	_inv.stash_locked = true
	for entry: InventoryActions.Entry in _actions(rifle):
		if entry.action == A.MOD:
			assert_false(entry.enabled, "레이드 중 잠긴 스태시의 무기는 모딩 불가")
