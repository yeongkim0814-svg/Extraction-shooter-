class_name PlayerController
extends CharacterBody3D
## 1인칭 컨트롤러. 입력은 InputState에서만 읽는다 (터치/키보드 구분 없음).
## 구조: 몸(CharacterBody3D, 좌우 회전) > Head(상하 회전 + 반동) > Camera3D.

signal ads_changed(on: bool)

const WALK_SPEED: float = 4.5
const SPRINT_SPEED: float = 6.5
const CROUCH_SPEED: float = 2.4
const ADS_SPEED_MULT: float = 0.6
const JUMP_VELOCITY: float = 4.6
const GRAVITY: float = 12.0
const GROUND_ACCEL: float = 45.0
const AIR_ACCEL: float = 8.0

const STAND_EYE: float = 1.6
const CROUCH_EYE: float = 1.0
const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.2
const BODY_RADIUS: float = 0.35
const EYE_LERP: float = 12.0

const PITCH_LIMIT: float = 1.48353  # 85도
const FOV_NORMAL: float = 75.0
const FOV_ADS: float = 45.0
const FOV_LERP: float = 14.0
const RECOIL_RECOVERY: float = 9.0

var input: InputState = InputState.new()
var health: Health = Health.new(100.0)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: WeaponController = $Weapons
@onready var _shape_node: CollisionShape3D = $CollisionShape3D

var _pitch: float = 0.0
var _recoil: Vector2 = Vector2.ZERO
var _crouching: bool = false
var _crouch_toggled: bool = false
var _ads_toggled: bool = false
var _ads_last: bool = false
var _eye_height: float = STAND_EYE
var _capsule: CapsuleShape3D


func _ready() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = BODY_RADIUS
	_shape_node.shape = _capsule
	_apply_body_height(STAND_HEIGHT)
	camera.fov = FOV_NORMAL
	camera.current = true


## 권한자·난수를 받아 무기 컨트롤러를 연결한다.
func setup(authority: GameAuthority, rng: RandomNumberGenerator) -> void:
	weapons.setup(authority, self, camera, rng)


func is_ads() -> bool:
	return _ads_toggled or input.is_ads_held()


func is_crouching() -> bool:
	return _crouching


## 카메라 반동 킥 (라디안). 시간이 지나면 절차적으로 원위치로 돌아온다.
func add_recoil(kick: Vector2) -> void:
	_recoil += kick


func look_pitch() -> float:
	return _pitch


func _process(delta: float) -> void:
	var ads: bool = is_ads()
	if ads != _ads_last:
		_ads_last = ads
		ads_changed.emit(ads)
	# 시점
	var look: Vector2 = input.consume_look()
	if ads:
		look *= InputState.ADS_LOOK_SCALE
	rotation.y -= look.x
	_pitch = clampf(_pitch - look.y, -PITCH_LIMIT, PITCH_LIMIT)
	_recoil *= exp(-RECOIL_RECOVERY * delta)
	head.rotation = Vector3(_pitch + _recoil.x, _recoil.y, 0.0)
	# 시야각 / 눈높이
	camera.fov = lerpf(camera.fov, FOV_ADS if ads else FOV_NORMAL, 1.0 - exp(-FOV_LERP * delta))
	var target_eye: float = CROUCH_EYE if _crouching else STAND_EYE
	_eye_height = lerpf(_eye_height, target_eye, 1.0 - exp(-EYE_LERP * delta))
	head.position.y = _eye_height
	health.tick(delta)


func _physics_process(delta: float) -> void:
	if input.consume_ads_toggle():
		_ads_toggled = not _ads_toggled
	if input.consume_crouch_toggle():
		_crouch_toggled = not _crouch_toggled
	var jump: bool = input.consume_jump()
	_update_crouch(input.is_crouch_held() or _crouch_toggled)
	if jump and is_on_floor():
		if _crouching:
			_crouch_toggled = false   # 앉은 상태에서 점프 = 먼저 일어서기
		else:
			velocity.y = JUMP_VELOCITY

	var move: Vector2 = input.move()
	var wish: Vector3 = transform.basis * Vector3(move.x, 0.0, move.y)
	var speed: float = WALK_SPEED
	if _crouching:
		speed = CROUCH_SPEED
	elif input.is_sprint() and move.y < -0.1 and not is_ads():
		speed = SPRINT_SPEED
	if is_ads():
		speed *= ADS_SPEED_MULT
	var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, wish.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, wish.z * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _update_crouch(want: bool) -> void:
	if want == _crouching:
		return
	if not want:
		# 머리 위가 막혀 있으면 일어서지 못한다
		var rise: float = STAND_HEIGHT - CROUCH_HEIGHT + 0.05
		if test_move(global_transform, Vector3(0.0, rise, 0.0)):
			return
	_crouching = want
	_apply_body_height(CROUCH_HEIGHT if want else STAND_HEIGHT)


func _apply_body_height(height: float) -> void:
	_capsule.height = height
	_shape_node.position.y = height * 0.5
