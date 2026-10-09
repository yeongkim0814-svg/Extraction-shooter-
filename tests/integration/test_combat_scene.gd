extends GutTest
## 전투 테스트 씬을 실제로 띄워 입력 → 사격 → 명중 → 재장전을 확인한다 (헤드리스).

var _scene: Node3D
var _player: PlayerController
var _dummy10: TargetDummy


func before_each() -> void:
	_scene = (load("res://scenes/dev/combat_test.tscn") as PackedScene).instantiate() as Node3D
	add_child(_scene)
	await wait_physics_frames(3)
	_player = _scene.get_node("Player") as PlayerController
	_dummy10 = _scene.get_node("Targets/Dummy10m") as TargetDummy


func after_each() -> void:
	_scene.queue_free()
	await wait_physics_frames(1)


func test_scene_builds_player_hud_and_loadout() -> void:
	assert_not_null(_player)
	assert_not_null(_player.weapons.current_runtime())
	assert_eq(_player.weapons.current_index(), 0)
	assert_eq(_player.weapons.current_runtime().rounds(), 30)
	assert_true(_scene.get_node("UI/Hud") is Hud)


func test_holding_fire_hits_the_ten_meter_dummy() -> void:
	var start_hp: float = _dummy10.hit_target.health.hp
	_player.input.set_fire_held(InputState.Source.KEYBOARD, true)
	_player.input.press_fire()
	await wait_physics_frames(30)
	_player.input.set_fire_held(InputState.Source.KEYBOARD, false)
	assert_lt(_player.weapons.current_runtime().rounds(), 30, "탄이 소비됨")
	assert_lt(_dummy10.hit_target.health.hp, start_hp, "10m 더미가 맞음")


func test_semi_auto_pistol_fires_once_per_press() -> void:
	_player.input.select_slot(2)
	await wait_physics_frames(40)   # 교체 시간 대기
	var pistol: WeaponRuntime = _player.weapons.current_runtime()
	assert_eq(_player.weapons.current_index(), 2)
	_player.input.set_fire_held(InputState.Source.KEYBOARD, true)
	_player.input.press_fire()
	await wait_physics_frames(30)
	_player.input.set_fire_held(InputState.Source.KEYBOARD, false)
	assert_eq(pistol.rounds(), 14, "누르고 있어도 단발은 한 발")


func test_reload_takes_time_then_refills() -> void:
	var rifle: WeaponRuntime = _player.weapons.current_runtime()
	rifle.item.magazine.pop_round()
	rifle.item.magazine.pop_round()
	_player.input.press_reload()
	await wait_physics_frames(3)
	assert_true(_player.weapons.is_reloading())
	assert_eq(rifle.rounds(), 28, "재장전이 끝나기 전에는 그대로")
	await wait_seconds(WeaponController.RELOAD_TIME + 0.3)
	assert_false(_player.weapons.is_reloading())
	assert_eq(rifle.rounds(), 30)


func test_reload_when_full_shows_korean_toast() -> void:
	var messages: Array[String] = []
	_player.weapons.toast.connect(func(text: String) -> void: messages.append(text))
	_player.input.press_reload()
	await wait_physics_frames(3)
	assert_eq(messages, ["탄창 가득 참"] as Array[String])


func test_crouch_jump_and_pitch_clamp() -> void:
	_player.input.add_look(Vector2(0.0, -100.0))   # 계속 위로
	await wait_process_frames(2)
	assert_almost_eq(_player.look_pitch(), PlayerController.PITCH_LIMIT, 0.0001)
	_player.input.press_crouch_toggle()
	await wait_physics_frames(3)
	assert_true(_player.is_crouching())
	_player.input.press_crouch_toggle()
	await wait_physics_frames(3)
	assert_false(_player.is_crouching())
	await wait_physics_frames(20)
	_player.input.press_jump()
	await wait_physics_frames(5)
	assert_gt(_player.velocity.y + (_player.global_position.y - 0.1), 0.2, "점프로 떠오름")


func test_sprint_lock_runs_forward_then_fire_cancels() -> void:
	var lock: SprintLock = _player.input.sprint_lock
	var logs: Array[String] = []
	lock.cancelled.connect(func(r: StringName) -> void: logs.append(String(r)))
	await wait_physics_frames(20)
	var start: Vector3 = _player.global_position
	lock.engage()   # 스틱에 손가락이 없는 상태
	assert_eq(_player.input.move(), Vector2.ZERO)
	await wait_seconds(1.0)
	var run: float = start.distance_to(_player.global_position)
	assert_gt(run, 2.0, "잠금 중 1초 동안 앞으로 이동 (%.2f m)" % run)
	assert_true(lock.is_locked())
	# 시점을 돌려도 계속 달린다 (방향은 yaw를 따름)
	var forward_before: Vector3 = -_player.global_basis.z
	_player.input.add_look(Vector2(0.4, 0.0))
	await wait_physics_frames(3)
	assert_true(lock.is_locked())
	assert_lt(forward_before.dot(-_player.global_basis.z), 0.99, "yaw가 돌아감")
	# 점프는 잠금을 유지
	_player.input.press_jump()
	await wait_physics_frames(3)
	assert_true(lock.is_locked())
	# 사격으로 취소
	var rifle: WeaponRuntime = _player.weapons.current_runtime()
	var rounds: int = rifle.rounds()
	_player.input.set_fire_held(InputState.Source.KEYBOARD, true)
	_player.input.press_fire()
	await wait_physics_frames(3)
	assert_false(lock.is_locked())
	assert_eq(logs, ["fire"] as Array[String])
	assert_eq(rifle.rounds(), rounds, "0.2초 지연 동안 사격 불가")
	await wait_seconds(0.5)
	assert_lt(rifle.rounds(), rounds, "지연 뒤 누르고 있으면 사격")
	_player.input.set_fire_held(InputState.Source.KEYBOARD, false)
	await wait_seconds(0.3)
	var horizontal := Vector2(_player.velocity.x, _player.velocity.z)
	assert_lt(horizontal.length(), 0.5, "달리기 멈춤")


func test_sprint_lock_cancelled_by_ads_press_which_then_engages() -> void:
	var lock: SprintLock = _player.input.sprint_lock
	lock.engage()
	await wait_physics_frames(5)
	_player.input.press_ads_toggle()
	await wait_physics_frames(3)
	assert_false(lock.is_locked())
	assert_true(_player.is_ads())
	assert_true(lock.can_fire(), "조준 취소는 사격 지연 없음")


func test_sprint_lock_wall_stop_cancels() -> void:
	var lock: SprintLock = _player.input.sprint_lock
	_player.global_position = Vector3(0.0, 0.1, -19.0)   # 북쪽 벽 앞, 정면(-z)이 벽
	_player.rotation.y = 0.0
	await wait_physics_frames(3)
	lock.engage()
	await wait_seconds(1.5)
	assert_false(lock.is_locked(), "벽에 막혀 0.5초 이상 멈추면 해제")
