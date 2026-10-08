extends GutTest
## AiBrain 상태 전이 테스트 (M3). 델타는 2진수로 정확히 표현되는 값(0.25 등)만 쓴다.

const S := AiBrain.State

var _profile: AiProfile
var _brain: AiBrain
var _bb: AiBlackboard


func before_each() -> void:
	_profile = AiProfile.new()
	_profile.reaction_time = 0.5
	_profile.suspicion_time = 4.0
	_profile.lose_target_time = 2.0
	_profile.search_duration = 8.0
	_profile.cover_health_ratio = 0.5
	_profile.cover_time = 3.0
	_brain = AiBrain.new(_profile)
	_bb = AiBlackboard.new()


## 같은 입력으로 total초 동안 0.25초씩 갱신한다.
func _run(total: float) -> void:
	var steps: int = roundi(total / 0.25)
	for _i: int in range(steps):
		_brain.update(_bb, 0.25)


func _to_combat() -> void:
	_bb.can_see_target = true
	_run(0.5)
	assert_eq(_brain.state, S.COMBAT)


func _to_search() -> void:
	_to_combat()
	_bb.can_see_target = false
	_run(2.0)
	assert_eq(_brain.state, S.SEARCH)


func test_defaults() -> void:
	var profile := AiProfile.new()
	assert_eq(profile.reaction_time, 0.6)
	assert_eq(profile.suspicion_time, 6.0)
	assert_eq(profile.lose_target_time, 4.0)
	assert_eq(profile.search_duration, 15.0)
	assert_eq(profile.cover_health_ratio, 0.35)
	assert_eq(profile.cover_time, 5.0)
	assert_eq(_brain.state, S.PATROL)
	assert_eq(_brain.time_in_state, 0.0)


func test_patrol_stays_without_stimuli() -> void:
	_run(10.0)
	assert_eq(_brain.state, S.PATROL)


func test_patrol_sees_target_after_reaction_time() -> void:
	_bb.can_see_target = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.PATROL)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.COMBAT)


func test_brief_glimpse_does_nothing() -> void:
	_bb.can_see_target = true
	_brain.update(_bb, 0.25)
	_bb.can_see_target = false
	_brain.update(_bb, 0.25)
	_bb.can_see_target = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.PATROL)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.COMBAT)


func test_patrol_noise_to_suspicious_and_consumed() -> void:
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.SUSPICIOUS)
	assert_false(_bb.heard_noise)
	assert_eq(_brain.time_in_state, 0.0)


func test_noise_consumed_even_when_ignored() -> void:
	_to_combat()
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	assert_false(_bb.heard_noise)
	assert_eq(_brain.state, S.COMBAT)


func test_suspicious_to_combat_on_sight() -> void:
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	_bb.can_see_target = true
	_run(0.5)
	assert_eq(_brain.state, S.COMBAT)


func test_suspicious_times_out_to_return() -> void:
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	_run(3.75)
	assert_eq(_brain.state, S.SUSPICIOUS)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.RETURN)
	assert_eq(_brain.time_in_state, 0.0)


func test_suspicious_new_noise_restarts_timer() -> void:
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	_run(3.0)
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.time_in_state, 0.0)
	_run(3.5)
	assert_eq(_brain.state, S.SUSPICIOUS)
	_run(0.5)
	assert_eq(_brain.state, S.RETURN)


func test_combat_to_cover_on_low_health() -> void:
	_to_combat()
	_bb.health_ratio = 0.25
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.TAKE_COVER)


func test_combat_to_cover_on_empty_mag() -> void:
	_to_combat()
	_bb.ammo_in_mag = 0
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.TAKE_COVER)


func test_combat_loses_target_to_search() -> void:
	_to_combat()
	_bb.can_see_target = false
	_run(1.75)
	assert_eq(_brain.state, S.COMBAT)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.SEARCH)
	assert_eq(_brain.time_in_state, 0.0)


func test_combat_lose_timer_resets_when_seen_again() -> void:
	_to_combat()
	_bb.can_see_target = false
	_run(1.5)
	_bb.can_see_target = true
	_brain.update(_bb, 0.25)
	_bb.can_see_target = false
	_run(1.75)
	assert_eq(_brain.state, S.COMBAT)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.SEARCH)


func test_cover_requires_being_in_cover() -> void:
	_to_combat()
	_bb.health_ratio = 0.1
	_brain.update(_bb, 0.25)
	_bb.health_ratio = 1.0
	_bb.in_cover = false
	_run(5.0)
	assert_eq(_brain.state, S.TAKE_COVER)


func test_cover_exits_when_recovered_back_to_combat() -> void:
	_to_combat()
	_bb.ammo_in_mag = 0
	_brain.update(_bb, 0.25)
	_bb.in_cover = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.TAKE_COVER)
	_bb.ammo_in_mag = 30
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.COMBAT)


func test_cover_timeout_without_sight_goes_to_search() -> void:
	_to_combat()
	_bb.health_ratio = 0.1
	_brain.update(_bb, 0.25)
	_bb.in_cover = true
	_bb.can_see_target = false
	_run(2.75)
	assert_eq(_brain.state, S.TAKE_COVER)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.SEARCH)


func test_cover_timeout_with_sight_goes_to_combat_even_if_hurt() -> void:
	_to_combat()
	_bb.health_ratio = 0.1
	_brain.update(_bb, 0.25)
	_bb.in_cover = true
	_run(3.0)
	assert_eq(_brain.state, S.COMBAT)


func test_search_to_combat_on_sight() -> void:
	_to_search()
	_bb.can_see_target = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.SEARCH)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.COMBAT)


func test_search_times_out_to_return() -> void:
	_to_search()
	_run(7.75)
	assert_eq(_brain.state, S.SEARCH)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.RETURN)


func test_search_noise_restarts_timer() -> void:
	_to_search()
	_run(7.0)
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.time_in_state, 0.0)
	_run(7.75)
	assert_eq(_brain.state, S.SEARCH)
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.RETURN)


func _to_return() -> void:
	_to_search()
	_run(8.0)
	assert_eq(_brain.state, S.RETURN)


func test_return_to_patrol_at_route() -> void:
	_to_return()
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.RETURN)
	_bb.at_patrol_route = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.PATROL)
	assert_eq(_brain.time_in_state, 0.0)


func test_return_noise_to_suspicious() -> void:
	_to_return()
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.SUSPICIOUS)


func test_return_to_combat_on_sight() -> void:
	_to_return()
	_bb.can_see_target = true
	_run(0.5)
	assert_eq(_brain.state, S.COMBAT)


func test_time_in_state_accumulates_and_resets() -> void:
	_run(1.0)
	assert_eq(_brain.time_in_state, 1.0)
	_bb.heard_noise = true
	_brain.update(_bb, 0.25)
	assert_eq(_brain.state, S.SUSPICIOUS)
	assert_eq(_brain.time_in_state, 0.0)
	_run(1.0)
	assert_eq(_brain.time_in_state, 1.0)
