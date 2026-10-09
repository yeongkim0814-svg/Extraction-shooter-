class_name WeaponMotion
extends RefCounted
## 1인칭 무기의 절차적 움직임. 순수 계산(정적 함수)과 프레임마다 갱신하는 상태를 함께 가진다.
## 노드 의존이 없어 테스트 가능하다. WeaponView가 결과(position/euler)를 노드에 적용한다.
##   반동: 모델 킥백(+Z)·총구 들림·무작위 좌우 틀어짐 → 임계 감쇠 스프링으로 복귀
##   흔들림: 정지 시 숨쉬기 흔들림, 이동 시 보빙 (ADS 중에는 크게 줄임), 시점 회전에 살짝 뒤처지는 룩 스웨이
##   ADS: 조작성(ERGONOMICS)으로 걸리는 시간이 정해지고, 무기가 중앙으로 오며 FOV가 줄어든다 (광학기기 "zoom" 스탯)
##   달리기 자세 / 재장전 자세 / 무기 교체 올리기

## 광학기기 부품이 additive 스탯으로 주는 배율 키 (코어 WeaponStats에는 없는 게임 계층 스탯). 총 배율 = 1 + zoom.
const ZOOM := &"zoom"

const FOV_NORMAL: float = 75.0
## 광학기기가 없을 때 ADS 시야각. zoom이 있으면 FOV_ADS_BASE / (1 + zoom).
const FOV_ADS_BASE: float = 55.0
const FOV_MIN: float = 12.0

const ADS_TIME_REF: float = 0.35
const ADS_ERGO_REF: float = 50.0
const ADS_TIME_MIN: float = 0.12
const ADS_TIME_MAX: float = 0.9

## 조작성 1당 반동 감소 비율. 조작성 100이면 40% 감소 (하한 0.4배).
const ERGO_RECOIL_REDUCTION: float = 0.004
const ERGO_RECOIL_FLOOR: float = 0.4

const SPRING_OMEGA: float = 16.0
const KICK_BACK_BASE: float = 0.012
const KICK_BACK_PER_RECOIL: float = 0.0006
const KICK_BACK_MAX: float = 0.08
const KICK_PITCH_PER_RECOIL: float = 0.0018
const KICK_PITCH_MAX: float = 0.16
const KICK_YAW_RATIO: float = 0.3
## ADS 중 시각적 킥을 이만큼 줄인다.
const ADS_KICK_REDUCTION: float = 0.4

const SWAY_AMOUNT: float = 0.0016
const BOB_FREQ: float = 1.7
const BOB_X: float = 0.009
const BOB_Y: float = 0.006
## ADS 중 흔들림·보빙 배율 (1 - ADS 비율 * (1 - 이 값)).
const ADS_SWAY_SCALE: float = 0.25
const ADS_BOB_SCALE: float = 0.12

const LOOK_LAG_GAIN: float = 0.55
const LOOK_LAG_MAX: float = 0.05
const LOOK_LAG_RECOVER: float = 9.0

const SPRINT_RATE: float = 7.0
const SPRINT_POS := Vector3(0.05, -0.09, 0.03)
const SPRINT_EULER := Vector3(-0.32, 0.6, 0.22)
const RELOAD_RATE: float = 6.0
const RELOAD_POS := Vector3(-0.02, -0.1, 0.04)
const RELOAD_EULER := Vector3(0.45, 0.2, -0.3)
const SWAP_DROP := Vector3(0.0, -0.22, 0.04)
const SWAP_TIME: float = 0.4

# --- 결과 (WeaponView가 읽는다) ---

var position: Vector3 = Vector3.ZERO
var euler: Vector3 = Vector3.ZERO

# --- 설정 ---

var hip_position := Vector3(0.12, -0.125, -0.4)
var ads_position := Vector3(0.0, -0.08, -0.17)
var ads_time: float = ADS_TIME_REF
var zoom: float = 0.0
var ergonomics: float = ADS_ERGO_REF

# --- 상태 ---

var _ads: float = 0.0              # 0..1 선형 진행도 (보이는 값은 ads_amount()의 부드러운 곡선)
var _sprint: float = 0.0
var _reload: float = 0.0
var _swap: float = 0.0
var _kick_z: Vector2 = Vector2.ZERO    # (위치, 속도)
var _kick_pitch: Vector2 = Vector2.ZERO
var _kick_yaw: Vector2 = Vector2.ZERO
var _look_lag: Vector2 = Vector2.ZERO
var _bob_phase: float = 0.0
var _bob_amount: float = 0.0
var _time: float = 0.0


# --- 순수 계산 ---

## ADS에 걸리는 시간(초). 조작성 50이면 0.35초, 높을수록 빠르다.
static func ads_time_for(ergo: float) -> float:
	return clampf(ADS_TIME_REF * ADS_ERGO_REF / maxf(ergo, 1.0), ADS_TIME_MIN, ADS_TIME_MAX)


## ADS 시야각. zoom은 additive 배율 스탯 (0 = 광학기기 없음).
static func ads_fov_for(p_zoom: float) -> float:
	return maxf(FOV_ADS_BASE / (1.0 + maxf(p_zoom, 0.0)), FOV_MIN)


## 조작성이 반동에 곱하는 배율 (1.0 = 감소 없음).
static func ergo_recoil_factor(ergo: float) -> float:
	return clampf(1.0 - maxf(ergo, 0.0) * ERGO_RECOIL_REDUCTION, ERGO_RECOIL_FLOOR, 1.0)


## 스탯 RECOIL을 조작성으로 줄인 실제 반동 세기. FireMath.recoil_kick과 모델 킥 모두 이 값을 쓴다.
static func effective_recoil(recoil: float, ergo: float) -> float:
	return maxf(recoil, 0.0) * ergo_recoil_factor(ergo)


## 임계 감쇠 스프링을 delta만큼 진행한다. 입력/출력 모두 (위치, 속도). 해석해라 delta가 커도 안정적이다.
static func spring_step(state: Vector2, omega: float, delta: float) -> Vector2:
	var decay: float = exp(-omega * delta)
	var b: float = state.y + omega * state.x
	return Vector2((state.x + b * delta) * decay, (state.y - omega * b * delta) * decay)


## 한 발의 모델 킥 크기: (뒤로 밀림 m, 총구 들림 rad).
static func kick_magnitude(effective: float) -> Vector2:
	return Vector2(minf(KICK_BACK_BASE + effective * KICK_BACK_PER_RECOIL, KICK_BACK_MAX),
			minf(effective * KICK_PITCH_PER_RECOIL, KICK_PITCH_MAX))


## ADS 진행도(선형 0..1)를 보이는 부드러운 곡선으로.
static func ease_ads(linear: float) -> float:
	return smoothstep(0.0, 1.0, clampf(linear, 0.0, 1.0))


## 이동 보빙 오프셋 (x, y). amount = 이동 속도 비율 * ADS 감쇠.
static func bob_offset(phase: float, amount: float) -> Vector2:
	return Vector2(sin(phase) * BOB_X, sin(phase * 2.0) * BOB_Y) * amount


## 정지 시 숨쉬기 흔들림 (x, y).
static func sway_offset(time: float, scale: float) -> Vector2:
	return Vector2(sin(time * 1.1), sin(time * 1.7 + 1.0)) * SWAY_AMOUNT * scale


# --- 상태 ---

## 스탯으로 ADS 시간·시야각을 정한다 (부품이 바뀔 때마다).
func configure(stats: Dictionary[StringName, float]) -> void:
	ergonomics = stats.get(WeaponStats.ERGONOMICS, ADS_ERGO_REF)
	zoom = stats.get(ZOOM, 0.0)
	ads_time = ads_time_for(ergonomics)


func set_sight_height(sight_y: float) -> void:
	ads_position = Vector3(0.0, -sight_y, ads_position.z)


## 보이는 ADS 비율 0..1.
func ads_amount() -> float:
	return ease_ads(_ads)


func fov() -> float:
	return lerpf(FOV_NORMAL, ads_fov_for(zoom), ads_amount())


func sprint_amount() -> float:
	return _sprint


func swap_amount() -> float:
	return _swap


## 무기를 새로 들었을 때: 아래에서 올라오는 동작을 시작한다.
func start_swap() -> void:
	_swap = 1.0


## 한 발 쏠 때. effective는 effective_recoil() 결과, yaw_random은 -1..1.
func kick(effective: float, yaw_random: float) -> void:
	var mag: Vector2 = kick_magnitude(effective)
	var scale: float = 1.0 - ADS_KICK_REDUCTION * ads_amount()
	_kick_z.x = minf(_kick_z.x + mag.x * scale, KICK_BACK_MAX)
	_kick_pitch.x = minf(_kick_pitch.x + mag.y * scale, KICK_PITCH_MAX)
	_kick_yaw.x += mag.y * KICK_YAW_RATIO * yaw_random * scale


## 프레임마다. speed_ratio = 수평 속력 / 걷기 속력(지상일 때만, 공중이면 0). look = 이번 프레임 시점 회전(라디안, x 오른쪽 +, y 아래 +).
func update(delta: float, want_ads: bool, want_sprint: bool, want_reload: bool, speed_ratio: float,
		look: Vector2) -> void:
	_time += delta
	_ads = move_toward(_ads, 1.0 if want_ads else 0.0, delta / maxf(ads_time, 0.01))
	var e: float = ads_amount()
	_sprint = move_toward(_sprint, 1.0 if (want_sprint and not want_ads) else 0.0, SPRINT_RATE * delta)
	_reload = move_toward(_reload, 1.0 if want_reload else 0.0, RELOAD_RATE * delta)
	_swap = move_toward(_swap, 0.0, delta / SWAP_TIME)
	_kick_z = spring_step(_kick_z, SPRING_OMEGA, delta)
	_kick_pitch = spring_step(_kick_pitch, SPRING_OMEGA, delta)
	_kick_yaw = spring_step(_kick_yaw, SPRING_OMEGA, delta)
	_look_lag = (_look_lag + look * LOOK_LAG_GAIN).limit_length(LOOK_LAG_MAX)
	_look_lag *= exp(-LOOK_LAG_RECOVER * delta)
	_bob_amount = move_toward(_bob_amount, speed_ratio, 6.0 * delta)
	_bob_phase = fposmod(_bob_phase + _bob_amount * BOB_FREQ * TAU * delta, TAU * 1000.0)

	var sway_scale: float = 1.0 - e * (1.0 - ADS_SWAY_SCALE)
	var bob_scale: float = _bob_amount * (1.0 - e * (1.0 - ADS_BOB_SCALE))
	var sway: Vector2 = sway_offset(_time, sway_scale)
	var bob: Vector2 = bob_offset(_bob_phase, bob_scale)
	var pose: float = 1.0 - e

	var pos: Vector3 = hip_position.lerp(ads_position, e)
	pos += Vector3(sway.x + bob.x, sway.y + bob.y, 0.0)
	pos += SPRINT_POS * (_sprint * pose) + RELOAD_POS * (_reload * pose) + SWAP_DROP * _swap
	pos.z += _kick_z.x
	position = pos

	var rot := Vector3(_kick_pitch.x + _look_lag.y, _kick_yaw.x + _look_lag.x, sway.x * 4.0)
	rot += SPRINT_EULER * (_sprint * pose) + RELOAD_EULER * (_reload * pose)
	rot.x -= _swap * 0.5
	euler = rot
