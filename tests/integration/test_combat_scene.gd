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


# --- M7: 모딩·절차적 움직임 ---

func _authority() -> LocalAuthority:
	return _scene.get(&"_authority") as LocalAuthority


func _spare_item(part_id: StringName) -> ItemInstance:
	var auth: LocalAuthority = _authority()
	for item: ItemInstance in auth.inventory.get_items():
		if item.def.id == part_id and item.weapon == null and item.container_key != &"":
			return item
	return null


func test_attaching_a_part_refreshes_weapon_stats_and_model() -> void:
	var rifle: WeaponRuntime = _player.weapons.current_runtime()
	var view: WeaponView = _player.weapons.view()
	assert_almost_eq(rifle.stats[WeaponStats.LOUDNESS], 1.0, 0.0001)
	var before: String = view.model_signature()
	var sup: ItemInstance = _spare_item(DemoWeapons.SUPPRESSOR)
	assert_not_null(sup, "로드아웃에 소음기가 들어 있다")
	var result: CommandResult = _authority().execute(
			AttachPartCommand.new(rifle.item.id, [&"barrel"] as Array[StringName], &"muzzle", sup.id))
	assert_true(result.ok, String(result.error))
	assert_almost_eq(rifle.stats[WeaponStats.LOUDNESS], 0.4, 0.0001, "WEAPON_CHANGED로 스탯 갱신")
	assert_ne(view.model_signature(), before, "모델도 다시 조립")
	assert_not_null(view.model_root().find_child("suppressor", true, false))
	var detach: CommandResult = _authority().execute(
			DetachPartCommand.new(rifle.item.id, [&"barrel"] as Array[StringName], &"muzzle"))
	assert_true(detach.ok)
	assert_almost_eq(rifle.stats[WeaponStats.LOUDNESS], 1.0, 0.0001)
	assert_eq(view.model_signature(), before)


func test_scope_lowers_ads_fov_and_slows_ads() -> void:
	var rifle: WeaponRuntime = _player.weapons.current_runtime()
	_player.input.set_ads_held(InputState.Source.KEYBOARD, true)
	await wait_seconds(0.9)
	var dot_fov: float = _player.camera.fov
	assert_almost_eq(dot_fov, WeaponMotion.ads_fov_for(0.1), 0.2, "레드 도트 배율")
	_player.input.set_ads_held(InputState.Source.KEYBOARD, false)
	await wait_seconds(0.9)
	assert_almost_eq(_player.camera.fov, WeaponMotion.FOV_NORMAL, 0.2)
	var auth: LocalAuthority = _authority()
	assert_true(auth.execute(DetachPartCommand.new(rifle.item.id, [] as Array[StringName], &"optic")).ok)
	var scope: ItemInstance = _spare_item(DemoWeapons.SCOPE_4X)
	assert_true(auth.execute(AttachPartCommand.new(rifle.item.id, [] as Array[StringName], &"optic", scope.id)).ok)
	assert_gt(rifle.stats[WeaponMotion.ZOOM], 1.0)
	_player.input.set_ads_held(InputState.Source.KEYBOARD, true)
	await wait_seconds(1.1)
	assert_lt(_player.camera.fov, dot_fov - 10.0, "4배율 조준경은 시야각이 훨씬 좁다")
	assert_gt(_player.weapons.scope_overlay(), 0.9, "배율 조준경 오버레이")
	_player.input.set_ads_held(InputState.Source.KEYBOARD, false)


func test_firing_kicks_the_weapon_model_back() -> void:
	var view: WeaponView = _player.weapons.view()
	await wait_process_frames(3)
	var rest_z: float = view.position.z
	_player.input.press_fire()
	_player.input.set_fire_held(InputState.Source.KEYBOARD, true)
	await wait_physics_frames(3)
	_player.input.set_fire_held(InputState.Source.KEYBOARD, false)
	assert_gt(view.position.z, rest_z + 0.004, "킥백")


func test_rifle_without_barrel_cannot_fire() -> void:
	var rifle: WeaponRuntime = _player.weapons.current_runtime()
	assert_true(_authority().execute(
			DetachPartCommand.new(rifle.item.id, [] as Array[StringName], &"barrel")).ok)
	var messages: Array[String] = []
	_player.weapons.toast.connect(func(text: String) -> void: messages.append(text))
	_player.input.press_fire()
	_player.input.set_fire_held(InputState.Source.KEYBOARD, true)
	await wait_physics_frames(10)
	_player.input.set_fire_held(InputState.Source.KEYBOARD, false)
	assert_eq(rifle.rounds(), 30, "필수 부품(총열)이 없으면 사격 불가")
	assert_gt(messages.size(), 0)
	assert_string_contains(messages[0], "총열")


func test_inventory_open_pauses_player_input() -> void:
	assert_false(_scene.is_inventory_open())
	_scene.set_inventory_open(true)
	assert_true(_scene.is_inventory_open())
	assert_eq(_player.process_mode, Node.PROCESS_MODE_DISABLED)
	var rounds: int = _player.weapons.current_runtime().rounds()
	_player.input.press_fire()
	_player.input.set_fire_held(InputState.Source.KEYBOARD, true)
	await wait_physics_frames(10)
	assert_eq(_player.weapons.current_runtime().rounds(), rounds, "열려 있는 동안 사격하지 않음")
	_scene.set_inventory_open(false)
	assert_eq(_player.process_mode, Node.PROCESS_MODE_INHERIT)
	_player.input.set_fire_held(InputState.Source.KEYBOARD, false)


func test_mod_screen_attaches_through_the_real_ui() -> void:
	_scene.set_inventory_open(true)
	var screen: InventoryScreen = _scene.get(&"_screen") as InventoryScreen
	var rifle: ItemInstance = _player.weapons.current_runtime().item
	var mod: ModScreen = screen.mod_screen()
	mod.open(_authority(), rifle.id)
	await wait_process_frames(3)
	assert_true(screen.is_mod_screen_open())
	assert_true(mod.is_open())
	_scene.set_inventory_open(false)
