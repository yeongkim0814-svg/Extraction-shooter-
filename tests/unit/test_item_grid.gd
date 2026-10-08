extends GutTest

var _next_id: int = 1


func before_each() -> void:
	_next_id = 1


func _item(w: int, h: int, max_stack: int = 1, can_rotate: bool = true,
		def_id: StringName = &"") -> ItemInstance:
	var id: StringName = def_id if def_id != &"" else StringName("item_%dx%d" % [w, h])
	var item := ItemInstance.new(_next_id, ItemDef.create(id, w, h, max_stack, can_rotate))
	_next_id += 1
	return item


# --- 배치 ---

func test_place_fills_every_covered_cell() -> void:
	var grid := ItemGrid.new(4, 4)
	var item := _item(2, 3)
	assert_true(grid.try_place(item, Vector2i(1, 0), false))
	for y: int in range(0, 3):
		for x: int in range(1, 3):
			assert_eq(grid.get_item_at(Vector2i(x, y)), item)
	assert_null(grid.get_item_at(Vector2i(0, 0)))
	assert_null(grid.get_item_at(Vector2i(3, 0)))
	assert_null(grid.get_item_at(Vector2i(1, 3)))
	assert_true(grid.is_consistent())


func test_exact_fit_at_bottom_right_edge() -> void:
	var grid := ItemGrid.new(5, 4)
	assert_true(grid.try_place(_item(2, 2), Vector2i(3, 2), false))


func test_out_of_bounds_rejected() -> void:
	var grid := ItemGrid.new(5, 4)
	var item := _item(2, 2)
	assert_false(grid.try_place(item, Vector2i(-1, 0), false))
	assert_false(grid.try_place(item, Vector2i(0, -1), false))
	assert_false(grid.try_place(item, Vector2i(4, 0), false))
	assert_false(grid.try_place(item, Vector2i(0, 3), false))
	assert_eq(grid.get_items().size(), 0)


func test_overlap_rejected() -> void:
	var grid := ItemGrid.new(4, 4)
	assert_true(grid.try_place(_item(2, 2), Vector2i(0, 0), false))
	assert_false(grid.try_place(_item(2, 2), Vector2i(1, 1), false))
	assert_true(grid.try_place(_item(2, 2), Vector2i(2, 2), false))


func test_same_item_cannot_be_placed_twice() -> void:
	var grid := ItemGrid.new(4, 4)
	var item := _item(1, 1)
	assert_true(grid.try_place(item, Vector2i(0, 0), false))
	assert_false(grid.try_place(item, Vector2i(3, 3), false))
	assert_eq(item.position, Vector2i(0, 0))


# --- 회전 ---

func test_rotated_item_swaps_footprint() -> void:
	var grid := ItemGrid.new(3, 3)
	var item := _item(3, 1)
	assert_true(grid.try_place(item, Vector2i(0, 0), true))
	assert_eq(item.size(), Vector2i(1, 3))
	assert_eq(grid.get_item_at(Vector2i(0, 2)), item)
	assert_null(grid.get_item_at(Vector2i(1, 0)))


func test_non_rotatable_item_rejects_rotation() -> void:
	var grid := ItemGrid.new(3, 3)
	assert_false(grid.try_place(_item(2, 1, 1, false), Vector2i(0, 0), true))


# --- 이동·제거 ---

func test_move_may_overlap_own_previous_cells() -> void:
	var grid := ItemGrid.new(4, 2)
	var item := _item(2, 2)
	grid.try_place(item, Vector2i(0, 0), false)
	assert_true(grid.move(item, Vector2i(1, 0), false))
	assert_null(grid.get_item_at(Vector2i(0, 0)))
	assert_eq(grid.get_item_at(Vector2i(2, 1)), item)
	assert_true(grid.is_consistent())


func test_failed_move_leaves_state_unchanged() -> void:
	var grid := ItemGrid.new(4, 2)
	var a := _item(2, 2)
	var b := _item(2, 2)
	grid.try_place(a, Vector2i(0, 0), false)
	grid.try_place(b, Vector2i(2, 0), false)
	assert_false(grid.move(a, Vector2i(1, 0), false))
	assert_eq(a.position, Vector2i(0, 0))
	assert_eq(grid.get_item_at(Vector2i(1, 1)), a)
	assert_eq(grid.get_item_at(Vector2i(2, 0)), b)
	assert_true(grid.is_consistent())


func test_move_with_rotation_in_place() -> void:
	var grid := ItemGrid.new(3, 3)
	var item := _item(3, 1)
	grid.try_place(item, Vector2i(0, 0), false)
	assert_true(grid.move(item, Vector2i(0, 0), true))
	assert_eq(grid.get_item_at(Vector2i(0, 2)), item)
	assert_null(grid.get_item_at(Vector2i(2, 0)))


func test_move_of_foreign_item_rejected() -> void:
	var grid := ItemGrid.new(3, 3)
	assert_false(grid.move(_item(1, 1), Vector2i(0, 0), false))


func test_remove_frees_cells_for_reuse() -> void:
	var grid := ItemGrid.new(2, 2)
	var item := _item(2, 2)
	grid.try_place(item, Vector2i(0, 0), false)
	assert_true(grid.remove(item))
	assert_eq(item.position, ItemInstance.NOT_PLACED)
	assert_false(grid.remove(item))
	assert_true(grid.try_place(_item(2, 2), Vector2i(0, 0), false))


# --- 자동 배치 ---

func test_auto_place_fills_single_cell_gap() -> void:
	var grid := ItemGrid.new(2, 2)
	grid.try_place(_item(2, 1), Vector2i(0, 0), false)
	grid.try_place(_item(1, 1), Vector2i(0, 1), false)
	var small := _item(1, 1)
	assert_true(grid.try_auto_place(small))
	assert_eq(small.position, Vector2i(1, 1))


func test_auto_place_rotates_only_when_needed() -> void:
	var grid := ItemGrid.new(2, 3)
	var long := _item(3, 1)
	assert_true(grid.try_auto_place(long))
	assert_true(long.rotated)
	var wide := ItemGrid.new(3, 3)
	var other := _item(3, 1)
	assert_true(wide.try_auto_place(other))
	assert_false(other.rotated)


func test_auto_place_scans_row_major() -> void:
	var grid := ItemGrid.new(3, 3)
	grid.try_place(_item(1, 1), Vector2i(0, 0), false)
	var item := _item(1, 1)
	grid.try_auto_place(item)
	assert_eq(item.position, Vector2i(1, 0))


func test_auto_place_fails_when_full() -> void:
	var grid := ItemGrid.new(2, 2)
	grid.try_place(_item(2, 2), Vector2i(0, 0), false)
	var item := _item(1, 1)
	assert_false(grid.try_auto_place(item))
	assert_eq(item.position, ItemInstance.NOT_PLACED)


# --- 스택 ---

func test_merge_moves_up_to_free_space_and_keeps_remainder() -> void:
	var grid := ItemGrid.new(4, 4)
	var target := ItemInstance.new(1, ItemDef.create(&"ammo", 1, 1, 60), 50)
	var source := ItemInstance.new(2, target.def, 30)
	grid.try_place(target, Vector2i(0, 0), false)
	grid.try_place(source, Vector2i(1, 0), false)
	assert_eq(grid.merge(source, target), 10)
	assert_eq(target.stack_count, 60)
	assert_eq(source.stack_count, 20)
	assert_true(grid.has_item(source))


func test_full_merge_removes_source() -> void:
	var grid := ItemGrid.new(4, 4)
	var target := ItemInstance.new(1, ItemDef.create(&"ammo", 1, 1, 60), 10)
	var source := ItemInstance.new(2, target.def, 20)
	grid.try_place(target, Vector2i(0, 0), false)
	grid.try_place(source, Vector2i(1, 0), false)
	assert_eq(grid.merge(source, target), 20)
	assert_false(grid.has_item(source))
	assert_null(grid.get_item_at(Vector2i(1, 0)))
	assert_true(grid.is_consistent())


func test_merge_rejects_different_or_unstackable_items() -> void:
	var grid := ItemGrid.new(4, 4)
	var ammo := ItemInstance.new(1, ItemDef.create(&"ammo_9mm", 1, 1, 60), 10)
	var other := ItemInstance.new(2, ItemDef.create(&"ammo_556", 1, 1, 60), 10)
	var gun_a := ItemInstance.new(3, ItemDef.create(&"pistol", 2, 1), 1)
	var gun_b := ItemInstance.new(4, gun_a.def, 1)
	for item: ItemInstance in [ammo, other, gun_a, gun_b]:
		grid.try_auto_place(item)
	assert_eq(grid.merge(other, ammo), 0)
	assert_eq(grid.merge(gun_b, gun_a), 0)
	assert_eq(grid.merge(ammo, ammo), 0)


func test_split_creates_new_stack_in_free_cell() -> void:
	var grid := ItemGrid.new(2, 1)
	var stack := ItemInstance.new(1, ItemDef.create(&"ammo", 1, 1, 60), 40)
	grid.try_place(stack, Vector2i(0, 0), false)
	var part: ItemInstance = grid.split(stack, 15, 2)
	assert_not_null(part)
	assert_eq(part.stack_count, 15)
	assert_eq(stack.stack_count, 25)
	assert_eq(part.position, Vector2i(1, 0))


func test_split_without_space_changes_nothing() -> void:
	var grid := ItemGrid.new(1, 1)
	var stack := ItemInstance.new(1, ItemDef.create(&"ammo", 1, 1, 60), 40)
	grid.try_place(stack, Vector2i(0, 0), false)
	assert_null(grid.split(stack, 15, 2))
	assert_eq(stack.stack_count, 40)


func test_split_rejects_invalid_amounts() -> void:
	var grid := ItemGrid.new(3, 1)
	var stack := ItemInstance.new(1, ItemDef.create(&"ammo", 1, 1, 60), 40)
	grid.try_place(stack, Vector2i(0, 0), false)
	assert_null(grid.split(stack, 0, 2))
	assert_null(grid.split(stack, 40, 2))
	assert_null(grid.split(stack, -5, 2))


# --- 불변식 ---

func test_random_operations_keep_grid_consistent() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	var grid := ItemGrid.new(10, 10)
	var pool: Array[ItemInstance] = []
	for i: int in range(40):
		pool.append(_item(rng.randi_range(1, 4), rng.randi_range(1, 3), 1, rng.randf() < 0.8))
	for step: int in range(2000):
		var item: ItemInstance = pool[rng.randi_range(0, pool.size() - 1)]
		var cell := Vector2i(rng.randi_range(-1, 10), rng.randi_range(-1, 10))
		var p_rotated: bool = rng.randf() < 0.5
		match rng.randi_range(0, 3):
			0:
				grid.try_place(item, cell, p_rotated)
			1:
				grid.move(item, cell, p_rotated)
			2:
				grid.remove(item)
			3:
				grid.try_auto_place(item)
		if not grid.is_consistent():
			fail_test("grid inconsistent at step %d" % step)
			return
	var occupied: int = 0
	for item: ItemInstance in grid.get_items():
		occupied += item.size().x * item.size().y
	var counted: int = 0
	for y: int in range(10):
		for x: int in range(10):
			if grid.get_item_at(Vector2i(x, y)) != null:
				counted += 1
	assert_eq(counted, occupied)
	assert_gt(grid.get_items().size(), 0)
