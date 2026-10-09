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


# --- 지속 상태 (소스별) ---

func set_move(source: Source, value: Vector2) -> void:
	_move[source] = value.limit_length(1.0)


func set_sprint(source: Source, on: bool) -> void:
	_sprint[source] = on


func set_crouch_held(source: Source, on: bool) -> void:
	_crouch_held[source] = on


func set_fire_held(source: Source, on: bool) -> void:
	_fire_held[source] = on


func set_ads_held(source: Source, on: bool) -> void:
	_ads_held[source] = on


## 이동 벡터: x = 오른쪽, y = 앞쪽이 음수 (Input.get_vector와 같은 방향). 더 큰 쪽 소스를 쓴다.
func move() -> Vector2:
	var a: Vector2 = _move[0]
	var b: Vector2 = _move[1]
	return a if a.length_squared() >= b.length_squared() else b


func is_sprint() -> bool:
	return _sprint[0] or _sprint[1]


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
	_fire_pressed = true


func press_jump() -> void:
	_jump_pressed = true


func press_reload() -> void:
	_reload_pressed = true


func press_switch() -> void:
	_switch_pressed = true


func press_crouch_toggle() -> void:
	_crouch_toggle = true


func press_ads_toggle() -> void:
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
