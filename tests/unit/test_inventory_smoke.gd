extends GutTest


func test_backpack_round_trip_through_authority() -> void:
	var authority := LocalAuthority.new(Inventory.new(Vector2i(10, 10)))
	var pack_def := ItemDef.create(&"backpack", 3, 3)
	pack_def.category = ItemDef.Category.BACKPACK
	pack_def.grids = [Vector2i(4, 4)]
	var pack: ItemInstance = authority.create_item(pack_def)
	var ammo: ItemInstance = authority.create_item(ItemDef.create(&"ammo", 1, 1, 60), 40)
	var inv: Inventory = authority.inventory
	assert_true(inv.add_item(pack, Inventory.STASH, Vector2i.ZERO, false).ok)
	assert_true(inv.add_item(ammo, Inventory.STASH, Vector2i(5, 0), false).ok)
	var pack_grid := Inventory.item_grid_key(pack.id, 0)
	assert_true(authority.execute(MoveItemCommand.new(ammo.id, pack_grid, Vector2i(1, 1))).ok)
	assert_true(authority.execute(EquipItemCommand.new(pack.id, EquipmentSlots.Slot.BACKPACK)).ok)
	assert_eq(ammo.container_key, pack_grid)
	var split: CommandResult = authority.execute(SplitStackCommand.new(ammo.id, 15, pack_grid, Vector2i(0, 0)))
	assert_true(split.ok)
	assert_eq(ammo.stack_count, 25)
	assert_eq(authority.execute(MoveItemCommand.new(pack.id, pack_grid, Vector2i(0, 2))).error,
			CommandResult.NESTING_NOT_ALLOWED)
	var discard: CommandResult = authority.execute(DiscardItemCommand.new(pack.id))
	assert_eq(discard.events[0].data["removed_ids"].size(), 3)
	assert_eq(inv.get_items().size(), 0)
	assert_true(inv.is_consistent())
