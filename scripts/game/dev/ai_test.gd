class_name AiTest
extends CombatTest
## M8 적 AI 테스트: 전투 테스트 사격장 + 순찰하는 적 3명 + 시체 루팅. 플레이어·HUD·터치·가방 구성은 CombatTest를 그대로 쓴다.
## 웹 스모크가 읽는 로그 (접두 "AI_TEST: "):
##   "AI_TEST: ready" / "AI_TEST: navmesh polys=<n>"
##   "AI_TEST: state <이름> <STATE>"            적 상태가 바뀔 때마다
##   "AI_TEST: enemy_shot <이름>"               적이 한 발 쏠 때마다
##   "AI_TEST: player_hit hp=<hp>"              플레이어가 맞았을 때
##   "AI_TEST: noise <반경>"                    플레이어 총소리만 (소음기를 달면 반경이 줄어든다)
##   "AI_TEST: enemy_dead <이름> loot=<키> items=<n>"
##   "AI_TEST: loot_open <키> items=<n>" / "AI_TEST: loot_close <키>"
##   "AI_TEST: player_dead"                     3초 뒤 씬을 다시 불러온다
## 개발 키(데스크톱): K = 가장 가까운 살아 있는 적을 즉시 처치하고 그 시체를 플레이어 앞 2 m로 옮긴다 (루팅 시험용 치트),
##                  F = 2.5 m 안·시선 앞쪽의 시체 루팅.

const AI_PREFIX: String = "AI_TEST: "
const AI_HINT: String = CombatTest.HINT + "  ·  F 루팅  ·  K 가까운 적 처치(개발)"
const CORPSE_DEV_DISTANCE: float = 2.0
const RESTART_DELAY: float = 3.0
const ENEMY_COUNT: int = 3
const NAV_CELL: float = 0.2

var _director: AiDirector
var _enemies: Array[EnemyAgent] = []
var _open_loot: StringName = &""
var _player_dead: bool = false
var _death_label: Label


func _hint_text() -> String:
	return AI_HINT


## 로그 줄 접두. 하위 씬(레이드)이 덮어쓴다.
func _log_prefix() -> String:
	return AI_PREFIX


func _post_setup() -> void:
	_director = AiDirector.new()
	add_child(_director)
	_director.bind_player(_player)
	_director.player_shot_noise.connect(func(radius: float) -> void: print(_log_prefix() + "noise %d" % roundi(radius)))
	_player.hit_target.damaged.connect(func(_result: DamageModel.HitResult) -> void:
		print(_log_prefix() + "player_hit hp=%d" % ceili(_player.health.hp)))
	_hud.interact_requested.connect(_try_loot)
	_death_label = Label.new()
	_death_label.text = "사망 — %d초 뒤 재시작" % int(RESTART_DELAY)
	_death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_label.add_theme_font_size_override("font_size", 40)
	_death_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	_death_label.add_theme_constant_override("outline_size", 10)
	_death_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_label.visible = false
	$UI.add_child(_death_label)
	_start_world()


## 내비메시를 굽고 적을 세운다. 굽기는 동기로 한다 (웹 빌드는 스레드가 없다).
func _start_world() -> void:
	await get_tree().process_frame
	var region := $Geometry as NavigationRegion3D
	# 에이전트 크기가 칸 크기의 배수가 되도록 지도와 내비메시의 칸을 0.2로 맞춘다 (경고 방지)
	var map: RID = region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, NAV_CELL)
	NavigationServer3D.map_set_cell_height(map, NAV_CELL)
	var navmesh := NavigationMesh.new()
	navmesh.cell_size = NAV_CELL
	navmesh.cell_height = NAV_CELL
	navmesh.agent_max_climb = NAV_CELL
	navmesh.agent_radius = 0.4
	navmesh.agent_height = 1.8
	navmesh.agent_max_slope = 40.0
	# CSG 상자를 직접 면(faces)으로 넘겨 굽는다: 렌더링 메시를 되읽지 않아 웹에서도 안전하고, 동기로 끝난다
	var source := NavigationMeshSourceGeometryData3D.new()
	var to_region: Transform3D = region.global_transform.affine_inverse()
	for child: Node in region.get_children():
		var box := child as CSGBox3D
		if box == null:
			continue
		var mesh := BoxMesh.new()
		mesh.size = box.size
		source.add_faces(mesh.get_faces(), to_region * box.global_transform)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	region.navigation_mesh = navmesh
	await get_tree().physics_frame
	await get_tree().physics_frame
	print(_log_prefix() + "navmesh polys=%d" % region.navigation_mesh.get_polygon_count())
	_spawn_enemies()
	await get_tree().process_frame
	print(_log_prefix() + "ready")


func _spawn_enemies() -> void:
	var routes: Node = $Routes
	for i: int in range(mini(ENEMY_COUNT, routes.get_child_count())):
		var points: Array[Vector3] = []
		for marker: Node in routes.get_child(i).get_children():
			points.append((marker as Marker3D).global_position)
		_spawn_enemy(i, points)


## 순찰 경로(points)의 첫 지점에 적 한 명을 세우고 AI를 시작한다.
func _spawn_enemy(index: int, points: Array[Vector3]) -> EnemyAgent:
	var enemy := EnemyAgent.new()
	enemy.enemy_name = "적%d" % (index + 1)
	enemy.loot_table = DemoLoot.build_table(_authority.content)
	add_child(enemy)
	enemy.global_position = points[0]
	if points.size() > 1:
		var heading: Vector3 = points[1] - points[0]
		enemy.rotation.y = atan2(-heading.x, -heading.z)
	enemy.setup(_authority, _rng, _player, points, AiProfile.new(), _director)
	enemy.died.connect(_on_enemy_died)
	enemy.shot_fired.connect(func(e: EnemyAgent) -> void: print(_log_prefix() + "enemy_shot " + e.enemy_name))
	enemy.state_changed.connect(_on_enemy_state)
	_enemies.append(enemy)
	return enemy


func _on_enemy_state(enemy: EnemyAgent, state: AiBrain.State) -> void:
	print(_log_prefix() + "state %s %s" % [enemy.enemy_name, String(AiBrain.State.keys()[state])])


func _on_enemy_died(enemy: EnemyAgent) -> void:
	print(_log_prefix() + "enemy_dead %s loot=%s items=%d" % [enemy.enemy_name, enemy.loot_key(), enemy.loot_item_count()])


# --- 루팅·상호작용 ---

## 상호작용 후보 목록 (하위 씬이 컨테이너·스위치를 더한다).
func _finder_containers() -> Array[LootContainer]:
	return []


func _finder_switches() -> Array[PowerLever]:
	return []


## 지금 상호작용할 수 있는 가장 가까운 대상 (시체·컨테이너·스위치). 없으면 null.
func _find_interactable() -> InteractionFinder.Target:
	var forward: Vector3 = -_player.camera.global_basis.z
	return InteractionFinder.find(_player.global_position, forward, _enemies, _finder_containers(), _finder_switches())


func _try_loot() -> void:
	if is_inventory_open() or _player_dead:
		return
	var target: InteractionFinder.Target = _find_interactable()
	if target != null:
		_interact(target)


## 대상과 상호작용한다. 기본은 컨테이너(시체) 열기. 하위 씬이 스위치 등을 더한다.
func _interact(target: InteractionFinder.Target) -> void:
	if target.key == &"":
		return
	if not _open_container(target.key):
		return
	var grid: ItemGrid = _authority.containers.get(target.key)
	var count: int = grid.get_items().size() if grid != null else 0
	print(_log_prefix() + "loot_open %s items=%d" % [target.key, count])
	set_inventory_open(true)


## 월드 컨테이너를 열고 열린 키를 기억한다. 실패하면 알림만 띄우고 false.
func _open_container(key: StringName) -> bool:
	var result: CommandResult = _authority.execute(OpenContainerCommand.new(key))
	if not result.ok:
		_hud.show_toast("열 수 없음")
		return false
	_open_loot = key
	return true


## 가방을 닫으면 열려 있던 월드 컨테이너도 닫는다.
func set_inventory_open(open: bool) -> void:
	super.set_inventory_open(open)
	if open or _open_loot == &"":
		return
	var key: StringName = _open_loot
	_open_loot = &""
	_authority.execute(CloseContainerCommand.new(key))
	print(_log_prefix() + "loot_close " + String(key))


# --- 개발 키·갱신 ---

func _input(event: InputEvent) -> void:
	super._input(event)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or is_inventory_open() or _player_dead:
		return
	if key.physical_keycode == KEY_K:
		_dev_kill_nearest()
	elif key.physical_keycode == KEY_F:
		_try_loot()


## [개발 치트] 가장 가까운 살아 있는 적을 죽이고, 시체를 플레이어 정면 2 m로 옮겨 바로 루팅해 볼 수 있게 한다.
func _dev_kill_nearest() -> void:
	var enemy: EnemyAgent = _director.nearest_living(_player.global_position)
	if enemy == null:
		return
	enemy.kill()
	var forward: Vector3 = -_player.global_basis.z
	forward.y = 0.0
	var spot: Vector3 = _player.global_position + forward.normalized() * CORPSE_DEV_DISTANCE
	enemy.place_corpse_at(Vector3(spot.x, _player.global_position.y, spot.z))


func _process(delta: float) -> void:
	super._process(delta)
	if not _player_dead and _player.health.is_dead():
		_on_player_dead()
	var target: InteractionFinder.Target = null if (is_inventory_open() or _player_dead) else _find_interactable()
	if target == null:
		_hud.set_interact("")
	else:
		_hud.set_interact(target.prompt if _touch.is_active() else "F  " + target.prompt)


func _on_player_dead() -> void:
	_player_dead = true
	print(_log_prefix() + "player_dead")
	set_inventory_open(false)
	_hud.set_interact("")
	_player.input.release_source(InputState.Source.KEYBOARD)
	_player.input.release_source(InputState.Source.TOUCH)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_death_label.visible = true
	get_tree().create_timer(RESTART_DELAY).timeout.connect(func() -> void: get_tree().reload_current_scene())
