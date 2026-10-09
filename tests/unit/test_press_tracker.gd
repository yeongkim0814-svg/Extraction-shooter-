extends GutTest
## PressTracker (M5): 롱프레스 없는 탭 / 즉시 드래그 / 스크롤 판정.

var _t: PressTracker


func before_each() -> void:
	_t = PressTracker.new()


func test_tap_on_item_without_moving() -> void:
	_t.press(Vector2(100, 100), true)
	assert_eq(_t.move(Vector2(103, 104)), PressTracker.Outcome.NONE, "slop 안의 떨림은 탭")
	assert_eq(_t.release(Vector2(103, 104)), PressTracker.Outcome.TAP_ITEM)
	assert_true(_t.is_idle())


func test_press_item_and_move_beyond_slop_starts_drag_immediately() -> void:
	_t.press(Vector2(100, 100), true)
	assert_eq(_t.move(Vector2(100, 111)), PressTracker.Outcome.DRAG_STARTED)
	assert_true(_t.is_dragging())
	assert_eq(_t.move(Vector2(200, 200)), PressTracker.Outcome.NONE, "이미 드래그 중")
	assert_eq(_t.release(Vector2(200, 200)), PressTracker.Outcome.DRAG_ENDED)


func test_slop_boundary_is_exclusive() -> void:
	_t.press(Vector2.ZERO, true)
	assert_eq(_t.move(Vector2(PressTracker.SLOP, 0)), PressTracker.Outcome.NONE)
	assert_eq(_t.move(Vector2(PressTracker.SLOP + 0.5, 0)), PressTracker.Outcome.DRAG_STARTED)


func test_no_time_dependence() -> void:
	# 오래 눌러도 움직이지 않으면 그냥 탭 (롱프레스 없음)
	_t.press(Vector2(5, 5), true)
	OS.delay_msec(50)
	assert_eq(_t.release(Vector2(5, 5)), PressTracker.Outcome.TAP_ITEM)


func test_empty_press_and_move_scrolls_never_drags() -> void:
	_t.press(Vector2(300, 300), false)
	assert_eq(_t.move(Vector2(300, 320)), PressTracker.Outcome.SCROLL_STARTED)
	assert_true(_t.is_scrolling())
	assert_false(_t.is_dragging())
	assert_eq(_t.release(Vector2(300, 400)), PressTracker.Outcome.SCROLL_ENDED)


func test_empty_tap() -> void:
	_t.press(Vector2(300, 300), false)
	assert_eq(_t.release(Vector2(301, 300)), PressTracker.Outcome.TAP_EMPTY)


func test_release_without_press_and_cancel() -> void:
	assert_eq(_t.release(Vector2.ZERO), PressTracker.Outcome.NONE)
	_t.press(Vector2.ZERO, true)
	_t.move(Vector2(50, 0))
	_t.cancel()
	assert_true(_t.is_idle())
	assert_eq(_t.release(Vector2(50, 0)), PressTracker.Outcome.NONE)
	assert_eq(_t.move(Vector2(99, 0)), PressTracker.Outcome.NONE)


func test_new_press_restarts_from_new_origin() -> void:
	_t.press(Vector2(0, 0), true)
	_t.press(Vector2(500, 500), false)
	assert_eq(_t.origin, Vector2(500, 500))
	assert_eq(_t.move(Vector2(500, 520)), PressTracker.Outcome.SCROLL_STARTED)
