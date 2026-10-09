class_name CombatTest
extends Node3D
## M6 전투 테스트 사격장. 플레이어 로드아웃을 코드로 만들고 컨트롤러·HUD·터치 컨트롤을 연결한다.
## 웹 스모크 테스트가 읽는 로그:
##   "COMBAT_TEST: ready"
##   "COMBAT_TEST: shot <ammo_id> rounds=<남은 탄>"
##   "COMBAT_TEST: hit <target> dmg=<d> pen=<true|false> hp=<hp>"
##   "COMBAT_TEST: reload <ok|error [코드]>"
##   "COMBAT_TEST: kill <target>"
##   "COMBAT_TEST: dry"
##   "COMBAT_TEST: inventory open" / "COMBAT_TEST: inventory close"   Tab·I 키 또는 HUD 가방 버튼 / 가방 화면 닫기 버튼 (열려 있는 동안 플레이어 입력 정지)
##   "COMBAT_TEST: close_button at <x>,<y>"   가방을 열 때 닫기 버튼 중심 (창 좌표)
##   "COMBAT_TEST: weapon_changed <슬롯 번호> recoil=<v> ergo=<v>"   부품이 바뀐 뒤 무기 스탯이 갱신됐을 때
##   "COMBAT_TEST: sprint_lock on" / "COMBAT_TEST: sprint_lock off <touch|pull_down|ads|fire|crouch|wall|key_back|toggle|focus>"
##   "COMBAT_TEST: pos x=<m> z=<m> yaw=<deg>"   위치·시점이 바뀌었을 때만 (최대 0.5초에 한 번)
## AI 테스트(AiTest)가 이 클래스를 상속한다: 플레이어·HUD·터치·가방 구성은 그대로 쓰고
## _post_setup()(씬 고유 구성), _hint_text()(안내 문구)만 덮어쓴다.

const PREFIX: String = "COMBAT_TEST: "
const HINT: String = "클릭: 마우스 시점  ·  WASD 이동  ·  좌클릭 사격  ·  우클릭 조준  ·  R 재장전  ·  1/2/3 무기  ·  Tab 가방(모딩)  ·  Esc 해제"
const SCREEN_SCENE: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")

@onready var _player: PlayerController = $Player
@onready var _hud: Hud = $UI/Hud
@onready var _touch: TouchControls = $UI/TouchControls
@onready var _desktop: DesktopInput = $DesktopInput
@onready var _spawn: Marker3D = $SpawnPoint

var _authority: LocalAuthority
var _rng := RandomNumberGenerator.new()
var _pos_timer: float = 0.0
var _last_pose: Vector3 = Vector3.INF
var _screen: InventoryScreen
var _touch_was_active: bool = false


func _ready() -> void:
	_rng.randomize()
	_authority = CombatLoadout.build()
	_player.global_position = _spawn.global_position
	_player.rotation.y = _spawn.rotation.y
	_player.setup(_authority, _rng)
	_desktop.bind(_player.input)
	_touch.bind(_player.input, _player)
	_hud.bind(_player, _player.weapons, _authority)
	var weapons: WeaponController = _player.weapons
	weapons.shot_fired.connect(_on_shot)
	weapons.hit_registered.connect(_on_hit)
	weapons.reload_finished.connect(_on_reload_finished)
	var lock: SprintLock = _player.input.sprint_lock
	lock.engaged.connect(func() -> void: print(PREFIX + "sprint_lock on"))
	lock.cancelled.connect(func(reason: StringName) -> void: print(PREFIX + "sprint_lock off " + String(reason)))
	weapons.dry_fired.connect(func() -> void: print(PREFIX + "dry"))
	weapons.weapon_changed.connect(_on_weapon_changed)
	_screen = SCREEN_SCENE.instantiate() as InventoryScreen
	$UI.add_child(_screen)
	_screen.setup(_authority)
	_screen.visible = false
	_screen.process_mode = Node.PROCESS_MODE_DISABLED
	_screen.set_close_button_visible(true)
	_screen.close_requested.connect(func() -> void: set_inventory_open(false))
	_hud.inventory_requested.connect(func() -> void: set_inventory_open(not is_inventory_open()))
	_post_setup()
	await get_tree().process_frame
	print(PREFIX + "ready")


## 하위 씬이 덮어쓰는 훅: 플레이어·HUD·가방 구성이 끝난 직후, "ready" 로그 전에 불린다.
func _post_setup() -> void:
	pass


## 화면 위쪽 안내 문구 (마우스 시점이 아닐 때만 보인다). 하위 씬이 덮어쓴다.
func _hint_text() -> String:
	return HINT


func is_inventory_open() -> bool:
	return _screen != null and _screen.visible


## 가방(인벤토리·모딩 화면)을 열고 닫는다. 열려 있는 동안 플레이어·입력·HUD는 멈춘다.
func set_inventory_open(open: bool) -> void:
	if open == is_inventory_open():
		return
	if open:
		_touch_was_active = _touch.is_active()
		_player.input.release_source(InputState.Source.KEYBOARD)
		_player.input.release_source(InputState.Source.TOUCH)
		_player.input.sprint_lock.cancel(SprintLock.Reason.FOCUS, false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_touch.set_active(false)
	_player.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	_desktop.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	_touch.process_mode = Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	_hud.visible = not open
	_screen.visible = open
	_screen.process_mode = Node.PROCESS_MODE_INHERIT if open else Node.PROCESS_MODE_DISABLED
	if not open:
		_screen.mod_screen().close()
		_touch.set_active(_touch_was_active)
	print(PREFIX + ("inventory open" if open else "inventory close"))
	if open:
		print(PREFIX + "close_button at " + _win_rect_str(_screen.close_button_rect()))


## 뷰포트 좌표를 브라우저 창 좌표(스모크 클릭용)로 바꾼 사각형 중심 "x,y".
func _win_rect_str(rect: Rect2) -> String:
	var center: Vector2 = get_viewport().get_screen_transform() * rect.get_center()
	return "%d,%d" % [roundi(center.x), roundi(center.y)]


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or (_screen != null and _screen.is_mod_screen_open()):
		return
	if key.physical_keycode == KEY_TAB or key.physical_keycode == KEY_I:
		set_inventory_open(not is_inventory_open())
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and is_inventory_open():
		set_inventory_open(false)
		get_viewport().set_input_as_handled()


func _on_weapon_changed() -> void:
	var runtime: WeaponRuntime = _player.weapons.current_runtime()
	if runtime != null:
		print(PREFIX + "weapon_changed %d recoil=%.1f ergo=%.1f" % [_player.weapons.current_index() + 1,
				runtime.stats.get(WeaponStats.RECOIL, 0.0), runtime.stats.get(WeaponStats.ERGONOMICS, 0.0)])


func _process(delta: float) -> void:
	_pos_timer += delta
	if _pos_timer >= 0.5:
		_pos_timer = 0.0
		var pose := Vector3(_player.global_position.x, _player.global_position.z, _player.rotation.y)
		if pose.distance_to(_last_pose) > 0.01:
			_last_pose = pose
			print(PREFIX + "pos x=%.2f z=%.2f yaw=%.1f" % [pose.x, pose.y, rad_to_deg(pose.z)])
	var show_hint: bool = not _touch.is_active() and not _desktop.is_mouse_captured()
	_hud.set_hint(_hint_text() if show_hint else "")


func _on_shot(ammo_id: StringName, rounds_left: int) -> void:
	print(PREFIX + "shot %s rounds=%d" % [ammo_id, rounds_left])


func _on_hit(target: HitTarget, result: DamageModel.HitResult) -> void:
	print(PREFIX + "hit %s dmg=%d pen=%s hp=%d" % [target.display_name, roundi(result.damage),
			str(result.penetrated).to_lower(), ceili(target.health.hp)])
	if target.health.is_dead():
		print(PREFIX + "kill " + target.display_name)


func _on_reload_finished(ok: bool, error: StringName) -> void:
	print(PREFIX + ("reload ok" if ok else "reload error " + String(error)))
