extends GutTest
## GameAuthority / LocalAuthority / 명령 / IdGenerator 테스트 (M2).

const STASH := Inventory.STASH

var _ammo_def: ItemDef


func before_each() -> void:
	_ammo_def = ItemDef.create(&"ammo", 1, 1, 30)


func _authority() -> LocalAuthority:
	return LocalAuthority.new(Inventory.new(Vector2i(10, 10)))


func _add_ammo(authority: LocalAuthority, count: int, cell: Vector2i) -> ItemInstance:
	var item: ItemInstance = authority.create_item(_ammo_def, count)
	assert_true(authority.inventory.add_item(item, STASH, cell, false).ok)
	return item


# --- LocalAuthority ---

func test_execute_returns_command_result() -> void:
	var authority := _authority()
	var item: ItemInstance = _add_ammo(authority, 5, Vector2i.ZERO)
	var result: CommandResult = authority.execute(MoveItemCommand.new(item.id, STASH, Vector2i(4, 4)))
	assert_true(result.ok)
	assert_eq(result.events.size(), 1)
	assert_eq(result.events[0].type, DomainEvent.ITEM_MOVED)
	assert_eq(item.position, Vector2i(4, 4))
	var failed: CommandResult = authority.execute(MoveItemCommand.new(9999, STASH, Vector2i.ZERO))
	assert_false(failed.ok)
	assert_eq(failed.error, CommandResult.UNKNOWN_ITEM)


func test_events_emitted_fires_on_success_with_events() -> void:
	var authority := _authority()
	var item: ItemInstance = _add_ammo(authority, 5, Vector2i.ZERO)
	watch_signals(authority)
	var result: CommandResult = authority.execute(MoveItemCommand.new(item.id, STASH, Vector2i(2, 2)))
	assert_signal_emitted(authority, "events_emitted")
	assert_signal_emit_count(authority, "events_emitted", 1)
	var params: Array = get_signal_parameters(authority, "events_emitted")
	var emitted: Array = params[0]
	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0], result.events[0])
	assert_eq((emitted[0] as DomainEvent).type, DomainEvent.ITEM_MOVED)


func test_events_emitted_not_fired_on_failure() -> void:
	var authority := _authority()
	watch_signals(authority)
	var result: CommandResult = authority.execute(DiscardItemCommand.new(12345))
	assert_false(result.ok)
	assert_signal_not_emitted(authority, "events_emitted")


func test_events_emitted_not_fired_for_noop_success() -> void:
	var authority := _authority()
	var weapon_def := ItemDef.create(&"rifle", 4, 2)
	weapon_def.category = ItemDef.Category.WEAPON
	var weapon: ItemInstance = authority.create_item(weapon_def)
	assert_true(authority.inventory.add_equipped(weapon, EquipmentSlots.Slot.PRIMARY_1).ok)
	watch_signals(authority)
	var result: CommandResult = authority.execute(EquipItemCommand.new(weapon.id, EquipmentSlots.Slot.PRIMARY_1))
	assert_true(result.ok)
	assert_signal_not_emitted(authority, "events_emitted")


func test_each_command_type_runs_through_authority() -> void:
	var authority := _authority()
	var weapon_def := ItemDef.create(&"rifle", 4, 2)
	weapon_def.category = ItemDef.Category.WEAPON
	var weapon: ItemInstance = authority.create_item(weapon_def)
	assert_true(authority.inventory.add_item(weapon, STASH, Vector2i(0, 8), false).ok)
	var a: ItemInstance = _add_ammo(authority, 20, Vector2i(0, 0))
	var b: ItemInstance = _add_ammo(authority, 20, Vector2i(1, 0))
	assert_true(authority.execute(EquipItemCommand.new(weapon.id, EquipmentSlots.Slot.PRIMARY_1)).ok)
	assert_eq(authority.inventory.equipment.get_item(EquipmentSlots.Slot.PRIMARY_1), weapon)
	assert_true(authority.execute(MergeStacksCommand.new(a.id, b.id)).ok)
	assert_eq(b.stack_count, 30)
	assert_eq(a.stack_count, 10)
	assert_true(authority.execute(SplitStackCommand.new(b.id, 10, STASH, Vector2i(5, 5))).ok)
	assert_eq(b.stack_count, 20)
	assert_true(authority.execute(DiscardItemCommand.new(a.id)).ok)
	assert_null(authority.inventory.get_item(a.id))
	assert_true(authority.inventory.is_consistent())


# --- SplitStackCommand와 id 발급 ---

func test_split_consumes_id_only_on_success() -> void:
	var authority := _authority()
	var item: ItemInstance = _add_ammo(authority, 20, Vector2i.ZERO)
	var next_before: int = authority.ids.peek()
	var result: CommandResult = authority.execute(SplitStackCommand.new(item.id, 5, STASH, Vector2i(3, 3)))
	assert_true(result.ok)
	assert_eq(authority.ids.peek(), next_before + 1)
	var part: ItemInstance = authority.inventory.get_item(next_before)
	assert_not_null(part, "new stack uses the peeked id")
	assert_eq(part.stack_count, 5)
	assert_eq(result.events[0].data["item_id"], next_before)


func test_split_does_not_consume_id_on_failure() -> void:
	var authority := _authority()
	var item: ItemInstance = _add_ammo(authority, 20, Vector2i.ZERO)
	var next_before: int = authority.ids.peek()
	var invalid: CommandResult = authority.execute(SplitStackCommand.new(item.id, 0, STASH, Vector2i(3, 3)))
	assert_eq(invalid.error, CommandResult.INVALID_AMOUNT)
	assert_eq(authority.ids.peek(), next_before)
	var no_space: CommandResult = authority.execute(SplitStackCommand.new(item.id, 5, STASH, Vector2i(0, 0)))
	assert_eq(no_space.error, CommandResult.NO_SPACE)
	assert_eq(authority.ids.peek(), next_before)
	var unknown_item: CommandResult = authority.execute(SplitStackCommand.new(999, 5, STASH, Vector2i(3, 3)))
	assert_eq(unknown_item.error, CommandResult.UNKNOWN_ITEM)
	assert_eq(authority.ids.peek(), next_before)
	var bad_container: CommandResult = authority.execute(SplitStackCommand.new(item.id, 5, &"nowhere", Vector2i.ZERO))
	assert_eq(bad_container.error, CommandResult.UNKNOWN_CONTAINER)
	assert_eq(authority.ids.peek(), next_before)
	assert_eq(item.stack_count, 20)


func test_successive_splits_get_increasing_ids() -> void:
	var authority := _authority()
	var item: ItemInstance = _add_ammo(authority, 20, Vector2i.ZERO)
	var first: CommandResult = authority.execute(SplitStackCommand.new(item.id, 2, STASH, Vector2i(2, 0)))
	var second: CommandResult = authority.execute(SplitStackCommand.new(item.id, 2, STASH, Vector2i(3, 0)))
	assert_true(first.ok and second.ok)
	assert_lt(int(first.events[0].data["item_id"]), int(second.events[0].data["item_id"]))


func test_create_item_ids_are_unique_and_increasing() -> void:
	var authority := _authority()
	var seen: Dictionary = {}
	var last: int = 0
	for i: int in range(50):
		var item: ItemInstance = authority.create_item(_ammo_def, 1)
		assert_gt(item.id, last)
		assert_false(seen.has(item.id))
		seen[item.id] = true
		last = item.id
	assert_eq(last, 50)


func test_create_item_does_not_add_to_inventory() -> void:
	var authority := _authority()
	var item: ItemInstance = authority.create_item(_ammo_def, 7)
	assert_eq(item.stack_count, 7)
	assert_eq(item.def, _ammo_def)
	assert_null(authority.inventory.get_item(item.id))
	assert_eq(item.container_key, &"")


# --- IdGenerator ---

func test_id_generator_starts_at_one_and_increments() -> void:
	var ids := IdGenerator.new()
	assert_eq(ids.peek(), 1)
	assert_eq(ids.next_id(), 1)
	assert_eq(ids.next_id(), 2)
	assert_eq(ids.peek(), 3)
	assert_eq(ids.peek(), 3, "peek does not consume")


func test_id_generator_ensure_above() -> void:
	var ids := IdGenerator.new()
	ids.ensure_above(10)
	assert_eq(ids.peek(), 11)
	assert_eq(ids.next_id(), 11)
	ids.ensure_above(5)
	assert_eq(ids.peek(), 12, "never moves backwards")
	ids.ensure_above(11)
	assert_eq(ids.peek(), 12)
	ids.ensure_above(12)
	assert_eq(ids.peek(), 13)


func test_ensure_above_affects_create_item() -> void:
	var authority := _authority()
	authority.ids.ensure_above(99)
	assert_eq(authority.create_item(_ammo_def).id, 100)


# --- 기본 구현 ---

func test_base_authority_execute_not_implemented() -> void:
	var authority := GameAuthority.new(Inventory.new())
	var result: CommandResult = authority.execute(DiscardItemCommand.new(1))
	assert_false(result.ok)
	assert_eq(result.error, CommandResult.NOT_IMPLEMENTED)
	assert_true(result.events.is_empty())


func test_base_command_execute_not_implemented() -> void:
	var command := GameCommand.new()
	var result: CommandResult = command.execute(_authority())
	assert_false(result.ok)
	assert_eq(result.error, CommandResult.NOT_IMPLEMENTED)


func test_base_command_through_local_authority_does_not_emit() -> void:
	var authority := _authority()
	watch_signals(authority)
	var result: CommandResult = authority.execute(GameCommand.new())
	assert_eq(result.error, CommandResult.NOT_IMPLEMENTED)
	assert_signal_not_emitted(authority, "events_emitted")
