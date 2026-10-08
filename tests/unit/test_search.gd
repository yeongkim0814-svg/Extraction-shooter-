extends GutTest
## 수색 시스템 테스트 (M3): 시간 계산, 공개 순서, 진행 누적, 소음, 중단.

var _grid: ItemGrid
var _calc: SearchTimeCalculator
var _state: SearchState
var _next_id: int = 1


func before_each() -> void:
	_grid = ItemGrid.new(5, 5)
	_calc = SearchTimeCalculator.new()
	_state = SearchState.new(_grid, _calc)
	_next_id = 1


func _def(w: int = 1, h: int = 1, price: int = 0) -> ItemDef:
	var def: ItemDef = ItemDef.create(&"d", w, h)
	def.base_price = price
	return def


func _put(x: int, y: int, def: ItemDef = null) -> ItemInstance:
	var item := ItemInstance.new(_next_id, def if def != null else _def())
	_next_id += 1
	assert_true(_grid.try_place(item, Vector2i(x, y), false))
	return item


# --- SearchTimeCalculator ---

func test_time_base_1x1() -> void:
	assert_almost_eq(_calc.time_for(_def()), 0.8, 0.0001)


func test_time_scales_per_cell() -> void:
	assert_almost_eq(_calc.time_for(_def(2, 1)), 0.8 * 1.15, 0.0001)
	assert_almost_eq(_calc.time_for(_def(2, 2)), 0.8 * 1.45, 0.0001)
	assert_gt(_calc.time_for(_def(3, 2)), _calc.time_for(_def(2, 2)))


func test_time_clamped_to_max_and_min() -> void:
	assert_eq(_calc.time_for(_def(10, 10)), SearchTimeCalculator.MAX_TIME)
	_calc.speed_multiplier = 10.0
	assert_eq(_calc.time_for(_def()), SearchTimeCalculator.MIN_TIME)
	_calc.speed_multiplier = 0.0  # 0으로 나누지 않고 최대 시간
	assert_eq(_calc.time_for(_def()), SearchTimeCalculator.MAX_TIME)


func test_time_rarity_tiers() -> void:
	assert_almost_eq(_calc.rarity_multiplier(0), 1.0, 0.0001)
	assert_almost_eq(_calc.rarity_multiplier(4999), 1.0, 0.0001)
	assert_almost_eq(_calc.rarity_multiplier(5000), 1.3, 0.0001)
	assert_almost_eq(_calc.rarity_multiplier(19999), 1.3, 0.0001)
	assert_almost_eq(_calc.rarity_multiplier(20000), 1.6, 0.0001)
	assert_almost_eq(_calc.rarity_multiplier(50000), 2.0, 0.0001)
	assert_almost_eq(_calc.time_for(_def(1, 1, 5000)), 0.8 * 1.3, 0.0001)
	assert_almost_eq(_calc.time_for(_def(2, 1, 50000)), 0.8 * 1.15 * 2.0, 0.0001)


func test_time_speed_multiplier() -> void:
	_calc.speed_multiplier = 2.0
	assert_almost_eq(_calc.time_for(_def(2, 2)), 0.8 * 1.45 / 2.0, 0.0001)
	_calc.speed_multiplier = 0.5
	assert_almost_eq(_calc.time_for(_def()), 1.6, 0.0001)


# --- SearchState ---

func test_reveal_order_top_to_bottom_then_left_to_right() -> void:
	var c: ItemInstance = _put(0, 1)
	var a: ItemInstance = _put(3, 0)
	var b: ItemInstance = _put(0, 0)
	var d: ItemInstance = _put(2, 1)
	assert_eq(_state.pending_items(), [b, a, c, d] as Array[ItemInstance])
	_state.start()
	var result: SearchState.TickResult = _state.tick(10.0)
	assert_eq(result.revealed, [b, a, c, d] as Array[ItemInstance])


func test_tick_does_nothing_unless_started() -> void:
	var item: ItemInstance = _put(0, 0)
	var result: SearchState.TickResult = _state.tick(5.0)
	assert_eq(result.revealed.size(), 0)
	assert_eq(result.noise, 0.0)
	assert_false(_state.is_revealed(item))
	assert_eq(_state.current_progress(), 0.0)


func test_tick_non_positive_delta_noop() -> void:
	_put(0, 0)
	_state.start()
	assert_eq(_state.tick(0.0).noise, 0.0)
	assert_eq(_state.tick(-1.0).noise, 0.0)
	assert_eq(_state.current_progress(), 0.0)


func test_partial_progress_accumulates() -> void:
	var item: ItemInstance = _put(0, 0)
	_state.start()
	var r1: SearchState.TickResult = _state.tick(0.5)
	assert_eq(r1.revealed.size(), 0)
	assert_almost_eq(_state.current_progress(), 0.5 / 0.8, 0.0001)
	assert_eq(_state.current_item_id(), item.id)
	var r2: SearchState.TickResult = _state.tick(0.31)
	assert_eq(r2.revealed, [item] as Array[ItemInstance])
	assert_true(_state.is_revealed(item))
	assert_eq(_state.current_progress(), 0.0)


func test_large_delta_reveals_several_and_carries_leftover() -> void:
	var a: ItemInstance = _put(0, 0)
	var b: ItemInstance = _put(1, 0)
	var c: ItemInstance = _put(2, 0)
	_state.start()
	var result: SearchState.TickResult = _state.tick(2.0)
	assert_eq(result.revealed, [a, b] as Array[ItemInstance])
	assert_eq(_state.current_item_id(), c.id)
	assert_almost_eq(_state.current_progress(), 0.4 / 0.8, 0.0001)
	assert_true(_state.searching)


func test_noise_is_rate_times_time_spent() -> void:
	_put(0, 0)
	_state.start()
	assert_almost_eq(_state.tick(0.5).noise, 0.5 * SearchState.NOISE_PER_SECOND, 0.0001)
	assert_almost_eq(_state.tick(0.1).noise, 0.1 * SearchState.NOISE_PER_SECOND, 0.0001)


func test_no_noise_after_completion() -> void:
	_put(0, 0)
	_put(1, 0)
	_put(2, 0)
	_state.start()
	# 3개를 공개하는 데 2.4초. 3초를 줘도 소음은 쓴 시간만큼만.
	var result: SearchState.TickResult = _state.tick(3.0)
	assert_eq(result.revealed.size(), 3)
	assert_almost_eq(result.noise, 2.4 * SearchState.NOISE_PER_SECOND, 0.0001)
	var after: SearchState.TickResult = _state.tick(3.0)
	assert_eq(after.noise, 0.0)
	assert_eq(after.revealed.size(), 0)


func test_searching_false_when_complete() -> void:
	_put(0, 0)
	_state.start()
	_state.tick(5.0)
	assert_true(_state.is_complete())
	assert_false(_state.searching)


func test_searching_false_when_last_item_finished_exactly() -> void:
	# 마지막 아이템이 정확히 끝나는 tick에서도 완료 즉시 searching이 꺼져야 한다.
	_put(0, 0)
	_state.start()
	_state.tick(0.8)
	assert_true(_state.is_complete())
	assert_false(_state.searching)


func test_start_on_empty_grid_stops_on_first_tick() -> void:
	_state.start()
	assert_true(_state.is_complete())
	var result: SearchState.TickResult = _state.tick(1.0)
	assert_eq(result.noise, 0.0)
	assert_false(_state.searching)


func test_interrupt_keeps_revealed_drops_progress() -> void:
	var a: ItemInstance = _put(0, 0)
	var b: ItemInstance = _put(1, 0)
	_state.start()
	_state.tick(1.3)  # a 공개, b 0.5초 진행
	assert_true(_state.is_revealed(a))
	assert_almost_eq(_state.current_progress(), 0.5 / 0.8, 0.0001)
	_state.interrupt()
	assert_false(_state.searching)
	assert_true(_state.is_revealed(a))
	assert_eq(_state.current_progress(), 0.0)
	assert_eq(_state.tick(5.0).revealed.size(), 0)  # 중단 중에는 진행 없음
	_state.start()
	# 진행도가 남아 있었다면 0.5 + 0.5로 공개됐을 것
	assert_eq(_state.tick(0.5).revealed.size(), 0)
	assert_eq(_state.tick(0.31).revealed, [b] as Array[ItemInstance])


func test_mark_revealed_skips_item() -> void:
	var a: ItemInstance = _put(0, 0)
	var b: ItemInstance = _put(1, 0)
	var c: ItemInstance = _put(2, 0)
	_state.mark_revealed(b)
	assert_true(_state.is_revealed(b))
	assert_eq(_state.pending_items(), [a, c] as Array[ItemInstance])
	_state.start()
	assert_eq(_state.tick(10.0).revealed, [a, c] as Array[ItemInstance])


func test_mark_revealed_in_progress_item() -> void:
	var a: ItemInstance = _put(0, 0)
	var b: ItemInstance = _put(1, 0)
	_state.start()
	_state.tick(0.5)
	assert_eq(_state.current_item_id(), a.id)
	_state.mark_revealed(a)
	assert_eq(_state.current_progress(), 0.0)
	assert_eq(_state.current_item_id(), b.id)
	# a의 진행도 0.5가 b로 넘어가지 않는다.
	assert_eq(_state.tick(0.5).revealed.size(), 0)
	assert_eq(_state.tick(0.31).revealed, [b] as Array[ItemInstance])


func test_removing_in_progress_item_moves_on() -> void:
	var a: ItemInstance = _put(0, 0)
	var b: ItemInstance = _put(1, 0)
	_state.start()
	_state.tick(0.5)
	assert_eq(_state.current_item_id(), a.id)
	_grid.remove(a)
	assert_eq(_state.current_item_id(), b.id)
	assert_eq(_state.current_progress(), 0.0)
	assert_eq(_state.tick(0.5).revealed.size(), 0)
	assert_eq(_state.tick(0.31).revealed, [b] as Array[ItemInstance])
	assert_false(_state.is_revealed(a))


func test_removing_last_pending_completes() -> void:
	var a: ItemInstance = _put(0, 0)
	_state.start()
	_state.tick(0.3)
	_grid.remove(a)
	assert_true(_state.is_complete())
	assert_eq(_state.current_item_id(), 0)
	_state.tick(1.0)
	assert_false(_state.searching)


func test_items_added_later_become_pending() -> void:
	var a: ItemInstance = _put(0, 1)
	_state.start()
	_state.tick(5.0)
	assert_true(_state.is_complete())
	var late: ItemInstance = _put(0, 0)
	assert_false(_state.is_complete())
	assert_eq(_state.pending_items(), [late] as Array[ItemInstance])
	assert_true(_state.is_revealed(a))
	_state.start()
	assert_eq(_state.tick(1.0).revealed, [late] as Array[ItemInstance])


func test_is_complete() -> void:
	assert_true(_state.is_complete())  # 빈 그리드
	var a: ItemInstance = _put(0, 0)
	var b: ItemInstance = _put(1, 0)
	assert_false(_state.is_complete())
	_state.mark_revealed(a)
	assert_false(_state.is_complete())
	_state.mark_revealed(b)
	assert_true(_state.is_complete())


func test_larger_item_takes_longer() -> void:
	var big: ItemInstance = _put(0, 0, _def(2, 2))
	_state.start()
	assert_eq(_state.tick(0.8).revealed.size(), 0)
	assert_eq(_state.tick(0.4).revealed, [big] as Array[ItemInstance])
