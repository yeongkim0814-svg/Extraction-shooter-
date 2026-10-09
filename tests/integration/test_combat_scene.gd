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
