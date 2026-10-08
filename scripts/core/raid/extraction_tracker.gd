class_name ExtractionTracker
extends RefCounted
## 플레이어가 탈출 지점 안에서 버틴 시간을 추적한다.

var _point: ExtractionPoint
var _elapsed: float = 0.0
var _fired: bool = false


func enter(point: ExtractionPoint) -> void:
	_point = point
	_elapsed = 0.0
	_fired = false


func leave() -> void:
	_point = null
	_elapsed = 0.0
	_fired = false


func is_inside() -> bool:
	return _point != null


## 열린 지점 안에서 wait_time을 채운 순간 단 한 번 true. 닫혀 있으면 진행도가 초기화된다.
func tick(delta: float, flags: Dictionary) -> bool:
	if _point == null:
		return false
	if _point.required_flag != &"" and not bool(flags.get(_point.required_flag, false)):
		_elapsed = 0.0
		_fired = false
		return false
	if _fired:
		return false
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= _point.wait_time:
		_fired = true
		return true
	return false


## 0~1 진행도.
func progress() -> float:
	if _point == null:
		return 0.0
	if _point.wait_time <= 0.0:
		return 1.0 if _fired else 0.0
	return clampf(_elapsed / _point.wait_time, 0.0, 1.0)
