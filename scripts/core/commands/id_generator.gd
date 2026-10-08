class_name IdGenerator
extends RefCounted
## 아이템 인스턴스 id 발급. 권한자만 소유한다 (클라이언트 생성 금지 → 복제 방지의 기반).

var _next: int = 1


func next_id() -> int:
	var id: int = _next
	_next += 1
	return id


## 저장 데이터 로드 후 기존 id와 겹치지 않도록 다음 값을 올린다.
func ensure_above(used_id: int) -> void:
	_next = maxi(_next, used_id + 1)


## 다음에 발급될 id (소비하지 않음).
func peek() -> int:
	return _next
