class_name TriggerLogic
extends RefCounted
## 방아쇠 판정: 단발은 누를 때마다 한 발, 연사는 누르고 있는 동안.
## 눌렀다 뗀 사이에 프레임이 끼어도 놓치지 않도록 눌림을 짧게 버퍼링한다 (발사 간격에 막힌 단발도 잠깐 기다려 줌).

const BUFFER_TIME: float = 0.15

var _held: bool = false
var _buffer_until: float = -INF


func press(now: float) -> void:
	_buffer_until = now + BUFFER_TIME


func set_held(held: bool) -> void:
	_held = held


## 이번에 쏘려는 의도가 있는가. 실제로 쏘면 consume()을 불러 버퍼를 비운다.
func wants_fire(automatic: bool, now: float) -> bool:
	if now <= _buffer_until:
		return true
	return automatic and _held


func consume() -> void:
	_buffer_until = -INF


func clear() -> void:
	_buffer_until = -INF
