class_name RaidController
extends AiTest
## M9 레이드 씬(산업단지) 루트. AiTest(전투 테스트 + 적 AI + 루팅 상호작용) 위에 얹는다:
## 맵 지오메트리·내비메시, 루팅 컨테이너 굴림, 수색 틱·소음·중단, 탈출 지점, RaidSession 흐름, 결과 화면.
## 웹 스모크가 읽는 로그 (접두 "RAID: "):
##   "RAID: geometry boxes=<n>" / "RAID: navmesh polys=<n>" / "RAID: containers=<n>" / "RAID: enemies=<n>" / "RAID: ready"
##   "RAID: open <키> <이름>"                  컨테이너를 열었다 (시체 포함)
##   "RAID: search_button at <x>,<y>"          열린 컨테이너의 수색/중단 버튼 중심 (창 좌표)
##   "RAID: search start <키>" / "RAID: revealed <키> <아이템 id>" / "RAID: search stop <키> <button|damage|fire|move|close>" /
##   "RAID: search complete <키>"
##   "RAID: take_hint item=<id> from=<x>,<y> to=<x>,<y>"   수색이 끝났을 때 첫 공개 아이템과 내 가방의 빈 자리 (창 좌표)
##   "RAID: take <아이템 id>"                  컨테이너에서 내 쪽으로 아이템이 옮겨졌다
##   "RAID: power_on" / "RAID: extract_enter <id>" / "RAID: extract_progress <id> <25|50|75>" / "RAID: extracted <id>"
##   "RAID: player_dead" / "RAID: results <EXTRACTED|KILLED|TIMED_OUT> value=<n> lost=<n>"
##   "RAID: results_buttons retry=<x>,<y> menu=<x>,<y>"
##   "RAID: quality <LOW|MID|HIGH>"              그래픽 품질 단계 (시작 때·바꿀 때)
##   "RAID: render draw_calls=<n> objects=<n> primitives=<n> fps=<n>"   5초마다 렌더 통계
##   "RAID: view <이름>"                          개발 시점으로 순간이동 (V)
## 개발 키(데스크톱): K 가까운 적 처치 · T 다음 탈출 지점으로 순간이동 · G 가장 가까운 안 연 컨테이너로 순간이동 ·
##                  P 전원 켜기 · F 열기/작동 · V 다음 시점(공장·내부·야적장…) · F2 그래픽 품질 순환 (터치는 네 손가락 동시 탭).
## (Q는 무기 전환이라 품질 키로 쓰지 않는다.)

const RAID_PREFIX: String = "RAID: "
const RAID_HINT: String = "WASD 이동  ·  좌클릭 사격  ·  Tab 가방  ·  F 열기  ·  개발: K 적 처치  T 탈출지점  G 상자  P 전원  V 시점  F2 품질"
const RESULTS_SCENE: PackedScene = preload("res://scenes/ui/raid_results.tscn")
const MENU_SCENE_PATH: String = "res://scenes/dev/dev_menu.tscn"
## 레이드 제한 시간 (초).
const RAID_SECONDS: float = 900.0
## 수색 소음: 반경 (m)과 최소 보고 간격 (초).
const SEARCH_NOISE_RADIUS: float = 8.0
const SEARCH_NOISE_INTERVAL: float = 0.5
## 가방을 연 자리에서 이만큼 벗어나면 수색이 중단된다.
const MOVE_INTERRUPT_DISTANCE: float = 0.5
const POWER_FLAG: StringName = &"power_on"
## G 키로 컨테이너 앞에 설 때의 거리 (m).
const TELEPORT_STAND_DISTANCE: float = 1.6
## 렌더 통계를 로그로 남기는 간격 (초).
const RENDER_LOG_INTERVAL: float = 5.0
## 터치로 품질을 넘기는 동시 터치 수.
const QUALITY_TOUCH_COUNT: int = 4

@onready var _map: IndustrialMap = $Map

var _session: RaidSession
var _world_ready: bool = false
var _ended: bool = false
var _flags: Dictionary = {}
var _tracker := ExtractionTracker.new()
var _active_zone: ExtractionZone = null
var _extract_milestone: int = 0
var _extract_cycle: int = 0
var _kills: int = 0
var _searched: Dictionary[StringName, bool] = {}
var _opened: Dictionary[StringName, bool] = {}
var _first_revealed: Dictionary[StringName, int] = {}
var _stop_reason: String = "button"
var _open_origin: Vector3 = Vector3.ZERO
var _noise_pending: bool = false
var _noise_cooldown: float = 0.0
var _results: RaidResults = null
var _extraction_text: String = ""
var _quality: GraphicsQuality
var _view_index: int = 0
var _render_timer: float = 0.0
var _render_frames: int = 0
var _touch_points: Dictionary[int, bool] = {}


func _hint_text() -> String:
	return RAID_HINT


func _log_prefix() -> String:
	return RAID_PREFIX


func _post_setup() -> void:
	_session = RaidSession.new(_authority.inventory)
	_session.start_loadout()
	_session.start_raid(RAID_SECONDS)
	_authority.events_emitted.connect(_on_authority_events)
	_setup_quality()
	_player.hit_target.damaged.connect(func(_result: DamageModel.HitResult) -> void: _interrupt_search("damage"))
	_player.weapons.shot_fired.connect(func(_ammo_id: StringName, _rounds: int) -> void: _interrupt_search("fire"))
	super._post_setup()


## 그래픽 품질 적용기를 달고 기기 기본 단계를 적용한다.
func _setup_quality() -> void:
	_quality = GraphicsQuality.new()
	_quality.name = "GraphicsQuality"
	add_child(_quality)
	_quality.setup($WorldEnvironment as WorldEnvironment, $Sun as DirectionalLight3D, get_viewport())
	_quality.apply(GraphicsQuality.detect_default())
	print(RAID_PREFIX + "quality " + GraphicsTier.tier_name(_quality.tier))


## [개발] 품질 단계를 다음으로 넘기고 토스트로 알린다.
func _cycle_quality() -> void:
	var tier: GraphicsTier.Tier = _quality.cycle()
	var tier_text: String = GraphicsTier.tier_name(tier)
	_hud.show_toast("그래픽 품질: " + tier_text)
	print(RAID_PREFIX + "quality " + tier_text)


## 내비메시를 굽고 컨테이너·적·탈출 지점을 세운다 (굽기는 동기: 웹 빌드는 스레드가 없다).
func _start_world() -> void:
	await get_tree().process_frame
	print(RAID_PREFIX + "geometry boxes=%d" % _map.box_count)
	var polys: int = _map.bake_navmesh()
	await get_tree().physics_frame
	await get_tree().physics_frame
	print(RAID_PREFIX + "navmesh polys=%d" % polys)
	for container: LootContainer in _map.containers:
		container.roll_contents(_authority, _rng)
	print(RAID_PREFIX + "containers=%d" % _map.containers.size())
	_spawn_raid_enemies()
	print(RAID_PREFIX + "enemies=%d" % _enemies.size())
	_setup_extraction()
	_world_ready = true
	await get_tree().process_frame
	print(RAID_PREFIX + "ready")


func _spawn_raid_enemies() -> void:
	var nav_map: RID = _map.region.get_navigation_map()
	for i: int in range(_map.enemy_routes.size()):
		var points: Array[Vector3] = []
		for point: Vector3 in _map.enemy_routes[i]:
			points.append(NavigationServer3D.map_get_closest_point(nav_map, point))
		_spawn_enemy(i, points)


func _setup_extraction() -> void:
	for zone: ExtractionZone in _map.extraction_zones:
		zone.player_entered.connect(_on_zone_entered)
		zone.player_exited.connect(_on_zone_exited)
	_refresh_extraction_hint()


# --- 상호작용 ---

func _finder_containers() -> Array[LootContainer]:
	return _map.containers


func _finder_switches() -> Array[PowerLever]:
	var levers: Array[PowerLever] = []
	if _map.lever != null:
		levers.append(_map.lever)
	return levers


func _interact(target: InteractionFinder.Target) -> void:
	if target.kind == InteractionFinder.Kind.SWITCH:
		_set_power()
		return
	if not _open_container(target.key):
		return
	_opened[target.key] = true
	_open_origin = _player.global_position
	print(RAID_PREFIX + "open %s %s" % [target.key, _authority.container_titles.get(target.key, "")])
	set_inventory_open(true)
	_log_search_button.call_deferred(target.key)


## 열린 컨테이너의 수색 버튼 좌표를 로그로 남긴다 (레이아웃이 잡힌 뒤에).
func _log_search_button(key: StringName) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var rect: Rect2 = _screen.search_button_rect(key)
	if rect.has_area():
		print(RAID_PREFIX + "search_button at " + _win_rect_str(rect))


func set_inventory_open(open: bool) -> void:
	if not open and _open_loot != &"":
		_stop_reason = "close"
	super.set_inventory_open(open)
	_stop_reason = "button"


# --- 전원 ---

func _set_power() -> void:
	if bool(_flags.get(POWER_FLAG, false)):
		return
	_flags[POWER_FLAG] = true
	if _map.lever != null:
		_map.lever.activate()
	for zone: ExtractionZone in _map.extraction_zones:
		if zone.point.required_flag == POWER_FLAG:
			zone.set_open(true)
	_hud.show_toast("전원이 켜졌습니다")
	_refresh_extraction_hint()
	print(RAID_PREFIX + "power_on")


func _refresh_extraction_hint() -> void:
	var names: Array[String] = []
	for zone: ExtractionZone in _map.extraction_zones:
		var closed: bool = zone.point.required_flag != &"" and not bool(_flags.get(zone.point.required_flag, false))
		names.append(zone.display_name + ("(전원 필요)" if closed else ""))
	_extraction_text = " · ".join(names)



# --- 탈출 ---

func _on_zone_entered(zone: ExtractionZone) -> void:
	if _ended:
		return
	_active_zone = zone
	_tracker.enter(zone.point)
	_extract_milestone = 0
	print(RAID_PREFIX + "extract_enter " + String(zone.point.id))


func _on_zone_exited(zone: ExtractionZone) -> void:
	if zone != _active_zone:
		return
	_tracker.leave()
	_active_zone = null
	zone.set_status("")
	_hud.set_extract_progress(0, -1.0)


func _update_extraction(delta: float) -> void:
	if _active_zone == null or _ended:
		return
	var zone: ExtractionZone = _active_zone
	var open: bool = zone.point.required_flag == &"" or bool(_flags.get(zone.point.required_flag, false))
	var done: bool = _tracker.tick(delta, _flags)
	if not open:
		_extract_milestone = 0
		zone.set_status("")
		_hud.set_extract_progress(0, -1.0)
		return
	var ratio: float = _tracker.progress()
	var left: int = ceili(zone.point.wait_time * (1.0 - ratio))
	zone.set_status("탈출 중 %d초" % left)
	_hud.set_extract_progress(left, ratio)
	var quarter: int = mini(int(ratio * 4.0), 3)
	while _extract_milestone < quarter:
		_extract_milestone += 1
		print(RAID_PREFIX + "extract_progress %s %d" % [zone.point.id, _extract_milestone * 25])
	if done:
		print(RAID_PREFIX + "extracted " + String(zone.point.id))
		_session.extract()
		_finish_raid()


# --- 수색 ---

func _on_authority_events(events: Array[DomainEvent]) -> void:
	for event: DomainEvent in events:
		match event.type:
			DomainEvent.ITEM_REVEALED:
				var key: StringName = event.data["container"]
				var item_id: int = event.data["item_id"]
				if not _first_revealed.has(key):
					_first_revealed[key] = item_id
				print(RAID_PREFIX + "revealed %s %d" % [key, item_id])
			DomainEvent.SEARCH_CHANGED:
				_on_search_changed(event)
			DomainEvent.ITEM_MOVED:
				var from: Dictionary = event.data["from"]
				var to: Dictionary = event.data["to"]
				if Inventory.is_external_key(from.get("container", &"")) and not Inventory.is_external_key(to.get("container", &"")):
					print(RAID_PREFIX + "take %d" % int(event.data["item_id"]))


func _on_search_changed(event: DomainEvent) -> void:
	var key: StringName = event.data["container"]
	if bool(event.data["searching"]):
		print(RAID_PREFIX + "search start " + String(key))
	elif bool(event.data["complete"]):
		_searched[key] = true
		print(RAID_PREFIX + "search complete " + String(key))
		_log_take_hint.call_deferred(key)
	else:
		print(RAID_PREFIX + "search stop %s %s" % [key, _stop_reason])


## 수색이 끝난 컨테이너의 첫 공개 아이템 위치와 내 가방의 빈 자리를 창 좌표로 남긴다 (스모크가 끌어다 놓는다).
func _log_take_hint(key: StringName) -> void:
	await get_tree().process_frame
	var item_id: int = int(_first_revealed.get(key, 0))
	var item: ItemInstance = _authority.inventory.get_item(item_id)
	if item == null or item.container_key != key or not is_inventory_open():
		return
	var from: Rect2 = _screen.item_global_rect(item_id)
	var keys: Array[StringName] = []
	for i: int in range(Inventory.POCKET_COUNT):
		keys.append(Inventory.pocket_key(i))
	for slot: EquipmentSlots.Slot in [EquipmentSlots.Slot.RIG, EquipmentSlots.Slot.BACKPACK]:
		var holder: ItemInstance = _authority.inventory.equipment.get_item(slot)
		if holder != null:
			for g: int in range(holder.grids.size()):
				keys.append(Inventory.item_grid_key(holder.id, g))
	for target_key: StringName in keys:
		var grid: ItemGrid = _authority.inventory.get_grid(target_key)
		var placement: ItemGrid.Placement = grid.find_free_placement(item) if grid != null else null
		if placement == null:
			continue
		var rect: Rect2 = _screen.visible_cell_rect(target_key, placement.cell, item.size_for(placement.rotated))
		if rect.has_area():
			print(RAID_PREFIX + "take_hint item=%d from=%s to=%s" % [item_id, _win_rect_str(from), _win_rect_str(rect)])
			return
	print(RAID_PREFIX + "take_hint none")


## 열려 있는 컨테이너의 수색을 중단한다 (사격·피격·이동).
func _interrupt_search(reason: String) -> void:
	if _open_loot == &"" or _ended:
		return
	var search: SearchState = _authority.searches.get(_open_loot)
	if search == null or not search.searching:
		return
	_stop_reason = reason
	_authority.execute(SearchContainerCommand.new(_open_loot, false))
	_stop_reason = "button"
	_hud.show_toast("수색 중단")
	_screen.show_toast("수색 중단")


# --- 매 프레임 ---

func _process(delta: float) -> void:
	super._process(delta)
	if not _world_ready or _ended:
		return
	var noise: float = _authority.tick_searches(delta)
	if noise > 0.0:
		_noise_pending = true
	_noise_cooldown -= delta
	if _noise_pending and _noise_cooldown <= 0.0:
		_noise_pending = false
		_noise_cooldown = SEARCH_NOISE_INTERVAL
		_director.report_noise(_player.global_position, SEARCH_NOISE_RADIUS, _player)
	if _open_loot != &"" and _player.global_position.distance_to(_open_origin) > MOVE_INTERRUPT_DISTANCE:
		_interrupt_search("move")
	_log_render_stats(delta)
	_session.tick(delta)
	if _session.state == RaidSession.State.DEAD:
		_finish_raid()
		return
	_update_extraction(delta)
	_hud.set_raid_info(RaidSummary.format_remaining(_session.time_limit - _session.elapsed), _extraction_text)


## 5초마다 렌더 통계(그리기 호출·객체·삼각형·프레임)를 로그로 남긴다.
func _log_render_stats(delta: float) -> void:
	_render_timer += delta
	_render_frames += 1
	if _render_timer < RENDER_LOG_INTERVAL:
		return
	var fps: int = roundi(float(_render_frames) / _render_timer)
	var draw_calls: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	var primitives: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print(RAID_PREFIX + "render draw_calls=%d objects=%d primitives=%d fps=%d" % [draw_calls, objects, primitives, fps])
	_render_timer = 0.0
	_render_frames = 0


func _on_enemy_died(enemy: EnemyAgent) -> void:
	super._on_enemy_died(enemy)
	_kills += 1


func _on_player_dead() -> void:
	_player_dead = true
	print(RAID_PREFIX + "player_dead")
	_session.die()
	_finish_raid()


# --- 결과 ---

func _finish_raid() -> void:
	if _ended:
		return
	_ended = true
	_session.show_results()
	set_inventory_open(false)
	_hud.set_interact("")
	_hud.set_extract_progress(0, -1.0)
	_player.input.release_source(InputState.Source.KEYBOARD)
	_player.input.release_source(InputState.Source.TOUCH)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_touch.set_active(false)
	_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var report: RaidSummary.Report = RaidSummary.build_report(_session, _kills, _searched.size())
	var outcome_name: String = String(RaidSession.Outcome.keys()[report.outcome])
	print(RAID_PREFIX + "results %s value=%d lost=%d" % [outcome_name, report.value, report.lost_count])
	_results = RESULTS_SCENE.instantiate() as RaidResults
	$UI.add_child(_results)
	_results.show_report(report)
	_results.retry_requested.connect(func() -> void: get_tree().reload_current_scene())
	_results.menu_requested.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE_PATH))
	_log_result_buttons.call_deferred()


func _log_result_buttons() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print(RAID_PREFIX + "results_buttons retry=%s menu=%s" % [_win_rect_str(_results.retry_button_rect()),
			_win_rect_str(_results.menu_button_rect())])


# --- 개발 키 ---

func _input(event: InputEvent) -> void:
	super._input(event)
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_touch_points[touch.index] = true
			if _touch_points.size() == QUALITY_TOUCH_COUNT and _world_ready and not _ended and not is_inventory_open():
				_cycle_quality()
		else:
			_touch_points.erase(touch.index)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or is_inventory_open() or _player_dead or _ended or not _world_ready:
		return
	match key.physical_keycode:
		KEY_T:
			_dev_teleport_to_extraction()
		KEY_G:
			_dev_teleport_to_container()
		KEY_P:
			_set_power()
		KEY_V:
			_dev_next_view()
		KEY_F2:
			_cycle_quality()


## [개발] 다음 개발 시점(맵의 view_points)으로 순간이동해 정해 둔 방향을 바라본다 (스크린샷용).
func _dev_next_view() -> void:
	if _map.view_points.is_empty():
		return
	var view: Dictionary = _map.view_points[_view_index % _map.view_points.size()]
	_view_index += 1
	# 스크린샷 도중 죽지 않게 체력을 채우고 출혈을 멈춘다 (개발 전용)
	_player.health.stop_bleeding()
	_player.health.heal(1000.0)
	_teleport_player(view["pos"] as Vector3)
	_player.set_look(deg_to_rad(float(view["yaw_deg"])), deg_to_rad(float(view["pitch_deg"])))
	print(RAID_PREFIX + "view " + String(view["name"]))


## [개발] 다음 탈출 지점 위로 순간이동 (정문 → 철길 → 화물 엘리베이터 순).
func _dev_teleport_to_extraction() -> void:
	var zones: Array[ExtractionZone] = _map.extraction_zones
	var zone: ExtractionZone = zones[_extract_cycle % zones.size()]
	_extract_cycle += 1
	_teleport_player(zone.global_position + Vector3(0.0, 0.1, 0.0))


## [개발] 아직 열지 않은 가장 가까운 컨테이너 앞으로 순간이동해 그쪽을 바라본다.
func _dev_teleport_to_container() -> void:
	var best: LootContainer = null
	var best_dist: float = INF
	for container: LootContainer in _map.containers:
		if _opened.has(container.loot_key):
			continue
		var dist: float = container.global_position.distance_to(_player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = container
	if best == null:
		return
	var nav_map: RID = _map.region.get_navigation_map()
	var base: Vector3 = best.global_position
	var stand: Vector3 = base + Vector3(0.0, 0.1, TELEPORT_STAND_DISTANCE)
	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0 + PI * 0.5
		var wanted: Vector3 = base + Vector3(cos(angle), 0.0, sin(angle)) * TELEPORT_STAND_DISTANCE
		var snapped: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, wanted)
		var flat: float = Vector2(snapped.x - wanted.x, snapped.z - wanted.z).length()
		if flat < 0.5 and absf(snapped.y - base.y) < 0.4:
			stand = Vector3(wanted.x, base.y + 0.1, wanted.z)
			break
	_teleport_player(stand)
	var look: Vector3 = base - stand
	_player.rotation.y = atan2(-look.x, -look.z)


func _teleport_player(position_: Vector3) -> void:
	_player.global_position = position_
	_player.velocity = Vector3.ZERO
