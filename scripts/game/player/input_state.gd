class_name InputState
extends RefCounted
## 플레이어 입력 추상화. 터치 컨트롤과 키보드/마우스가 각자 자기 소스(Source)로 값을 채우고,
## 컨트롤러는 합쳐진 값만 읽는다. 한 번만 처리할 이벤트(점프·재장전 …)는 래치해 두었다가 consume_*로 꺼낸다.

enum Source { KEYBOARD, TOUCH }

## 시점 감도 (라디안/픽셀). 터치 값은 논리 해상도(1280×720 기준) 픽셀.
const MOUSE_LOOK_SENS: float = 0.0022
const TOUCH_LOOK_SENS: float = 0.0035
## ADS 중에는 시점 이동량을 줄인다.
const ADS_LOOK_SCALE: float = 0.55

var _move: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _sprint: Array[bool] = [false, false]
var _crouch_held: Array[bool] = [false, false]
var _fire_held: Array[bool] = [false, false]
var _ads_held: Array[bool] = [false, false]
var _look: Vector2 = Vector2.ZERO
var _fire_pressed: bool = false
var _jump_pressed: bool = false
var _reload_pressed: bool = false
var _switch_pressed: bool = false
var _crouch_toggle: bool = false
var _ads_toggle: bool = false
var _slot_select: int = -1

## 달리기 잠금(자동 달리기) 상태·판단. 사격·조준·앉기 입력은 아래 press_*/set_*에서 잠금을 취소한다.
var sprint_lock := SprintLock.new()


# --- 지속 상태 (소스별) ---

func set_move(source: Source, value: Vector2) -> void:
	_move[source] = value.limit_length(1.0)


func set_sprint(source: Source, on: bool) -> void:
	_sprint[source] = on


func set_crouch_held(source: Source, on: bool) -> void:
	if on and not is_crouch_held():
		sprint_lock.cancel(SprintLock.Reason.CROUCH, is_sprint())
	_crouch_held[source] = on


func set_fire_held(source: Source, on: bool) -> void:
	_fire_held[source] = on


func set_ads_held(source: Source, on: bool) -> void:
	if on and not is_ads_held():
		sprint_lock.cancel(SprintLock.Reason.ADS, is_sprint())
	_ads_held[source] = on


## 이동 벡터: x = 오른쪽, y = 앞쪽이 음수 (Input.get_vector와 같은 방향). 더 큰 쪽 소스를 쓴다.
func move() -> Vector2:
	var a: Vector2 = _move[0]
	var b: Vector2 = _move[1]
	return a if a.length_squared() >= b.length_squared() else b


## 눌러서 하는 달리기 (스틱 가장자리 / Shift). 잠금은 포함하지 않는다.
func is_sprint() -> bool:
	return _sprint[0] or _sprint[1]


## 실제 달리기 여부: 잠금이거나, 눌린 달리기가 사격·조준 등으로 억제되지 않았을 때.
func sprint_active() -> bool:
	return sprint_lock.sprinting(is_sprint())


## 이동 벡터 + 달리기 잠금 반영: 잠금 중이면 항상 앞(-y)으로 (좌우 입력은 유지). 방향은 몸의 yaw가 정한다.
func effective_move() -> Vector2:
	var m: Vector2 = move()
	if sprint_lock.is_locked():
		return Vector2(m.x, -1.0).limit_length(1.0)
	return m


## 물리 틱마다 한 번 (시간 진행, 눌린 달리기 억제 해제 판단).
func tick(delta: float) -> void:
	sprint_lock.advance(delta, is_sprint())


func is_crouch_held() -> bool:
	return _crouch_held[0] or _crouch_held[1]


func is_fire_held() -> bool:
	return _fire_held[0] or _fire_held[1]


func is_ads_held() -> bool:
	return _ads_held[0] or _ads_held[1]


## 모든 지속 입력을 해제한다 (창 포커스를 잃었을 때, 터치 컨트롤이 숨겨질 때).
func release_source(source: Source) -> void:
	_move[source] = Vector2.ZERO
	_sprint[source] = false
	_crouch_held[source] = false
	_fire_held[source] = false
	_ads_held[source] = false


# --- 시점 (라디안 누적) ---

## delta.x = 오른쪽으로 돌린 양, delta.y = 아래로 내린 양.
func add_look(delta: Vector2) -> void:
	_look += delta


func consume_look() -> Vector2:
	var value: Vector2 = _look
	_look = Vector2.ZERO
	return value


# --- 한 번만 처리하는 이벤트 ---

func press_fire() -> void:
	sprint_lock.cancel(SprintLock.Reason.FIRE, is_sprint())
	_fire_pressed = true


func press_jump() -> void:
	_jump_pressed = true


func press_reload() -> void:
	_reload_pressed = true


func press_switch() -> void:
	_switch_pressed = true


func press_crouch_toggle() -> void:
	sprint_lock.cancel(SprintLock.Reason.CROUCH, is_sprint())
	_crouch_toggle = true


func press_ads_toggle() -> void:
	sprint_lock.cancel(SprintLock.Reason.ADS, is_sprint())
	_ads_toggle = true


## 0 = 주무기1, 1 = 주무기2, 2 = 보조무기.
func select_slot(index: int) -> void:
	_slot_select = index


func consume_fire_pressed() -> bool:
	var value: bool = _fire_pressed
	_fire_pressed = false
	return value


func consume_jump() -> bool:
	var value: bool = _jump_pressed
	_jump_pressed = false
	return value


func consume_reload() -> bool:
	var value: bool = _reload_pressed
	_reload_pressed = false
	return value


func consume_switch() -> bool:
	var value: bool = _switch_pressed
	_switch_pressed = false
	return value


func consume_crouch_toggle() -> bool:
	var value: bool = _crouch_toggle
	_crouch_toggle = false
	return value


func consume_ads_toggle() -> bool:
	var value: bool = _ads_toggle
	_ads_toggle = false
	return value


## 선택 요청이 없으면 -1.
func consume_slot_select() -> int:
	var value: int = _slot_select
	_slot_select = -1
	return value
