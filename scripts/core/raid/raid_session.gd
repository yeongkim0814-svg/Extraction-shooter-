class_name RaidSession
extends RefCounted
## 레이드 한 판의 상태 머신: 은신처 → 로드아웃 → 레이드 → 탈출/사망 → 결과 → 은신처.
## 잘못된 전이는 false를 돌려주고 아무것도 바꾸지 않는다.

enum State { HIDEOUT, LOADOUT, IN_RAID, EXTRACTED, DEAD, RESULTS }
enum Outcome { NONE, EXTRACTED, KILLED, TIMED_OUT }

var inventory: Inventory
var state: State = State.HIDEOUT
var outcome: Outcome = Outcome.NONE
## 레이드 경과 시간 (초).
var elapsed: float = 0.0
var time_limit: float = 0.0
## 사망으로 잃은 아이템 id (중첩 포함).
var lost_item_ids: Array[int] = []


func _init(p_inventory: Inventory) -> void:
	inventory = p_inventory


func start_loadout() -> bool:
	if state != State.HIDEOUT:
		return false
	state = State.LOADOUT
	return true


## time_limit_sec는 0보다 커야 한다. 시작하면 스태시가 잠긴다.
func start_raid(time_limit_sec: float) -> bool:
	if state != State.LOADOUT or time_limit_sec <= 0.0:
		return false
	state = State.IN_RAID
	outcome = Outcome.NONE
	elapsed = 0.0
	time_limit = time_limit_sec
	lost_item_ids = []
	inventory.stash_locked = true
	return true


## 레이드 중일 때만 시간이 흐르고 true. 제한 시간에 닿으면 TIMED_OUT 사망.
func tick(delta: float) -> bool:
	if state != State.IN_RAID or delta < 0.0:
		return false
	elapsed += delta
	if elapsed >= time_limit:
		elapsed = time_limit
		_kill(Outcome.TIMED_OUT)
	return true


func extract() -> bool:
	if state != State.IN_RAID:
		return false
	state = State.EXTRACTED
	outcome = Outcome.EXTRACTED
	return true


func die() -> bool:
	if state != State.IN_RAID:
		return false
	_kill(Outcome.KILLED)
	return true


func show_results() -> bool:
	if state != State.EXTRACTED and state != State.DEAD:
		return false
	state = State.RESULTS
	return true


func return_to_hideout() -> bool:
	if state != State.RESULTS:
		return false
	state = State.HIDEOUT
	inventory.stash_locked = false
	return true


func _kill(p_outcome: Outcome) -> void:
	state = State.DEAD
	outcome = p_outcome
	lost_item_ids = DeathResolver.resolve(inventory)
