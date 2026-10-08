extends GutTest
## LootTable 테스트 (M3): 결정성, 가중치, 스택 범위, FIR, fill_grid.

var _authority: LocalAuthority
var _a: ItemDef
var _b: ItemDef


func before_each() -> void:
	_authority = LocalAuthority.new(Inventory.new())
	_a = ItemDef.create(&"a", 1, 1, 30)
	_b = ItemDef.create(&"b", 2, 2, 1)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _table(min_items: int, max_items: int, entries: Array[LootEntry]) -> LootTable:
	var table := LootTable.new()
	table.min_items = min_items
	table.max_items = max_items
	table.entries = entries
	return table


func _signature(items: Array[ItemInstance]) -> Array:
	var sig: Array = []
	for item: ItemInstance in items:
		sig.append([item.def.id, item.stack_count])
	return sig


func test_same_seed_same_result() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a, 1.0, 1, 30), LootEntry.create(_b, 2.0)]
	var table: LootTable = _table(2, 6, entries)
	var first: Array[ItemInstance] = table.roll(_rng(42), _authority)
	var second: Array[ItemInstance] = table.roll(_rng(42), _authority)
	assert_eq(_signature(first), _signature(second))
	assert_gte(first.size(), 2)


func test_weight_distribution_roughly_respected() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a, 3.0), LootEntry.create(_b, 1.0)]
	var table: LootTable = _table(1, 1, entries)
	var rng: RandomNumberGenerator = _rng(7)
	var count_a: int = 0
	for _i: int in range(2000):
		var rolled: Array[ItemInstance] = table.roll(rng, _authority)
		if rolled[0].def == _a:
			count_a += 1
	# 기대 75% (1500). 느슨한 범위.
	assert_between(count_a, 1350, 1650)


func test_zero_weight_never_picked() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a, 0.0), LootEntry.create(_b, 1.0)]
	var table: LootTable = _table(1, 3, entries)
	var rng: RandomNumberGenerator = _rng(3)
	for _i: int in range(300):
		for item: ItemInstance in table.roll(rng, _authority):
			assert_eq(item.def, _b)


func test_all_zero_weight_returns_empty() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a, 0.0)]
	assert_eq(_table(1, 3, entries).roll(_rng(1), _authority).size(), 0)


func test_empty_table_returns_empty() -> void:
	var table := LootTable.new()
	assert_eq(table.roll(_rng(1), _authority).size(), 0)
	assert_eq(table.fill_grid(ItemGrid.new(4, 4), _rng(1), _authority).size(), 0)


func test_item_count_within_bounds() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a)]
	var table: LootTable = _table(2, 4, entries)
	var rng: RandomNumberGenerator = _rng(11)
	var seen: Dictionary[int, bool] = {}
	for _i: int in range(200):
		var n: int = table.roll(rng, _authority).size()
		assert_between(n, 2, 4)
		seen[n] = true
	assert_eq(seen.size(), 3)


func test_stack_within_bounds_and_clamped_to_def_max() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a, 1.0, 5, 10)]
	var table: LootTable = _table(1, 1, entries)
	var rng: RandomNumberGenerator = _rng(5)
	for _i: int in range(200):
		assert_between(table.roll(rng, _authority)[0].stack_count, 5, 10)
	var big: Array[LootEntry] = [LootEntry.create(_a, 1.0, 100, 500), LootEntry.create(_b, 0.0)]
	var big_table: LootTable = _table(1, 1, big)
	assert_eq(big_table.roll(rng, _authority)[0].stack_count, 30)
	var single: Array[LootEntry] = [LootEntry.create(_b, 1.0, 3, 9)]
	assert_eq(_table(1, 1, single).roll(rng, _authority)[0].stack_count, 1)


func test_items_are_fir_with_unique_ids() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a)]
	var rolled: Array[ItemInstance] = _table(5, 5, entries).roll(_rng(2), _authority)
	var ids: Dictionary[int, bool] = {}
	for item: ItemInstance in rolled:
		assert_true(item.found_in_raid)
		assert_gt(item.id, 0)
		ids[item.id] = true
	assert_eq(ids.size(), 5)


func test_fill_grid_places_only_what_fits_and_stays_consistent() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_b, 1.0)]
	var table: LootTable = _table(10, 10, entries)
	var grid := ItemGrid.new(4, 4)
	var placed: Array[ItemInstance] = table.fill_grid(grid, _rng(9), _authority)
	assert_eq(placed.size(), 4) # 2x2 아이템 4개만 들어간다
	assert_eq(grid.get_items().size(), 4)
	assert_true(grid.is_consistent())
	for item: ItemInstance in placed:
		assert_true(grid.has_item(item))


func test_fill_grid_partial_room() -> void:
	var entries: Array[LootEntry] = [LootEntry.create(_a, 1.0, 1, 1), LootEntry.create(_b, 1.0)]
	var table: LootTable = _table(8, 8, entries)
	var grid := ItemGrid.new(3, 3)
	var placed: Array[ItemInstance] = table.fill_grid(grid, _rng(21), _authority)
	assert_lte(placed.size(), 8)
	assert_eq(grid.get_items().size(), placed.size())
	assert_true(grid.is_consistent())
