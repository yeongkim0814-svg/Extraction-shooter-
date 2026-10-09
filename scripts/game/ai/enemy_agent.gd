class_name EnemyAgent
extends CharacterBody3D
## 적 AI 실행 계층 (M8). 코어 AiBrain이 상태를 정하고, 여기서는 감지 값(AiBlackboard)을 채우고
## 상태에 맞게 이동·조준·사격을 실행한다. 외형은 코드로 만든 임시 도형 (target_dummy.gd와 같은 방식).
## 죽으면 시체가 되어 루팅 컨테이너(권한자 등록)를 남긴다.
##
## 충돌 레이어: 살아 있을 때 3 (월드 1 + 사격 대상 2), 마스크 1.
## 시체는 레이어 1만 쓴다: 플레이어 총알(마스크 3)이 월드처럼 막히고(더는 피해를 주지 않는 사격 대상이 아님),
## 플레이어 이동도 계속 막는다. 루팅은 레이캐스트가 아니라 거리·시선 판정으로 한다.

signal shot_fired(enemy: EnemyAgent)
signal died(enemy: EnemyAgent)
signal state_changed(enemy: EnemyAgent, state: AiBrain.State)

const FONT: Font = preload("res://assets/fonts/NotoSansKR.ttf")

const EYE_HEIGHT: float = 1.6
const BODY_RADIUS: float = 0.35
const BODY_HEIGHT: float = 1.8
const GRAVITY: float = 12.0
const LAYER_ALIVE: int = 3
const LAYER_CORPSE: int = 1
## 시야 확인 레이 (월드만).
const LOS_MASK: int = 1
## 사격 레이: 월드(1) + 사격 대상(2) + 플레이어(4).
const SHOOT_MASK: int = 7
const SHOOT_RANGE: float = 80.0
const COVER_ARRIVE: float = 0.8
const COVER_MAX_DISTANCE: float = 30.0
const COVER_RAY_HEIGHT: float = 1.0
const PATROL_WAIT: float = 2.0
const PATROL_ARRIVE: float = 0.7
const ROUTE_ARRIVE: float = 1.0
const SEARCH_RADIUS: float = 8.0
const SUSPICIOUS_SPEED_MULT: float = 0.7
const STRAFE_SPEED: float = 1.2
## 무기 연사 간격에 곱하는 AI 보정 (소총 10발/초를 그대로 쓰면 너무 빨라서).
const FIRE_INTERVAL_MULT: float = 1.8
const MAG_SIZE: int = 30
## 교전 밖에서 탄이 이만큼 미만이면 재장전한다.
const RELOAD_BELOW: int = 15
const FLASH_TIME: float = 0.07
const HIT_FLASH_TIME: float = 0.06
const BODY_COLOR := Color(0.24, 0.29, 0.14)
const CORPSE_COLOR := Color(0.14, 0.15, 0.12)
## 살아 있는 적의 약한 자체 발광 (가시성). 시체는 끈다.
const ALIVE_GLOW := Color(0.36, 0.44, 0.2)
const ALIVE_GLOW_ENERGY: float = 0.4

@export var enemy_name: String = "적"
## 머리 위 이름·상태·HP 글자 (개발용).
var show_debug_label: bool = true:
	set(value):
		show_debug_label = value
		if _label != null:
			_label.visible = value
## 시체에 넣을 추가 루팅 테이블 (없으면 소총·탄약만).
var loot_table: LootTable = null
var profile: AiProfile
var brain: AiBrain
var blackboard := AiBlackboard.new()
var hit_target: HitTarget

var _authority: GameAuthority
var _rng: RandomNumberGenerator
var _player: PlayerController
var _director: AiDirector
var _patrol_points: Array[Vector3] = []
var _home: Vector3 = Vector3.ZERO

var _runtime: WeaponRuntime
var _ammo: AmmoDef
var _gunner: AiGunner

var _nav: NavigationAgent3D
var _visual: Node3D
var _shape_node: CollisionShape3D
var _body_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _label: Label3D
var _muzzle: Node3D
var _flash_left: float = 0.0
var _hit_flash_left: float = 0.0
var _label_timer: float = 0.0

var _dead: bool = false
var _loot_key: StringName = &""
var _loot_grid: ItemGrid
var _was_seen_once: bool = false

var _nav_goal: Vector3 = Vector3.INF
var _face_dir: Vector3 = Vector3.ZERO

var _patrol_index: int = 0
var _patrol_wait: float = 0.0
var _cover_point: Vector3 = Vector3.INF
var _cover_repick: float = 0.0
var _search_reached: bool = false
var _search_wait: float = 0.0
var _search_goal: Vector3 = Vector3.INF
var _strafe_dir: float = 0.0
var _strafe_timer: float = 0.0


func _ready() -> void:
	collision_layer = LAYER_ALIVE
	collision_mask = 1
	_build_visuals()
	_nav = NavigationAgent3D.new()
	_nav.radius = BODY_RADIUS + 0.05
	_nav.height = BODY_HEIGHT
	_nav.path_desired_distance = 0.5
	_nav.target_desired_distance = 0.6
	_nav.avoidance_enabled = false
	add_child(_nav)
	hit_target = HitTarget.new()
	hit_target.display_name = enemy_name
	hit_target.health = Health.new(100.0)
	add_child(hit_target)
	hit_target.damaged.connect(_on_damaged)
	hit_target.died.connect(_on_died)
	_update_label()


## 권한자·난수·플레이어·순찰 지점·성향·감독을 받아 AI를 시작한다. 씬 트리에 들어온 뒤에 부른다.
func setup(authority: GameAuthority, rng: RandomNumberGenerator, player: PlayerController,
		patrol_points: Array[Vector3], profile_: AiProfile, director: AiDirector) -> void:
	_authority = authority
	_rng = rng
	_player = player
	_patrol_points = patrol_points
	profile = profile_
	_director = director
	_home = global_position
	brain = AiBrain.new(profile)
	_build_weapon()
	_gunner = AiGunner.new(profile, MAG_SIZE, _runtime.fire_interval() * FIRE_INTERVAL_MULT, rng)
	if director != null:
		director.register(self)
	_update_label()


func is_dead() -> bool:
	return _dead


## 시체 루팅 컨테이너 키 (살아 있으면 &"").
func loot_key() -> StringName:
	return _loot_key


## 시체 그리드에 든 아이템 수 (로그·테스트용).
func loot_item_count() -> int:
	return _loot_grid.get_items().size() if _loot_grid != null else 0


func eye_position() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT


## 시체의 중심 (누워 있는 몸통 가운데). 살아 있으면 몸 위치.
func corpse_position() -> Vector3:
	return global_position + global_basis * Vector3(0.0, 0.0, -0.9) if _dead else global_position


## [개발용] 시체 중심이 world_pos(바닥 높이)에 오도록 옮긴다.
func place_corpse_at(world_pos: Vector3) -> void:
	global_position = world_pos - global_basis * Vector3(0.0, 0.0, -0.9) if _dead else world_pos


## 소음을 들었다 (감독이 부른다). 다음 틱에 두뇌가 읽는다.
func hear_noise(position_: Vector3) -> void:
	if _dead:
		return
	blackboard.heard_noise = true
	blackboard.noise_position = position_


## [개발용] 즉시 죽인다.
func kill() -> void:
	if _dead:
		return
	hit_target.health.hp = 0.0
	_on_died()


func state_name() -> String:
	return String(AiBrain.State.keys()[brain.state]) if brain != null else "-"


# --- 외형 ---

func _build_visuals() -> void:
	_shape_node = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	_shape_node.shape = capsule
	_shape_node.position.y = BODY_HEIGHT * 0.5
	add_child(_shape_node)

	_visual = Node3D.new()
	add_child(_visual)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = BODY_COLOR
	_body_mat.roughness = 0.9
	_head_mat = StandardMaterial3D.new()
	_head_mat.albedo_color = BODY_COLOR.lightened(0.25)
	_head_mat.roughness = 0.9
	# 어두운 실내·안개 속에서도 보이도록 약한 자체 발광 + 가장자리 빛 (M10)
	for mat: StandardMaterial3D in [_body_mat, _head_mat]:
		mat.emission_enabled = true
		mat.emission = ALIVE_GLOW
		mat.emission_energy_multiplier = ALIVE_GLOW_ENERGY
		mat.rim_enabled = true
		mat.rim = 0.7
		mat.rim_tint = 0.5

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = BODY_RADIUS
	body_mesh.height = BODY_HEIGHT - 0.2
	body.mesh = body_mesh
	body.position.y = (BODY_HEIGHT - 0.2) * 0.5
	body.material_override = _body_mat
	_visual.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.26, 0.26, 0.26)
	head.mesh = head_mesh
	head.position = Vector3(0.0, BODY_HEIGHT - 0.1, 0.0)
	head.material_override = _head_mat
	_visual.add_child(head)

	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.08, 0.12, 0.7)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.22, 1.2, -0.5)
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.08, 0.08, 0.09)
	gun.material_override = gun_mat
	_visual.add_child(gun)

	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.22, 1.2, -0.9)
	_muzzle.visible = false
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.14
	flash_mesh.height = 0.28
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	flash.mesh = flash_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.85, 0.35)
	flash.material_override = flash_mat
	_muzzle.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 3.0
	light.omni_range = 7.0
	_muzzle.add_child(light)
	_visual.add_child(_muzzle)

	_label = Label3D.new()
	_label.font = FONT
	_label.font_size = 36
	_label.pixel_size = 0.007
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 2.35
	_label.visible = show_debug_label
	add_child(_label)


func _update_label() -> void:
	if _label == null:
		return
	if _dead:
		_label.text = "시체"
		return
	var hp: Health = hit_target.health if hit_target != null else null
	var hp_text: String = "HP %d/%d" % [ceili(hp.hp), int(hp.max_hp)] if hp != null else ""
	_label.text = "%s\n%s  %s" % [enemy_name, state_name(), hp_text]


# --- 무기 ---

## 플레이어 소총과 같은 구성의 소총을 만든다. 인벤토리에는 넣지 않고, 죽으면 시체 그리드에 들어간다.
func _build_weapon() -> void:
	var content: ContentDatabase = _authority.content
	var def: ItemDef = content.get_item(&"rifle")
	_ammo = content.get_ammo(CombatLoadout.AMMO_556)
	assert(def != null and _ammo != null, "EnemyAgent: rifle/ammo definition missing in content")
	var item: ItemInstance = _authority.create_item(def)
	item.weapon = DemoWeapons.assemble(content, &"rifle")
	item.magazine = Magazine.new(_ammo.caliber, MAG_SIZE)
	item.magazine.load_rounds(_ammo, MAG_SIZE)
	_runtime = WeaponRuntime.new(item)


# --- 틱 ---

func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_muzzle.visible = false
	if _hit_flash_left > 0.0:
		_hit_flash_left -= delta
		if _hit_flash_left <= 0.0:
			_body_mat.albedo_color = CORPSE_COLOR if _dead else BODY_COLOR
			_head_mat.albedo_color = (CORPSE_COLOR if _dead else BODY_COLOR).lightened(0.25)
	_label_timer -= delta
	if _label_timer <= 0.0:
		_label_timer = 0.25
		_update_label()


func _physics_process(delta: float) -> void:
	if _dead or _player == null or brain == null:
		return
	_update_blackboard()
	var previous: AiBrain.State = brain.state
	brain.update(blackboard, delta)
	if brain.state != previous:
		_on_state_entered(brain.state)
		state_changed.emit(self, brain.state)
	_face_dir = Vector3.ZERO
	var wish := Vector3.ZERO
	var fire_allowed: bool = false
	match brain.state:
		AiBrain.State.PATROL:
			wish = _do_patrol(delta)
		AiBrain.State.SUSPICIOUS:
			wish = _do_suspicious()
		AiBrain.State.COMBAT:
			wish = _do_combat(delta)
			fire_allowed = true
		AiBrain.State.TAKE_COVER:
			wish = _do_take_cover(delta)
			fire_allowed = blackboard.in_cover
		AiBrain.State.SEARCH:
			wish = _do_search(delta)
		AiBrain.State.RETURN:
			wish = _do_return()
	_update_firing(delta, fire_allowed)
	_apply_motion(wish, delta)


func _on_state_entered(state: AiBrain.State) -> void:
	match state:
		AiBrain.State.TAKE_COVER:
			_cover_point = Vector3.INF
			_cover_repick = 0.0
		AiBrain.State.SEARCH:
			_search_reached = false
			_search_goal = blackboard.last_known_position
			_search_wait = 0.0
		AiBrain.State.RETURN:
			_patrol_index = _nearest_patrol_index()
		AiBrain.State.COMBAT:
			_strafe_timer = 0.0
	_nav_goal = Vector3.INF


# --- 감지 ---

func _chest_point() -> Vector3:
	return _player.global_position + Vector3.UP * (0.6 if _player.is_crouching() else 1.1)


func _ray_clear(from: Vector3, to: Vector3) -> bool:
	var exclude: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(from, to, LOS_MASK, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _compute_can_see() -> bool:
	if _player.health.is_dead():
		return false
	var eye: Vector3 = eye_position()
	var chest: Vector3 = _chest_point()
	var sight: float = AiPerception.sight_distance(profile.view_distance, _player.is_crouching(),
			_player.is_sprinting())
	# 교전 중에는 이미 목표를 쫓고 있으므로 시야각 제한 없이 거리·가림만 본다
	var alerted: bool = brain.state == AiBrain.State.COMBAT or brain.state == AiBrain.State.TAKE_COVER
	if alerted:
		if eye.distance_to(chest) > sight:
			return false
	elif not AiPerception.in_view_cone(eye, -global_basis.z, chest, profile.fov_deg, sight):
		return false
	return _ray_clear(eye, chest) or _ray_clear(eye, _player.head.global_position)


func _update_blackboard() -> void:
	var bb: AiBlackboard = blackboard
	bb.can_see_target = _compute_can_see()
	if bb.can_see_target:
		bb.target_position = _player.global_position
		bb.last_known_position = _player.global_position
		_was_seen_once = true
	bb.health_ratio = clampf(hit_target.health.hp / hit_target.health.max_hp, 0.0, 1.0)
	bb.ammo_in_mag = _gunner.rounds()
	bb.at_patrol_route = _flat_distance(global_position, _patrol_point(_nearest_patrol_index())) <= ROUTE_ARRIVE
	bb.in_cover = _check_in_cover()


func _check_in_cover() -> bool:
	if brain.state != AiBrain.State.TAKE_COVER:
		return false
	if _cover_point == Vector3.INF:
		return true   # 쓸 만한 엄폐물이 없으면 제자리에서 재장전하며 버틴다
	if _flat_distance(global_position, _cover_point) > COVER_ARRIVE:
		return false
	return not _ray_clear(global_position + Vector3.UP * COVER_RAY_HEIGHT, _player.head.global_position)


# --- 엄폐 ---

func _cover_candidates() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group("cover_point"):
		var marker := node as Node3D
		if marker != null:
			result.append(marker.global_position)
	return result


## 플레이어 머리로 가는 선(높이 1.0 m)이 막히는 가장 가까운 엄폐 지점. 없으면 INF.
func _pick_cover() -> Vector3:
	var head: Vector3 = _player.head.global_position
	var best: Vector3 = Vector3.INF
	var best_dist: float = COVER_MAX_DISTANCE
	for point: Vector3 in _cover_candidates():
		var dist: float = _flat_distance(global_position, point)
		if dist >= best_dist:
			continue
		if _ray_clear(point + Vector3.UP * COVER_RAY_HEIGHT, head):
			continue
		best = point
		best_dist = dist
	return best


# --- 상태별 행동. 반환값은 원하는 수평 이동 속도 벡터 ---

func _do_patrol(delta: float) -> Vector3:
	if _patrol_points.is_empty():
		return Vector3.ZERO
	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		return Vector3.ZERO
	var goal: Vector3 = _patrol_points[_patrol_index % _patrol_points.size()]
	var move: Vector3 = _steer_to(goal, profile.walk_speed, PATROL_ARRIVE)
	if move == Vector3.ZERO:
		_patrol_wait = PATROL_WAIT
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
	return move


func _do_suspicious() -> Vector3:
	var noise: Vector3 = blackboard.noise_position
	_face_dir = _flat_dir(global_position, noise)
	return _steer_to(noise, profile.walk_speed * SUSPICIOUS_SPEED_MULT, 1.5)


func _do_combat(delta: float) -> Vector3:
	_face_dir = _flat_dir(global_position, _player.global_position)
	if blackboard.can_see_target:
		return _strafe(delta)
	_face_dir = Vector3.ZERO   # 시야가 없으면 이동 방향을 본다
	return _steer_to(blackboard.last_known_position, profile.run_speed, 1.0)


func _strafe(delta: float) -> Vector3:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = _rng.randf_range(1.0, 2.5)
		var options: Array[float] = [-1.0, 0.0, 0.0, 1.0]
		_strafe_dir = options[_rng.randi_range(0, 3)]
	if _strafe_dir == 0.0:
		return Vector3.ZERO
	var motion: Vector3 = global_basis.x * _strafe_dir * STRAFE_SPEED
	if test_move(global_transform, motion * 0.4):
		_strafe_dir = -_strafe_dir
		return Vector3.ZERO
	return motion


func _do_take_cover(delta: float) -> Vector3:
	_cover_repick -= delta
	var arrived: bool = _cover_point != Vector3.INF and _flat_distance(global_position, _cover_point) <= COVER_ARRIVE
	if not arrived and _cover_repick <= 0.0:
		_cover_repick = 1.0
		_cover_point = _pick_cover()
	if blackboard.can_see_target or _was_seen_once:
		_face_dir = _flat_dir(global_position, _player.global_position)
	var move := Vector3.ZERO
	if _cover_point != Vector3.INF and not arrived:
		_face_dir = Vector3.ZERO
		move = _steer_to(_cover_point, profile.run_speed, COVER_ARRIVE * 0.5)
	if blackboard.in_cover and _gunner.needs_reload():
		_gunner.start_reload()
	return move


func _do_search(delta: float) -> Vector3:
	var arrived: bool = _search_goal == Vector3.INF or _flat_distance(global_position, _search_goal) <= 1.5
	if arrived:
		_search_wait -= delta
		if _search_wait <= 0.0:
			_search_reached = true
			_search_wait = _rng.randf_range(1.0, 2.5)
			_search_goal = _random_nearby_point(SEARCH_RADIUS)
		return Vector3.ZERO
	return _steer_to(_search_goal, profile.walk_speed, 1.5)


func _do_return() -> Vector3:
	return _steer_to(_patrol_point(_patrol_index), profile.walk_speed, ROUTE_ARRIVE * 0.5)


func _random_nearby_point(radius: float) -> Vector3:
	var angle: float = _rng.randf() * TAU
	var dist: float = radius * sqrt(_rng.randf())
	var wanted: Vector3 = global_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
	var map: RID = get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, wanted)


# --- 경로·이동 ---

func _patrol_point(index: int) -> Vector3:
	if _patrol_points.is_empty():
		return _home
	return _patrol_points[index % _patrol_points.size()]


func _nearest_patrol_index() -> int:
	var best: int = 0
	var best_dist: float = INF
	for i: int in range(maxi(_patrol_points.size(), 1)):
		var dist: float = _flat_distance(global_position, _patrol_point(i))
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _flat_dir(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length() > 0.001 else Vector3.ZERO


## 내비메시 경로를 따라 goal로 가는 수평 속도. 도착했으면 ZERO.
func _steer_to(goal: Vector3, speed: float, arrive: float) -> Vector3:
	if _flat_distance(global_position, goal) <= arrive:
		return Vector3.ZERO
	if _nav_goal == Vector3.INF or goal.distance_to(_nav_goal) > 0.5:
		_nav_goal = goal
		_nav.target_position = goal
	var next: Vector3 = _nav.get_next_path_position()
	if _nav.is_navigation_finished():
		return Vector3.ZERO
	var dir: Vector3 = _flat_dir(global_position, next)
	return dir * speed


func _apply_motion(wish: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, wish.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, wish.z, 30.0 * delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	var look: Vector3 = _face_dir
	if look == Vector3.ZERO and wish.length() > 0.05:
		look = wish.normalized()
	if look != Vector3.ZERO:
		var target_yaw: float = atan2(-look.x, -look.z)
		var step: float = profile.turn_speed * delta
		rotation.y += clampf(angle_difference(rotation.y, target_yaw), -step, step)
	move_and_slide()


# --- 사격 ---

func _update_firing(delta: float, fire_allowed: bool) -> void:
	# 교전과 상관없이 시간은 흐른다 (재장전 진행·쿨다운)
	var los: bool = blackboard.can_see_target and fire_allowed and not _player.health.is_dead()
	var distance: float = global_position.distance_to(_player.global_position)
	# 조준은 시야각 안일 때만 (몸이 아직 덜 돌았으면 쏘지 않는다)
	if los:
		var to_player: Vector3 = _flat_dir(global_position, _player.global_position)
		var facing: Vector3 = Vector3(-global_basis.z.x, 0.0, -global_basis.z.z).normalized()
		if to_player != Vector3.ZERO and facing.dot(to_player) < 0.8:
			los = false
	if _gunner.update(delta, los, distance):
		_fire(distance)
	elif brain.state != AiBrain.State.COMBAT and brain.state != AiBrain.State.TAKE_COVER \
			and _gunner.rounds() < RELOAD_BELOW and not _gunner.is_reloading():
		_gunner.start_reload()   # 교전이 끝나면 슬그머니 재장전


func _fire(distance: float) -> void:
	var origin: Vector3 = eye_position()
	var aim: Vector3 = (_chest_point() - origin).normalized()
	var basis_aim: Basis = Basis.looking_at(aim, Vector3.UP if absf(aim.y) < 0.95 else Vector3.RIGHT)
	var spread: float = _gunner.spread_deg(distance) + _runtime.stats.get(WeaponStats.SPREAD, 1.0)
	var dir: Vector3 = FireMath.spread_direction(basis_aim, spread, _rng)
	var exclude: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * SHOOT_RANGE, SHOOT_MASK, exclude)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = origin + dir * SHOOT_RANGE
	if not hit.is_empty():
		end = hit["position"]
		var collider := hit["collider"] as Node
		if not (collider is EnemyAgent):   # 아군 사격은 막히기만 한다
			var target: HitTarget = HitTarget.find_for(collider)
			if target != null:
				target.apply_hit(_ammo, profile.damage_mult, _rng)
	_muzzle.visible = true
	_flash_left = FLASH_TIME
	_spawn_tracer(_muzzle.global_position, end)
	shot_fired.emit(self)
	if _director != null:
		_director.report_noise(global_position, AiPerception.shot_noise_radius(
				_runtime.stats.get(WeaponStats.LOUDNESS, 1.0)), self)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length < 0.5 or get_parent() == null:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	tracer.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	tracer.material_override = mat
	tracer.top_level = true
	get_parent().add_child(tracer)
	var dir: Vector3 = (to - from) / length
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	tracer.look_at_from_position((from + to) * 0.5, to, up)
	get_tree().create_timer(0.05).timeout.connect(tracer.queue_free)


# --- 피격·사망 ---

func _on_damaged(_result: DamageModel.HitResult) -> void:
	_body_mat.albedo_color = Color.WHITE
	_head_mat.albedo_color = Color.WHITE
	_hit_flash_left = HIT_FLASH_TIME
	if _player != null and not _dead and brain != null and brain.state != AiBrain.State.COMBAT:
		# 맞았는데 시야에 없다면 쏜 쪽(플레이어)을 향해 의심한다
		blackboard.heard_noise = true
		blackboard.noise_position = _player.global_position
		blackboard.last_known_position = _player.global_position
	_update_label()


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	collision_layer = LAYER_CORPSE
	velocity = Vector3.ZERO
	# 시체: 몸을 눕히고 바닥에 붙인다 (회전 중심은 발 → 반지름만큼 올림)
	_visual.rotation.x = -PI * 0.5
	_visual.position = Vector3(0.0, BODY_RADIUS, 0.0)
	_shape_node.rotation.x = -PI * 0.5
	_shape_node.position = Vector3(0.0, BODY_RADIUS, -BODY_HEIGHT * 0.5)
	_body_mat.albedo_color = CORPSE_COLOR
	_head_mat.albedo_color = CORPSE_COLOR.lightened(0.25)
	_body_mat.emission_enabled = false
	_head_mat.emission_enabled = false
	_body_mat.rim_enabled = false
	_head_mat.rim_enabled = false
	_muzzle.visible = false
	_label.position.y = 0.9
	_build_corpse_loot()
	_update_label()
	died.emit(self)


## 시체 루팅 그리드(6×5): 이 적의 소총(남은 탄 반영), 5.56 탄약 15~40발, 루팅 테이블 굴림.
func _build_corpse_loot() -> void:
	_loot_grid = ItemGrid.new(6, 5)
	var rifle: ItemInstance = _runtime.item
	rifle.found_in_raid = true
	var remaining: int = _gunner.rounds() if _gunner != null else 0
	rifle.magazine = Magazine.new(_ammo.caliber, MAG_SIZE)
	rifle.magazine.load_rounds(_ammo, remaining)
	_loot_grid.try_auto_place(rifle)
	var ammo_def: ItemDef = _authority.content.get_item(CombatLoadout.AMMO_556)
	if ammo_def != null:
		var stack: ItemInstance = _authority.create_item(ammo_def, _rng.randi_range(15, 40))
		stack.found_in_raid = true
		_loot_grid.try_auto_place(stack)
	if loot_table != null:
		loot_table.fill_grid(_loot_grid, _rng, _authority)
	_loot_key = _authority.register_container(_loot_grid, "%s 시체" % enemy_name)
