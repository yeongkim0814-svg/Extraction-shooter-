class_name Magazine
extends RefCounted
## 탄창 안의 실제 탄. 탄종이 섞일 수 있어 한 발씩 기록한다 (배열 끝 = 다음에 발사될 탄).

var caliber: StringName
var capacity: int
var _rounds: Array[StringName] = []


func _init(p_caliber: StringName, p_capacity: int) -> void:
	assert(p_capacity > 0, "magazine capacity must be positive")
	caliber = p_caliber
	capacity = p_capacity


func count() -> int:
	return _rounds.size()


func is_empty() -> bool:
	return _rounds.is_empty()


func is_full() -> bool:
	return _rounds.size() >= capacity


## 탄을 최대 amount발 장전하고 실제 장전한 수를 돌려준다. 구경이 다르면 0.
func load_rounds(ammo: AmmoDef, amount: int) -> int:
	if ammo.caliber != caliber or amount <= 0:
		return 0
	var loaded: int = mini(amount, capacity - _rounds.size())
	for i: int in range(loaded):
		_rounds.append(ammo.id)
	return loaded


## 다음 탄을 꺼낸다 (발사). 비었으면 &"".
func pop_round() -> StringName:
	if _rounds.is_empty():
		return &""
	return _rounds.pop_back()


func peek_round() -> StringName:
	if _rounds.is_empty():
		return &""
	return _rounds.back()


## 모든 탄을 빼서 탄종별 수량으로 돌려준다 (인벤토리로 되돌릴 때).
func unload_all() -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	for ammo_id: StringName in _rounds:
		counts[ammo_id] = counts.get(ammo_id, 0) + 1
	_rounds.clear()
	return counts


## 저장용 복사본 (아래부터 위 순서).
func get_rounds() -> Array[StringName]:
	return _rounds.duplicate()
