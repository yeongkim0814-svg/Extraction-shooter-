class_name WeaponController
extends Node
## 장착한 무기(주무기1·주무기2·보조무기)를 들고 사격·재장전·교체를 처리한다.
## 상태 변경(재장전)은 반드시 authority.execute(ReloadCommand)로, 탄 소비는 코어 WeaponRuntime이 한다.
## 명중 판정은 카메라 중앙 히트스캔: 퍼짐(스탯 SPREAD, ADS면 줄어듦) → 레이캐스트 → HitTarget의 Health.take_hit.

signal weapon_changed
signal shot_fired(ammo_id: StringName, rounds_left: int)
signal hit_registered(target: HitTarget, result: DamageModel.HitResult)
signal dry_fired
signal reload_started(duration: float)
signal reload_finished(ok: bool, error: StringName)
signal toast(text: String)

const SLOTS: Array[EquipmentSlots.Slot] = [
	EquipmentSlots.Slot.PRIMARY_1, EquipmentSlots.Slot.PRIMARY_2, EquipmentSlots.Slot.SECONDARY]
const DEFAULT_RANGE: float = 150.0
const DEFAULT_SPREAD_DEG: float = 1.0
const SWAP_TIME: float = 0.4
const RELOAD_TIME: float = 2.0
const RELOAD_TIME_PISTOL: float = 1.5
## 월드(1) + 사격 대상(2)
const HIT_MASK: int = 3
const IMPACT_TIME: float = 0.25
const MARK_TIME: float = 6.0

var _authority: GameAuthority
var _player: PlayerController
var _camera: Camera3D
var _rng: RandomNumberGenerator
var _runtimes: Array[WeaponRuntime] = [null, null, null]
var _current: int = -1
var _trigger := TriggerLogic.new()
var _reloading: bool = false
var _reload_start: float = 0.0
var _reload_end: float = 0.0
var _swap_end: float = 0.0
var _view: WeaponView
var _impact_mesh: SphereMesh
var _impact_hit_mat: StandardMaterial3D
var _impact_world_mat: StandardMaterial3D
var _mark_mesh: QuadMesh
var _mark_mat: StandardMaterial3D


func setup(authority: GameAuthority, player: PlayerController, camera: Camera3D,
		rng: RandomNumberGenerator) -> void:
	_authority = authority
	_player = player
	_camera = camera
	_rng = rng
	_view = WeaponView.new()
	camera.add_child(_view)
	_build_impact_assets()
	refresh()


## 장비 슬롯에서 무기를 다시 읽는다. 현재 무기가 아직 있으면 유지.
func refresh() -> void:
	var inv: Inventory = _authority.inventory
	for i: int in range(SLOTS.size()):
		var item: ItemInstance = inv.equipment.get_item(SLOTS[i])
		if item != null and item.magazine != null:
			var existing: WeaponRuntime = _runtimes[i]
			_runtimes[i] = existing if existing != null and existing.item == item else WeaponRuntime.new(item)
		else:
			_runtimes[i] = null
	if _current < 0 or _runtimes[_current] == null:
		_current = -1
		for i: int in range(SLOTS.size()):
			if _runtimes[i] != null:
				_current = i
				break
	_update_view()
	weapon_changed.emit()


func current_runtime() -> WeaponRuntime:
	return _runtimes[_current] if _current >= 0 else null


func current_index() -> int:
	return _current


func is_reloading() -> bool:
	return _reloading


## 재장전 진행도 0..1, 재장전 중이 아니면 -1.
func reload_progress() -> float:
	if not _reloading:
		return -1.0
	return clampf((_now() - _reload_start) / maxf(_reload_end - _reload_start, 0.001), 0.0, 1.0)


func select(index: int) -> void:
	if index < 0 or index >= _runtimes.size() or index == _current or _runtimes[index] == null:
		return
	if _reloading:
		_reloading = false
		toast.emit("재장전 취소")
	_current = index
	_swap_end = _now() + SWAP_TIME
	_trigger.clear()
	_update_view()
	weapon_changed.emit()


func select_next() -> void:
	for step: int in range(1, SLOTS.size()):
		var index: int = (maxi(_current, 0) + step) % SLOTS.size()
		if _runtimes[index] != null:
			select(index)
			return


func start_reload() -> void:
	var runtime: WeaponRuntime = current_runtime()
	if runtime == null or _reloading or _now() < _swap_end:
		return
	var mag: Magazine = runtime.item.magazine
	# 즉시 알려 줄 수 있는 실패는 먼저 거른다 (실제 적용은 끝난 뒤 명령으로)
	var error: StringName = &""
	if mag.is_full():
		error = CommandResult.MAGAZINE_FULL
	elif AmmoCounter.count_carried(_authority.inventory, _authority.content, mag.caliber) <= 0:
		error = CommandResult.NO_AMMO
	if error != &"":
		toast.emit(reload_error_text(error))
		reload_finished.emit(false, error)
		return
	_reloading = true
	_reload_start = _now()
	_reload_end = _reload_start + reload_duration(_current)
	_trigger.clear()
	reload_started.emit(_reload_end - _reload_start)


static func reload_duration(slot_index: int) -> float:
	return RELOAD_TIME_PISTOL if slot_index == 2 else RELOAD_TIME


static func reload_error_text(error: StringName) -> String:
	match error:
		CommandResult.NO_AMMO:
			return "탄약 없음"
		CommandResult.MAGAZINE_FULL:
			return "탄창 가득 참"
		_:
			return "재장전 실패"


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var now: float = _now()
	var input: InputState = _player.input
	var slot: int = input.consume_slot_select()
	if slot >= 0:
		select(slot)
	if input.consume_switch():
		select_next()
	if input.consume_reload():
		start_reload()
	var pressed: bool = input.consume_fire_pressed()
	if pressed:
		_trigger.press(now)
	_trigger.set_held(input.is_fire_held())
	_view.set_ads_amount(1.0 if _player.is_ads() else 0.0)

	if _reloading and now >= _reload_end:
		_finish_reload()
	var runtime: WeaponRuntime = current_runtime()
	if runtime == null or _reloading or now < _swap_end:
		return
	if not _trigger.wants_fire(runtime.is_automatic(), now):
		return
	if runtime.rounds() <= 0:
		if pressed:
			dry_fired.emit()
		_trigger.clear()
		return
	var ammo_id: StringName = runtime.try_fire(now)
	if ammo_id == &"":
		return   # 연사 속도 제한: 다음 틱에 다시 시도
	_trigger.consume()
	_shoot(runtime, ammo_id)


func _finish_reload() -> void:
	_reloading = false
	var runtime: WeaponRuntime = current_runtime()
	var result: CommandResult = _authority.execute(ReloadCommand.new(runtime.item.id))
	if not result.ok:
		toast.emit(reload_error_text(result.error))
	reload_finished.emit(result.ok, result.error)


func _shoot(runtime: WeaponRuntime, ammo_id: StringName) -> void:
	var ammo: AmmoDef = _authority.content.get_ammo(ammo_id) if _authority.content != null else null
	if ammo == null:
		push_warning("unknown ammo id: %s" % ammo_id)
		return
	var ads: bool = _player.is_ads()
	var spread: float = FireMath.effective_spread_deg(
			runtime.stats.get(WeaponStats.SPREAD, DEFAULT_SPREAD_DEG), ads)
	var weapon_range: float = runtime.stats.get(WeaponStats.RANGE, DEFAULT_RANGE)
	var damage_mult: float = runtime.stats.get(WeaponStats.DAMAGE_MULT, 1.0)
	var origin: Vector3 = _camera.global_position
	var basis: Basis = _camera.global_basis
	var space: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	for pellet: int in range(maxi(ammo.projectile_count, 1)):
		var dir: Vector3 = FireMath.spread_direction(basis, spread, _rng)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * weapon_range, HIT_MASK, exclude)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var position: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		var target: HitTarget = HitTarget.find_for(hit["collider"] as Node)
		if target != null:
			var result: DamageModel.HitResult = target.apply_hit(ammo, damage_mult, _rng)
			if result != null:
				hit_registered.emit(target, result)
		_spawn_impact(position, normal, target != null)
	_view.flash()
	_player.add_recoil(FireMath.recoil_kick(runtime.stats.get(WeaponStats.RECOIL, 0.0), ads, _rng))
	shot_fired.emit(ammo_id, runtime.rounds())


func _update_view() -> void:
	var runtime: WeaponRuntime = current_runtime()
	if runtime != null:
		_view.set_weapon_length(0.1 * runtime.item.def.width + 0.1)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- 임시 이펙트 (M7에서 교체) ---

func _build_impact_assets() -> void:
	_impact_mesh = SphereMesh.new()
	_impact_mesh.radius = 0.06
	_impact_mesh.height = 0.12
	_impact_mesh.radial_segments = 8
	_impact_mesh.rings = 4
	_impact_hit_mat = _unshaded(Color(1.0, 0.35, 0.25))
	_impact_world_mat = _unshaded(Color(0.85, 0.82, 0.7))
	_mark_mesh = QuadMesh.new()
	_mark_mesh.size = Vector2(0.09, 0.09)
	_mark_mat = _unshaded(Color(0.05, 0.05, 0.05))


static func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func _spawn_impact(position: Vector3, normal: Vector3, on_target: bool) -> void:
	var parent: Node = _player.get_parent()
	var puff := MeshInstance3D.new()
	puff.mesh = _impact_mesh
	puff.material_override = _impact_hit_mat if on_target else _impact_world_mat
	parent.add_child(puff)
	puff.global_position = position + normal * 0.03
	var tween: Tween = puff.create_tween()
	tween.tween_property(puff, "scale", Vector3.ONE * 2.5, IMPACT_TIME)
	tween.tween_callback(puff.queue_free)
	if on_target:
		return
	var mark := MeshInstance3D.new()
	mark.mesh = _mark_mesh
	mark.material_override = _mark_mat
	parent.add_child(mark)
	var up: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	mark.look_at_from_position(position + normal * 0.01, position + normal, up)
	var timer: SceneTreeTimer = get_tree().create_timer(MARK_TIME)
	timer.timeout.connect(mark.queue_free)
