class_name AiGunner
extends RefCounted
## AI 사격 규율 (엔진 노드 없음): 연사 단위로 쏘고 쉬며, 연사 간격·탄창·재장전을 지키고,
## 시야를 잡은 시간에 따라 조준 퍼짐을 줄인다. 시간은 호출자가 delta로 넘기고, 난수는 주입받는다.

## 거리 퍼짐 보정: 이 거리(m)를 넘는 만큼 1 m당 더한다 (도).
const DISTANCE_FREE: float = 10.0
const DISTANCE_SPREAD_PER_M: float = 0.04

var profile: AiProfile
var mag_size: int
var fire_interval: float

var _rng: RandomNumberGenerator
var _rounds: int
var _reloading: bool = false
var _reload_left: float = 0.0
## 현재 연사에서 남은 발수 (0이면 다음 발사 때 새 연사를 정한다).
var _burst_left: int = 0
var _pause_left: float = 0.0
var _cooldown: float = 0.0
## 시야를 연속으로 잡고 있는 시간.
var _los_time: float = 0.0


func _init(p_profile: AiProfile, p_mag_size: int, p_fire_interval: float,
		p_rng: RandomNumberGenerator = null) -> void:
	profile = p_profile
	mag_size = maxi(p_mag_size, 1)
	fire_interval = maxf(p_fire_interval, 0.0)
	_rng = p_rng if p_rng != null else RandomNumberGenerator.new()
	_rounds = mag_size


func rounds() -> int:
	return _rounds


func is_reloading() -> bool:
	return _reloading


## 탄창이 비었고 아직 재장전을 시작하지 않았다.
func needs_reload() -> bool:
	return _rounds <= 0 and not _reloading


## 재장전을 시작한다. 이미 재장전 중이거나 탄창이 가득이면 무시.
func start_reload() -> void:
	if _reloading or _rounds >= mag_size:
		return
	_reloading = true
	_reload_left = profile.reload_time
	_burst_left = 0
	_pause_left = 0.0


## 연속 시야 시간 (조준 퍼짐 계산용, 테스트·디버그용).
func los_time() -> float:
	return _los_time


## 이번 틱에 한 발 쏘아야 하면 true (탄은 이미 한 발 줄어 있다).
## 시야가 없거나 사거리 밖이면 쏘지 않고 진행 중이던 연사는 끊는다.
func update(delta: float, has_line_of_sight: bool, distance: float) -> bool:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_pause_left = maxf(_pause_left - delta, 0.0)
	if has_line_of_sight:
		_los_time += delta
	else:
		_los_time = 0.0
	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reloading = false
			_rounds = mag_size
		return false
	if not has_line_of_sight or distance > profile.view_distance:
		_burst_left = 0
		return false
	if _rounds <= 0 or _pause_left > 0.0:
		return false
	if _burst_left <= 0:
		_burst_left = _rng.randi_range(maxi(profile.burst_min, 1), maxi(profile.burst_max, profile.burst_min))
	if _cooldown > 0.0:
		return false
	_rounds -= 1
	_burst_left -= 1
	_cooldown = fire_interval
	if _burst_left <= 0 and _rounds > 0:
		_pause_left = profile.burst_pause
	elif _rounds <= 0:
		_burst_left = 0
	return true


## 지금 쏠 때의 퍼짐 (도): 시야를 잡은 직후엔 aim_spread_start_deg, aim_settle_time 동안 선형으로
## aim_spread_min_deg까지 줄고, 거리 10 m를 넘는 만큼 1 m당 0.04도를 더한다.
func spread_deg(distance: float) -> float:
	var t: float = 1.0
	if profile.aim_settle_time > 0.0:
		t = clampf(_los_time / profile.aim_settle_time, 0.0, 1.0)
	var base: float = lerpf(profile.aim_spread_start_deg, profile.aim_spread_min_deg, t)
	return base + maxf(distance - DISTANCE_FREE, 0.0) * DISTANCE_SPREAD_PER_M
