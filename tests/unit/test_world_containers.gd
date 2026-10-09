extends GutTest
## 월드 컨테이너(시체·상자) 열기/닫기: Inventory.attach_external / detach_external, Open/CloseContainerCommand (M8).

var _authority: LocalAuthority
var _ammo: ItemDef
var _gun: ItemDef
var _bag: ItemDef


func before_each() -> void:
	_authority = LocalAuthority.new(Inventory.new(Vector2i.ZERO))
	_authority.inventory.stash_locked = true
	_ammo = ItemDef.create(&"ammo", 1, 1, 60)
	_gun = ItemDef.create(&"gun", 3, 1)
	_bag = ItemDef.create(&"bag", 2, 2)
	_bag.category = ItemDef.Category.BACKPACK
	_bag.grids = [Vector2i(3, 3)]


func _corpse() -> Dictionary:
	var grid := ItemGrid.new(6, 4)
	var gun: ItemInstance = _authority.create_item(_gun)
	var ammo: ItemInstance = _authority.create_item(_ammo, 20)
	assert_true(grid.try_place(gun, Vector2i(0, 0), false))
	assert_true(grid.try_place(ammo, Vector2i(5, 3), false))
	var key: StringName = _authority.register_container(grid, "시체")
	return {"key": key, "grid": grid, "gun": gun, "ammo": ammo}


func test_external_key_format() -> void:
	assert_true(Inventory.is_external_key(&"loot_7"))
	assert_eq(Inventory.external_key(12), &"loot_12")
	for bad: StringName in [&"loot_", &"loot_0", &"loot_-1", &"loot_07", &"loot_a", &"stash", &"item_3_0"]:
		assert_false(Inventory.is_external_key(bad), String(bad))


func test_register_issues_unique_keys_and_titles() -> void:
	var a: Dictionary = _corpse()
	var b: Dictionary = _corpse()
	assert_ne(a["key"], b["key"])
	assert_eq(_authority.container_titles[a["key"]], "시체")


func test_open_registers_items_and_allows_moving_to_pocket() -> void:
	var c: Dictionary = _corpse()
	var opened: CommandResult = _authority.execute(OpenContainerCommand.new(c["key"]))
	assert_true(opened.ok)
	assert_eq(opened.events[0].type, DomainEvent.CONTAINER_OPENED)
	var inv: Inventory = _authority.inventory
	assert_eq(inv.get_grid(c["key"]), c["grid"])
	assert_true(inv.external_keys().has(c["key"]))
	var ammo: ItemInstance = c["ammo"]
	assert_eq(ammo.container_key, c["key"])
	assert_true(_authority.execute(MoveItemCommand.new(ammo.id, Inventory.pocket_key(0), Vector2i.ZERO)).ok)
	assert_eq(ammo.container_key, Inventory.pocket_key(0))
	assert_true(inv.is_consistent())


func test_close_keeps_remaining_items_in_world_grid() -> void:
	var c: Dictionary = _corpse()
	var inv: Inventory = _authority.inventory
	_authority.execute(OpenContainerCommand.new(c["key"]))
	var ammo: ItemInstance = c["ammo"]
	var gun: ItemInstance = c["gun"]
	_authority.execute(MoveItemCommand.new(ammo.id, Inventory.pocket_key(1), Vector2i.ZERO))
	var closed: CommandResult = _authority.execute(CloseContainerCommand.new(c["key"]))
	assert_true(closed.ok)
	assert_eq(closed.events[0].type, DomainEvent.CONTAINER_CLOSED)
	assert_eq(closed.events[0].data["removed_ids"], [gun.id])
	assert_null(inv.get_grid(c["key"]))
	assert_null(inv.get_item(gun.id))
	assert_eq(inv.get_item(ammo.id), ammo)
	var grid: ItemGrid = c["grid"]
	assert_true(grid.has_item(gun))
	assert_eq(gun.position, Vector2i(0, 0))
	assert_false(grid.has_item(ammo))
	assert_true(inv.is_consistent())
	# 다시 열면 남은 그대로 보인다.
	assert_true(_authority.execute(OpenContainerCommand.new(c["key"])).ok)
	assert_eq(inv.get_item(gun.id), gun)
	assert_true(inv.is_consistent())


func test_item_dropped_into_container_leaves_inventory_on_close() -> void:
	var c: Dictionary = _corpse()
	var inv: Inventory = _authority.inventory
	var own: ItemInstance = _authority.create_item(_ammo, 5)
	assert_true(inv.add_item(own, Inventory.pocket_key(2), Vector2i.ZERO, false).ok)
	_authority.execute(OpenContainerCommand.new(c["key"]))
	assert_true(_authority.execute(MoveItemCommand.new(own.id, c["key"], Vector2i(4, 0))).ok)
	_authority.execute(CloseContainerCommand.new(c["key"]))
	assert_null(inv.get_item(own.id))
	assert_true((c["grid"] as ItemGrid).has_item(own))
	assert_true(inv.is_consistent())


func test_backpack_inside_container_is_allowed_and_its_contents_registered() -> void:
	var grid := ItemGrid.new(4, 4)
	var bag: ItemInstance = _authority.create_item(_bag)
	var inside: ItemInstance = _authority.create_item(_ammo, 3)
	assert_true(bag.grids[0].try_place(inside, Vector2i.ZERO, false))
	assert_true(grid.try_place(bag, Vector2i.ZERO, false))
	var key: StringName = _authority.register_container(grid, "상자")
	assert_true(_authority.execute(OpenContainerCommand.new(key)).ok)
	var inv: Inventory = _authority.inventory
	assert_eq(inv.get_item(inside.id), inside)
	assert_eq(inside.container_key, Inventory.item_grid_key(bag.id, 0))
	assert_true(inv.is_consistent())
	_authority.execute(CloseContainerCommand.new(key))
	assert_null(inv.get_item(inside.id))
	assert_true(bag.grids[0].has_item(inside))
	assert_true(inv.is_consistent())


func test_nested_container_contents_rejected() -> void:
	var grid := ItemGrid.new(4, 4)
	var bag: ItemInstance = _authority.create_item(_bag)
	var small := ItemDef.create(&"pouch", 1, 1)
	small.grids = [Vector2i(1, 1)]
	assert_true(bag.grids[0].try_place(_authority.create_item(small), Vector2i.ZERO, false))
	assert_true(grid.try_place(bag, Vector2i.ZERO, false))
	var key: StringName = _authority.register_container(grid, "상자")
	var result: CommandResult = _authority.execute(OpenContainerCommand.new(key))
	assert_false(result.ok)
	assert_eq(result.error, CommandResult.NESTING_NOT_ALLOWED)
	assert_null(_authority.inventory.get_grid(key))


func test_open_errors() -> void:
	var c: Dictionary = _corpse()
	assert_eq(_authority.execute(OpenContainerCommand.new(&"loot_999")).error, CommandResult.UNKNOWN_CONTAINER)
	assert_true(_authority.execute(OpenContainerCommand.new(c["key"])).ok)
	assert_eq(_authority.execute(OpenContainerCommand.new(c["key"])).error, CommandResult.ALREADY_ADDED)
	assert_eq(_authority.execute(CloseContainerCommand.new(&"loot_999")).error, CommandResult.UNKNOWN_CONTAINER)
	assert_eq(_authority.inventory.attach_external(&"stash", ItemGrid.new(2, 2)).error,
			CommandResult.UNKNOWN_CONTAINER)
	assert_eq(_authority.inventory.detach_external(Inventory.pocket_key(0)).error,
			CommandResult.UNKNOWN_CONTAINER)


func test_open_rejects_already_registered_item() -> void:
	var grid := ItemGrid.new(2, 2)
	var own: ItemInstance = _authority.create_item(_ammo, 5)
	assert_true(_authority.inventory.add_item(own, Inventory.pocket_key(0), Vector2i.ZERO, false).ok)
	var copy := ItemInstance.new(own.id, _ammo, 5)
	assert_true(grid.try_place(copy, Vector2i.ZERO, false))
	var key: StringName = _authority.register_container(grid, "상자")
	assert_eq(_authority.execute(OpenContainerCommand.new(key)).error, CommandResult.ALREADY_ADDED)
	assert_eq(own.container_key, Inventory.pocket_key(0))


func test_save_skips_open_container_items() -> void:
	var c: Dictionary = _corpse()
	_authority.execute(OpenContainerCommand.new(c["key"]))
	var data: Dictionary = SaveSerializer.to_dict(_authority.inventory, _authority.ids)
	assert_eq((data["items"] as Array).size(), 0)
