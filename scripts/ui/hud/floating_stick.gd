class_name FloatingStick
extends RefCounted
## 떠 있는 가상 조이스틱의 벡터 계산 (화면 좌표 → -1..1 이동 벡터). 그리기·터치 처리는 TouchControls.
## begin()으로 손가락이 닿은 곳이 기준점이 되고, follow가 켜져 있으면 손가락이 반지름을 넘을 때 기준점이 따라온다.

var radius: float = 90.0
var deadzone: float = 0.12
## 이 크기 이상 밀면 달리기.
var sprint_threshold: float = 0.92
var follow: bool = true

var origin: Vector2 = Vector2.ZERO
var active: bool = false
## 데드존을 반영한 이동 벡터 (y가 음수 = 앞).
var vector: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func begin(pos: Vector2) -> void:
	origin = pos
	_knob = pos
	active = true
	vector = Vector2.ZERO


func update(pos: Vector2) -> Vector2:
	if not active:
		return Vector2.ZERO
	var offset: Vector2 = pos - origin
	var dist: float = offset.length()
	if follow and dist > radius:
		origin += offset / dist * (dist - radius)
		offset = pos - origin
		dist = offset.length()
	var raw: Vector2 = offset / radius
	if raw.length() > 1.0:
		raw = raw.normalized()
	_knob = origin + raw * radius
	var magnitude: float = raw.length()
	if magnitude < deadzone:
		vector = Vector2.ZERO
	else:
		vector = raw.normalized() * ((magnitude - deadzone) / (1.0 - deadzone))
	return vector


func end() -> void:
	active = false
	vector = Vector2.ZERO


## 손잡이(원) 그리기 위치.
func knob_position() -> Vector2:
	return _knob


func is_sprint() -> bool:
	return active and vector.length() >= sprint_threshold
