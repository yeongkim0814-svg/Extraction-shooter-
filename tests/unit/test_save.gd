extends GutTest
## SaveSerializer / SaveMigrations 테스트 (M3): JSON 왕복 보존, id 연속성, 실패 케이스, 버전 거부.

const Slot := EquipmentSlots.Slot

var _db: ContentDatabase
var _ids: IdGenerator
var _inv: Inventory

# 아이템 정의
var _rifle: ItemDef
var _mag: ItemDef
var _ammo: ItemDef
var _med: ItemDef
var _big: ItemDef
var _pack: ItemDef
var _rig: ItemDef

# 무기 부품
var _rcv: WeaponPartDef
var _hg: WeaponPartDef
var _grip_a: WeaponPartDef
var _grip_b: WeaponPartDef
var _barrel: WeaponPartDef
var _stock_fold: WeaponPartDef
var _supp: WeaponPartDef


func before_each() -> void:
	_db = ContentDatabase.new()
	_ids = IdGenerator.new()
	_inv = Inventory.new(Vector2i(10, 8))

	_rifle = ItemDef.create(&"rifle", 4, 2)
	_rifle.category = ItemDef.Category.WEAPON
	_mag = ItemDef.create(&"mag", 1, 2)
	_mag.category = ItemDef.Category.MAGAZINE
	_ammo = ItemDef.create(&"ammo", 1, 1, 60)
	_ammo.category = ItemDef.Category.AMMO
	_med = ItemDef.create(&"med", 1, 1, 5)
	_big = ItemDef.create(&"big", 2, 3)
	_pack = ItemDef.create(&"pack", 3, 4)
	_pack.category = ItemDef.Category.BACKPACK
	_pack.grids = [Vector2i(5, 5)] as Array[Vector2i]
	_rig = ItemDef.create(&"rig", 3, 2)
	_rig.category = ItemDef.Category.RIG
	_rig.grids = [Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 1)] as Array[Vector2i]
	for def: ItemDef in [_rifle, _mag, _ammo, _med, _big, _pack, _rig]:
		_db.add_item(def)

	_rcv = WeaponPartDef.create(&"rcv", &"receiver")
	_rcv.sockets.append(WeaponSocket.create(&"handguard", &"handguard", true))
	_rcv.sockets.append(WeaponSocket.create(&"barrel", &"barrel", true))
	_rcv.sockets.append(WeaponSocket.create(&"stock", &"stock"))
	_hg = WeaponPartDef.create(&"hg", &"handguard")
	_hg.sockets.append(WeaponSocket.create(&"grip", &"grip"))
	_grip_a = WeaponPartDef.create(&"grip_a", &"grip")
	_grip_a.conflicts.append(&"stock_fold")
	_grip_b = WeaponPartDef.create(&"grip_b", &"grip")
	_barrel = WeaponPartDef.create(&"barrel", &"barrel")
	var muzzle: WeaponSocket = WeaponSocket.create(&"muzzle", &"muzzle")
	_barrel.sockets.append(muzzle)
	_stock_fold = WeaponPartDef.create(&"stock_fold", &"stock")
	_supp = WeaponPartDef.create(&"supp", &"muzzle")
	for part: WeaponPartDef in [_rcv, _hg, _grip_a, _grip_b, _barrel, _stock_fold, _supp]:
		_db.add_part(part)

	for entry: Array in [[&"fmj", &"556"], [&"ap", &"556"], [&"x762", &"762"]]:
		_db.add_ammo(AmmoDef.create(entry[0], entry[1], 40.0, 20.0))


func _make(def: ItemDef, stack: int = 1, fir: bool = false) -> ItemInstance:
	var item := ItemInstance.new(_ids.next_id(), def, stack)
	item.found_in_raid = fir
	return item


func _path(names: Array) -> Array[StringName]:
	var p: Array[StringName] = []
	p.assign(names)
	return p


## 리시버 → 핸드가드 → 손잡이, 총열 → 소음기가 달린 무기.
func _weapon_item() -> ItemInstance:
	var item: ItemInstance = _make(_rifle)
	var w := WeaponAssembly.new(_rcv)
	assert_eq(w.attach(_path([]), &"handguard", _hg), WeaponAssembly.OK)
	assert_eq(w.attach(_path([&"handguard"]), &"grip", _grip_a), WeaponAssembly.OK)
	assert_eq(w.attach(_path([]), &"barrel", _barrel), WeaponAssembly.OK)
	assert_eq(w.attach(_path([&"barrel"]), &"muzzle", _supp), WeaponAssembly.OK)
	item.weapon = w
	return item


func _mag_item() -> ItemInstance:
	var item: ItemInstance = _make(_mag)
	var m := Magazine.new(&"556", 30)
	m.load_rounds(_db.get_ammo(&"fmj"), 4)
	m.load_rounds(_db.get_ammo(&"ap"), 2)
	m.load_rounds(_db.get_ammo(&"fmj"), 1)
	item.magazine = m
	return item


func _add(item: ItemInstance, key: StringName, x: int, y: int, rotated: bool = false) -> void:
	assert_true(_inv.add_item(item, key, Vector2i(x, y), rotated).ok, "add %s" % item.def.id)


## 스태시·주머니·배낭(내용물)·리그(그리드 3개)·무기·탄창·회전 아이템·스태시 잠금을 모두 가진 인벤토리.
func _populate() -> Dictionary:
	var named: Dictionary = {}
	var rifle: ItemInstance = _weapon_item()
	assert_true(_inv.add_equipped(rifle, Slot.PRIMARY_1).ok)
	named["rifle"] = rifle

	var pack: ItemInstance = _make(_pack)
	assert_true(_inv.add_equipped(pack, Slot.BACKPACK).ok)
	named["pack"] = pack
	var pack_key: StringName = Inventory.item_grid_key(pack.id, 0)
	var mag: ItemInstance = _mag_item()
	_add(mag, pack_key, 1, 1)
	named["mag"] = mag
	var med: ItemInstance = _make(_med, 3, true)
	_add(med, pack_key, 0, 0)
	named["med"] = med
	var big_in_pack: ItemInstance = _make(_big)
	_add(big_in_pack, pack_key, 2, 3, true)  # 회전: 3×2 차지
	named["big_in_pack"] = big_in_pack

	var rig: ItemInstance = _make(_rig)
	assert_true(_inv.add_equipped(rig, Slot.RIG).ok)
	named["rig"] = rig
	var rig_ammo: ItemInstance = _make(_ammo, 45, true)
	_add(rig_ammo, Inventory.item_grid_key(rig.id, 0), 1, 0)
	var rig_med: ItemInstance = _make(_med, 2)
	_add(rig_med, Inventory.item_grid_key(rig.id, 2), 2, 0)
	named["rig_ammo"] = rig_ammo
	named["rig_med"] = rig_med

	var pocket: ItemInstance = _make(_med, 5, true)
	_add(pocket, Inventory.pocket_key(2), 0, 0)
	named["pocket"] = pocket

	var stash_ammo: ItemInstance = _make(_ammo, 60)
	_add(stash_ammo, Inventory.STASH, 7, 5)
	var stash_big: ItemInstance = _make(_big)
	_add(stash_big, Inventory.STASH, 2, 2, true)
	named["stash_ammo"] = stash_ammo
	named["stash_big"] = stash_big
	var stash_mag: ItemInstance = _mag_item()
	_add(stash_mag, Inventory.STASH, 9, 0)
	named["stash_mag"] = stash_mag

	_inv.stash_locked = true
	return named


func _roundtrip_dict(inv: Inventory, ids: IdGenerator) -> Dictionary:
	var text: String = JSON.stringify(SaveSerializer.to_dict(inv, ids))
	var parsed: Variant = JSON.parse_string(text)
	assert_typeof(parsed, TYPE_DICTIONARY)
	return parsed


func _load(data: Dictionary) -> SaveSerializer.LoadResult:
	return SaveSerializer.from_dict(data, _db)


## 한 번 저장한 뒤 JSON을 거쳐 불러온다.
func _roundtrip() -> SaveSerializer.LoadResult:
	return _load(_roundtrip_dict(_inv, _ids))


func _is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return true
		TYPE_ARRAY:
			for element: Variant in value as Array:
				if not _is_json_safe(element):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value as Dictionary:
				if typeof(key) != TYPE_STRING or not _is_json_safe((value as Dictionary)[key]):
					return false
			return true
	return false


func _dump_tree(node: WeaponPartNode) -> Dictionary:
	var children: Dictionary = {}
	for socket_name: StringName in node.children:
		children[String(socket_name)] = _dump_tree(node.children[socket_name])
	return {"part": String(node.def.id), "children": children}


func _snapshot(inv: Inventory) -> Dictionary:
	var snap: Dictionary = {}
	for item: ItemInstance in inv.get_items():
		snap[item.id] = {
			"def": item.def.id, "stack": item.stack_count, "fir": item.found_in_raid,
			"key": item.container_key, "pos": item.position, "rot": item.rotated,
			"grids": item.grids.size(),
			"weapon": _dump_tree(item.weapon.root) if item.weapon != null else null,
			"rounds": item.magazine.get_rounds() if item.magazine != null else null,
			"caliber": item.magazine.caliber if item.magazine != null else null,
			"capacity": item.magazine.capacity if item.magazine != null else null,
		}
	return snap


# --- 왕복 ---

func test_roundtrip_preserves_everything() -> void:
	_populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	assert_true(result.ok, result.error)
	assert_eq(result.error, "")
	assert_true(result.inventory.is_consistent())
	assert_eq(_snapshot(result.inventory), _snapshot(_inv))
	assert_eq(result.inventory.get_items().size(), _inv.get_items().size())


func test_roundtrip_is_idempotent() -> void:
	_populate()
	var first: Dictionary = SaveSerializer.to_dict(_inv, _ids)
	var result: SaveSerializer.LoadResult = _load(_roundtrip_dict(_inv, _ids))
	var second: Dictionary = SaveSerializer.to_dict(result.inventory, result.ids)
	assert_eq(JSON.stringify(second), JSON.stringify(first))


func test_to_dict_is_json_safe_and_deterministic() -> void:
	_populate()
	var a: Dictionary = SaveSerializer.to_dict(_inv, _ids)
	var b: Dictionary = SaveSerializer.to_dict(_inv, _ids)
	assert_eq(JSON.stringify(a), JSON.stringify(b))
	assert_eq(a["version"], 1)
	assert_eq(a["stash_size"], [10, 8])
	assert_eq(a["stash_locked"], true)
	var text: String = JSON.stringify(a)
	assert_ne(text, "")
	assert_true(_is_json_safe(a), "only Dictionary/Array/String/int/float/bool")


func test_to_dict_only_root_items_at_top_level() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = SaveSerializer.to_dict(_inv, _ids)
	var root_ids: Array = []
	for item: Dictionary in data["items"]:
		root_ids.append(item["id"])
		assert_false(String(item["container"]).begins_with("item_"))
	assert_true(root_ids.has((named["pack"] as ItemInstance).id))
	assert_false(root_ids.has((named["mag"] as ItemInstance).id))
	assert_false(root_ids.has((named["rig_ammo"] as ItemInstance).id))


func test_backpack_with_contents_equipped() -> void:
	var named: Dictionary = _populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	var pack: ItemInstance = result.inventory.equipment.get_item(Slot.BACKPACK)
	assert_not_null(pack)
	assert_eq(pack.id, (named["pack"] as ItemInstance).id)
	assert_eq(pack.container_key, &"slot_backpack")
	assert_eq(pack.grids.size(), 1)
	assert_eq(pack.grids[0].get_items().size(), 3)
	var mag: ItemInstance = result.inventory.get_item((named["mag"] as ItemInstance).id)
	assert_eq(mag.container_key, Inventory.item_grid_key(pack.id, 0))
	assert_eq(mag.position, Vector2i(1, 1))
	assert_eq(pack.grids[0].get_item_at(Vector2i(1, 1)), mag)


func test_rig_with_multiple_grids() -> void:
	var named: Dictionary = _populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	var rig: ItemInstance = result.inventory.equipment.get_item(Slot.RIG)
	assert_eq(rig.grids.size(), 3)
	assert_eq(rig.grids[0].get_items().size(), 1)
	assert_eq(rig.grids[1].get_items().size(), 0)
	assert_eq(rig.grids[2].get_items().size(), 1)
	var ammo: ItemInstance = rig.grids[0].get_item_at(Vector2i(1, 0))
	assert_eq(ammo.id, (named["rig_ammo"] as ItemInstance).id)
	assert_eq(ammo.stack_count, 45)
	assert_true(ammo.found_in_raid)
	assert_eq(rig.grids[2].get_item_at(Vector2i(2, 0)).container_key, Inventory.item_grid_key(rig.id, 2))


func test_pockets_and_stash_items() -> void:
	var named: Dictionary = _populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	var pocket: ItemInstance = result.inventory.get_item((named["pocket"] as ItemInstance).id)
	assert_eq(pocket.container_key, &"pocket_2")
	assert_eq(pocket.stack_count, 5)
	assert_true(pocket.found_in_raid)
	var stash_ammo: ItemInstance = result.inventory.get_item((named["stash_ammo"] as ItemInstance).id)
	assert_eq(stash_ammo.container_key, Inventory.STASH)
	assert_eq(stash_ammo.position, Vector2i(7, 5))
	assert_eq(stash_ammo.stack_count, 60)
	assert_false(stash_ammo.found_in_raid)
	var stash: ItemGrid = result.inventory.get_grid(Inventory.STASH)
	assert_eq(stash.width, 10)
	assert_eq(stash.height, 8)


func test_rotated_item_roundtrip() -> void:
	var named: Dictionary = _populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	var stash_big: ItemInstance = result.inventory.get_item((named["stash_big"] as ItemInstance).id)
	assert_true(stash_big.rotated)
	assert_eq(stash_big.position, Vector2i(2, 2))
	assert_eq(stash_big.size(), Vector2i(3, 2))
	# 회전된 점유 칸이 그리드에 반영돼 있다.
	var stash: ItemGrid = result.inventory.get_grid(Inventory.STASH)
	assert_eq(stash.get_item_at(Vector2i(4, 3)), stash_big)
	assert_null(stash.get_item_at(Vector2i(2, 4)))
	var in_pack: ItemInstance = result.inventory.get_item((named["big_in_pack"] as ItemInstance).id)
	assert_true(in_pack.rotated)
	var unrotated: ItemInstance = result.inventory.get_item((named["pocket"] as ItemInstance).id)
	assert_false(unrotated.rotated)


func test_weapon_tree_roundtrip() -> void:
	var named: Dictionary = _populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	var rifle: ItemInstance = result.inventory.equipment.get_item(Slot.PRIMARY_1)
	assert_eq(rifle.id, (named["rifle"] as ItemInstance).id)
	assert_not_null(rifle.weapon)
	assert_eq(rifle.weapon.root.def, _rcv)
	assert_eq(rifle.weapon.find_node(_path([&"handguard", &"grip"])).def, _grip_a)
	assert_eq(rifle.weapon.find_node(_path([&"barrel", &"muzzle"])).def, _supp)
	assert_null(rifle.weapon.find_node(_path([&"stock"])))
	assert_true(rifle.weapon.is_operational())
	assert_eq(rifle.weapon.get_parts().size(), 5)
	assert_null(result.inventory.get_item((named["pack"] as ItemInstance).id).weapon)


func test_magazine_mixed_rounds_roundtrip() -> void:
	var named: Dictionary = _populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	var mag: ItemInstance = result.inventory.get_item((named["mag"] as ItemInstance).id)
	assert_not_null(mag.magazine)
	assert_eq(mag.magazine.caliber, &"556")
	assert_eq(mag.magazine.capacity, 30)
	assert_eq(mag.magazine.get_rounds(),
			[&"fmj", &"fmj", &"fmj", &"fmj", &"ap", &"ap", &"fmj"] as Array[StringName])
	assert_eq(mag.magazine.pop_round(), &"fmj")  # 위(마지막)부터 발사
	assert_eq(mag.magazine.pop_round(), &"ap")
	var stash_mag: ItemInstance = result.inventory.get_item((named["stash_mag"] as ItemInstance).id)
	assert_eq(stash_mag.magazine.count(), 7)


func test_empty_magazine_roundtrip() -> void:
	var mag: ItemInstance = _make(_mag)
	mag.magazine = Magazine.new(&"556", 20)
	_add(mag, Inventory.STASH, 0, 0)
	var result: SaveSerializer.LoadResult = _roundtrip()
	assert_true(result.ok, result.error)
	var loaded: ItemInstance = result.inventory.get_item(mag.id)
	assert_true(loaded.magazine.is_empty())
	assert_eq(loaded.magazine.capacity, 20)


func test_stash_locked_roundtrip() -> void:
	_populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	assert_true(result.ok, result.error)
	assert_true(result.inventory.stash_locked)
	# 잠금이 실제로 적용돼 있다.
	var stash_ammo: ItemInstance = result.inventory.get_item(
			(result.inventory.get_grid(Inventory.STASH).get_item_at(Vector2i(7, 5))).id)
	assert_false(result.inventory.move_item(stash_ammo.id, Inventory.STASH, Vector2i.ZERO, false).ok)


func test_stash_unlocked_roundtrip() -> void:
	_populate()
	_inv.stash_locked = false
	var result: SaveSerializer.LoadResult = _roundtrip()
	assert_true(result.ok, result.error)
	assert_false(result.inventory.stash_locked)


func test_no_stash_roundtrip() -> void:
	_inv = Inventory.new()
	var pocket: ItemInstance = _make(_med, 2)
	_add(pocket, Inventory.pocket_key(1), 0, 0)
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	assert_eq(int(data["stash_size"][0]), 0)
	assert_eq(int(data["stash_size"][1]), 0)
	var result: SaveSerializer.LoadResult = _load(data)
	assert_true(result.ok, result.error)
	assert_null(result.inventory.get_grid(Inventory.STASH))
	assert_eq(result.inventory.get_item(pocket.id).stack_count, 2)
	assert_true(result.inventory.is_consistent())


func test_empty_inventory_roundtrip() -> void:
	var result: SaveSerializer.LoadResult = _roundtrip()
	assert_true(result.ok, result.error)
	assert_eq(result.inventory.get_items().size(), 0)
	assert_true(result.inventory.is_consistent())
	assert_eq(result.ids.peek(), 1)


func test_loaded_inventory_is_usable() -> void:
	var named: Dictionary = _populate()
	var result: SaveSerializer.LoadResult = _roundtrip()
	result.inventory.stash_locked = false
	var pocket: ItemInstance = result.inventory.get_item((named["pocket"] as ItemInstance).id)
	assert_true(result.inventory.move_item(pocket.id, Inventory.STASH, Vector2i(0, 0), false).ok)
	assert_true(result.inventory.is_consistent())
	var fresh := ItemInstance.new(result.ids.next_id(), _med)
	assert_true(result.inventory.add_item(fresh, Inventory.STASH, Vector2i(0, 7), false).ok)


# --- IdGenerator 연속성 ---

func test_id_generator_continuity() -> void:
	_populate()
	var saved_next: int = _ids.peek()
	var result: SaveSerializer.LoadResult = _roundtrip()
	assert_eq(result.ids.peek(), saved_next)
	var max_id: int = 0
	for item: ItemInstance in result.inventory.get_items():
		max_id = maxi(max_id, item.id)
	assert_gt(result.ids.next_id(), max_id)


func test_id_generator_above_loaded_ids_even_if_next_id_low() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	data["next_id"] = 1
	var result: SaveSerializer.LoadResult = _load(data)
	assert_true(result.ok, result.error)
	var max_id: int = 0
	for item: ItemInstance in result.inventory.get_items():
		max_id = maxi(max_id, item.id)
	assert_eq(result.ids.peek(), max_id + 1)


func test_id_generator_respects_higher_saved_next_id() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	data["next_id"] = 500
	var result: SaveSerializer.LoadResult = _load(data)
	assert_eq(result.ids.peek(), 500)


func test_id_generator_counts_burned_ids() -> void:
	# 발급만 되고 인벤토리에는 없는 id(버려진 아이템)도 저장된 next_id로 재사용되지 않는다.
	var pocket: ItemInstance = _make(_med)
	_add(pocket, Inventory.pocket_key(0), 0, 0)
	for _i: int in range(5):
		_ids.next_id()
	var result: SaveSerializer.LoadResult = _roundtrip()
	assert_eq(result.ids.peek(), _ids.peek())


# --- 정수/실수 처리 ---

func test_float_numbers_from_json_are_handled() -> void:
	_populate()
	var text: String = JSON.stringify(SaveSerializer.to_dict(_inv, _ids))
	var parsed: Dictionary = JSON.parse_string(text)
	assert_typeof(parsed["next_id"], TYPE_FLOAT)  # JSON.parse_string은 정수를 float로 돌려준다.
	var result: SaveSerializer.LoadResult = _load(parsed)
	assert_true(result.ok, result.error)
	for item: ItemInstance in result.inventory.get_items():
		assert_typeof(item.id, TYPE_INT)
		assert_typeof(item.stack_count, TYPE_INT)
		assert_typeof(item.position.x, TYPE_INT)


func test_non_integral_float_rejected() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	(data["items"] as Array)[0]["stack"] = 1.5
	assert_false(_load(data).ok)


# --- 실패 케이스 ---

func _assert_fails(data: Dictionary, expected_fragment: String = "") -> SaveSerializer.LoadResult:
	var result: SaveSerializer.LoadResult = _load(data)
	assert_false(result.ok)
	assert_ne(result.error, "", "error message should describe the failure")
	assert_null(result.inventory, "no partial inventory on failure")
	assert_null(result.ids)
	if not expected_fragment.is_empty():
		assert_string_contains(result.error, expected_fragment)
	return result


func _item_dict(data: Dictionary, item_id: int) -> Dictionary:
	return _find_item(data["items"], item_id)


func _find_item(items: Array, item_id: int) -> Dictionary:
	for entry: Dictionary in items:
		if int(entry["id"]) == item_id:
			return entry
		for grid: Array in entry.get("grids", []):
			var found: Dictionary = _find_item(grid, item_id)
			if not found.is_empty():
				return found
	return {}


func test_fail_future_version() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	data["version"] = SaveMigrations.CURRENT_VERSION + 1
	_assert_fails(data, "newer")


func test_fail_missing_or_invalid_version() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	data.erase("version")
	_assert_fails(data, "version")
	data["version"] = 0
	_assert_fails(data, "version")
	data["version"] = "one"
	_assert_fails(data, "version")


func test_fail_unknown_item_def() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["rig_ammo"] as ItemInstance).id)["def"] = "ghost"  # 중첩 깊은 곳
	_assert_fails(data, "ghost")


func test_fail_unknown_part_root_and_child() -> void:
	var named: Dictionary = _populate()
	var rifle_id: int = (named["rifle"] as ItemInstance).id
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, rifle_id)["weapon"]["part"] = "ghost_receiver"
	_assert_fails(data, "ghost_receiver")
	data = _roundtrip_dict(_inv, _ids)
	_item_dict(data, rifle_id)["weapon"]["children"]["barrel"]["part"] = "ghost_barrel"
	_assert_fails(data, "ghost_barrel")


func test_fail_unknown_ammo() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	var mag: Dictionary = _item_dict(data, (named["mag"] as ItemInstance).id)
	(mag["magazine"]["rounds"] as Array)[2] = "ghost_ammo"
	_assert_fails(data, "ghost_ammo")


func test_fail_magazine_wrong_caliber_or_overflow() -> void:
	var named: Dictionary = _populate()
	var mag_id: int = (named["mag"] as ItemInstance).id
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	(_item_dict(data, mag_id)["magazine"]["rounds"] as Array)[0] = "x762"
	_assert_fails(data)
	data = _roundtrip_dict(_inv, _ids)
	_item_dict(data, mag_id)["magazine"]["capacity"] = 3
	_assert_fails(data)
	data = _roundtrip_dict(_inv, _ids)
	_item_dict(data, mag_id)["magazine"]["capacity"] = 0
	_assert_fails(data)


func test_fail_placement_overlap_in_stash() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	# 스태시 탄약을 회전된 큰 아이템(2,2)과 겹치는 칸으로
	_item_dict(data, (named["stash_ammo"] as ItemInstance).id)["cell"] = [3, 2]
	_assert_fails(data, "place")


func test_fail_placement_out_of_bounds_root() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["pocket"] as ItemInstance).id)["cell"] = [1, 0]  # 주머니는 1×1
	_assert_fails(data)


func test_fail_placement_nested_overlap() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["med"] as ItemInstance).id)["cell"] = [1, 1]  # 탄창과 겹침
	_assert_fails(data, "place")


func test_fail_placement_nested_out_of_bounds() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["rig_med"] as ItemInstance).id)["cell"] = [3, 0]  # 그리드 폭 3 → 범위 밖
	_assert_fails(data)


func test_fail_equipment_slot_wrong_item() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["pack"] as ItemInstance).id)["container"] = "slot_rig"
	_assert_fails(data)


func test_fail_equipment_slot_occupied() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["rig"] as ItemInstance).id)["container"] = "slot_backpack"
	_assert_fails(data)  # 배낭 슬롯에 리그 (카테고리 불일치 + 점유)


func test_fail_unknown_container() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["pocket"] as ItemInstance).id)["container"] = "pocket_9"
	_assert_fails(data)


func test_fail_stash_item_without_stash() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	data["stash_size"] = [0, 0]
	_assert_fails(data)


func test_fail_invalid_weapon_unknown_socket() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	var children: Dictionary = _item_dict(data, (named["rifle"] as ItemInstance).id)["weapon"]["children"]
	children["scope_rail"] = children["barrel"]
	_assert_fails(data, "unknown_socket")


func test_fail_invalid_weapon_wrong_part_type() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	var children: Dictionary = _item_dict(data, (named["rifle"] as ItemInstance).id)["weapon"]["children"]
	children["stock"] = {"part": "supp", "children": {}}
	_assert_fails(data, "wrong_part_type")


func test_fail_invalid_weapon_conflict() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	var children: Dictionary = _item_dict(data, (named["rifle"] as ItemInstance).id)["weapon"]["children"]
	children["stock"] = {"part": "stock_fold", "children": {}}  # grip_a와 충돌
	_assert_fails(data, "conflict")


func test_fail_weapon_data_on_non_weapon() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["pocket"] as ItemInstance).id)["weapon"] = {"part": "rcv", "children": {}}
	_assert_fails(data)


func test_fail_duplicate_ids() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["rig_med"] as ItemInstance).id)["id"] = (named["pocket"] as ItemInstance).id
	_assert_fails(data, "duplicate")


func test_fail_stack_exceeds_max() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["stash_ammo"] as ItemInstance).id)["stack"] = 61
	_assert_fails(data, "stack")
	_item_dict(data, (named["stash_ammo"] as ItemInstance).id)["stack"] = 0
	_assert_fails(data, "stack")


func test_fail_nested_container_not_allowed() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	# 리그 첫 그리드에 배낭 정의를 가진 아이템을 끼워 넣는다 (배낭 안 배낭 유사).
	var rig: Dictionary = _item_dict(data, (named["rig"] as ItemInstance).id)
	var inner: Dictionary = {
		"id": 900, "def": "pack", "stack": 1, "fir": false,
		"container": "item_%d_1" % (named["rig"] as ItemInstance).id,
		"cell": [0, 0], "rotated": false, "grids": [[]],
	}
	rig["grids"][1].append(inner)
	_assert_fails(data)


func test_fail_child_container_key_mismatch() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	_item_dict(data, (named["mag"] as ItemInstance).id)["container"] = "stash"
	_assert_fails(data, "container")


func test_fail_root_item_in_item_grid() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	var pack_id: int = (named["pack"] as ItemInstance).id
	var stray: Dictionary = {
		"id": 901, "def": "med", "stack": 1, "fir": false,
		"container": "item_%d_0" % pack_id, "cell": [4, 4], "rotated": false, "grids": [],
	}
	(data["items"] as Array).append(stray)
	_assert_fails(data)


func test_fail_grid_count_mismatch() -> void:
	var named: Dictionary = _populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	((_item_dict(data, (named["rig"] as ItemInstance).id))["grids"] as Array).pop_back()
	_assert_fails(data, "grids")


func test_fail_malformed_structure() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	data["items"] = "nope"
	_assert_fails(data)
	data = _roundtrip_dict(_inv, _ids)
	(data["items"] as Array)[0] = 5
	_assert_fails(data)
	data = _roundtrip_dict(_inv, _ids)
	data["stash_size"] = [10]
	_assert_fails(data, "stash_size")
	data = _roundtrip_dict(_inv, _ids)
	data["stash_size"] = [0, 4]
	_assert_fails(data, "stash_size")


func test_failure_does_not_touch_source_data() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	var before: String = JSON.stringify(data)
	(data["items"] as Array)[0]["def"] = "ghost"
	var broken: String = JSON.stringify(data)
	_assert_fails(data)
	assert_eq(JSON.stringify(data), broken)
	assert_ne(before, broken)


# --- 마이그레이션 ---

func test_current_version_constant() -> void:
	assert_eq(SaveMigrations.CURRENT_VERSION, 1)
	assert_eq(SaveSerializer.to_dict(_inv, _ids)["version"], SaveMigrations.CURRENT_VERSION)


func test_migrate_current_version_is_identity() -> void:
	_populate()
	var data: Dictionary = _roundtrip_dict(_inv, _ids)
	var migrated: Dictionary = SaveMigrations.migrate(data)
	assert_eq(JSON.stringify(migrated), JSON.stringify(data))


func test_migrate_does_not_mutate_input() -> void:
	var data: Dictionary = {"version": 1, "items": []}
	var migrated: Dictionary = SaveMigrations.migrate(data)
	migrated["items"].append(1)
	assert_eq((data["items"] as Array).size(), 0)


func test_migrate_leaves_future_version_untouched() -> void:
	var data: Dictionary = {"version": 99, "items": []}
	assert_eq(SaveMigrations.migrate(data)["version"], 99)


func test_migrate_without_step_does_not_loop_forever() -> void:
	# 버전 0에는 적용할 단계가 없다: 그대로 돌려주고 from_dict가 거부한다.
	var data: Dictionary = {"version": 0, "items": []}
	assert_eq(SaveMigrations.migrate(data)["version"], 0)
	assert_false(_load(data).ok)


func test_version_of_handles_float_and_garbage() -> void:
	assert_eq(SaveMigrations.version_of({"version": 1.0}), 1)
	assert_eq(SaveMigrations.version_of({"version": "1"}), 0)
	assert_eq(SaveMigrations.version_of({}), 0)
