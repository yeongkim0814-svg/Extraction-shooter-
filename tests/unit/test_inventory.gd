extends GutTest
## Inventory 모델 테스트 (M2): 생성, 추가, 이동, 장착, 중첩 규칙, 병합, 분할, 버리기, 무작위 검증.

const STASH := Inventory.STASH
const Slot := EquipmentSlots.Slot

var _next_id: int = 1
var _ammo_def: ItemDef


func before_each() -> void:
	_next_id = 1
	_ammo_def = ItemDef.create(&"ammo", 1, 1, 30)


# --- 헬퍼 ---

func _make(def: ItemDef, stack: int = 1) -> ItemInstance:
	var item := ItemInstance.new(_next_id, def, stack)
	_next_id += 1
	return item


func _plain(w: int = 1, h: int = 1, def_id: StringName = &"plain") -> ItemInstance:
	return _make(ItemDef.create(def_id, w, h))


func _ammo(count: int) -> ItemInstance:
	return _make(_ammo_def, count)


func _container_def(category: ItemDef.Category, grid_sizes: Array[Vector2i], w: int = 2, h: int = 2) -> ItemDef:
	var def := ItemDef.create(&"container", w, h)
	def.category = category
	def.grids = grid_sizes
	return def


func _backpack(gw: int = 4, gh: int = 4) -> ItemInstance:
	var sizes: Array[Vector2i] = [Vector2i(gw, gh)]
	return _make(_container_def(ItemDef.Category.BACKPACK, sizes))


func _rig() -> ItemInstance:
	var sizes: Array[Vector2i] = [Vector2i(2, 1), Vector2i(2, 1)]
	return _make(_container_def(ItemDef.Category.RIG, sizes))


func _weapon() -> ItemInstance:
	var def := ItemDef.create(&"rifle", 4, 2)
	def.category = ItemDef.Category.WEAPON
	return _make(def)


func _helmet() -> ItemInstance:
	var def := ItemDef.create(&"helmet", 2, 2)
	def.category = ItemDef.Category.HELMET
	return _make(def)


func _inv(stash: Vector2i = Vector2i(10, 10)) -> Inventory:
	return Inventory.new(stash)


func _keys(list: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for key: Variant in list:
		result.append(StringName(key))
	return result


## 인벤토리 전체 상태를 비교 가능한 문자열 목록으로 만든다.
func _snapshot(inv: Inventory) -> Array[String]:
	var lines: Array[String] = []
	for item: ItemInstance in inv.get_items():
		lines.append("%d|%s|%s|%s|%d" % [item.id, item.container_key, item.position, item.rotated, item.stack_count])
	lines.sort()
	for slot: int in EquipmentSlots.Slot.values():
		var equipped: ItemInstance = inv.equipment.get_item(slot as Slot)
		lines.append("slot%d=%d" % [slot, equipped.id if equipped != null else 0])
	for key: StringName in inv.grid_keys():
		lines.append("grid:%s" % key)
	return lines


func _assert_failed(result: CommandResult, error: StringName, inv: Inventory, before: Array[String]) -> void:
	assert_false(result.ok, "should fail with %s" % error)
	assert_eq(result.error, error)
	assert_eq(_snapshot(inv), before, "failed operation must not change state")
	assert_true(inv.is_consistent())


func _stash_add(inv: Inventory, item: ItemInstance, cell: Vector2i = Vector2i.ZERO, rotated: bool = false) -> void:
	var result: CommandResult = inv.add_item(item, STASH, cell, rotated)
	assert_true(result.ok, "setup add_item failed: %s" % result.error)


# --- 생성 ---

func test_construct_with_stash() -> void:
	var inv := _inv(Vector2i(6, 8))
	var stash: ItemGrid = inv.get_grid(STASH)
	assert_not_null(stash)
	assert_eq(stash.width, 6)
	assert_eq(stash.height, 8)
	assert_true(inv.is_consistent())


func test_construct_without_stash() -> void:
	var inv := Inventory.new()
	assert_null(inv.get_grid(STASH))
	assert_eq(inv.grid_keys().size(), Inventory.POCKET_COUNT)
	var zero_width := Inventory.new(Vector2i(0, 5))
	assert_null(zero_width.get_grid(STASH))
	assert_true(inv.is_consistent())


func test_four_pockets_of_one_by_one() -> void:
	var inv := _inv()
	for i: int in range(4):
		var pocket: ItemGrid = inv.get_grid(Inventory.pocket_key(i))
		assert_not_null(pocket, "pocket %d" % i)
		assert_eq(pocket.width, 1)
		assert_eq(pocket.height, 1)
	assert_null(inv.get_grid(Inventory.pocket_key(4)))
	assert_eq(Inventory.pocket_key(2), &"pocket_2")


func test_unknown_grid_keys_return_null() -> void:
	var inv := _inv()
	assert_null(inv.get_grid(&"nope"))
	assert_null(inv.get_grid(&"item_99_0"))
	assert_null(inv.get_grid(&"item_x_0"))
	assert_null(inv.get_grid(&"item_1_2_3"))


func test_grid_keys_include_container_grids_only_while_present() -> void:
	var inv := _inv()
	var pack := _backpack()
	var base_count: int = inv.grid_keys().size()
	var key: StringName = Inventory.item_grid_key(pack.id, 0)
	assert_false(inv.grid_keys().has(key))
	assert_null(inv.get_grid(key))
	_stash_add(inv, pack)
	assert_true(inv.grid_keys().has(key))
	assert_eq(inv.grid_keys().size(), base_count + 1)
	assert_eq(inv.get_grid(key), pack.grids[0])
	assert_true(inv.discard(pack.id).ok)
	assert_false(inv.grid_keys().has(key))
	assert_null(inv.get_grid(key))
	assert_true(inv.is_consistent())


func test_rig_exposes_one_key_per_grid() -> void:
	var inv := _inv()
	var rig := _rig()
	_stash_add(inv, rig)
	assert_not_null(inv.get_grid(Inventory.item_grid_key(rig.id, 0)))
	assert_not_null(inv.get_grid(Inventory.item_grid_key(rig.id, 1)))
	assert_null(inv.get_grid(Inventory.item_grid_key(rig.id, 2)))


## 의심되는 버그: 음수 그리드 번호가 GDScript 음수 인덱스로 해석되어 마지막 그리드를 돌려준다.
func test_get_grid_rejects_negative_grid_index() -> void:
	var inv := _inv()
	var pack := _backpack()
	_stash_add(inv, pack)
	assert_null(inv.get_grid(StringName("item_%d_-1" % pack.id)))


# --- add_item ---

func test_add_item_success_and_event_payload() -> void:
	var inv := _inv()
	var item := _plain(2, 1)
	var result: CommandResult = inv.add_item(item, STASH, Vector2i(3, 4), true)
	assert_true(result.ok)
	assert_eq(result.error, &"")
	assert_eq(result.events.size(), 1)
	var event: DomainEvent = result.events[0]
	assert_eq(event.type, DomainEvent.ITEM_ADDED)
	assert_eq(event.data["item_id"], item.id)
	var to: Dictionary = event.data["to"]
	assert_eq(to["container"], STASH)
	assert_eq(to["cell"], Vector2i(3, 4))
	assert_eq(to["rotated"], true)
	assert_eq(inv.get_item(item.id), item)
	assert_eq(item.container_key, STASH)
	assert_eq(item.position, Vector2i(3, 4))
	assert_true(item.rotated)
	assert_eq(inv.get_grid(STASH).get_item_at(Vector2i(3, 5)), item)
	assert_true(inv.is_consistent())


func test_add_item_already_added() -> void:
	var inv := _inv()
	var item := _plain()
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_item(item, STASH, Vector2i(5, 5), false), CommandResult.ALREADY_ADDED, inv, before)


func test_add_item_unknown_container() -> void:
	var inv := _inv()
	var item := _plain()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_item(item, &"nowhere", Vector2i.ZERO, false), CommandResult.UNKNOWN_CONTAINER, inv, before)
	assert_null(inv.get_item(item.id))
	assert_eq(item.container_key, &"")


func test_add_item_to_stash_when_no_stash() -> void:
	var inv := Inventory.new()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_item(_plain(), STASH, Vector2i.ZERO, false), CommandResult.UNKNOWN_CONTAINER, inv, before)


func test_add_item_no_space_overlap_bounds_and_rotation() -> void:
	var inv := _inv(Vector2i(4, 4))
	_stash_add(inv, _plain(2, 2), Vector2i(1, 1))
	var before: Array[String] = _snapshot(inv)
	var blocked := _plain(2, 2)
	_assert_failed(inv.add_item(blocked, STASH, Vector2i(2, 2), false), CommandResult.NO_SPACE, inv, before)
	_assert_failed(inv.add_item(blocked, STASH, Vector2i(3, 3), false), CommandResult.NO_SPACE, inv, before)
	_assert_failed(inv.add_item(blocked, STASH, Vector2i(-1, 0), false), CommandResult.NO_SPACE, inv, before)
	var fixed := _make(ItemDef.create(&"fixed", 2, 1, 1, false))
	_assert_failed(inv.add_item(fixed, STASH, Vector2i(0, 3), true), CommandResult.NO_SPACE, inv, before)
	assert_null(inv.get_item(blocked.id))
	assert_eq(blocked.container_key, &"")


func test_add_item_pocket_too_small() -> void:
	var inv := _inv()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_item(_plain(2, 1), Inventory.pocket_key(0), Vector2i.ZERO, false),
			CommandResult.NO_SPACE, inv, before)
	assert_true(inv.add_item(_plain(), Inventory.pocket_key(0), Vector2i.ZERO, false).ok)


func test_add_item_nesting_not_allowed() -> void:
	var inv := _inv()
	var outer := _backpack()
	_stash_add(inv, outer)
	var inner := _backpack()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_item(inner, Inventory.item_grid_key(outer.id, 0), Vector2i.ZERO, false),
			CommandResult.NESTING_NOT_ALLOWED, inv, before)
	var rig := _rig()
	_assert_failed(inv.add_item(rig, Inventory.item_grid_key(outer.id, 0), Vector2i.ZERO, false),
			CommandResult.NESTING_NOT_ALLOWED, inv, before)


func test_unknown_container_takes_precedence_over_nesting() -> void:
	var inv := _inv()
	var result: CommandResult = inv.add_item(_backpack(), &"item_77_0", Vector2i.ZERO, false)
	assert_eq(result.error, CommandResult.UNKNOWN_CONTAINER)


func test_add_non_container_item_into_backpack_grid() -> void:
	var inv := _inv()
	var pack := _backpack()
	_stash_add(inv, pack)
	var key: StringName = Inventory.item_grid_key(pack.id, 0)
	var item := _plain(2, 2)
	var result: CommandResult = inv.add_item(item, key, Vector2i(1, 1), false)
	assert_true(result.ok)
	assert_eq(item.container_key, key)
	assert_eq(result.events[0].data["to"]["container"], key)
	assert_true(inv.is_consistent())


func test_add_prefilled_container_registers_contents() -> void:
	var inv := _inv()
	var pack := _backpack()
	var child := _plain(2, 1)
	var other := _ammo(10)
	assert_true(pack.grids[0].try_place(child, Vector2i(1, 1), false))
	assert_true(pack.grids[0].try_place(other, Vector2i(0, 3), false))
	assert_eq(child.container_key, &"", "contents have no key before registration")
	var result: CommandResult = inv.add_item(pack, STASH, Vector2i.ZERO, false)
	assert_true(result.ok)
	var key: StringName = Inventory.item_grid_key(pack.id, 0)
	assert_eq(inv.get_item(child.id), child)
	assert_eq(inv.get_item(other.id), other)
	assert_eq(child.container_key, key)
	assert_eq(other.container_key, key)
	assert_eq(inv.get_items().size(), 3)
	assert_true(inv.is_consistent())


func test_add_prefilled_rig_keys_per_grid() -> void:
	var inv := _inv()
	var rig := _rig()
	var a := _plain()
	var b := _plain()
	assert_true(rig.grids[0].try_place(a, Vector2i.ZERO, false))
	assert_true(rig.grids[1].try_place(b, Vector2i(1, 0), false))
	assert_true(inv.add_item(rig, STASH, Vector2i.ZERO, false).ok)
	assert_eq(a.container_key, Inventory.item_grid_key(rig.id, 0))
	assert_eq(b.container_key, Inventory.item_grid_key(rig.id, 1))
	assert_true(inv.is_consistent())


# --- auto_add_item ---

func test_auto_add_uses_first_key_with_room() -> void:
	var inv := _inv()
	var first := _plain()
	var result: CommandResult = inv.auto_add_item(first, _keys([Inventory.pocket_key(1), STASH]))
	assert_true(result.ok)
	assert_eq(first.container_key, &"pocket_1")
	var second := _plain()
	assert_true(inv.auto_add_item(second, _keys([Inventory.pocket_key(1), STASH])).ok)
	assert_eq(second.container_key, STASH, "pocket_1 is full, falls through to stash")
	assert_eq(second.position, Vector2i.ZERO)
	assert_true(inv.is_consistent())


func test_auto_add_event_describes_final_placement() -> void:
	var inv := _inv()
	var item := _plain()
	var result: CommandResult = inv.auto_add_item(item, _keys([STASH]))
	assert_eq(result.events[0].type, DomainEvent.ITEM_ADDED)
	assert_eq(result.events[0].data["to"]["container"], STASH)


func test_auto_add_rotates_when_needed() -> void:
	var inv := _inv()
	var pack := _backpack(1, 3)
	_stash_add(inv, pack)
	var key: StringName = Inventory.item_grid_key(pack.id, 0)
	var item := _plain(3, 1)
	assert_true(inv.auto_add_item(item, _keys([key])).ok)
	assert_true(item.rotated)
	assert_true(inv.is_consistent())


func test_auto_add_skips_grids_violating_nesting() -> void:
	var inv := _inv()
	var outer := _backpack()
	_stash_add(inv, outer)
	var inner := _backpack()
	var outer_key: StringName = Inventory.item_grid_key(outer.id, 0)
	assert_true(inv.auto_add_item(inner, _keys([outer_key, STASH])).ok)
	assert_eq(inner.container_key, STASH)
	var only_nested := _backpack()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.auto_add_item(only_nested, _keys([outer_key])), CommandResult.NO_SPACE, inv, before)


func test_auto_add_skips_unknown_keys() -> void:
	var inv := _inv()
	var item := _plain()
	assert_true(inv.auto_add_item(item, _keys([&"nope", Inventory.pocket_key(0)])).ok)
	assert_eq(item.container_key, &"pocket_0")


func test_auto_add_no_space() -> void:
	var inv := _inv()
	var before: Array[String] = _snapshot(inv)
	var big := _plain(2, 2)
	_assert_failed(inv.auto_add_item(big, _keys([Inventory.pocket_key(0), Inventory.pocket_key(1)])),
			CommandResult.NO_SPACE, inv, before)
	_assert_failed(inv.auto_add_item(big, _keys([])), CommandResult.NO_SPACE, inv, before)
	assert_null(inv.get_item(big.id))


func test_auto_add_already_added() -> void:
	var inv := _inv()
	var item := _plain()
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.auto_add_item(item, _keys([STASH])), CommandResult.ALREADY_ADDED, inv, before)


# --- add_equipped ---

func test_add_equipped_success() -> void:
	var inv := _inv()
	var weapon := _weapon()
	var result: CommandResult = inv.add_equipped(weapon, Slot.PRIMARY_1)
	assert_true(result.ok)
	assert_eq(result.events[0].type, DomainEvent.ITEM_ADDED)
	assert_eq(result.events[0].data["to"]["container"], &"slot_primary_1")
	assert_eq(weapon.container_key, &"slot_primary_1")
	assert_eq(inv.equipment.get_item(Slot.PRIMARY_1), weapon)
	assert_eq(inv.get_item(weapon.id), weapon)
	assert_true(inv.is_consistent())


func test_add_equipped_slot_not_allowed() -> void:
	var inv := _inv()
	var weapon := _weapon()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_equipped(weapon, Slot.BACKPACK), CommandResult.SLOT_NOT_ALLOWED, inv, before)
	assert_null(inv.get_item(weapon.id))


func test_add_equipped_slot_occupied() -> void:
	var inv := _inv()
	assert_true(inv.add_equipped(_weapon(), Slot.PRIMARY_1).ok)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_equipped(_weapon(), Slot.PRIMARY_1), CommandResult.SLOT_OCCUPIED, inv, before)


func test_add_equipped_already_added() -> void:
	var inv := _inv()
	var weapon := _weapon()
	assert_true(inv.add_equipped(weapon, Slot.PRIMARY_1).ok)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.add_equipped(weapon, Slot.PRIMARY_2), CommandResult.ALREADY_ADDED, inv, before)


func test_add_equipped_prefilled_backpack_registers_contents() -> void:
	var inv := _inv()
	var pack := _backpack()
	var child := _plain()
	assert_true(pack.grids[0].try_place(child, Vector2i(2, 2), false))
	assert_true(inv.add_equipped(pack, Slot.BACKPACK).ok)
	assert_eq(child.container_key, Inventory.item_grid_key(pack.id, 0))
	assert_eq(inv.get_item(child.id), child)
	assert_true(inv.is_consistent())


# --- move_item ---

func test_move_within_same_grid() -> void:
	var inv := _inv()
	var item := _plain(2, 1)
	_stash_add(inv, item, Vector2i(0, 0))
	var result: CommandResult = inv.move_item(item.id, STASH, Vector2i(5, 5), false)
	assert_true(result.ok)
	assert_eq(result.events.size(), 1)
	var event: DomainEvent = result.events[0]
	assert_eq(event.type, DomainEvent.ITEM_MOVED)
	assert_eq(event.data["item_id"], item.id)
	assert_eq(event.data["from"], {"container": STASH, "cell": Vector2i(0, 0), "rotated": false})
	assert_eq(event.data["to"], {"container": STASH, "cell": Vector2i(5, 5), "rotated": false})
	assert_eq(item.position, Vector2i(5, 5))
	assert_null(inv.get_grid(STASH).get_item_at(Vector2i(0, 0)))
	assert_eq(inv.get_grid(STASH).get_item_at(Vector2i(6, 5)), item)
	assert_true(inv.is_consistent())


func test_move_onto_own_old_cells_in_same_grid() -> void:
	var inv := _inv()
	var item := _plain(3, 2)
	_stash_add(inv, item, Vector2i(2, 2))
	assert_true(inv.move_item(item.id, STASH, Vector2i(3, 2), false).ok, "shift by one overlaps own cells")
	assert_eq(item.position, Vector2i(3, 2))
	assert_null(inv.get_grid(STASH).get_item_at(Vector2i(2, 2)))
	assert_true(inv.move_item(item.id, STASH, Vector2i(3, 2), true).ok, "rotate in place")
	assert_true(item.rotated)
	assert_true(inv.move_item(item.id, STASH, Vector2i(3, 2), true).ok, "same spot again")
	assert_true(inv.is_consistent())


func test_move_same_grid_blocked_by_other_item() -> void:
	var inv := _inv()
	var a := _plain(2, 2)
	var b := _plain(2, 2)
	_stash_add(inv, a, Vector2i(0, 0))
	_stash_add(inv, b, Vector2i(4, 0))
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(a.id, STASH, Vector2i(3, 1), false), CommandResult.NO_SPACE, inv, before)
	_assert_failed(inv.move_item(a.id, STASH, Vector2i(9, 9), false), CommandResult.NO_SPACE, inv, before)


func test_move_across_grids_stash_to_backpack_to_pocket() -> void:
	var inv := _inv()
	var pack := _backpack()
	var item := _plain()
	_stash_add(inv, pack, Vector2i(0, 0))
	_stash_add(inv, item, Vector2i(6, 6))
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var result: CommandResult = inv.move_item(item.id, pack_key, Vector2i(2, 3), false)
	assert_true(result.ok)
	assert_eq(result.events[0].data["from"]["container"], STASH)
	assert_eq(result.events[0].data["to"]["container"], pack_key)
	assert_eq(item.container_key, pack_key)
	assert_null(inv.get_grid(STASH).get_item_at(Vector2i(6, 6)), "old cell freed")
	assert_eq(pack.grids[0].get_item_at(Vector2i(2, 3)), item)
	assert_true(inv.is_consistent())
	assert_true(inv.move_item(item.id, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	assert_eq(item.container_key, &"pocket_0")
	assert_null(pack.grids[0].get_item_at(Vector2i(2, 3)))
	assert_eq(inv.get_grid(&"pocket_0").get_item_at(Vector2i.ZERO), item)
	assert_true(inv.is_consistent())


func test_move_out_of_equipment_slot_into_grid() -> void:
	var inv := _inv()
	var weapon := _weapon()
	assert_true(inv.add_equipped(weapon, Slot.PRIMARY_1).ok)
	var result: CommandResult = inv.move_item(weapon.id, STASH, Vector2i(1, 1), true)
	assert_true(result.ok)
	assert_null(inv.equipment.get_item(Slot.PRIMARY_1))
	assert_eq(weapon.container_key, STASH)
	assert_eq(weapon.position, Vector2i(1, 1))
	assert_true(weapon.rotated)
	assert_eq(result.events[0].data["from"]["container"], &"slot_primary_1")
	assert_eq(inv.get_item(weapon.id), weapon)
	assert_true(inv.is_consistent())


func test_move_equipped_backpack_to_stash_keeps_contents() -> void:
	var inv := _inv()
	var pack := _backpack()
	var child := _plain()
	assert_true(pack.grids[0].try_place(child, Vector2i.ZERO, false))
	assert_true(inv.add_equipped(pack, Slot.BACKPACK).ok)
	assert_true(inv.move_item(pack.id, STASH, Vector2i(2, 2), false).ok)
	assert_eq(child.container_key, Inventory.item_grid_key(pack.id, 0))
	assert_eq(inv.get_item(child.id), child)
	assert_true(inv.is_consistent())


func test_move_failure_codes() -> void:
	var inv := _inv()
	var item := _plain()
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(9999, STASH, Vector2i.ZERO, false), CommandResult.UNKNOWN_ITEM, inv, before)
	_assert_failed(inv.move_item(item.id, &"nowhere", Vector2i.ZERO, false), CommandResult.UNKNOWN_CONTAINER, inv, before)
	_assert_failed(inv.move_item(item.id, &"item_9999_0", Vector2i.ZERO, false), CommandResult.UNKNOWN_CONTAINER, inv, before)
	_assert_failed(inv.move_item(item.id, STASH, Vector2i(10, 0), false), CommandResult.NO_SPACE, inv, before)


func test_failed_cross_grid_move_leaves_everything_unchanged() -> void:
	var inv := _inv()
	var item := _plain(2, 1)
	var blocker := _plain()
	_stash_add(inv, item, Vector2i(3, 3))
	assert_true(inv.add_item(blocker, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(item.id, Inventory.pocket_key(0), Vector2i.ZERO, false), CommandResult.NO_SPACE, inv, before)
	_assert_failed(inv.move_item(blocker.id, Inventory.pocket_key(1), Vector2i(1, 0), false), CommandResult.NO_SPACE, inv, before)
	assert_eq(item.container_key, STASH)
	assert_eq(item.position, Vector2i(3, 3))
	assert_eq(inv.get_grid(STASH).get_item_at(Vector2i(4, 3)), item)


func test_failed_move_out_of_slot_keeps_item_equipped() -> void:
	var inv := _inv(Vector2i(2, 2))
	var weapon := _weapon()
	assert_true(inv.add_equipped(weapon, Slot.PRIMARY_1).ok)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(weapon.id, STASH, Vector2i.ZERO, false), CommandResult.NO_SPACE, inv, before)
	assert_eq(inv.equipment.get_item(Slot.PRIMARY_1), weapon)
	assert_eq(weapon.container_key, &"slot_primary_1")


func test_move_rotation_unsupported_fails() -> void:
	var inv := _inv()
	var fixed := _make(ItemDef.create(&"fixed", 2, 1, 1, false))
	_stash_add(inv, fixed)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(fixed.id, STASH, Vector2i(4, 4), true), CommandResult.NO_SPACE, inv, before)


# --- equip ---

func test_equip_from_stash() -> void:
	var inv := _inv()
	var weapon := _weapon()
	_stash_add(inv, weapon, Vector2i(2, 2))
	var result: CommandResult = inv.equip(weapon.id, Slot.PRIMARY_1)
	assert_true(result.ok)
	assert_eq(result.events.size(), 1)
	var event: DomainEvent = result.events[0]
	assert_eq(event.type, DomainEvent.ITEM_MOVED)
	assert_eq(event.data["from"]["container"], STASH)
	assert_eq(event.data["from"]["cell"], Vector2i(2, 2))
	assert_eq(event.data["to"]["container"], &"slot_primary_1")
	assert_eq(inv.equipment.get_item(Slot.PRIMARY_1), weapon)
	assert_eq(weapon.container_key, &"slot_primary_1")
	assert_null(inv.get_grid(STASH).get_item_at(Vector2i(2, 2)))
	assert_true(inv.get_grid(STASH).get_items().is_empty())
	assert_true(inv.is_consistent())


func test_equip_from_inside_container_grid() -> void:
	var inv := _inv()
	var pack := _backpack()
	assert_true(inv.add_equipped(pack, Slot.BACKPACK).ok)
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var weapon := _weapon()
	assert_true(inv.add_item(weapon, pack_key, Vector2i.ZERO, false).ok)
	assert_true(inv.equip(weapon.id, Slot.SECONDARY).ok)
	assert_true(pack.grids[0].get_items().is_empty())
	assert_eq(weapon.container_key, &"slot_secondary")
	assert_true(inv.is_consistent())


func test_equip_same_slot_again_is_noop_success() -> void:
	var inv := _inv()
	var weapon := _weapon()
	assert_true(inv.add_equipped(weapon, Slot.PRIMARY_1).ok)
	var before: Array[String] = _snapshot(inv)
	var result: CommandResult = inv.equip(weapon.id, Slot.PRIMARY_1)
	assert_true(result.ok)
	assert_true(result.events.is_empty())
	assert_eq(_snapshot(inv), before)
	assert_true(inv.is_consistent())


func test_equip_moves_between_slots() -> void:
	var inv := _inv()
	var weapon := _weapon()
	assert_true(inv.add_equipped(weapon, Slot.PRIMARY_1).ok)
	var result: CommandResult = inv.equip(weapon.id, Slot.PRIMARY_2)
	assert_true(result.ok)
	assert_null(inv.equipment.get_item(Slot.PRIMARY_1))
	assert_eq(inv.equipment.get_item(Slot.PRIMARY_2), weapon)
	assert_eq(result.events[0].data["from"]["container"], &"slot_primary_1")
	assert_true(inv.is_consistent())


func test_equip_wrong_category() -> void:
	var inv := _inv()
	var item := _plain()
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.equip(item.id, Slot.BACKPACK), CommandResult.SLOT_NOT_ALLOWED, inv, before)
	var helmet := _helmet()
	_stash_add(inv, helmet, Vector2i(5, 5))
	before = _snapshot(inv)
	_assert_failed(inv.equip(helmet.id, Slot.ARMOR), CommandResult.SLOT_NOT_ALLOWED, inv, before)


func test_equip_occupied_slot() -> void:
	var inv := _inv()
	assert_true(inv.add_equipped(_weapon(), Slot.PRIMARY_1).ok)
	var second := _weapon()
	_stash_add(inv, second)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.equip(second.id, Slot.PRIMARY_1), CommandResult.SLOT_OCCUPIED, inv, before)
	assert_eq(second.container_key, STASH)


func test_equip_category_checked_before_occupancy() -> void:
	var inv := _inv()
	assert_true(inv.add_equipped(_weapon(), Slot.PRIMARY_1).ok)
	var item := _plain()
	_stash_add(inv, item)
	assert_eq(inv.equip(item.id, Slot.PRIMARY_1).error, CommandResult.SLOT_NOT_ALLOWED)


func test_equip_unknown_item() -> void:
	var inv := _inv()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.equip(4242, Slot.PRIMARY_1), CommandResult.UNKNOWN_ITEM, inv, before)


func test_equip_backpack_carries_contents() -> void:
	var inv := _inv()
	var pack := _backpack()
	_stash_add(inv, pack)
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var a := _plain(2, 2)
	var b := _ammo(12)
	assert_true(inv.add_item(a, pack_key, Vector2i(1, 0), false).ok)
	assert_true(inv.add_item(b, pack_key, Vector2i(0, 3), false).ok)
	assert_true(inv.equip(pack.id, Slot.BACKPACK).ok)
	assert_eq(a.container_key, pack_key)
	assert_eq(b.container_key, pack_key)
	assert_eq(a.position, Vector2i(1, 0))
	assert_eq(inv.get_grid(pack_key), pack.grids[0])
	assert_eq(inv.get_grid(pack_key).get_item_at(Vector2i(2, 1)), a)
	assert_eq(inv.get_item(a.id), a)
	assert_true(inv.grid_keys().has(pack_key))
	assert_true(inv.is_consistent())


func test_equip_rig_keeps_all_grids_reachable() -> void:
	var inv := _inv()
	var rig := _rig()
	_stash_add(inv, rig)
	var item := _plain()
	var key1: StringName = Inventory.item_grid_key(rig.id, 1)
	assert_true(inv.add_item(item, key1, Vector2i.ZERO, false).ok)
	assert_true(inv.equip(rig.id, Slot.RIG).ok)
	assert_eq(item.container_key, key1)
	assert_not_null(inv.get_grid(key1))
	assert_true(inv.is_consistent())


# --- 중첩 규칙 ---

func test_nesting_backpack_into_other_backpack_grid() -> void:
	var inv := _inv()
	var outer := _backpack()
	var inner := _backpack()
	_stash_add(inv, outer, Vector2i(0, 0))
	_stash_add(inv, inner, Vector2i(5, 5))
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(inner.id, Inventory.item_grid_key(outer.id, 0), Vector2i.ZERO, false),
			CommandResult.NESTING_NOT_ALLOWED, inv, before)


func test_nesting_backpack_into_own_grid() -> void:
	var inv := _inv()
	var pack := _backpack(6, 6)
	_stash_add(inv, pack)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(pack.id, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false),
			CommandResult.NESTING_NOT_ALLOWED, inv, before)


func test_nesting_rig_into_backpack_grid() -> void:
	var inv := _inv()
	var pack := _backpack()
	var rig := _rig()
	_stash_add(inv, pack)
	_stash_add(inv, rig, Vector2i(5, 5))
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(rig.id, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false),
			CommandResult.NESTING_NOT_ALLOWED, inv, before)


func test_nesting_equipped_container_into_other_container_grid() -> void:
	var inv := _inv()
	var pack := _backpack()
	var rig := _rig()
	_stash_add(inv, pack)
	assert_true(inv.add_equipped(rig, Slot.RIG).ok)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.move_item(rig.id, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false),
			CommandResult.NESTING_NOT_ALLOWED, inv, before)


func test_nesting_container_into_root_grids_is_fine() -> void:
	var inv := _inv()
	var pack := _backpack()
	var rig := _rig()
	_stash_add(inv, pack)
	_stash_add(inv, rig, Vector2i(5, 5))
	assert_true(inv.move_item(pack.id, STASH, Vector2i(0, 5), false).ok)
	assert_true(inv.move_item(rig.id, STASH, Vector2i(5, 0), true).ok)


func test_nesting_non_container_into_backpack_grid_is_allowed() -> void:
	var inv := _inv()
	var pack := _backpack()
	var item := _plain()
	_stash_add(inv, pack)
	_stash_add(inv, item, Vector2i(6, 6))
	assert_true(inv.move_item(item.id, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false).ok)
	assert_true(inv.is_consistent())


# --- merge ---

func test_merge_partial_same_grid() -> void:
	var inv := _inv()
	var source := _ammo(20)
	var target := _ammo(20)
	_stash_add(inv, source, Vector2i(0, 0))
	_stash_add(inv, target, Vector2i(1, 0))
	var result: CommandResult = inv.merge(source.id, target.id)
	assert_true(result.ok)
	assert_eq(target.stack_count, 30)
	assert_eq(source.stack_count, 10)
	assert_eq(result.events.size(), 2)
	assert_eq(result.events[0].type, DomainEvent.STACK_CHANGED)
	assert_eq(result.events[0].data["item_id"], target.id)
	assert_eq(result.events[0].data["stack_count"], 30)
	assert_eq(result.events[1].type, DomainEvent.STACK_CHANGED)
	assert_eq(result.events[1].data["item_id"], source.id)
	assert_eq(result.events[1].data["stack_count"], 10)
	assert_eq(inv.get_item(source.id), source, "remainder stays")
	assert_true(inv.get_grid(STASH).has_item(source))
	assert_true(inv.is_consistent())


func test_merge_full_removes_source() -> void:
	var inv := _inv()
	var source := _ammo(5)
	var target := _ammo(10)
	_stash_add(inv, source, Vector2i(0, 0))
	_stash_add(inv, target, Vector2i(1, 0))
	var result: CommandResult = inv.merge(source.id, target.id)
	assert_true(result.ok)
	assert_eq(target.stack_count, 15)
	assert_eq(result.events.size(), 2)
	assert_eq(result.events[0].type, DomainEvent.STACK_CHANGED)
	assert_eq(result.events[1].type, DomainEvent.ITEM_REMOVED)
	assert_eq(result.events[1].data["item_id"], source.id)
	assert_eq(result.events[1].data["removed_ids"], [source.id])
	assert_null(inv.get_item(source.id))
	assert_false(inv.get_grid(STASH).has_item(source))
	assert_null(inv.get_grid(STASH).get_item_at(Vector2i(0, 0)))
	assert_eq(inv.get_items().size(), 1)
	assert_true(inv.is_consistent())


func test_merge_across_grids() -> void:
	var inv := _inv()
	var pack := _backpack()
	_stash_add(inv, pack)
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var source := _ammo(8)
	var target := _ammo(10)
	assert_true(inv.add_item(source, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	assert_true(inv.add_item(target, pack_key, Vector2i(1, 1), false).ok)
	assert_true(inv.merge(source.id, target.id).ok)
	assert_eq(target.stack_count, 18)
	assert_null(inv.get_item(source.id))
	assert_true(inv.get_grid(Inventory.pocket_key(0)).get_items().is_empty())
	assert_true(inv.is_consistent())


func test_merge_across_grids_partial_keeps_source_in_place() -> void:
	var inv := _inv()
	var source := _ammo(25)
	var target := _ammo(25)
	assert_true(inv.add_item(source, Inventory.pocket_key(2), Vector2i.ZERO, false).ok)
	_stash_add(inv, target)
	assert_true(inv.merge(source.id, target.id).ok)
	assert_eq(source.stack_count, 20)
	assert_eq(source.container_key, &"pocket_2")
	assert_eq(target.stack_count, 30)
	assert_true(inv.is_consistent())


func test_merge_not_stackable_different_defs() -> void:
	var inv := _inv()
	var a := _ammo(5)
	var b := _make(ItemDef.create(&"bolts", 1, 1, 30), 5)
	_stash_add(inv, a, Vector2i(0, 0))
	_stash_add(inv, b, Vector2i(1, 0))
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.merge(a.id, b.id), CommandResult.NOT_STACKABLE, inv, before)


func test_merge_not_stackable_max_stack_one() -> void:
	var inv := _inv()
	var def := ItemDef.create(&"gizmo", 1, 1, 1)
	var a := _make(def)
	var b := _make(def)
	_stash_add(inv, a, Vector2i(0, 0))
	_stash_add(inv, b, Vector2i(1, 0))
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.merge(a.id, b.id), CommandResult.NOT_STACKABLE, inv, before)


func test_merge_not_stackable_with_itself() -> void:
	var inv := _inv()
	var a := _ammo(5)
	_stash_add(inv, a)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.merge(a.id, a.id), CommandResult.NOT_STACKABLE, inv, before)


func test_merge_no_space_when_target_full() -> void:
	var inv := _inv()
	var source := _ammo(5)
	var target := _ammo(30)
	_stash_add(inv, source, Vector2i(0, 0))
	_stash_add(inv, target, Vector2i(1, 0))
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.merge(source.id, target.id), CommandResult.NO_SPACE, inv, before)


func test_merge_unknown_item() -> void:
	var inv := _inv()
	var a := _ammo(5)
	_stash_add(inv, a)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.merge(a.id, 777), CommandResult.UNKNOWN_ITEM, inv, before)
	_assert_failed(inv.merge(777, a.id), CommandResult.UNKNOWN_ITEM, inv, before)


# --- split ---

func test_split_into_another_grid() -> void:
	var inv := _inv()
	var pack := _backpack()
	_stash_add(inv, pack, Vector2i(0, 5))
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var item := _ammo(20)
	_stash_add(inv, item, Vector2i(0, 0))
	var new_id: int = _next_id
	_next_id += 1
	var result: CommandResult = inv.split(item.id, 7, new_id, pack_key, Vector2i(1, 2), false)
	assert_true(result.ok)
	var part: ItemInstance = inv.get_item(new_id)
	assert_not_null(part)
	assert_eq(part.stack_count, 7)
	assert_eq(part.container_key, pack_key)
	assert_eq(part.position, Vector2i(1, 2))
	assert_eq(part.def, item.def)
	assert_eq(item.stack_count, 13)
	assert_eq(result.events.size(), 2)
	assert_eq(result.events[0].type, DomainEvent.ITEM_ADDED)
	assert_eq(result.events[0].data["item_id"], new_id)
	assert_eq(result.events[1].type, DomainEvent.STACK_CHANGED)
	assert_eq(result.events[1].data["item_id"], item.id)
	assert_eq(result.events[1].data["stack_count"], 13)
	assert_true(inv.is_consistent())


func test_split_invalid_amount() -> void:
	var inv := _inv()
	var item := _ammo(20)
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	for amount: int in [0, -3, 20, 21]:
		_assert_failed(inv.split(item.id, amount, 900, STASH, Vector2i(5, 5), false),
				CommandResult.INVALID_AMOUNT, inv, before)
	assert_null(inv.get_item(900))


func test_split_unknown_item_and_container() -> void:
	var inv := _inv()
	var item := _ammo(20)
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.split(555, 5, 900, STASH, Vector2i(5, 5), false), CommandResult.UNKNOWN_ITEM, inv, before)
	_assert_failed(inv.split(item.id, 5, 900, &"nowhere", Vector2i.ZERO, false), CommandResult.UNKNOWN_CONTAINER, inv, before)


func test_split_target_overlapping_source_cells_fails() -> void:
	var inv := _inv()
	var item := _make(ItemDef.create(&"crate", 2, 2, 10), 8)
	_stash_add(inv, item, Vector2i(3, 3))
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.split(item.id, 3, 900, STASH, Vector2i(3, 3), false), CommandResult.NO_SPACE, inv, before)
	_assert_failed(inv.split(item.id, 3, 900, STASH, Vector2i(4, 4), false), CommandResult.NO_SPACE, inv, before)
	assert_eq(item.stack_count, 8)
	assert_null(inv.get_item(900))


func test_split_no_space_in_pocket() -> void:
	var inv := _inv()
	var item := _make(ItemDef.create(&"crate", 2, 2, 10), 8)
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.split(item.id, 3, 900, Inventory.pocket_key(0), Vector2i.ZERO, false),
			CommandResult.NO_SPACE, inv, before)


func test_split_duplicate_new_id_is_rejected() -> void:
	var inv := _inv()
	var item := _ammo(20)
	_stash_add(inv, item)
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.split(item.id, 5, item.id, STASH, Vector2i(5, 5), false),
			CommandResult.ALREADY_ADDED, inv, before)


func test_split_copies_found_in_raid() -> void:
	var inv := _inv()
	var item := _ammo(20)
	item.found_in_raid = true
	_stash_add(inv, item)
	assert_true(inv.split(item.id, 5, 900, STASH, Vector2i(4, 4), false).ok)
	assert_true(inv.get_item(900).found_in_raid)
	var plain := _ammo(10)
	_stash_add(inv, plain, Vector2i(8, 8))
	assert_true(inv.split(plain.id, 2, 901, STASH, Vector2i(6, 6), false).ok)
	assert_false(inv.get_item(901).found_in_raid)


# --- discard ---

func test_discard_simple_item() -> void:
	var inv := _inv()
	var item := _plain(2, 2)
	_stash_add(inv, item, Vector2i(1, 1))
	var result: CommandResult = inv.discard(item.id)
	assert_true(result.ok)
	assert_eq(result.events.size(), 1)
	var event: DomainEvent = result.events[0]
	assert_eq(event.type, DomainEvent.ITEM_REMOVED)
	assert_eq(event.data["item_id"], item.id)
	assert_eq(event.data["removed_ids"], [item.id])
	assert_eq(event.data["from"]["container"], STASH)
	assert_eq(event.data["from"]["cell"], Vector2i(1, 1))
	assert_null(inv.get_item(item.id))
	assert_null(inv.get_grid(STASH).get_item_at(Vector2i(1, 1)))
	assert_true(inv.is_consistent())


func test_discard_container_removes_nested_contents() -> void:
	var inv := _inv()
	var pack := _backpack()
	assert_true(inv.add_equipped(pack, Slot.BACKPACK).ok)
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var a := _plain()
	var b := _ammo(10)
	var survivor := _plain()
	assert_true(inv.add_item(a, pack_key, Vector2i(0, 0), false).ok)
	assert_true(inv.add_item(b, pack_key, Vector2i(1, 0), false).ok)
	_stash_add(inv, survivor)
	var result: CommandResult = inv.discard(pack.id)
	assert_true(result.ok)
	var removed: Array = result.events[0].data["removed_ids"]
	assert_eq(removed.size(), 3)
	for id: int in [pack.id, a.id, b.id]:
		assert_true(removed.has(id), "removed_ids has %d" % id)
		assert_null(inv.get_item(id), "item %d gone" % id)
	assert_false(inv.grid_keys().has(pack_key))
	assert_null(inv.get_grid(pack_key))
	assert_null(inv.equipment.get_item(Slot.BACKPACK))
	assert_eq(result.events[0].data["from"]["container"], &"slot_backpack")
	assert_eq(inv.get_item(survivor.id), survivor)
	assert_eq(inv.get_items().size(), 1)
	assert_true(inv.is_consistent())


func test_discard_rig_removes_both_grids() -> void:
	var inv := _inv()
	var rig := _rig()
	_stash_add(inv, rig)
	var a := _plain()
	var b := _plain()
	assert_true(inv.add_item(a, Inventory.item_grid_key(rig.id, 0), Vector2i.ZERO, false).ok)
	assert_true(inv.add_item(b, Inventory.item_grid_key(rig.id, 1), Vector2i.ZERO, false).ok)
	var base: int = inv.grid_keys().size() - 2
	var result: CommandResult = inv.discard(rig.id)
	assert_eq(result.events[0].data["removed_ids"].size(), 3)
	assert_eq(inv.grid_keys().size(), base)
	assert_eq(inv.get_items().size(), 0)
	assert_true(inv.is_consistent())


func test_discard_item_inside_container_leaves_container() -> void:
	var inv := _inv()
	var pack := _backpack()
	_stash_add(inv, pack)
	var key: StringName = Inventory.item_grid_key(pack.id, 0)
	var child := _plain()
	assert_true(inv.add_item(child, key, Vector2i.ZERO, false).ok)
	assert_true(inv.discard(child.id).ok)
	assert_eq(inv.get_item(pack.id), pack)
	assert_true(pack.grids[0].get_items().is_empty())
	assert_true(inv.is_consistent())


func test_discard_unknown_item() -> void:
	var inv := _inv()
	var before: Array[String] = _snapshot(inv)
	_assert_failed(inv.discard(31337), CommandResult.UNKNOWN_ITEM, inv, before)


func test_discard_twice_second_fails() -> void:
	var inv := _inv()
	var item := _plain()
	_stash_add(inv, item)
	assert_true(inv.discard(item.id).ok)
	assert_eq(inv.discard(item.id).error, CommandResult.UNKNOWN_ITEM)


# --- 무작위 시나리오 ---

func test_randomized_operations_keep_inventory_consistent() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240607
	var inv := _inv(Vector2i(8, 8))
	var defs: Array[ItemDef] = []
	defs.append(ItemDef.create(&"small", 1, 1))
	defs.append(ItemDef.create(&"wide", 2, 1))
	defs.append(ItemDef.create(&"block", 2, 2))
	defs.append(ItemDef.create(&"fixed", 3, 1, 1, false))
	defs.append(_ammo_def)
	defs.append(ItemDef.create(&"crate", 2, 2, 10))
	var weapon_def := ItemDef.create(&"rifle", 4, 2)
	weapon_def.category = ItemDef.Category.WEAPON
	defs.append(weapon_def)
	var pack_sizes: Array[Vector2i] = [Vector2i(5, 5)]
	var rig_sizes: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 2)]
	var pack_def := _container_def(ItemDef.Category.BACKPACK, pack_sizes, 3, 3)
	var rig_def := _container_def(ItemDef.Category.RIG, rig_sizes, 3, 2)
	var slots: Array = EquipmentSlots.Slot.values()
	var counts: Dictionary = {}
	for op_name: String in ["add", "auto", "equipped", "move", "equip", "merge", "split", "discard"]:
		counts[op_name] = 0

	for step: int in range(1500):
		var op: int = rng.randi_range(0, 7)
		var ids: Array[int] = []
		for existing: ItemInstance in inv.get_items():
			ids.append(existing.id)
		ids.sort()
		var keys: Array[StringName] = inv.grid_keys()
		var before: Array[String] = _snapshot(inv)
		var result: CommandResult = null
		var name: String = ""
		match op:
			0:
				name = "add"
				var item: ItemInstance = _random_item(rng, defs, pack_def, rig_def)
				var key: StringName = &"bogus" if rng.randi() % 20 == 0 else keys[rng.randi() % keys.size()]
				result = inv.add_item(item, key, Vector2i(rng.randi_range(0, 5), rng.randi_range(0, 5)), rng.randi() % 2 == 0)
			1:
				name = "auto"
				var item: ItemInstance = _random_item(rng, defs, pack_def, rig_def)
				var order: Array[StringName] = keys.duplicate()
				for i: int in range(order.size() - 1, 0, -1):
					var j: int = rng.randi_range(0, i)
					var tmp: StringName = order[i]
					order[i] = order[j]
					order[j] = tmp
				order.resize(rng.randi_range(1, order.size()))
				result = inv.auto_add_item(item, order)
			2:
				name = "equipped"
				var item: ItemInstance = _random_item(rng, defs, pack_def, rig_def)
				result = inv.add_equipped(item, slots[rng.randi() % slots.size()] as Slot)
			3:
				name = "move"
				if not ids.is_empty():
					result = inv.move_item(ids[rng.randi() % ids.size()], keys[rng.randi() % keys.size()],
							Vector2i(rng.randi_range(0, 6), rng.randi_range(0, 6)), rng.randi() % 2 == 0)
			4:
				name = "equip"
				if not ids.is_empty():
					result = inv.equip(ids[rng.randi() % ids.size()], slots[rng.randi() % slots.size()] as Slot)
			5:
				name = "merge"
				if ids.size() >= 2:
					result = inv.merge(ids[rng.randi() % ids.size()], ids[rng.randi() % ids.size()])
			6:
				name = "split"
				if not ids.is_empty():
					var source: ItemInstance = inv.get_item(ids[rng.randi() % ids.size()])
					var new_id: int = _next_id
					_next_id += 1
					result = inv.split(source.id, rng.randi_range(0, source.stack_count + 1), new_id,
							keys[rng.randi() % keys.size()], Vector2i(rng.randi_range(0, 6), rng.randi_range(0, 6)),
							rng.randi() % 2 == 0)
			7:
				name = "discard"
				if not ids.is_empty() and rng.randi() % 3 == 0:
					result = inv.discard(ids[rng.randi() % ids.size()])
		if result == null:
			continue
		var context: String = "step %d (%s)" % [step, name]
		if result.ok:
			counts[name] = int(counts[name]) + 1
		else:
			assert_ne(result.error, &"", context)
			assert_eq(_snapshot(inv), before, "%s failed (%s) but changed state" % [context, result.error])
		if not inv.is_consistent():
			fail_test("inventory inconsistent after %s" % context)
			return
		if not _all_reachable(inv):
			fail_test("unreachable item after %s" % context)
			return
	for op_name: String in counts:
		assert_gt(int(counts[op_name]), 0, "random run never succeeded at %s" % op_name)


func _random_item(rng: RandomNumberGenerator, defs: Array[ItemDef], pack_def: ItemDef, rig_def: ItemDef) -> ItemInstance:
	var roll: int = rng.randi_range(0, 9)
	var item: ItemInstance
	if roll == 0:
		item = _make(pack_def)
	elif roll == 1:
		item = _make(rig_def)
	else:
		var def: ItemDef = defs[rng.randi() % defs.size()]
		item = _make(def, rng.randi_range(1, def.max_stack))
	item.found_in_raid = rng.randi() % 2 == 0
	return item


## 등록된 모든 아이템이 container_key가 가리키는 그리드·슬롯에서 실제로 발견되는지 확인한다.
func _all_reachable(inv: Inventory) -> bool:
	for item: ItemInstance in inv.get_items():
		var slot: int = EquipmentSlots.slot_from_key(item.container_key)
		if slot >= 0:
			if inv.equipment.get_item(slot as Slot) != item:
				return false
		else:
			var grid: ItemGrid = inv.get_grid(item.container_key)
			if grid == null or not grid.has_item(item):
				return false
	return true


# --- 회귀: 키 정규 형태, 미리 채워진 컨테이너 ---

func test_get_grid_rejects_non_canonical_item_keys() -> void:
	var inv := Inventory.new(Vector2i(10, 10))
	var pack := _backpack()
	assert_true(inv.add_item(pack, Inventory.STASH, Vector2i.ZERO, false).ok)
	assert_not_null(inv.get_grid(Inventory.item_grid_key(pack.id, 0)))
	assert_null(inv.get_grid(StringName("item_0%d_0" % pack.id)))
	assert_null(inv.get_grid(StringName("item_%d_00" % pack.id)))
	assert_null(inv.get_grid(StringName("item_%d_+0" % pack.id)))


func test_prefilled_container_holding_container_is_rejected() -> void:
	var inv := Inventory.new(Vector2i(10, 10))
	var outer := _backpack(6, 6)
	var inner := _backpack(2, 2)
	assert_true(outer.grids[0].try_place(inner, Vector2i.ZERO, false))
	assert_eq(inv.add_item(outer, Inventory.STASH, Vector2i.ZERO, false).error,
			CommandResult.NESTING_NOT_ALLOWED)
	assert_eq(inv.add_equipped(outer, EquipmentSlots.Slot.BACKPACK).error,
			CommandResult.NESTING_NOT_ALLOWED)
	assert_eq(inv.get_items().size(), 0)
	assert_true(inv.is_consistent())


# --- 스태시 잠금 (레이드 중) ---

func test_locked_stash_blocks_all_changes_in_and_out() -> void:
	var inv := Inventory.new(Vector2i(10, 10))
	var pack := _backpack()
	var inside := _plain(1, 1, &"inside")
	var outside := _plain(1, 1, &"outside")
	assert_true(inv.add_item(pack, Inventory.STASH, Vector2i.ZERO, false).ok)
	assert_true(inv.add_item(inside, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false).ok)
	assert_true(inv.add_item(outside, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	inv.stash_locked = true
	var locked: StringName = CommandResult.STASH_LOCKED
	assert_eq(inv.move_item(outside.id, Inventory.STASH, Vector2i(5, 5), false).error, locked)
	assert_eq(inv.move_item(outside.id, Inventory.item_grid_key(pack.id, 0), Vector2i(2, 2), false).error, locked)
	assert_eq(inv.move_item(inside.id, Inventory.pocket_key(1), Vector2i.ZERO, false).error, locked)
	assert_eq(inv.equip(pack.id, EquipmentSlots.Slot.BACKPACK).error, locked)
	assert_eq(inv.discard(inside.id).error, locked)
	assert_eq(inv.add_item(_plain(), Inventory.STASH, Vector2i(9, 9), false).error, locked)
	assert_true(inv.move_item(outside.id, Inventory.pocket_key(1), Vector2i.ZERO, false).ok)
	inv.stash_locked = false
	assert_true(inv.move_item(inside.id, Inventory.pocket_key(2), Vector2i.ZERO, false).ok)
	assert_true(inv.is_consistent())
