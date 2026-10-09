extends GutTest
## M7 총기 모딩 규칙: 부품 아이템 장착·분리, 무기 크기 변화와 공간 검증, 저장.

var _auth: LocalAuthority
var _inv: Inventory
var _db: ContentDatabase
var _rifle: ItemInstance
const STASH := Inventory.STASH


func _part(id: StringName, type: StringName, delta: Vector2i = Vector2i.ZERO,
		sockets: Array[WeaponSocket] = []) -> WeaponPartDef:
	var p := WeaponPartDef.create(id, type)
	p.size_delta = delta
	p.sockets = sockets
	_db.add_part(p)
	var item_def := ItemDef.create(id, 1 + maxi(delta.x, 0), 1)
	item_def.category = ItemDef.Category.ATTACHMENT
	_db.add_item(item_def)
	return p


func _part_item(id: StringName, cell: Vector2i, key: StringName = STASH) -> ItemInstance:
	var item: ItemInstance = _auth.create_item(_db.get_item(id))
	assert_true(_inv.add_item(item, key, cell, false).ok)
	return item


func before_each() -> void:
	_inv = Inventory.new(Vector2i(10, 6))
	_auth = LocalAuthority.new(_inv)
	_db = ContentDatabase.new()
	_auth.content = _db
	_part(&"barrel_long", &"barrel", Vector2i(1, 0), [WeaponSocket.create(&"muzzle", &"muzzle")])
	_part(&"suppressor", &"muzzle", Vector2i(1, 0))
	_part(&"red_dot", &"optic")
	var receiver := WeaponPartDef.create(&"rifle_receiver", &"receiver")
	receiver.sockets = [WeaponSocket.create(&"barrel", &"barrel"), WeaponSocket.create(&"optic", &"optic")]
	_db.add_part(receiver)
	var rifle_def := ItemDef.create(&"rifle", 4, 2)
	rifle_def.category = ItemDef.Category.WEAPON
	_db.add_item(rifle_def)
	_rifle = _auth.create_item(rifle_def)
	_rifle.weapon = WeaponAssembly.new(receiver)
	assert_true(_inv.add_item(_rifle, STASH, Vector2i.ZERO, false).ok)


func _root() -> Array[StringName]:
	return []


func test_attach_moves_part_into_weapon_and_grows_weapon() -> void:
	var barrel := _part_item(&"barrel_long", Vector2i(0, 4))
	var r: CommandResult = _auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"barrel", barrel.id))
	assert_true(r.ok)
	assert_null(_inv.get_item(barrel.id))
	assert_eq(_rifle.size(), Vector2i(5, 2))
	assert_eq(_inv.get_grid(STASH).get_item_at(Vector2i(4, 1)), _rifle)
	assert_eq(_rifle.weapon.find_node([&"barrel"]).item, barrel)
	assert_eq(r.events.back().type, DomainEvent.WEAPON_CHANGED)
	assert_eq(r.events.back().data["size"], [5, 2])
	assert_true(_inv.is_consistent())


func test_attach_blocked_growth_fails_and_restores_everything() -> void:
	var blocker: ItemInstance = _auth.create_item(ItemDef.create(&"box", 1, 1))
	_inv.add_item(blocker, STASH, Vector2i(4, 0), false)
	var barrel := _part_item(&"barrel_long", Vector2i(0, 4))
	var r: CommandResult = _auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"barrel", barrel.id))
	assert_eq(r.error, CommandResult.NO_SPACE)
	assert_eq(_inv.get_item(barrel.id), barrel)
	assert_eq(barrel.position, Vector2i(0, 4))
	assert_eq(_rifle.size(), Vector2i(4, 2))
	assert_null(_rifle.weapon.find_node([&"barrel"]))
	assert_true(_inv.is_consistent())


func test_part_lying_in_the_growth_area_frees_its_own_space() -> void:
	var barrel := _part_item(&"barrel_long", Vector2i(4, 0))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"barrel", barrel.id)).ok)
	assert_eq(_rifle.size(), Vector2i(5, 2))
	assert_true(_inv.is_consistent())


func test_attach_validation_errors() -> void:
	var dot := _part_item(&"red_dot", Vector2i(0, 4))
	assert_eq(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"barrel", dot.id)).error,
			WeaponAssembly.WRONG_PART_TYPE)
	var junk: ItemInstance = _auth.create_item(ItemDef.create(&"junk", 1, 1))
	_inv.add_item(junk, STASH, Vector2i(2, 4), false)
	assert_eq(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"optic", junk.id)).error,
			CommandResult.NOT_A_PART)
	assert_eq(_auth.execute(AttachPartCommand.new(junk.id, _root(), &"optic", dot.id)).error,
			CommandResult.NOT_A_WEAPON)
	_inv.stash_locked = true
	assert_eq(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"optic", dot.id)).error,
			CommandResult.STASH_LOCKED)
	assert_eq(_inv.get_item(dot.id), dot)


func test_detach_order_and_return_same_items() -> void:
	var barrel := _part_item(&"barrel_long", Vector2i(0, 4))
	var sup := _part_item(&"suppressor", Vector2i(3, 4))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"barrel", barrel.id)).ok)
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, [&"barrel"], &"muzzle", sup.id)).ok)
	assert_eq(_rifle.size(), Vector2i(6, 2))
	assert_eq(_auth.execute(DetachPartCommand.new(_rifle.id, _root(), &"barrel")).error,
			CommandResult.HAS_ATTACHMENTS)
	var r: CommandResult = _auth.execute(DetachPartCommand.new(_rifle.id, [&"barrel"], &"muzzle"))
	assert_true(r.ok)
	assert_eq(_inv.get_item(sup.id), sup)
	assert_eq(_rifle.size(), Vector2i(5, 2))
	assert_true(_auth.execute(DetachPartCommand.new(_rifle.id, _root(), &"barrel")).ok)
	assert_eq(_inv.get_item(barrel.id), barrel)
	assert_eq(_rifle.size(), Vector2i(4, 2))
	assert_eq(_auth.execute(DetachPartCommand.new(_rifle.id, _root(), &"barrel")).error,
			WeaponAssembly.UNKNOWN_SOCKET)
	assert_true(_inv.is_consistent())


func test_detach_without_space_keeps_part_attached() -> void:
	var dot := _part_item(&"red_dot", Vector2i(0, 4))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"optic", dot.id)).ok)
	# 스태시를 꽉 채운다 (무기 자리 제외).
	var filler := ItemDef.create(&"filler", 1, 1)
	var grid: ItemGrid = _inv.get_grid(STASH)
	while true:
		var f: ItemInstance = _auth.create_item(filler)
		var p: ItemGrid.Placement = grid.find_free_placement(f)
		if p == null:
			break
		_inv.add_item(f, STASH, p.cell, p.rotated)
	for i: int in range(Inventory.POCKET_COUNT):
		_inv.add_item(_auth.create_item(filler), Inventory.pocket_key(i), Vector2i.ZERO, false)
	var r: CommandResult = _auth.execute(DetachPartCommand.new(_rifle.id, _root(), &"optic"))
	assert_eq(r.error, CommandResult.NO_SPACE)
	assert_eq(_rifle.weapon.find_node([&"optic"]).item, dot)
	assert_null(_inv.get_item(dot.id))
	assert_true(_inv.is_consistent())


func test_equipped_weapon_can_grow_freely() -> void:
	_inv.move_item(_rifle.id, STASH, Vector2i(0, 0), false)
	assert_true(_inv.equip(_rifle.id, EquipmentSlots.Slot.PRIMARY_1).ok)
	var blocker: ItemInstance = _auth.create_item(ItemDef.create(&"box", 1, 1))
	_inv.add_item(blocker, STASH, Vector2i(4, 0), false)
	var barrel := _part_item(&"barrel_long", Vector2i(0, 4))
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"barrel", barrel.id)).ok)
	assert_eq(_rifle.size(), Vector2i(5, 2))
	assert_true(_inv.is_consistent())


func test_save_round_trip_keeps_attached_part_items() -> void:
	var barrel := _part_item(&"barrel_long", Vector2i(0, 4))
	barrel.found_in_raid = true
	assert_true(_auth.execute(AttachPartCommand.new(_rifle.id, _root(), &"barrel", barrel.id)).ok)
	var data: Dictionary = SaveSerializer.to_dict(_inv, _auth.ids)
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	var loaded: SaveSerializer.LoadResult = SaveSerializer.from_dict(parsed, _db)
	assert_true(loaded.ok, loaded.error)
	var rifle: ItemInstance = loaded.inventory.get_item(_rifle.id)
	var node: WeaponPartNode = rifle.weapon.find_node([&"barrel"])
	assert_not_null(node.item)
	assert_eq(node.item.id, barrel.id)
	assert_true(node.item.found_in_raid)
	assert_eq(rifle.size(), Vector2i(5, 2))
	assert_gt(loaded.ids.peek(), barrel.id)
	assert_true(loaded.inventory.is_consistent())
