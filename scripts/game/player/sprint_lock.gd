class_name SprintLock
extends RefCounted
## 달리기 잠금(자동 달리기) 판단 로직. 엔진 시간·노드에 의존하지 않는다 (시간은 advance(delta)로만 흐른다).
##  - 존 기하: 조이스틱 손잡이를 링 위쪽(거리 > 1.35 × 반지름, 정면 위 ±35°)까지 끌어올린 채 떼면 잠금 ON
##  - 잠금 중에는 앞으로 달리기 속도로 계속 이동 (방향은 시점 yaw를 따름 = PlayerController가 처리)
##  - 취소 사유: 조이스틱 재터치, 스틱 아래로 당김, 조준, 사격, 앉기, 벽에 막혀 0.5초 정지, 키보드 S/토글/포커스 아웃
##  - 사격 때문에 달리기(누름·잠금)가 끝나면 FIRE_DELAY 동안 사격 불가 (총을 들어 올리는 시간)
## 점프·재장전·무기 교체는 잠금을 유지한다 (호출하지 않으면 그대로).

enum Reason { NONE, TOUCH, PULL_DOWN, ADS, FIRE, CROUCH, WALL, KEY_BACK, TOGGLE, FOCUS }
## 존 상태: 없음 / 힌트(위쪽으로 끌어올리는 중) / 안쪽(떼면 잠금)
enum Zone { NONE, NEAR, INSIDE }

## 존 안쪽 최소 거리 (반지름 배수)와 정면 위 기준 허용 각도.
const ZONE_MIN_RATIO: float = 1.35
const ZONE_HALF_ANGLE_DEG: float = 35.0
## 힌트 표시 조건: 링 가장자리 근처(0.9R 이상)에서 정면 위 ±HINT_HALF_ANGLE_DEG.
const HINT_MIN_RATIO: float = 0.9
const HINT_HALF_ANGLE_DEG: float = 50.0
const FIRE_DELAY: float = 0.2
const WALL_STOP_TIME: float = 0.5
## 이 속도(m/s) 미만이면 "멈췄다"
const WALL_STOP_SPEED: float = 1.0
## 잠금 중 스틱을 이 값 이상 아래로 당기면 취소 (stick.vector.y 양수 = 아래)
const PULL_DOWN_THRESHOLD: float = 0.3

signal engaged
signal cancelled(reason: StringName)

var _locked: bool = false
var _time: float = 0.0
var _fire_block_until: float = -INF
var _held_suppressed: bool = false
var _stuck_time: float = 0.0
var _caps_down: bool = false


# --- 존 기하 (정적) ---

## 정면 위(화면 -y)와의 각도 0..180 (도).
static func angle_from_up_deg(offset: Vector2) -> float:
	if offset.is_zero_approx():
		return 180.0
	return rad_to_deg(absf(Vector2.UP.angle_to(offset)))


## offset = 손가락 - 스틱 중심 (화면 좌표).
static func zone_of(offset: Vector2, radius: float) -> Zone:
	var dist: float = offset.length()
	var angle: float = angle_from_up_deg(offset)
	if dist > radius * ZONE_MIN_RATIO and angle <= ZONE_HALF_ANGLE_DEG:
		return Zone.INSIDE
	if dist >= radius * HINT_MIN_RATIO and angle <= HINT_HALF_ANGLE_DEG:
		return Zone.NEAR
	return Zone.NONE


static func in_zone(offset: Vector2, radius: float) -> bool:
	return zone_of(offset, radius) == Zone.INSIDE


static func reason_name(reason: Reason) -> StringName:
	match reason:
		Reason.TOUCH:
			return &"touch"
		Reason.PULL_DOWN:
			return &"pull_down"
		Reason.ADS:
			return &"ads"
		Reason.FIRE:
			return &"fire"
		Reason.CROUCH:
			return &"crouch"
		Reason.WALL:
			return &"wall"
		Reason.KEY_BACK:
			return &"key_back"
		Reason.TOGGLE:
			return &"toggle"
		Reason.FOCUS:
			return &"focus"
		_:
			return &"none"


# --- 상태 ---

func is_locked() -> bool:
	return _locked


## 시간 진행. held = 현재 눌러서 달리는 중(스틱 가장자리 / Shift)인지. 눌림이 풀리면 억제도 풀린다.
func advance(delta: float, held: bool) -> void:
	_time += delta
	if not held:
		_held_suppressed = false


## 조이스틱을 놓았을 때: 존 안쪽이었다면 잠금 ON. 잠금이 켜졌는지 반환.
func release_stick(offset: Vector2, radius: float) -> bool:
	if _locked or not in_zone(offset, radius):
		return false
	engage()
	return true


func engage() -> void:
	if _locked:
		return
	_locked = true
	_stuck_time = 0.0
	_held_suppressed = false
	engaged.emit()


## 키보드 토글 (CapsLock): 켜져 있으면 끄고, 꺼져 있으면 켠다.
func toggle() -> void:
	if _locked:
		cancel(Reason.TOGGLE, false)
	else:
		engage()


## CapsLock 키 이벤트 → 토글. Windows는 누를 때마다 down+up, macOS는 켤 때 down만/끌 때 up만 오므로
## "down 없이 온 up"도 한 번의 누름으로 센다.
func key_toggle_event(pressed: bool) -> void:
	if pressed:
		_caps_down = true
		toggle()
	elif _caps_down:
		_caps_down = false
	else:
		toggle()


## 잠금 취소. held = 취소 시점에 누른 달리기(스틱 가장자리/Shift)가 켜져 있었는지.
## 누른 달리기가 있었다면 그것도 다시 떼었다 누를 때까지 억제한다.
## 잠금/달리기가 사격 때문에 끝났다면 FIRE_DELAY 동안 사격 불가.
## 잠금이 켜져 있었으면 true.
func cancel(reason: Reason, held: bool) -> bool:
	var was_locked: bool = _locked
	if reason == Reason.FIRE and (was_locked or held):
		_fire_block_until = _time + FIRE_DELAY
	if held and reason != Reason.TOUCH:
		_held_suppressed = true
	if was_locked:
		_locked = false
		_stuck_time = 0.0
		cancelled.emit(reason_name(reason))
	return was_locked


## 스틱이 새로 눌려 있는 동안의 이동 벡터를 알려 준다. 아래로 당기면 취소.
func update_stick(vector: Vector2) -> void:
	if _locked and vector.y > PULL_DOWN_THRESHOLD:
		cancel(Reason.PULL_DOWN, false)


## 잠금 중 매 물리 틱: 수평 속력이 WALL_STOP_TIME 이상 멈춰 있으면 취소.
func update_motion(horizontal_speed: float, delta: float) -> void:
	if not _locked:
		return
	if horizontal_speed < WALL_STOP_SPEED:
		_stuck_time += delta
		if _stuck_time > WALL_STOP_TIME:
			cancel(Reason.WALL, false)
	else:
		_stuck_time = 0.0


# --- 질의 ---

## 실제로 달리는가: 잠금이거나, 누른 달리기가 억제되지 않았을 때.
func sprinting(held: bool) -> bool:
	return _locked or (held and not _held_suppressed)


func can_fire() -> bool:
	return _time >= _fire_block_until


## 사격 가능까지 남은 시간 (0이면 즉시).
func fire_block_remaining() -> float:
	return maxf(_fire_block_until - _time, 0.0)
