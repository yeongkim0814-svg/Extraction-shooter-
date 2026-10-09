class_name WeaponView
extends Node3D
## 1인칭 무기 임시 외형(상자) + 총구 화염(짧게 켜지는 라이트·사각형). M7에서 실제 모델·절차적 반동/ADS로 교체한다.

const HIP_POS: Vector3 = Vector3(0.17, -0.16, -0.38)
const ADS_POS: Vector3 = Vector3(0.0, -0.1, -0.34)
const FLASH_TIME: float = 0.05
const KICK_BACK: float = 0.04
const KICK_RECOVERY: float = 14.0

var _body: MeshInstance3D
var _flash_root: Node3D
var _flash_light: OmniLight3D
var _flash_left: float = 0.0
var _kick: float = 0.0
var _ads_amount: float = 0.0
var _length: float = 0.5


func _ready() -> void:
	_body = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.035, 0.06, 0.5)
	_body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.31, 0.34)
	box.material = mat
	add_child(_body)

	_flash_root = Node3D.new()
	var quad := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(0.22, 0.22)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.85, 0.4)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mesh.material = flash_mat
	quad.mesh = quad_mesh
	_flash_root.add_child(quad)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.45)
	_flash_light.light_energy = 3.0
	_flash_light.omni_range = 6.0
	_flash_root.add_child(_flash_light)
	_flash_root.visible = false
	add_child(_flash_root)
	position = HIP_POS
	set_weapon_length(_length)


## 인벤토리 가로 칸 수 등으로 정한 길이 (m).
func set_weapon_length(length: float) -> void:
	_length = length
	(_body.mesh as BoxMesh).size = Vector3(0.035, 0.06, length)
	_body.position = Vector3(0.0, 0.0, -length * 0.5 + 0.1)
	_flash_root.position = Vector3(0.0, 0.02, -length - 0.05)


func set_ads_amount(amount: float) -> void:
	_ads_amount = clampf(amount, 0.0, 1.0)


func flash() -> void:
	_flash_left = FLASH_TIME
	_flash_root.visible = true
	_kick = KICK_BACK


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_root.visible = false
	_kick = move_toward(_kick, 0.0, KICK_RECOVERY * KICK_BACK * delta)
	position = HIP_POS.lerp(ADS_POS, _ads_amount) + Vector3(0.0, 0.0, _kick)
