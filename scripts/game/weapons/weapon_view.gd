class_name WeaponView
extends Node3D
## 1인칭 무기 표시: 부품 트리로 조립한 플레이스홀더 모델(WeaponAssembler) + 절차적 움직임(WeaponMotion) + 총구 화염.
## 카메라의 자식. 무기가 바뀌거나 부품 구성이 바뀌면 모델을 다시 조립한다.

const FLASH_TIME: float = 0.05
## 1인칭 모델 배율. 실물 크기 모델을 그대로 두면 카메라가 가까워 화면을 너무 차지한다.
const VIEW_SCALE: float = 0.7
## ADS 비율이 이 값을 넘으면 확대 조준경 모델을 숨긴다 (조준선을 가리지 않게).
const SCOPE_HIDE_AT: float = 0.55

var motion := WeaponMotion.new()

var _built: WeaponAssembler.Built = null
var _signature: String = ""
var _item_id: int = 0
var _flash_root: Node3D
var _flash_quad: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_left: float = 0.0
var _scope_hidden: bool = false


func _ready() -> void:
	_flash_root = Node3D.new()
	_flash_quad = MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(0.14, 0.14)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.85, 0.4)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mesh.material = flash_mat
	_flash_quad.mesh = quad_mesh
	_flash_root.add_child(_flash_quad)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.45)
	_flash_light.light_energy = 2.5
	_flash_light.omni_range = 5.0
	_flash_root.add_child(_flash_light)
	_flash_root.visible = false
	add_child(_flash_root)
	position = motion.hip_position


## 들고 있는 무기를 지정한다. 아이템이 같고 부품 구성도 같으면 모델은 그대로 두고 스탯만 갱신한다.
func set_weapon(item: ItemInstance, stats: Dictionary[StringName, float]) -> void:
	if item == null:
		_clear_model()
		_item_id = 0
		visible = false
		return
	visible = true
	var signature: String = WeaponAssembler.signature(item.weapon) if item.weapon != null else "plain:" + str(item.id)
	if item.id != _item_id:
		motion.start_swap()
		_item_id = item.id
	if signature != _signature or _built == null:
		_rebuild(item)
		_signature = signature
	set_stats(stats)


func set_stats(stats: Dictionary[StringName, float]) -> void:
	motion.configure(stats)


func has_model() -> bool:
	return _built != null


## 현재 조립된 모델의 부품 구성 키 (테스트용).
func model_signature() -> String:
	return _signature


func model_root() -> Node3D:
	return _built.root if _built != null else null


func ads_amount() -> float:
	return motion.ads_amount()


func fov() -> float:
	return motion.fov()


## 확대 조준경 ADS 오버레이 강도 0..1 (배율이 있는 조준경일 때만).
func scope_overlay() -> float:
	return motion.ads_amount() if motion.zoom >= 0.5 else 0.0


func flash(loudness: float = 1.0) -> void:
	_flash_left = FLASH_TIME
	_flash_root.visible = true
	_flash_quad.scale = Vector3.ONE * clampf(loudness, 0.3, 1.0)
	_flash_light.light_energy = 2.5 * clampf(loudness, 0.2, 1.0)


## 한 발 쏜 뒤. effective는 WeaponMotion.effective_recoil() 결과.
func kick(effective: float, yaw_random: float) -> void:
	motion.kick(effective, yaw_random)


## 프레임마다 (WeaponController가 호출). 움직임을 갱신해 노드에 적용한다.
func drive(delta: float, want_ads: bool, want_sprint: bool, want_reload: bool, speed_ratio: float,
		look: Vector2) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_root.visible = false
	motion.update(delta, want_ads, want_sprint, want_reload, speed_ratio, look)
	position = motion.position
	rotation = motion.euler
	if _built != null:
		var hide_scope: bool = motion.ads_amount() > SCOPE_HIDE_AT
		if hide_scope != _scope_hidden:
			_scope_hidden = hide_scope
			for node: Node3D in _built.ads_hidden:
				node.visible = not hide_scope


func _rebuild(item: ItemInstance) -> void:
	_clear_model()
	if item.weapon != null:
		_built = WeaponAssembler.build(item.weapon)
	else:
		_built = _plain_model(item)
	add_child(_built.root)
	_built.root.scale = Vector3.ONE * VIEW_SCALE
	motion.set_sight_height(_built.sight_y * VIEW_SCALE)
	_flash_root.position = (_built.muzzle + Vector3(0.0, 0.0, -0.03)) * VIEW_SCALE
	_scope_hidden = false


func _clear_model() -> void:
	if _built != null:
		remove_child(_built.root)
		_built.root.queue_free()
		_built = null
	_signature = ""


## 부품 트리가 없는 아이템용 단순 상자.
static func _plain_model(item: ItemInstance) -> WeaponAssembler.Built:
	var built := WeaponAssembler.Built.new()
	built.root = Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length: float = 0.08 * float(item.def.width) + 0.05
	box.size = Vector3(0.035, 0.06, length)
	mi.mesh = box
	mi.material_override = WeaponAssembler.material_for(WeaponLook.METAL, false)
	mi.position = Vector3(0.0, 0.02, -length * 0.5 + 0.05)
	built.root.add_child(mi)
	built.muzzle = Vector3(0.0, 0.03, -length + 0.05)
	built.sight_y = 0.05
	return built
