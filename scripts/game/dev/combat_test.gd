extends Node3D
## M6 전투 테스트 사격장. 플레이어 로드아웃을 코드로 만들고 컨트롤러·HUD·터치 컨트롤을 연결한다.
## 웹 스모크 테스트가 읽는 로그:
##   "COMBAT_TEST: ready"
##   "COMBAT_TEST: shot <ammo_id> rounds=<남은 탄>"
##   "COMBAT_TEST: hit <target> dmg=<d> pen=<true|false> hp=<hp>"
##   "COMBAT_TEST: reload <ok|error [코드]>"
##   "COMBAT_TEST: kill <target>"
##   "COMBAT_TEST: dry"
##   "COMBAT_TEST: pos x=<m> z=<m> yaw=<deg>"   위치·시점이 바뀌었을 때만 (최대 0.5초에 한 번)

const PREFIX: String = "COMBAT_TEST: "
const HINT: String = "화면을 클릭해 마우스 시점 켜기  ·  WASD 이동  ·  좌클릭 사격  ·  우클릭 조준  ·  R 재장전  ·  1/2/3 무기  ·  Esc 해제"

@onready var _player: PlayerController = $Player
@onready var _hud: Hud = $UI/Hud
@onready var _touch: TouchControls = $UI/TouchControls
@onready var _desktop: DesktopInput = $DesktopInput
@onready var _spawn: Marker3D = $SpawnPoint

var _authority: LocalAuthority
var _rng := RandomNumberGenerator.new()
var _pos_timer: float = 0.0
var _last_pose: Vector3 = Vector3.INF


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
	weapons.dry_fired.connect(func() -> void: print(PREFIX + "dry"))
	await get_tree().process_frame
	print(PREFIX + "ready")


func _process(delta: float) -> void:
	_pos_timer += delta
	if _pos_timer >= 0.5:
		_pos_timer = 0.0
		var pose := Vector3(_player.global_position.x, _player.global_position.z, _player.rotation.y)
		if pose.distance_to(_last_pose) > 0.01:
			_last_pose = pose
			print(PREFIX + "pos x=%.2f z=%.2f yaw=%.1f" % [pose.x, pose.y, rad_to_deg(pose.z)])
	var show_hint: bool = not _touch.is_active() and not _desktop.is_mouse_captured()
	_hud.set_hint(HINT if show_hint else "")


func _on_shot(ammo_id: StringName, rounds_left: int) -> void:
	print(PREFIX + "shot %s rounds=%d" % [ammo_id, rounds_left])


func _on_hit(target: HitTarget, result: DamageModel.HitResult) -> void:
	print(PREFIX + "hit %s dmg=%d pen=%s hp=%d" % [target.display_name, roundi(result.damage),
			str(result.penetrated).to_lower(), ceili(target.health.hp)])
	if target.health.is_dead():
		print(PREFIX + "kill " + target.display_name)


func _on_reload_finished(ok: bool, error: StringName) -> void:
	print(PREFIX + ("reload ok" if ok else "reload error " + String(error)))
