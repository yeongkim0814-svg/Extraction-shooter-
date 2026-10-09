class_name ZoneFactoryBlock
extends RefCounted
## 공장 본관 구역 (공장 홀 동쪽·북쪽): "03" 본관 블록 + 부속동, 굴뚝 4개와 연도, 홀 뒤뜰 탱크·컨테이너, 부속동 옆 큰 저장 탱크.
## 빛 정체성 (ART.md 11.6): 탱크 구역은 램프 없이 바깥 연무 속 역광 실루엣, 본관 바깥은 벽등 몇 개만.
## 위치·크기·충돌은 옛 IndustrialFactory(_main_block/_stacks/_north_yard)와 같다. 엄폐·루팅·연기는 맵 코드가 그대로 둔다.

const MAIN := Rect2(8.0, -80.0, 28.0, 28.0)
const MAIN_H: float = 24.0
const ANNEX := Rect2(36.0, -76.0, 14.0, 20.0)
const ANNEX_H: float = 15.0
## 굴뚝 (x, 높이): 옛 _stacks와 같다. z = -84.
const STACKS: Array[Vector2] = [Vector2(12.0, 46.0), Vector2(20.0, 38.0), Vector2(28.0, 52.0), Vector2(34.0, 34.0)]
const STACK_Z: float = -84.0


static func build(zb: ZoneBuilder) -> void:
	zb.cell_m = 32.0
	_main_block(zb)
	_annex(zb)
	_stacks(zb)
	_north_yard(zb)
	_big_tank(zb)
	# 본관 앞 콘크리트 앞마당, 뒤뜰 콘크리트, 큰 탱크 받침
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(6.0, -52.4, 46.0, 4.6))
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(-45.0, -88.0, 38.0, 11.0))
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(51.0, -81.0, 22.0, 22.0))


static func _main_block(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("block_main")
	ZoneParts.block_building(kb, MAIN, MAIN_H)
	# 가로 띠: 벽돌 줄 (옛 y = 11, 21) + 위
	ZoneParts.belt(kb, MAIN, 10.9)
	ZoneParts.belt(kb, MAIN, 20.9)
	# 남쪽 면 (바깥 +Z, 앞마당 쪽) 창 두 줄: 줄마다 6개
	var face: float = MAIN.end.y
	for y: float in [3.7, 6.9]:
		ZoneParts.window_row(kb, Vector3(12.0, y, face), Vector3(4.0, 0.0, 0.0), 6, 0.0)
	# 북쪽 면 (뒤뜰 쪽) 창 한 줄
	ZoneParts.window_row(kb, Vector3(12.0, 5.3, MAIN.position.y), Vector3(4.0, 0.0, 0.0), 6, 180.0)
	# 옥상 설비
	for rect: Rect2 in [Rect2(10, -78, 4, 4), Rect2(18, -70, 6, 3), Rect2(28, -62, 5, 5), Rect2(12, -60, 3, 3)]:
		ZoneParts.rooftop_unit(kb, rect, MAIN_H, 2.0)
	# 벽을 타고 오르는 수직 배관 세 줄 (창 사이 기둥 자리) + 이음 플랜지
	for x: float in [13.7, 14.3, 30.0]:
		var pid: StringName = KitMaterials.PIPE_RED if x < 20.0 else KitMaterials.PIPE_TEAL
		kb.cylinder(pid, KitParts.at(Vector3(x, 11.0, face + 0.3)), 0.22, 22.0, 10, 0.0, true, false)
		var fy: float = 5.5
		while fy < 22.0:
			kb.cylinder(KitMaterials.PIPE_JOINT, KitParts.at(Vector3(x, fy, face + 0.3)), 0.31, 0.1, 10, 0.0, false, false)
			fy += 5.5
		kb.block(KitMaterials.FLAT_METAL, Vector3(x, 0.0, face + 0.3), Vector3(0.5, 0.2, 0.5), 0.0, false)
	# 바깥 캣워크 (장식, 높이 9.2) + 받침 사선
	var x: float = 12.0
	while x < 34.0:
		zb.place_at(&"catwalk_4m", Vector3(x, 9.2, face + 0.9))
		x += 4.0
	var sk: KitBuild = zb.custom("block_catwalk_supports")
	for sx: float in [10.2, 16.0, 22.0, 28.0, 33.8]:
		sk.strut(KitMaterials.BEAM_YELLOW, Vector3(sx, 9.0, face + 1.4), Vector3(sx, 5.0, face + 0.05), 0.12)
		sk.block(KitMaterials.BEAM_YELLOW, Vector3(sx - 0.06, 8.8, face), Vector3(0.12, 0.2, 1.5), 0.0, false)
	# 본관 앞 벽등 둘 (창 사이 기둥)
	zb.place_at(&"lamp_wall", Vector3(18.0, 2.3, face))
	zb.place_at(&"lamp_wall", Vector3(26.0, 2.3, face))


static func _annex(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("block_annex")
	ZoneParts.block_building(kb, ANNEX, ANNEX_H, 0.0, KitMaterials.FLAT_CONCRETE_DARK)
	ZoneParts.belt(kb, ANNEX, 10.9)
	# 남쪽 면 창 두 줄 (옛 줄 높이), 동쪽 면 창 한 줄
	for y: float in [3.7, 6.9]:
		ZoneParts.window_row(kb, Vector3(39.0, y, ANNEX.end.y), Vector3(4.0, 0.0, 0.0), 3, 0.0)
	ZoneParts.window_row(kb, Vector3(ANNEX.end.x, 5.3, -70.0), Vector3(0.0, 0.0, 4.0), 3, 90.0)
	for rect: Rect2 in [Rect2(40, -72, 3, 3)]:
		ZoneParts.rooftop_unit(kb, rect, ANNEX_H, 1.6)
	zb.place_at(&"lamp_wall", Vector3(41.0, 2.3, ANNEX.end.y))


## 굴뚝 넷 + 위쪽 연도 (옛: 높이 46/38/52/34, 밑 반지름 2.3 -> 위 1.4, 셋째는 빨강·흰 띠 꼭대기 16 m).
static func _stacks(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("block_stacks")
	for i: int in range(STACKS.size()):
		var spec: Vector2 = STACKS[i]
		ZoneParts.smokestack(kb, Vector3(spec.x, 0.0, STACK_Z), spec.y, 2.3, 1.4, 14.0, 16.0 if i == 2 else 0.0, 3.8, 8.0)
	# 굴뚝을 잇는 가로 연도 (큰 관 + 작은 관) + 이음·받침
	var cx: float = (12.0 + 34.0) * 0.5
	KitParts.cyl_x(kb, KitMaterials.PIPE_RED, Vector3(cx, 8.0, -82.0), 0.8, 22.0, 12)
	KitParts.cyl_x(kb, KitMaterials.PIPE_TEAL, Vector3(cx, 11.0, -81.0), 0.5, 22.0, 10)
	for x: float in [16.0, 24.0, 31.0]:
		KitParts.cyl_x(kb, KitMaterials.PIPE_JOINT, Vector3(x, 8.0, -82.0), 1.05, 0.12, 12)
		KitParts.cyl_x(kb, KitMaterials.PIPE_JOINT, Vector3(x, 11.0, -81.0), 0.72, 0.1, 10)
		kb.block(KitMaterials.FLAT_METAL, Vector3(x + 0.8, 0.0, -81.6), Vector3(0.3, 7.2, 0.3), 0.0, false)


## 홀 북쪽 뒤뜰: 세로 탱크 둘 (옛 지름 8 x 높이 9, 충돌 7.2), 이어 주는 관, 청록 컨테이너, 드럼통.
static func _north_yard(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("block_north_yard")
	for x: float in [-30.0, -20.0]:
		ZoneParts.tank(kb, Vector3(x, 0.0, -82.0), 4.0, 9.0, KitMaterials.FLAT_METAL, 22, KitMaterials.BAND_RED, 30.0 if x < -25.0 else -30.0, 7.2)
	KitParts.cyl_x(kb, KitMaterials.PIPE_TEAL, Vector3(-25.0, 7.0, -82.0), 0.35, 2.4, 10)
	for x: float in [-25.9, -24.1]:
		KitParts.cyl_x(kb, KitMaterials.PIPE_JOINT, Vector3(x, 7.0, -82.0), 0.5, 0.08, 10)
	ZoneProps.container(zb, -38.0, -82.5, &"container_20ft_teal", 0, true)
	ZoneProps.barrels(zb, Vector3(-14.0, 0.0, -80.0), 3)


## 부속동 옆 큰 저장 탱크 (옛 반지름 9 x 높이 13, 충돌 17).
static func _big_tank(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("block_big_tank")
	ZoneParts.tank(kb, Vector3(62.0, 0.0, -70.0), 9.0, 13.0, KitMaterials.FLAT_TANK_WHITE, 28, KitMaterials.BAND_RED, 200.0, 17.0)
