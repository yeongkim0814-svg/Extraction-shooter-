extends GutTest
## 달리기 잠금: 존 기하, 놓을 때 잠금, 취소 사유, 사격 지연, 키보드 토글, InputState 연동.

const R: float = 100.0
const R_UP: Vector2 = Vector2(0.0, -1.0)

var _lock: SprintLock


func before_each() -> void:
	_lock = SprintLock.new()


func _up(dist: float, angle_deg: float = 0.0) -> Vector2:
	return R_UP.rotated(deg_to_rad(angle_deg)) * dist


# --- 존 기하 ---

func test_angle_from_up() -> void:
	assert_almost_eq(SprintLock.angle_from_up_deg(Vector2(0, -50)), 0.0, 0.001)
	assert_almost_eq(SprintLock.angle_from_up_deg(Vector2(50, 0)), 90.0, 0.001)
	assert_almost_eq(SprintLock.angle_from_up_deg(Vector2(-50, 0)), 90.0, 0.001)
	assert_almost_eq(SprintLock.angle_from_up_deg(Vector2(0, 50)), 180.0, 0.001)


func test_zone_requires_distance_beyond_135_percent() -> void:
	assert_true(SprintLock.in_zone(_up(R * 1.36), R))
	assert_false(SprintLock.in_zone(_up(R * 1.34), R), "1.35R 이하는 존 밖")
	assert_false(SprintLock.in_zone(_up(R * 1.0), R), "링 가장자리는 존 밖")
	assert_false(SprintLock.in_zone(Vector2.ZERO, R))


func test_zone_angle_limit_is_35_degrees_both_sides() -> void:
	assert_true(SprintLock.in_zone(_up(R * 1.6, 34.0), R))
	assert_true(SprintLock.in_zone(_up(R * 1.6, -34.0), R))
	assert_false(SprintLock.in_zone(_up(R * 1.6, 36.0), R))
	assert_false(SprintLock.in_zone(_up(R * 1.6, -36.0), R))
	assert_false(SprintLock.in_zone(Vector2(0, R * 1.6), R), "아래쪽은 존 밖")
	assert_false(SprintLock.in_zone(Vector2(R * 1.6, 0), R), "옆쪽은 존 밖")


func test_zone_hint_state_near_ring_edge() -> void:
	assert_eq(SprintLock.zone_of(_up(R * 0.95, 20.0), R), SprintLock.Zone.NEAR)
	assert_eq(SprintLock.zone_of(_up(R * 1.6), R), SprintLock.Zone.INSIDE)
	assert_eq(SprintLock.zone_of(_up(R * 0.5), R), SprintLock.Zone.NONE)
	assert_eq(SprintLock.zone_of(Vector2(0, R * 1.6), R), SprintLock.Zone.NONE)


# --- 놓을 때 잠금 ---

func test_release_inside_zone_locks_and_emits() -> void:
	var fired: Array[bool] = [false]
	_lock.engaged.connect(func() -> void: fired[0] = true)
	assert_true(_lock.release_stick(_up(R * 1.6), R))
	assert_true(_lock.is_locked())
	assert_true(fired[0])
	assert_true(_lock.sprinting(false), "누르지 않아도 달린다")


func test_release_outside_zone_does_not_lock() -> void:
	assert_false(_lock.release_stick(_up(R * 1.0), R))
	assert_false(_lock.release_stick(_up(R * 1.6, 60.0), R))
	assert_false(_lock.is_locked())
	assert_false(_lock.sprinting(false))


# --- 취소 사유 ---

func _cancel_reason_of(reason: SprintLock.Reason) -> StringName:
	var got: Array[StringName] = []
	var lock := SprintLock.new()
	lock.cancelled.connect(func(r: StringName) -> void: got.append(r))
	lock.engage()
	assert_true(lock.cancel(reason, false))
	assert_false(lock.is_locked())
	return got[0] if got.size() == 1 else &"<none>"


func test_each_cancel_reason_unlocks_with_name() -> void:
	assert_eq(_cancel_reason_of(SprintLock.Reason.TOUCH), &"touch")
	assert_eq(_cancel_reason_of(SprintLock.Reason.PULL_DOWN), &"pull_down")
	assert_eq(_cancel_reason_of(SprintLock.Reason.ADS), &"ads")
	assert_eq(_cancel_reason_of(SprintLock.Reason.FIRE), &"fire")
	assert_eq(_cancel_reason_of(SprintLock.Reason.CROUCH), &"crouch")
	assert_eq(_cancel_reason_of(SprintLock.Reason.WALL), &"wall")
	assert_eq(_cancel_reason_of(SprintLock.Reason.KEY_BACK), &"key_back")
	assert_eq(_cancel_reason_of(SprintLock.Reason.TOGGLE), &"toggle")
	assert_eq(_cancel_reason_of(SprintLock.Reason.FOCUS), &"focus")


func test_cancel_when_unlocked_is_silent() -> void:
	var count: Array[int] = [0]
	_lock.cancelled.connect(func(_r: StringName) -> void: count[0] += 1)
	assert_false(_lock.cancel(SprintLock.Reason.ADS, false))
	assert_eq(count[0], 0)


func test_pull_stick_down_cancels_but_up_and_sideways_keep() -> void:
	_lock.engage()
	_lock.update_stick(Vector2(0, -1))
	_lock.update_stick(Vector2(0.8, 0.1))
	assert_true(_lock.is_locked())
	_lock.update_stick(Vector2(0, 0.5))
	assert_false(_lock.is_locked())


func test_wall_stop_cancels_after_half_second_only() -> void:
	_lock.engage()
	for i: int in range(20):   # 0.4 s 정지
		_lock.update_motion(0.0, 0.02)
	assert_true(_lock.is_locked())
	_lock.update_motion(5.0, 0.02)   # 다시 달리면 누적 초기화
	for i: int in range(20):
		_lock.update_motion(0.0, 0.02)
	assert_true(_lock.is_locked(), "초기화되어 아직 0.4초")
	for i: int in range(10):
		_lock.update_motion(0.0, 0.02)
	assert_false(_lock.is_locked(), "0.5초 초과 정지")


func test_wall_stop_ignored_when_unlocked() -> void:
	for i: int in range(100):
		_lock.update_motion(0.0, 0.02)
	assert_false(_lock.is_locked())


# --- 사격 지연 / 눌린 달리기 억제 ---

func test_fire_cancel_of_lock_blocks_fire_for_200ms() -> void:
	_lock.engage()
	_lock.cancel(SprintLock.Reason.FIRE, false)
	assert_false(_lock.can_fire())
	assert_almost_eq(_lock.fire_block_remaining(), SprintLock.FIRE_DELAY, 0.0001)
	_lock.advance(0.19, false)
	assert_false(_lock.can_fire())
	_lock.advance(0.02, false)
	assert_true(_lock.can_fire())
	assert_eq(_lock.fire_block_remaining(), 0.0)


func test_fire_while_held_sprint_blocks_fire_and_suppresses_sprint() -> void:
	assert_true(_lock.sprinting(true))
	_lock.cancel(SprintLock.Reason.FIRE, true)
	assert_false(_lock.can_fire())
	assert_false(_lock.sprinting(true), "스틱을 계속 밀어도 사격 후엔 달리기 끝")
	_lock.advance(0.1, true)
	assert_false(_lock.sprinting(true))
	_lock.advance(0.1, false)   # 스틱을 풀었다
	assert_true(_lock.can_fire())
	assert_true(_lock.sprinting(true), "다시 밀면 달리기 재개")


func test_fire_without_sprint_has_no_delay() -> void:
	_lock.cancel(SprintLock.Reason.FIRE, false)
	assert_true(_lock.can_fire())


func test_ads_while_held_sprint_suppresses_without_fire_delay() -> void:
	_lock.cancel(SprintLock.Reason.ADS, true)
	assert_false(_lock.sprinting(true))
	assert_true(_lock.can_fire())


func test_touch_cancel_does_not_suppress_new_press() -> void:
	_lock.engage()
	_lock.cancel(SprintLock.Reason.TOUCH, true)
	assert_true(_lock.sprinting(true), "새 터치가 곧바로 달리기를 이어받을 수 있다")


# --- 유지되는 동작 (점프 · 재장전 · 무기 교체) ---

func test_jump_reload_switch_do_not_cancel_lock() -> void:
	var st := InputState.new()
	st.sprint_lock.engage()
	st.press_jump()
	st.press_reload()
	st.press_switch()
	st.select_slot(1)
	st.add_look(Vector2(0.2, 0.0))
	assert_true(st.sprint_lock.is_locked())


# --- 키보드 토글 ---

func test_toggle_on_and_off() -> void:
	var reasons: Array[StringName] = []
	_lock.cancelled.connect(func(r: StringName) -> void: reasons.append(r))
	_lock.toggle()
	assert_true(_lock.is_locked())
	_lock.toggle()
	assert_false(_lock.is_locked())
	assert_eq(reasons, [&"toggle"] as Array[StringName])


func test_capslock_down_up_pair_toggles_once() -> void:
	_lock.key_toggle_event(true)
	_lock.key_toggle_event(false)
	assert_true(_lock.is_locked(), "Windows형: down+up = 한 번")
	_lock.key_toggle_event(true)
	_lock.key_toggle_event(false)
	assert_false(_lock.is_locked())


func test_capslock_macos_release_only_counts_as_press() -> void:
	_lock.key_toggle_event(true)    # 켤 때 keydown만
	assert_true(_lock.is_locked())
	_lock.key_toggle_event(false)   # 짝이 되는 keyup은 무시
	_lock.key_toggle_event(false)   # 끌 때 keyup만 -> 토글
	assert_false(_lock.is_locked())


# --- InputState 연동 ---

func test_input_state_effective_move_is_forward_when_locked() -> void:
	var st := InputState.new()
	assert_eq(st.effective_move(), Vector2.ZERO)
	st.sprint_lock.engage()
	assert_eq(st.effective_move(), Vector2(0, -1))
	assert_true(st.sprint_active())
	st.set_move(InputState.Source.KEYBOARD, Vector2(1, 0))
	assert_almost_eq(st.effective_move().y, -0.7071, 0.001, "좌우 입력은 유지")


func test_input_state_fire_ads_crouch_cancel_lock() -> void:
	var st := InputState.new()
	st.sprint_lock.engage()
	st.press_fire()
	assert_false(st.sprint_lock.is_locked())
	assert_false(st.sprint_lock.can_fire())
	st.sprint_lock.engage()
	st.press_ads_toggle()
	assert_false(st.sprint_lock.is_locked())
	st.sprint_lock.engage()
	st.set_ads_held(InputState.Source.KEYBOARD, true)   # 우클릭
	assert_false(st.sprint_lock.is_locked())
	st.sprint_lock.engage()
	st.press_crouch_toggle()
	assert_false(st.sprint_lock.is_locked())
	st.sprint_lock.engage()
	st.set_crouch_held(InputState.Source.KEYBOARD, true)   # Ctrl
	assert_false(st.sprint_lock.is_locked())


func test_crouch_held_cancels_only_on_rising_edge() -> void:
	var st := InputState.new()
	st.set_crouch_held(InputState.Source.KEYBOARD, true)
	st.sprint_lock.engage()
	st.set_crouch_held(InputState.Source.KEYBOARD, true)   # 매 프레임 같은 값 -> 취소 아님
	assert_true(st.sprint_lock.is_locked())


func test_input_state_held_sprint_suppressed_by_fire_until_release() -> void:
	var st := InputState.new()
	st.set_sprint(InputState.Source.TOUCH, true)
	st.tick(0.016)
	assert_true(st.sprint_active())
	st.press_fire()
	assert_false(st.sprint_active())
	assert_false(st.sprint_lock.can_fire())
	st.set_sprint(InputState.Source.TOUCH, false)
	st.tick(0.016)
	st.set_sprint(InputState.Source.TOUCH, true)
	assert_true(st.sprint_active())
