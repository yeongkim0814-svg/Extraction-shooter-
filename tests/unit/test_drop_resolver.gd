extends GutTest
## DropResolver 테스트 (M5): 이동·병합·장착 판정과 미리보기 유효성.

const STASH := Inventory.STASH

var _inv: Inventory
var _auth: LocalAuthority
var _pistol_def: ItemDef
var _ammo_def: ItemDef
var _pack_def: ItemDef
var _rig_def: ItemDef


func before_each() -> void:
	_inv = Inventory.new(Vector2i(10, 10))
	_auth = LocalAuthority.new(_inv)
	_pistol_def = ItemDef.create(&"pistol", 2, 1)
	_pistol_def.category = ItemDef.Category.PISTOL
	_ammo_def = ItemDef.create(&"ammo", 1, 1, 60)
	_pack_def = ItemDef.create(&"pack", 3, 3)
	_pack_def.category = ItemDef.Category.BACKPACK
	_pack_def.grids = [Vector2i(4, 4)]
	_rig_def = ItemDef.create(&"rig", 2, 2)
	_rig_def.category = ItemDef.Category.RIG
	_rig_def.grids = [Vector2i(1, 2)]


func _add(def: ItemDef, cell: Vector2i, count: int = 1, key: StringName = STASH) -> ItemInstance:
	var item: ItemInstance = _auth.create_item(def, count)
	assert_true(_inv.add_item(item, key, cell, false).ok)
	return item


# --- 이동 ---

func test_move_to_empty_cell_is_valid() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(5, 5), false)
	assert_true(r.valid)
	assert_eq(r.kind, DropResolver.Kind.MOVE)
	assert_true(r.command is MoveItemCommand)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(pistol.position, Vector2i(5, 5))


func test_move_out_of_bounds_invalid() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(9, 0), false)
	assert_false(r.valid)
	assert_eq(r.kind, DropResolver.Kind.NONE)
	assert_null(r.command)
	assert_eq(r.error, CommandResult.NO_SPACE)
	assert_false(DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(-1, 0), false).valid)


func test_move_onto_other_item_invalid() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	_add(_pack_def, Vector2i(4, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(3, 0), false)
	assert_false(r.valid)
	assert_null(r.command)


func test_overlap_with_self_in_same_grid_is_valid() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(2, 2))
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(3, 2), false)
	assert_true(r.valid)
	assert_eq(r.kind, DropResolver.Kind.MOVE)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(pistol.position, Vector2i(3, 2))


func test_rotate_in_place_is_move_and_same_spot_is_noop() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(2, 2))
	var same: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(2, 2), false)
	assert_true(same.valid)
	assert_eq(same.kind, DropResolver.Kind.NONE)
	assert_null(same.command)
	var rot: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(2, 2), true)
	assert_true(rot.valid)
	assert_eq(rot.kind, DropResolver.Kind.MOVE)
	assert_true(_auth.execute(rot.command).ok)
	assert_true(pistol.rotated)


func test_rotate_denied_when_def_cannot_rotate() -> void:
	var def := ItemDef.create(&"fixed", 2, 1, 1, false)
	var item: ItemInstance = _add(def, Vector2i(0, 0))
	assert_false(DropResolver.resolve_grid(_inv, item.id, STASH, Vector2i(4, 4), true).valid)


func test_move_between_grids_into_backpack() -> void:
	var pack: ItemInstance = _add(_pack_def, Vector2i(0, 5))
	assert_true(_auth.execute(EquipItemCommand.new(pack.id, EquipmentSlots.Slot.BACKPACK)).ok)
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var key: StringName = Inventory.item_grid_key(pack.id, 0)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pistol.id, key, Vector2i(0, 0), false)
	assert_true(r.valid)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(pistol.container_key, key)
	assert_false(DropResolver.resolve_grid(_inv, pistol.id, key, Vector2i(3, 0), false).valid)


func test_unknown_item_and_container_invalid() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	assert_eq(DropResolver.resolve_grid(_inv, 999, STASH, Vector2i.ZERO, false).error, CommandResult.UNKNOWN_ITEM)
	assert_eq(DropResolver.resolve_grid(_inv, pistol.id, &"nope", Vector2i.ZERO, false).error,
			CommandResult.UNKNOWN_CONTAINER)


func test_pocket_accepts_only_1x1() -> void:
	var ammo: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 10)
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(2, 0))
	assert_true(DropResolver.resolve_grid(_inv, ammo.id, Inventory.pocket_key(0), Vector2i.ZERO, false).valid)
	assert_false(DropResolver.resolve_grid(_inv, pistol.id, Inventory.pocket_key(0), Vector2i.ZERO, false).valid)


# --- 병합 ---

func test_merge_onto_same_def_stack() -> void:
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	var b: ItemInstance = _add(_ammo_def, Vector2i(3, 3), 30)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, a.id, STASH, Vector2i(3, 3), false)
	assert_true(r.valid)
	assert_eq(r.kind, DropResolver.Kind.MERGE)
	assert_true(r.command is MergeStacksCommand)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(b.stack_count, 50)
	assert_null(_inv.get_item(a.id))


func test_merge_partial_when_target_nearly_full() -> void:
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	var b: ItemInstance = _add(_ammo_def, Vector2i(3, 3), 50)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, a.id, STASH, Vector2i(3, 3), false)
	assert_eq(r.kind, DropResolver.Kind.MERGE)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(b.stack_count, 60)
	assert_eq(a.stack_count, 10)


func test_merge_into_full_stack_is_invalid_not_move() -> void:
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	_add(_ammo_def, Vector2i(3, 3), 60)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, a.id, STASH, Vector2i(3, 3), false)
	assert_false(r.valid)
	assert_eq(r.kind, DropResolver.Kind.NONE)
	assert_null(r.command)
	assert_eq(r.error, CommandResult.NO_SPACE)


func test_different_def_does_not_merge() -> void:
	var other_def := ItemDef.create(&"ammo_556", 1, 1, 60)
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	_add(other_def, Vector2i(3, 3), 10)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, a.id, STASH, Vector2i(3, 3), false)
	assert_false(r.valid)
	assert_eq(r.kind, DropResolver.Kind.NONE)


func test_merge_onto_itself_is_not_merge() -> void:
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, a.id, STASH, Vector2i(0, 0), false)
	assert_eq(r.kind, DropResolver.Kind.NONE)
	assert_true(r.valid)


func test_merge_across_grids() -> void:
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	var b: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 10, Inventory.pocket_key(1))
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, a.id, Inventory.pocket_key(1), Vector2i.ZERO, false)
	assert_eq(r.kind, DropResolver.Kind.MERGE)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(b.stack_count, 30)


# --- 장착 ---

func test_equip_allowed() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_slot(_inv, pistol.id, EquipmentSlots.Slot.SECONDARY)
	assert_true(r.valid)
	assert_eq(r.kind, DropResolver.Kind.EQUIP)
	assert_true(r.command is EquipItemCommand)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(_inv.equipment.get_item(EquipmentSlots.Slot.SECONDARY), pistol)


func test_equip_wrong_category_denied() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_slot(_inv, pistol.id, EquipmentSlots.Slot.HELMET)
	assert_false(r.valid)
	assert_null(r.command)
	assert_eq(r.error, CommandResult.SLOT_NOT_ALLOWED)


func test_equip_occupied_slot_denied() -> void:
	var p1: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var p2: ItemInstance = _add(_pistol_def, Vector2i(0, 1))
	assert_true(_auth.execute(EquipItemCommand.new(p1.id, EquipmentSlots.Slot.SECONDARY)).ok)
	var r: DropResolver.Resolution = DropResolver.resolve_slot(_inv, p2.id, EquipmentSlots.Slot.SECONDARY)
	assert_false(r.valid)
	assert_eq(r.error, CommandResult.SLOT_OCCUPIED)
	assert_false(DropResolver.resolve_slot(_inv, p1.id, EquipmentSlots.Slot.SECONDARY).valid)


func test_unequip_by_dropping_on_grid() -> void:
	var pack: ItemInstance = _add(_pack_def, Vector2i(0, 0))
	assert_true(_auth.execute(EquipItemCommand.new(pack.id, EquipmentSlots.Slot.BACKPACK)).ok)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pack.id, STASH, Vector2i(5, 5), false)
	assert_true(r.valid)
	assert_true(_auth.execute(r.command).ok)
	assert_null(_inv.equipment.get_item(EquipmentSlots.Slot.BACKPACK))


# --- 중첩·잠금 ---

func test_nesting_rejected() -> void:
	var pack1: ItemInstance = _add(_pack_def, Vector2i(0, 0))
	var pack2: ItemInstance = _add(_pack_def, Vector2i(4, 0))
	var rig: ItemInstance = _add(_rig_def, Vector2i(8, 0))
	assert_true(_auth.execute(EquipItemCommand.new(pack1.id, EquipmentSlots.Slot.BACKPACK)).ok)
	var inner: StringName = Inventory.item_grid_key(pack1.id, 0)
	var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, pack2.id, inner, Vector2i.ZERO, false)
	assert_false(r.valid)
	assert_eq(r.error, CommandResult.NESTING_NOT_ALLOWED)
	assert_false(DropResolver.resolve_grid(_inv, rig.id, inner, Vector2i(0, 1), false).valid)
	# 자기 자신 안으로도 불가
	assert_false(DropResolver.resolve_grid(_inv, pack1.id, inner, Vector2i.ZERO, false).valid)


func test_non_container_into_container_is_fine() -> void:
	var pack: ItemInstance = _add(_pack_def, Vector2i(0, 0))
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(4, 0))
	assert_true(DropResolver.resolve_grid(_inv, pistol.id, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false).valid)


func test_locked_stash_blocks_everything_inside() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var ammo: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 10, Inventory.pocket_key(0))
	_inv.stash_locked = true
	# 스태시 안에서 이동·꺼내기·장착 모두 불가
	assert_eq(DropResolver.resolve_grid(_inv, pistol.id, STASH, Vector2i(5, 5), false).error, CommandResult.STASH_LOCKED)
	assert_false(DropResolver.resolve_grid(_inv, pistol.id, Inventory.pocket_key(1), Vector2i.ZERO, false).valid)
	assert_false(DropResolver.resolve_slot(_inv, pistol.id, EquipmentSlots.Slot.SECONDARY).valid)
	# 스태시로 넣기도 불가
	assert_eq(DropResolver.resolve_grid(_inv, ammo.id, STASH, Vector2i(5, 5), false).error, CommandResult.STASH_LOCKED)
	# 잠기지 않은 곳끼리는 계속 가능
	assert_true(DropResolver.resolve_grid(_inv, ammo.id, Inventory.pocket_key(1), Vector2i.ZERO, false).valid)


func test_locked_stash_blocks_container_contents() -> void:
	var pack: ItemInstance = _add(_pack_def, Vector2i(0, 0))
	var inner: StringName = Inventory.item_grid_key(pack.id, 0)
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0), 1, inner)
	_inv.stash_locked = true
	assert_false(DropResolver.resolve_grid(_inv, pistol.id, inner, Vector2i(2, 2), false).valid)
	assert_false(DropResolver.resolve_grid(_inv, pistol.id, Inventory.pocket_key(0), Vector2i.ZERO, false).valid)


func test_resolver_agrees_with_inventory_on_random_drops() -> void:
	# 유효 판정은 실제로 성공해야 하고, 무효 판정은 Inventory도 거부해야 한다 (고정 시드).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pack: ItemInstance = _add(_pack_def, Vector2i(0, 7))
	var items: Array[ItemInstance] = [pack]
	for i: int in range(6):
		items.append(_add(_ammo_def if i % 2 == 0 else _pistol_def, Vector2i((i % 5) * 2, i / 5), 5))
	var keys: Array[StringName] = [STASH, Inventory.pocket_key(0), Inventory.item_grid_key(pack.id, 0)]
	var executed: int = 0
	for _n: int in range(300):
		var item: ItemInstance = items[rng.randi_range(0, items.size() - 1)]
		if _inv.get_item(item.id) == null:
			continue
		var key: StringName = keys[rng.randi_range(0, keys.size() - 1)]
		var cell := Vector2i(rng.randi_range(-1, 9), rng.randi_range(-1, 9))
		var rot: bool = rng.randi() % 2 == 0
		var r: DropResolver.Resolution = DropResolver.resolve_grid(_inv, item.id, key, cell, rot)
		if r.valid and r.command != null:
			assert_true(_auth.execute(r.command).ok, "valid drop must succeed")
			executed += 1
		elif not r.valid:
			assert_false(_auth.execute(MoveItemCommand.new(item.id, key, cell, rot)).ok,
					"invalid drop must be rejected by Inventory too")
		assert_true(_inv.is_consistent())
	assert_gt(executed, 10)


# --- 반으로 나누기 ---

func test_plan_split_uses_first_free_spot() -> void:
	var ammo: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 31)
	var cmd: SplitStackCommand = DropResolver.plan_split(_inv, ammo.id)
	assert_not_null(cmd)
	assert_eq(cmd.amount, 15)
	assert_eq(cmd.cell, Vector2i(1, 0))
	assert_true(_auth.execute(cmd).ok)
	assert_eq(ammo.stack_count, 16)


func test_plan_split_null_cases() -> void:
	var single: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	assert_null(DropResolver.plan_split(_inv, single.id))
	var one: ItemInstance = _add(_ammo_def, Vector2i(5, 5), 1)
	assert_null(DropResolver.plan_split(_inv, one.id))
	assert_null(DropResolver.plan_split(_inv, 12345))
	# 가득 찬 1x1 주머니: 나눌 자리가 없다
	var pocket_ammo: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 10, Inventory.pocket_key(0))
	assert_null(DropResolver.plan_split(_inv, pocket_ammo.id))
	var stack: ItemInstance = _add(_ammo_def, Vector2i(7, 7), 10)
	_inv.stash_locked = true
	assert_null(DropResolver.plan_split(_inv, stack.id))


# --- 탭 이동 (find_nearest_placement) ---

func _rifle_def() -> ItemDef:
	var def: ItemDef = ItemDef.create(&"rifle", 4, 2)
	def.category = ItemDef.Category.WEAPON
	return def


func test_tap_move_to_empty_cell_places_there() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, pistol.id, STASH, Vector2i(6, 6), false)
	assert_true(r.valid)
	assert_eq(r.kind, DropResolver.Kind.MOVE)
	assert_true(r.cell.y == 6 and r.cell.x >= 5 and r.cell.x <= 6, "탭한 칸을 덮는 자리")
	assert_eq(r.key, STASH)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(pistol.position, r.cell)


func test_tap_move_snaps_to_nearest_when_item_would_not_fit() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	# 오른쪽 끝 칸 (9,3)을 탭하면 2x1이 들어가도록 (8,3)으로 보정
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, pistol.id, STASH, Vector2i(9, 3), false)
	assert_true(r.valid)
	assert_eq(r.cell, Vector2i(8, 3))
	assert_false(r.rotated)


func test_tap_move_uses_preferred_rotation() -> void:
	var rifle: ItemInstance = _add(_rifle_def(), Vector2i(0, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, rifle.id, STASH, Vector2i(5, 5), true)
	assert_true(r.valid)
	assert_true(r.rotated)
	assert_true(_auth.execute(r.command).ok)
	assert_true(rifle.rotated)


func test_tap_move_falls_back_to_other_rotation() -> void:
	# 3칸 폭 그리드 (배낭 안): 4x2 소총은 못 들어가고 회전하면 2x4가 들어간다 (4x4 그리드)
	var pack: ItemInstance = _add(_pack_def, Vector2i(0, 0))
	var inner: StringName = Inventory.item_grid_key(pack.id, 0)
	var rifle: ItemInstance = _add(_rifle_def(), Vector2i(4, 0))
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, rifle.id, inner, Vector2i(1, 1), true)
	assert_true(r.valid)
	assert_true(r.rotated)
	var r2: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, rifle.id, inner, Vector2i(1, 1), false)
	assert_true(r2.valid)
	assert_false(r2.rotated, "회전하지 않는 쪽을 선호하면 4x2가 그대로 들어간다")


func test_tap_move_no_space_is_invalid_with_error() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	var rig_item: ItemInstance = _add(_rig_def, Vector2i(5, 5))
	# 1x1 주머니는 2x1 권총이 들어갈 수 없다
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, pistol.id, Inventory.pocket_key(0), Vector2i.ZERO, false)
	assert_false(r.valid)
	assert_null(r.command)
	assert_eq(r.error, CommandResult.NO_SPACE)
	assert_not_null(rig_item)


func test_tap_move_onto_compatible_stack_merges() -> void:
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	var b: ItemInstance = _add(_ammo_def, Vector2i(5, 5), 30)
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, a.id, STASH, Vector2i(5, 5), false)
	assert_true(r.valid)
	assert_eq(r.kind, DropResolver.Kind.MERGE)
	assert_true(r.command is MergeStacksCommand)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(b.stack_count, 50)


func test_tap_move_onto_full_stack_is_invalid() -> void:
	var a: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 20)
	_add(_ammo_def, Vector2i(5, 5), 60)
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, a.id, STASH, Vector2i(5, 5), false)
	assert_false(r.valid)
	assert_eq(r.error, CommandResult.NO_SPACE)


func test_tap_move_same_spot_is_noop_valid() -> void:
	var ammo: ItemInstance = _add(_ammo_def, Vector2i(3, 3), 5)
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, ammo.id, STASH, Vector2i(3, 3), false)
	assert_true(r.valid)
	assert_eq(r.kind, DropResolver.Kind.NONE)
	assert_null(r.command)


func test_tap_move_refuses_nesting_and_locked_stash() -> void:
	var pack1: ItemInstance = _add(_pack_def, Vector2i(0, 0))
	var pack2: ItemInstance = _add(_pack_def, Vector2i(4, 0))
	var inner: StringName = Inventory.item_grid_key(pack1.id, 0)
	assert_eq(DropResolver.resolve_tap_grid(_inv, pack2.id, inner, Vector2i.ZERO, false).error,
			CommandResult.NESTING_NOT_ALLOWED)
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 5))
	_inv.stash_locked = true
	assert_eq(DropResolver.resolve_tap_grid(_inv, pistol.id, STASH, Vector2i(5, 5), false).error,
			CommandResult.STASH_LOCKED)


func test_tap_move_from_slot_into_grid() -> void:
	var pistol: ItemInstance = _auth.create_item(_pistol_def)
	assert_true(_inv.add_equipped(pistol, EquipmentSlots.Slot.SECONDARY).ok)
	var r: DropResolver.Resolution = DropResolver.resolve_tap_grid(_inv, pistol.id, STASH, Vector2i(4, 4), false)
	assert_true(r.valid)
	assert_true(_auth.execute(r.command).ok)
	assert_null(_inv.equipment.get_item(EquipmentSlots.Slot.SECONDARY))


# --- 장착 / 해제 계획 ---

func test_plan_equip_picks_first_free_compatible_slot() -> void:
	var rifle_def: ItemDef = _rifle_def()
	var first: ItemInstance = _add(rifle_def, Vector2i(0, 0))
	var second: ItemInstance = _add(rifle_def, Vector2i(0, 3))
	var third: ItemInstance = _add(rifle_def, Vector2i(0, 6))
	var r: DropResolver.Resolution = DropResolver.plan_equip(_inv, first.id)
	assert_true(r.valid)
	assert_eq((r.command as EquipItemCommand).slot, EquipmentSlots.Slot.PRIMARY_1)
	assert_true(_auth.execute(r.command).ok)
	r = DropResolver.plan_equip(_inv, second.id)
	assert_eq((r.command as EquipItemCommand).slot, EquipmentSlots.Slot.PRIMARY_2)
	assert_true(_auth.execute(r.command).ok)
	r = DropResolver.plan_equip(_inv, third.id)
	assert_false(r.valid)
	assert_eq(r.error, CommandResult.SLOT_OCCUPIED)


func test_plan_equip_rejects_incompatible_equipped_and_locked() -> void:
	var ammo: ItemInstance = _add(_ammo_def, Vector2i(0, 0), 5)
	assert_eq(DropResolver.plan_equip(_inv, ammo.id).error, CommandResult.SLOT_NOT_ALLOWED)
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(2, 0))
	assert_true(_auth.execute(DropResolver.plan_equip(_inv, pistol.id).command).ok)
	assert_false(DropResolver.plan_equip(_inv, pistol.id).valid, "이미 장착됨")
	var other: ItemInstance = _add(_pistol_def, Vector2i(4, 0))
	assert_false(DropResolver.plan_equip(_inv, other.id).valid, "권총집 사용 중")
	_inv.stash_locked = true
	assert_eq(DropResolver.plan_equip(_inv, other.id).error, CommandResult.STASH_LOCKED)


func test_plan_unequip_prefers_stash() -> void:
	var pistol: ItemInstance = _auth.create_item(_pistol_def)
	assert_true(_inv.add_equipped(pistol, EquipmentSlots.Slot.SECONDARY).ok)
	var r: DropResolver.Resolution = DropResolver.plan_unequip(_inv, pistol.id)
	assert_true(r.valid)
	assert_eq(r.key, STASH)
	assert_true(_auth.execute(r.command).ok)
	assert_eq(pistol.container_key, STASH)
	assert_null(_inv.equipment.get_item(EquipmentSlots.Slot.SECONDARY))


func test_plan_unequip_falls_back_to_backpack_rig_then_pockets() -> void:
	var inv := Inventory.new()   # 스태시 없음 (레이드 중)
	var auth := LocalAuthority.new(inv)
	var pack: ItemInstance = auth.create_item(_pack_def)
	var rig_item: ItemInstance = auth.create_item(_rig_def)
	assert_true(inv.add_equipped(pack, EquipmentSlots.Slot.BACKPACK).ok)
	assert_true(inv.add_equipped(rig_item, EquipmentSlots.Slot.RIG).ok)
	var pistol: ItemInstance = auth.create_item(_pistol_def)
	assert_true(inv.add_equipped(pistol, EquipmentSlots.Slot.SECONDARY).ok)
	var r: DropResolver.Resolution = DropResolver.plan_unequip(inv, pistol.id)
	assert_eq(r.key, Inventory.item_grid_key(pack.id, 0), "배낭이 먼저")
	# 배낭 그리드를 가득 채우면 리그 (1x2 그리드에는 2x1이 회전해서 들어간다)
	var filler_def: ItemDef = ItemDef.create(&"filler", 4, 4)
	var filler: ItemInstance = auth.create_item(filler_def)
	assert_true(inv.add_item(filler, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false).ok)
	r = DropResolver.plan_unequip(inv, pistol.id)
	assert_eq(r.key, Inventory.item_grid_key(rig_item.id, 0))
	assert_true(r.rotated)
	# 컨테이너 아이템은 컨테이너 그리드에 못 들어가므로 주머니(1x1)도 안 맞으면 NO_SPACE
	var pack_in_slot: DropResolver.Resolution = DropResolver.plan_unequip(inv, pack.id)
	assert_false(pack_in_slot.valid)
	assert_eq(pack_in_slot.error, CommandResult.NO_SPACE)
	# 1x1 아이템이면 주머니로 간다
	var tiny_def: ItemDef = ItemDef.create(&"glasses", 1, 1)
	tiny_def.category = ItemDef.Category.EYEWEAR
	var tiny: ItemInstance = auth.create_item(tiny_def)
	assert_true(inv.add_equipped(tiny, EquipmentSlots.Slot.EYE).ok)
	assert_true(inv.add_item(auth.create_item(ItemDef.create(&"block", 1, 2)), Inventory.item_grid_key(rig_item.id, 0), Vector2i.ZERO, false).ok)
	var r_tiny: DropResolver.Resolution = DropResolver.plan_unequip(inv, tiny.id)
	assert_true(r_tiny.valid)


func test_plan_unequip_not_equipped_or_locked_stash() -> void:
	var pistol: ItemInstance = _add(_pistol_def, Vector2i(0, 0))
	assert_false(DropResolver.plan_unequip(_inv, pistol.id).valid)
	assert_false(DropResolver.plan_unequip(_inv, 9999).valid)
	var eye_def: ItemDef = ItemDef.create(&"glasses", 1, 1)
	eye_def.category = ItemDef.Category.EYEWEAR
	var worn: ItemInstance = _auth.create_item(eye_def)
	assert_true(_inv.add_equipped(worn, EquipmentSlots.Slot.EYE).ok)
	_inv.stash_locked = true
	var r: DropResolver.Resolution = DropResolver.plan_unequip(_inv, worn.id)
	assert_true(r.valid)
	assert_ne(r.key, STASH, "잠긴 스태시는 건너뛴다")


# --- 제자리 회전 ---

func test_plan_rotate_in_place() -> void:
	var rifle: ItemInstance = _add(_rifle_def(), Vector2i(0, 0))
	var cmd: MoveItemCommand = DropResolver.plan_rotate_in_place(_inv, rifle.id, true)
	assert_not_null(cmd)
	assert_eq(cmd.cell, Vector2i(0, 0))
	assert_true(_auth.execute(cmd).ok)
	assert_true(rifle.rotated)
	assert_null(DropResolver.plan_rotate_in_place(_inv, 9999, true))


func test_plan_rotate_in_place_blocked_and_slot() -> void:
	var rifle: ItemInstance = _add(_rifle_def(), Vector2i(0, 0))
	_add(_ammo_def, Vector2i(0, 2), 1)   # 회전하면 (0,2)까지 닿아 겹침
	assert_null(DropResolver.plan_rotate_in_place(_inv, rifle.id, true))
	var worn: ItemInstance = _auth.create_item(_pistol_def)
	assert_true(_inv.add_equipped(worn, EquipmentSlots.Slot.SECONDARY).ok)
	assert_null(DropResolver.plan_rotate_in_place(_inv, worn.id, true))


func test_can_rotate_excludes_square_and_fixed() -> void:
	var square: ItemInstance = _auth.create_item(ItemDef.create(&"sq", 2, 2))
	var fixed: ItemInstance = _auth.create_item(ItemDef.create(&"fx", 3, 1, 1, false))
	var normal: ItemInstance = _auth.create_item(_pistol_def)
	assert_false(DropResolver.can_rotate(square))
	assert_false(DropResolver.can_rotate(fixed))
	assert_true(DropResolver.can_rotate(normal))
