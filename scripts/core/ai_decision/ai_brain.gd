class_name AiBrain
extends RefCounted
## 적 AI 상태 결정: 순찰 → 의심 → 교전 → 엄폐 → 수색 → 복귀. 이동·사격 같은 실행은 게임 계층 몫.

enum State { PATROL, SUSPICIOUS, COMBAT, TAKE_COVER, SEARCH, RETURN }

var profile: AiProfile
var state: State = State.PATROL
## 현재 상태에 머문 시간. 전이할 때마다 0으로 돌아간다.
var time_in_state: float = 0.0
## 목표를 연속으로 본 시간 (시야를 놓치면 0).
var _seen_time: float = 0.0
## 교전 중 목표를 연속으로 못 본 시간.
var _lost_time: float = 0.0


func _init(p_profile: AiProfile) -> void:
	profile = p_profile


func update(bb: AiBlackboard, delta: float) -> State:
	var noise: bool = bb.heard_noise
	bb.heard_noise = false
	time_in_state += delta
	if bb.can_see_target:
		_seen_time += delta
	else:
		_seen_time = 0.0
	var noticed: bool = _seen_time >= profile.reaction_time

	match state:
		State.PATROL:
			if noticed:
				_enter(State.COMBAT)
			elif noise:
				_enter(State.SUSPICIOUS)
		State.SUSPICIOUS:
			if noticed:
				_enter(State.COMBAT)
			elif noise:
				time_in_state = 0.0
			elif time_in_state >= profile.suspicion_time:
				_enter(State.RETURN)
		State.COMBAT:
			if bb.health_ratio < profile.cover_health_ratio or bb.ammo_in_mag == 0:
				_enter(State.TAKE_COVER)
			else:
				if bb.can_see_target:
					_lost_time = 0.0
				else:
					_lost_time += delta
				if _lost_time >= profile.lose_target_time:
					_enter(State.SEARCH)
		State.TAKE_COVER:
			var recovered: bool = bb.ammo_in_mag > 0 and bb.health_ratio >= profile.cover_health_ratio
			if bb.in_cover and (time_in_state >= profile.cover_time or recovered):
				_enter(State.COMBAT if bb.can_see_target else State.SEARCH)
		State.SEARCH:
			if noticed:
				_enter(State.COMBAT)
			elif noise:
				time_in_state = 0.0
			elif time_in_state >= profile.search_duration:
				_enter(State.RETURN)
		State.RETURN:
			if noticed:
				_enter(State.COMBAT)
			elif noise:
				_enter(State.SUSPICIOUS)
			elif bb.at_patrol_route:
				_enter(State.PATROL)
	return state


func _enter(next: State) -> void:
	state = next
	time_in_state = 0.0
	_lost_time = 0.0
	if next == State.COMBAT:
		_seen_time = 0.0
