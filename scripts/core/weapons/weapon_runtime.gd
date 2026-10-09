class_name WeaponRuntime
extends RefCounted
## 손에 든 무기의 사격 상태: 연사 속도 제한, 단발/연사, 탄 소비.
## 시간은 호출자가 넘긴다 (엔진 시계에 의존하지 않아 테스트·서버 재현 가능).
## 멀티 단계에서는 사격도 권한자 명령으로 검증한다 (지금은 로컬).

const DEFAULT_FIRE_RATE := 600.0

var item: ItemInstance
var stats: Dictionary[StringName, float] = {}
var _last_shot_time: float = -INF


func _init(p_item: ItemInstance) -> void:
	item = p_item
	refresh_stats()


## 부품이 바뀌면 다시 호출한다.
func refresh_stats() -> void:
	if item.weapon != null:
		stats = item.weapon.compute_stats()
	else:
		stats.clear()


func fire_rate() -> float:
	return maxf(stats.get(WeaponStats.FIRE_RATE, DEFAULT_FIRE_RATE), 1.0)


func fire_interval() -> float:
	return 60.0 / fire_rate()


func is_automatic() -> bool:
	return stats.get(WeaponStats.AUTO, 0.0) >= 0.5


func rounds() -> int:
	return item.magazine.count() if item.magazine != null else 0


## 발사 가능한 시점이면 탄 하나를 꺼내 탄종 id를 돌려준다. 쏠 수 없으면 &"".
## 단발/연사 판단(방아쇠를 새로 눌렀는지)은 입력 쪽이 is_automatic()으로 한다.
func try_fire(now: float) -> StringName:
	if item.magazine == null or item.magazine.is_empty():
		return &""
	if now - _last_shot_time < fire_interval() - 0.0001:
		return &""
	_last_shot_time = now
	return item.magazine.pop_round()
