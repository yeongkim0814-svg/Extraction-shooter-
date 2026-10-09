extends GutTest
## WeaponMotion (M7): 스프링 감쇠, ADS 시간·시야각, 반동 배율, 상태 갱신.

const DT: float = 1.0 / 60.0


func test_spring_decays_monotonically_without_overshoot() -> void:
	var state := Vector2(0.05, 0.0)
	var previous: float = state.x
	for i: int in range(120):
		state = WeaponMotion.spring_step(state, WeaponMotion.SPRING_OMEGA, DT)
		assert_lte(state.x, previous + 0.000001, "임계 감쇠는 넘어가지 않고 줄어든다")
		assert_gte(state.x, 0.0)
		previous = state.x
	assert_lt(state.x, 0.0005, "2초 뒤에는 거의 0")


func test_spring_step_is_frame_rate_independent() -> void:
	var coarse := WeaponMotion.spring_step(Vector2(0.04, 0.1), 16.0, 0.1)
	var fine := Vector2(0.04, 0.1)
	for i: int in range(10):
		fine = WeaponMotion.spring_step(fine, 16.0, 0.01)
	assert_almost_eq(coarse.x, fine.x, 0.00001)
	assert_almost_eq(coarse.y, fine.y, 0.00001)


func test_spring_with_zero_delta_changes_nothing() -> void:
	assert_eq(WeaponMotion.spring_step(Vector2(0.3, -0.2), 16.0, 0.0), Vector2(0.3, -0.2))


func test_ads_time_from_ergonomics() -> void:
	assert_almost_eq(WeaponMotion.ads_time_for(50.0), 0.35, 0.0001)
	assert_lt(WeaponMotion.ads_time_for(80.0), WeaponMotion.ads_time_for(50.0), "조작성이 높을수록 빠르다")
	assert_gt(WeaponMotion.ads_time_for(30.0), 0.35)
	assert_eq(WeaponMotion.ads_time_for(1000.0), WeaponMotion.ADS_TIME_MIN, "하한")
	assert_eq(WeaponMotion.ads_time_for(0.0), WeaponMotion.ADS_TIME_MAX, "0이어도 상한에서 멈춘다")


func test_ads_fov_shrinks_with_zoom() -> void:
	assert_almost_eq(WeaponMotion.ads_fov_for(0.0), WeaponMotion.FOV_ADS_BASE, 0.0001)
	assert_lt(WeaponMotion.ads_fov_for(0.1), WeaponMotion.ads_fov_for(0.0))
	assert_lt(WeaponMotion.ads_fov_for(1.5), WeaponMotion.ads_fov_for(0.1))
	assert_gte(WeaponMotion.ads_fov_for(100.0), WeaponMotion.FOV_MIN)
	assert_almost_eq(WeaponMotion.ads_fov_for(-1.0), WeaponMotion.FOV_ADS_BASE, 0.0001, "음수 zoom은 무시")


func test_recoil_scaling_by_ergonomics() -> void:
	assert_almost_eq(WeaponMotion.effective_recoil(30.0, 0.0), 30.0, 0.0001)
	assert_lt(WeaponMotion.effective_recoil(30.0, 50.0), 30.0)
	assert_lt(WeaponMotion.effective_recoil(30.0, 80.0), WeaponMotion.effective_recoil(30.0, 50.0))
	assert_almost_eq(WeaponMotion.effective_recoil(30.0, 50.0), 30.0 * 0.8, 0.0001)
	assert_almost_eq(WeaponMotion.ergo_recoil_factor(10000.0), WeaponMotion.ERGO_RECOIL_FLOOR, 0.0001)
	assert_eq(WeaponMotion.effective_recoil(-5.0, 40.0), 0.0)


func test_kick_magnitude_grows_with_recoil_and_is_capped() -> void:
	var small: Vector2 = WeaponMotion.kick_magnitude(10.0)
	var big: Vector2 = WeaponMotion.kick_magnitude(60.0)
	assert_gt(big.x, small.x)
	assert_gt(big.y, small.y)
	var huge: Vector2 = WeaponMotion.kick_magnitude(100000.0)
	assert_almost_eq(huge.x, WeaponMotion.KICK_BACK_MAX, 0.00001)
	assert_almost_eq(huge.y, WeaponMotion.KICK_PITCH_MAX, 0.00001)


func test_configure_reads_stats() -> void:
	var motion := WeaponMotion.new()
	var stats: Dictionary[StringName, float] = {WeaponStats.ERGONOMICS: 80.0, WeaponMotion.ZOOM: 1.5}
	motion.configure(stats)
	assert_almost_eq(motion.ads_time, WeaponMotion.ads_time_for(80.0), 0.0001)
	assert_almost_eq(motion.zoom, 1.5, 0.0001)


func test_ads_reaches_full_after_ads_time_and_returns() -> void:
	var motion := WeaponMotion.new()
	var stats: Dictionary[StringName, float] = {WeaponStats.ERGONOMICS: 50.0}
	motion.configure(stats)
	var steps: int = int(ceil(motion.ads_time / DT)) + 1
	for i: int in range(steps - 4):
		motion.update(DT, true, false, false, 0.0, Vector2.ZERO)
	assert_lt(motion.ads_amount(), 1.0, "시간이 다 되기 전에는 아직")
	for i: int in range(6):
		motion.update(DT, true, false, false, 0.0, Vector2.ZERO)
	assert_almost_eq(motion.ads_amount(), 1.0, 0.0001)
	assert_almost_eq(motion.fov(), WeaponMotion.FOV_ADS_BASE, 0.001)
	assert_almost_eq(motion.position.x, 0.0, 0.01, "중앙으로 온다")
	for i: int in range(60):
		motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	assert_eq(motion.ads_amount(), 0.0)
	assert_almost_eq(motion.fov(), WeaponMotion.FOV_NORMAL, 0.001)


func test_faster_ergonomics_reaches_ads_sooner() -> void:
	var slow := WeaponMotion.new()
	var fast := WeaponMotion.new()
	slow.configure({WeaponStats.ERGONOMICS: 30.0})
	fast.configure({WeaponStats.ERGONOMICS: 80.0})
	for i: int in range(12):
		slow.update(DT, true, false, false, 0.0, Vector2.ZERO)
		fast.update(DT, true, false, false, 0.0, Vector2.ZERO)
	assert_gt(fast.ads_amount(), slow.ads_amount())


func test_zoom_changes_ads_fov() -> void:
	var motion := WeaponMotion.new()
	motion.configure({WeaponMotion.ZOOM: 1.5})
	for i: int in range(80):
		motion.update(DT, true, false, false, 0.0, Vector2.ZERO)
	assert_almost_eq(motion.fov(), WeaponMotion.ads_fov_for(1.5), 0.001)


func test_kick_pushes_weapon_back_then_recovers() -> void:
	var motion := WeaponMotion.new()
	motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	var rest_z: float = motion.position.z
	motion.kick(25.0, 0.5)
	motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	assert_gt(motion.position.z, rest_z + 0.005, "킥백 (+Z = 카메라 쪽)")
	assert_gt(motion.euler.x, 0.01, "총구 들림")
	for i: int in range(120):
		motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	assert_almost_eq(motion.position.z, rest_z, 0.002)
	assert_almost_eq(motion.euler.x, 0.0, 0.002)


func test_ads_kick_is_smaller_than_hip_kick() -> void:
	var hip := WeaponMotion.new()
	var ads := WeaponMotion.new()
	for i: int in range(60):
		ads.update(DT, true, false, false, 0.0, Vector2.ZERO)
		hip.update(DT, false, false, false, 0.0, Vector2.ZERO)
	hip.kick(25.0, 0.0)
	ads.kick(25.0, 0.0)
	hip.update(DT, false, false, false, 0.0, Vector2.ZERO)
	ads.update(DT, true, false, false, 0.0, Vector2.ZERO)
	assert_lt(ads.euler.x, hip.euler.x)


func test_sprint_pose_blends_in_and_is_suppressed_by_ads() -> void:
	var motion := WeaponMotion.new()
	for i: int in range(40):
		motion.update(DT, false, true, false, 1.4, Vector2.ZERO)
	assert_almost_eq(motion.sprint_amount(), 1.0, 0.001)
	assert_lt(motion.position.y, motion.hip_position.y - 0.05, "총을 내린다")
	assert_gt(absf(motion.euler.y), 0.3, "총을 눕힌다")
	var aiming := WeaponMotion.new()
	for i: int in range(40):
		aiming.update(DT, true, true, false, 1.4, Vector2.ZERO)
	assert_eq(aiming.sprint_amount(), 0.0, "조준 중에는 달리기 자세 없음")


func test_sway_and_bob_are_scaled_down_while_ads() -> void:
	assert_lt(absf(WeaponMotion.sway_offset(1.3, WeaponMotion.ADS_SWAY_SCALE).x),
			absf(WeaponMotion.sway_offset(1.3, 1.0).x) + 0.000001)
	var walk := WeaponMotion.bob_offset(1.0, 1.0)
	var aim := WeaponMotion.bob_offset(1.0, WeaponMotion.ADS_BOB_SCALE)
	assert_lt(aim.length(), walk.length())
	assert_eq(WeaponMotion.bob_offset(1.0, 0.0), Vector2.ZERO)


func test_look_lag_follows_and_decays() -> void:
	var motion := WeaponMotion.new()
	motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	var rest_yaw: float = motion.euler.y
	motion.update(DT, false, false, false, 0.0, Vector2(0.1, 0.0))
	assert_gt(motion.euler.y, rest_yaw + 0.005, "오른쪽으로 돌리면 무기는 왼쪽으로 뒤처진다")
	motion.update(DT, false, false, false, 0.0, Vector2(10.0, 0.0))
	assert_lt(motion.euler.y, rest_yaw + WeaponMotion.LOOK_LAG_MAX + 0.01, "뒤처짐에는 상한이 있다")
	for i: int in range(120):
		motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	assert_almost_eq(motion.euler.y, rest_yaw, 0.01)


func test_swap_starts_low_and_rises() -> void:
	var motion := WeaponMotion.new()
	motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	var rest_y: float = motion.position.y
	motion.start_swap()
	motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	assert_lt(motion.position.y, rest_y - 0.1)
	for i: int in range(40):
		motion.update(DT, false, false, false, 0.0, Vector2.ZERO)
	assert_almost_eq(motion.position.y, rest_y, 0.01)


func test_sight_height_puts_sightline_at_screen_center_in_ads() -> void:
	var motion := WeaponMotion.new()
	motion.set_sight_height(0.09)
	for i: int in range(80):
		motion.update(DT, true, false, false, 0.0, Vector2.ZERO)
	assert_almost_eq(motion.position.y + 0.09, 0.0, 0.005)
