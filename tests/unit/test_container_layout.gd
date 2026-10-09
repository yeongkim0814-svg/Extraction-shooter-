extends GutTest

const CELL: int = 10
const GAP: int = 2


func _rig_sizes() -> Array[Vector2i]:
	return [Vector2i(2, 2), Vector2i(2, 2), Vector2i(1, 3), Vector2i(1, 3), Vector2i(1, 3), Vector2i(1, 3)]


func _rig_offsets() -> Array[Vector2i]:
	return [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]


func test_empty() -> void:
	var layout: ContainerLayout = ContainerLayout.compute([], [], CELL, 100.0, GAP)
	assert_eq(layout.rects.size(), 0)
	assert_eq(layout.size, Vector2.ZERO)


func test_authored_layout_with_gaps() -> void:
	var layout: ContainerLayout = ContainerLayout.compute(_rig_sizes(), _rig_offsets(), CELL, 200.0, GAP)
	assert_true(layout.authored)
	assert_eq(layout.rects.size(), 6)
	assert_eq(layout.rects[0], Rect2(0, 0, 20, 20))
	assert_eq(layout.rects[1], Rect2(2 * CELL + 2 * GAP, 0, 20, 20))
	assert_eq(layout.rects[2], Rect2(0, 2 * CELL + GAP, 10, 30))
	assert_eq(layout.rects[5], Rect2(3 * CELL + 3 * GAP, 2 * CELL + GAP, 10, 30))
	assert_eq(layout.size, Vector2(4 * CELL + 3 * GAP, 5 * CELL + GAP))


func test_authored_groups_do_not_overlap() -> void:
	var layout: ContainerLayout = ContainerLayout.compute(_rig_sizes(), _rig_offsets(), CELL, 200.0, GAP)
	for i: int in range(layout.rects.size()):
		for j: int in range(i + 1, layout.rects.size()):
			assert_false(layout.rects[i].intersects(layout.rects[j]), "%d x %d" % [i, j])


func test_auto_flow_wraps_and_uses_tallest_row_height() -> void:
	var sizes: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 2), Vector2i(1, 3), Vector2i(1, 3)]
	var layout: ContainerLayout = ContainerLayout.compute(sizes, [], CELL, 45.0, GAP)
	assert_false(layout.authored)
	assert_eq(layout.rects[0].position, Vector2(0, 0))
	assert_eq(layout.rects[1].position, Vector2(22, 0))
	# 세 번째(너비 10)는 x=44에서 54 > 45 라 다음 줄로
	assert_eq(layout.rects[2].position, Vector2(0, 22))
	assert_eq(layout.rects[3].position, Vector2(12, 22))
	assert_eq(layout.size, Vector2(42, 52))


func test_authored_wider_than_available_falls_back_to_flow() -> void:
	var layout: ContainerLayout = ContainerLayout.compute(_rig_sizes(), _rig_offsets(), CELL, 40.0, GAP)
	assert_false(layout.authored)
	assert_eq(layout.rects.size(), 6)
	assert_eq(layout.rects[0].position, Vector2.ZERO)
	for rect: Rect2 in layout.rects:
		assert_true(rect.end.x <= 40.0)
	assert_eq(layout.rects[1].position, Vector2(0, 22))


func test_offsets_length_mismatch_uses_flow() -> void:
	var offsets: Array[Vector2i] = [Vector2i(0, 0)]
	var layout: ContainerLayout = ContainerLayout.compute(_rig_sizes(), offsets, CELL, 200.0, GAP)
	assert_false(layout.authored)


func test_negative_offset_uses_flow() -> void:
	var sizes: Array[Vector2i] = [Vector2i(1, 1)]
	var offsets: Array[Vector2i] = [Vector2i(-1, 0)]
	var layout: ContainerLayout = ContainerLayout.compute(sizes, offsets, CELL, 200.0, GAP)
	assert_false(layout.authored)
	assert_eq(layout.rects[0].position, Vector2.ZERO)


func test_single_grid_wider_than_available_still_placed() -> void:
	var sizes: Array[Vector2i] = [Vector2i(10, 2)]
	var layout: ContainerLayout = ContainerLayout.compute(sizes, [], CELL, 50.0, GAP)
	assert_eq(layout.rects[0], Rect2(0, 0, 100, 20))
