extends GutTest
## 사격 계산: 퍼짐 방향, ADS 보정, 반동 킥, 방아쇠(단발/연사) 판정.


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_zero_spread_is_exactly_forward() -> void:
	var basis := Basis.from_euler(Vector3(0.3, 1.1, 0.0))
	var dir: Vector3 = FireMath.spread_direction(basis, 0.0, _rng())
	assert_almost_eq(dir.distance_to(-basis.z), 0.0, 0.0001)


func test_spread_stays_inside_cone_and_is_unit_length() -> void:
	var basis := Basis.from_euler(Vector3(-0.2, 0.7, 0.0))
	var rng: RandomNumberGenerator = _rng(42)
	var max_angle: float = 0.0
	for i: int in range(500):
		var dir: Vector3 = FireMath.spread_direction(basis, 3.0, rng)
		assert_almost_eq(dir.length(), 1.0, 0.0001)
		max_angle = maxf(max_angle, rad_to_deg((-basis.z).angle_to(dir)))
	assert_lte(max_angle, 3.0 + 0.001)
	assert_gt(max_angle, 2.5, "원뿔 가장자리 근처까지 퍼져야 한다")


func test_spread_is_deterministic_for_same_seed() -> void:
	var a: Vector3 = FireMath.spread_direction(Basis.IDENTITY, 2.0, _rng(5))
	var b: Vector3 = FireMath.spread_direction(Basis.IDENTITY, 2.0, _rng(5))
	assert_eq(a, b)


func test_ads_tightens_spread() -> void:
	assert_almost_eq(FireMath.effective_spread_deg(2.0, false), 2.0, 0.0001)
	assert_almost_eq(FireMath.effective_spread_deg(2.0, true), 2.0 * FireMath.ADS_SPREAD_MULT, 0.0001)
	assert_eq(FireMath.effective_spread_deg(-1.0, false), 0.0)


func test_recoil_kick_scales_with_stat_and_ads() -> void:
	var low: Vector2 = FireMath.recoil_kick(20.0, false, _rng())
	var high: Vector2 = FireMath.recoil_kick(80.0, false, _rng())
	assert_almost_eq(high.x, low.x * 4.0, 0.0001)
	assert_almost_eq(low.x, deg_to_rad(20.0 * FireMath.RECOIL_DEG_PER_POINT), 0.0001)
	var ads: Vector2 = FireMath.recoil_kick(80.0, true, _rng())
	assert_almost_eq(ads.x, high.x * FireMath.ADS_RECOIL_MULT, 0.0001)
	assert_lte(absf(high.y), high.x * FireMath.YAW_KICK_RATIO + 0.0001)
	assert_eq(FireMath.recoil_kick(0.0, false, _rng()).x, 0.0)


# --- TriggerLogic ---

func test_semi_fires_once_per_press() -> void:
	var t := TriggerLogic.new()
	t.set_held(true)
	assert_false(t.wants_fire(false, 0.0), "누른 적 없이 held만으로는 단발 안 됨")
	t.press(0.0)
	assert_true(t.wants_fire(false, 0.01))
	t.consume()
	assert_false(t.wants_fire(false, 0.02), "쏜 뒤에는 누르고 있어도 다시 안 나감")
	t.press(1.0)
	assert_true(t.wants_fire(false, 1.0))


func test_auto_fires_while_held() -> void:
	var t := TriggerLogic.new()
	t.press(0.0)
	t.set_held(true)
	t.consume()
	assert_true(t.wants_fire(true, 5.0))
	t.set_held(false)
	assert_false(t.wants_fire(true, 5.0))


func test_quick_tap_is_buffered_then_expires() -> void:
	var t := TriggerLogic.new()
	t.press(0.0)
	t.set_held(false)   # 프레임 사이에 이미 뗌
	assert_true(t.wants_fire(false, TriggerLogic.BUFFER_TIME * 0.5))
	assert_false(t.wants_fire(false, TriggerLogic.BUFFER_TIME + 0.1))


func test_clear_drops_buffered_press() -> void:
	var t := TriggerLogic.new()
	t.press(0.0)
	t.clear()
	assert_false(t.wants_fire(false, 0.01))
