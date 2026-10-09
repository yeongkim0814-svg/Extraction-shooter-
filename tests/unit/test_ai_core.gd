extends GutTest
## M8 AI 코어: AiPerception(시야·청각·소음 반경)과 AiGunner(연사·재장전·조준 퍼짐).

const DT: float = 0.05

var _profile: AiProfile
var _rng: RandomNumberGenerator


func before_each() -> void:
	_profile = AiProfile.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345


func _gunner(mag: int = 30, interval: float = 0.1) -> AiGunner:
	return AiGunner.new(_profile, mag, interval, _rng)


## 시간을 흘려 보내며 발사 시각 목록을 모은다.
func _run(gunner: AiGunner, seconds: float, los: bool = true, distance: float = 10.0) -> Array[float]:
	var shots: Array[float] = []
	var t: float = 0.0
	while t < seconds:
		t += DT
		if gunner.update(DT, los, distance):
			shots.append(t)
	return shots


# --- AiPerception ---

func test_view_cone_straight_ahead() -> void:
	assert_true(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -10), 110.0, 45.0))


func test_view_cone_behind_is_not_visible() -> void:
	assert_false(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 10), 110.0, 45.0))


func test_view_cone_horizontal_edge() -> void:
	var inside := Vector3(sin(deg_to_rad(50.0)), 0, -cos(deg_to_rad(50.0))) * 10.0
	var outside := Vector3(sin(deg_to_rad(60.0)), 0, -cos(deg_to_rad(60.0))) * 10.0
	assert_true(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, inside, 110.0, 45.0))
	assert_false(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, outside, 110.0, 45.0))


func test_view_cone_vertical_limit() -> void:
	var up_inside := Vector3(0, sin(deg_to_rad(40.0)), -cos(deg_to_rad(40.0))) * 10.0
	var up_outside := Vector3(0, sin(deg_to_rad(70.0)), -cos(deg_to_rad(70.0))) * 10.0
	assert_true(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, up_inside, 110.0, 45.0))
	assert_false(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, up_outside, 110.0, 45.0))


func test_view_cone_distance_limit() -> void:
	assert_true(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -45), 110.0, 45.0))
	assert_false(AiPerception.in_view_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -45.5), 110.0, 45.0))


func test_view_cone_zero_distance_counts_as_visible() -> void:
	assert_true(AiPerception.in_view_cone(Vector3(1, 2, 3), Vector3.FORWARD, Vector3(1, 2, 3), 10.0, 5.0))


func test_view_cone_unnormalized_forward_and_straight_up() -> void:
	assert_true(AiPerception.in_view_cone(Vector3.ZERO, Vector3(0, 0, -5), Vector3(0, 0, -10), 90.0, 45.0))
	assert_true(AiPerception.in_view_cone(Vector3.ZERO, Vector3.UP, Vector3(0, 10, 0), 90.0, 45.0))


func test_view_cone_degenerate_forward_sees_nothing() -> void:
	assert_false(AiPerception.in_view_cone(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -5), 110.0, 45.0))


func test_sight_distance_modifiers() -> void:
	assert_almost_eq(AiPerception.sight_distance(40.0, false, false), 40.0, 0.001)
	assert_almost_eq(AiPerception.sight_distance(40.0, true, false), 24.0, 0.001)
	assert_almost_eq(AiPerception.sight_distance(40.0, false, true), 50.0, 0.001)
	assert_almost_eq(AiPerception.sight_distance(40.0, true, true), 24.0, 0.001)


func test_hears_within_radius_and_multiplier() -> void:
	assert_true(AiPerception.hears(Vector3.ZERO, 20.0, Vector3(20, 0, 0), 1.0))
	assert_false(AiPerception.hears(Vector3.ZERO, 20.0, Vector3(20.1, 0, 0), 1.0))
	assert_true(AiPerception.hears(Vector3.ZERO, 20.0, Vector3(30, 0, 0), 1.5))
	assert_false(AiPerception.hears(Vector3.ZERO, 20.0, Vector3(10, 0, 0), 0.0))


func test_noise_radii() -> void:
	assert_almost_eq(AiPerception.shot_noise_radius(1.0), 90.0, 0.001)
	assert_almost_eq(AiPerception.shot_noise_radius(0.4), 36.0, 0.001)
	assert_almost_eq(AiPerception.shot_noise_radius(-1.0), 0.0, 0.001)
	assert_almost_eq(AiPerception.footstep_noise_radius(true, false, true), 15.0, 0.001)
	assert_almost_eq(AiPerception.footstep_noise_radius(false, false, true), 7.0, 0.001)
	assert_almost_eq(AiPerception.footstep_noise_radius(false, true, true), 2.0, 0.001)
	assert_almost_eq(AiPerception.footstep_noise_radius(true, true, false), 0.0, 0.001)


# --- AiGunner ---

func test_new_gunner_has_full_mag() -> void:
	var gunner: AiGunner = _gunner(30)
	assert_eq(gunner.rounds(), 30)
	assert_false(gunner.is_reloading())
	assert_false(gunner.needs_reload())


func test_no_fire_without_line_of_sight() -> void:
	var gunner: AiGunner = _gunner()
	assert_eq(_run(gunner, 3.0, false).size(), 0)
	assert_eq(gunner.rounds(), 30)


func test_no_fire_beyond_view_distance() -> void:
	var gunner: AiGunner = _gunner()
	assert_eq(_run(gunner, 3.0, true, _profile.view_distance + 1.0).size(), 0)


func test_burst_sizes_within_profile_range() -> void:
	_profile.burst_min = 2
	_profile.burst_max = 4
	_profile.burst_pause = 0.7
	var gunner: AiGunner = _gunner(300, 0.1)
	var shots: Array[float] = _run(gunner, 40.0)
	var bursts: Array[int] = []
	var current: int = 1
	for i: int in range(1, shots.size()):
		if shots[i] - shots[i - 1] > 0.5:
			bursts.append(current)
			current = 1
		else:
			current += 1
	assert_gt(bursts.size(), 10)
	for size: int in bursts:
		assert_between(size, 2, 4)
	assert_true(bursts.has(2) or bursts.has(3) or bursts.has(4))
	assert_gt(bursts.max() - bursts.min(), 0, "연사 크기가 매번 같으면 안 된다")


func test_fixed_burst_size_and_pause_length() -> void:
	_profile.burst_min = 3
	_profile.burst_max = 3
	_profile.burst_pause = 1.0
	var gunner: AiGunner = _gunner(300, 0.1)
	var shots: Array[float] = _run(gunner, 10.0)
	# 연사 안 간격은 연사 속도, 연사 사이 간격은 쉬는 시간(+조금)
	assert_almost_eq(shots[1] - shots[0], 0.1, DT * 1.01)
	assert_almost_eq(shots[2] - shots[1], 0.1, DT * 1.01)
	assert_between(shots[3] - shots[2], 1.0, 1.0 + DT * 1.5)
	assert_eq(shots.size() % 3, 0)


func test_respects_fire_interval() -> void:
	_profile.burst_min = 10
	_profile.burst_max = 10
	var gunner: AiGunner = _gunner(300, 0.2)
	var shots: Array[float] = _run(gunner, 2.0)
	for i: int in range(1, mini(shots.size(), 10)):
		assert_gte(shots[i] - shots[i - 1], 0.2 - 0.0001)


func test_losing_sight_ends_burst() -> void:
	_profile.burst_min = 4
	_profile.burst_max = 4
	_profile.burst_pause = 5.0
	var gunner: AiGunner = _gunner(300, 0.1)
	var first: Array[float] = _run(gunner, 0.25)
	assert_gt(first.size(), 0)
	assert_lt(first.size(), 4)
	_run(gunner, 0.2, false)
	# 시야를 되찾으면 쉬는 시간 없이 새 연사를 시작한다
	assert_gt(_run(gunner, 0.3).size(), 0)


func test_empty_mag_stops_and_needs_reload() -> void:
	_profile.burst_min = 2
	_profile.burst_max = 2
	_profile.burst_pause = 0.1
	var gunner: AiGunner = _gunner(5, 0.1)
	var shots: Array[float] = _run(gunner, 10.0)
	assert_eq(shots.size(), 5)
	assert_eq(gunner.rounds(), 0)
	assert_true(gunner.needs_reload())
	assert_eq(_run(gunner, 2.0).size(), 0)


func test_reload_cycle() -> void:
	_profile.reload_time = 2.5
	_profile.burst_min = 5
	_profile.burst_max = 5
	_profile.burst_pause = 0.0
	var gunner: AiGunner = _gunner(5, 0.1)
	_run(gunner, 3.0)
	assert_true(gunner.needs_reload())
	gunner.start_reload()
	assert_true(gunner.is_reloading())
	assert_false(gunner.needs_reload())
	assert_eq(_run(gunner, 2.0).size(), 0, "재장전 중에는 쏘지 않는다")
	assert_true(gunner.is_reloading())
	assert_eq(gunner.rounds(), 0)
	gunner.update(0.6, false, 10.0)
	assert_false(gunner.is_reloading())
	assert_eq(gunner.rounds(), 5)
	assert_gt(_run(gunner, 1.0).size(), 0, "재장전 뒤 다시 쏜다")


func test_reload_ignored_when_full_or_already_reloading() -> void:
	var gunner: AiGunner = _gunner(5, 0.1)
	gunner.start_reload()
	assert_false(gunner.is_reloading())
	_run(gunner, 0.5)
	gunner.start_reload()
	assert_true(gunner.is_reloading())
	gunner.update(1.0, false, 10.0)
	gunner.start_reload()   # 이미 재장전 중: 시간이 다시 늘어나지 않는다
	gunner.update(1.6, false, 10.0)
	assert_false(gunner.is_reloading())
	assert_eq(gunner.rounds(), 5)


func test_reload_works_without_line_of_sight() -> void:
	_profile.burst_min = 5
	_profile.burst_max = 5
	var gunner: AiGunner = _gunner(5, 0.1)
	_run(gunner, 3.0)
	gunner.start_reload()
	_run(gunner, 3.0, false)
	assert_eq(gunner.rounds(), 5)


# --- 조준 퍼짐 ---

func test_spread_starts_at_profile_start_on_acquire() -> void:
	var gunner: AiGunner = _gunner()
	gunner.update(0.001, true, 5.0)
	assert_almost_eq(gunner.spread_deg(5.0), _profile.aim_spread_start_deg, 0.05)


func test_spread_decays_linearly_to_min() -> void:
	_profile.aim_spread_start_deg = 6.0
	_profile.aim_spread_min_deg = 2.0
	_profile.aim_settle_time = 2.0
	var gunner: AiGunner = _gunner()
	gunner.update(1.0, true, 5.0)
	assert_almost_eq(gunner.spread_deg(5.0), 4.0, 0.001)
	gunner.update(1.0, true, 5.0)
	assert_almost_eq(gunner.spread_deg(5.0), 2.0, 0.001)
	gunner.update(5.0, true, 5.0)
	assert_almost_eq(gunner.spread_deg(5.0), 2.0, 0.001)


func test_spread_resets_when_sight_lost() -> void:
	var gunner: AiGunner = _gunner()
	gunner.update(5.0, true, 5.0)
	assert_almost_eq(gunner.spread_deg(5.0), _profile.aim_spread_min_deg, 0.001)
	gunner.update(0.1, false, 5.0)
	gunner.update(0.001, true, 5.0)
	assert_almost_eq(gunner.spread_deg(5.0), _profile.aim_spread_start_deg, 0.05)


func test_spread_distance_term() -> void:
	var gunner: AiGunner = _gunner()
	gunner.update(10.0, true, 5.0)
	var near: float = gunner.spread_deg(10.0)
	assert_almost_eq(near, _profile.aim_spread_min_deg, 0.001)
	assert_almost_eq(gunner.spread_deg(5.0), near, 0.001, "10 m 안쪽은 거리 보정 없음")
	assert_almost_eq(gunner.spread_deg(60.0) - near, 50.0 * 0.04, 0.001)


func test_spread_zero_settle_time_is_instant() -> void:
	_profile.aim_settle_time = 0.0
	var gunner: AiGunner = _gunner()
	assert_almost_eq(gunner.spread_deg(0.0), _profile.aim_spread_min_deg, 0.001)
