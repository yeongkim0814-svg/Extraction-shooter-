class_name ZoneFactoryHall
extends RefCounted
## 공장 홀 구역 (ART.md 11.6: 천창 빛줄기 + 따뜻한 나트륨 램프). 외곽·출입구 위치는 M9 게임플레이 배치(IndustrialFactory)와 같다.
##   - 벽: 4 m 모듈 두 단 (아래 = 출입구·벽, 위 = 높은 창 띠), 모서리 기둥. 높이 8 m.
##   - 지붕: 4 m 판 + 가운데 줄 천창(유리 한 칸 빠짐 -> 빛줄기), 8 m 철골 기둥 두 줄과 보.
##   - 안: 북쪽 벽 캣워크(높이 4 m) + 두 단 강철 계단, 천장 크레인 레일, 소품 (엄폐·루팅 위치는 맵 코드가 그대로 둔다).
## 좌표는 맵 좌표 (IndustrialFactory.HALL_*).

const X0: float = IndustrialFactory.HALL_X0
const X1: float = IndustrialFactory.HALL_X1
const Z0: float = IndustrialFactory.HALL_Z0
const Z1: float = IndustrialFactory.HALL_Z1
const ROW_H: float = 4.0
const HALL_H: float = 8.0
## 캣워크 바닥 높이 (계단 두 단 = 4 m).
const CATWALK_Y: float = 4.0
const CATWALK_Z: float = -74.6
const COLUMN_XS: Array[float] = [-40.0, -28.0, -16.0, -4.0]
const COLUMN_ZS: Array[float] = [-56.0, -68.0]


static func build(zb: ZoneBuilder) -> void:
	_walls(zb)
	_roof(zb)
	_structure(zb)
	_catwalk(zb)
	_props(zb)
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(X0, Z0, X1 - X0, Z1 - Z0))


## 벽 한 줄: a에서 b로 4 m 모듈. lower = 위치(가운데 좌표, 벽 방향 축) -> 부품. 위 단은 창·벽 번갈아.
static func _wall_line(zb: ZoneBuilder, a: Vector3, b: Vector3, yaw: float, lower: Dictionary[int, StringName], upper_offset: int) -> void:
	var dir: Vector3 = (b - a).normalized()
	var count: int = int(round((b - a).length() / 4.0))
	for i: int in range(count):
		var p: Vector3 = a + dir * (4.0 * float(i) + 2.0)
		var along: int = int(round(p.x if absf(dir.x) > 0.5 else p.z))
		zb.place_at(lower.get(along, &"wall_4m"), Vector3(p.x, 0.0, p.z), yaw)
		var upper: StringName = &"wall_4m_window" if (i + upper_offset) % 2 == 0 else &"wall_4m"
		zb.place_at(upper, Vector3(p.x, ROW_H, p.z), yaw)


static func _walls(zb: ZoneBuilder) -> void:
	# 남쪽(정면, 바깥 +Z): 큰 출입구 셋 (x = -34, -18, -2), 동쪽 끝은 무너진 벽
	_wall_line(zb, Vector3(X0, 0, Z1), Vector3(X1, 0, Z1), 0.0,
			{-34: &"wall_4m_shutter_open", -18: &"wall_4m_shutter_open", -2: &"wall_4m_shutter_open", 6: &"wall_4m_damaged",
			-26: &"wall_4m_door"}, 0)
	# 북쪽(바깥 -Z): 뒤뜰로 나가는 출입구 (x = -30)
	_wall_line(zb, Vector3(X0, 0, Z0), Vector3(X1, 0, Z0), 180.0, {-30: &"wall_4m_shutter_open", -10: &"wall_4m_door"}, 1)
	# 서쪽(바깥 -X): 출입구 (z = -54)
	_wall_line(zb, Vector3(X0, 0, Z0), Vector3(X0, 0, Z1), -90.0, {-54: &"wall_4m_shutter_open"}, 0)
	# 동쪽(바깥 +X): 본관과 붙은 쪽, 막힌 벽 + 반쯤 열린 셔터 하나
	_wall_line(zb, Vector3(X1, 0, Z0), Vector3(X1, 0, Z1), 90.0, {-62: &"wall_4m_shutter"}, 1)
	for c: Vector2 in [Vector2(X0, Z0), Vector2(X1, Z0), Vector2(X0, Z1), Vector2(X1, Z1)]:
		zb.place_at(&"wall_corner", Vector3(c.x, 0.0, c.y))
		zb.place_at(&"wall_corner", Vector3(c.x, ROW_H, c.y))


## 지붕: 4 m 판, 가운데 줄(z = -62)은 천창 (빛줄기가 들어오는 빠진 유리).
static func _roof(zb: ZoneBuilder) -> void:
	var x: float = X0 + 2.0
	while x < X1:
		var z: float = Z0 + 2.0
		while z < Z1:
			var sky: bool = absf(z + 62.0) < 0.1 and posmod(int(round(x)), 8) == 2
			zb.place_at(&"skylight_4m" if sky else &"roof_panel_4m", Vector3(x, HALL_H, z))
			z += 4.0
		x += 4.0


## 8 m 철골 기둥 두 줄 + 기둥 위 길이 방향 보 + 4 m마다 가로 보 + 천장 크레인 레일.
static func _structure(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("hall_structure")
	for z: float in COLUMN_ZS:
		for x: float in COLUMN_XS:
			_h_column(kb, Vector3(x, 0.0, z), HALL_H - 0.4)
		# 길이 방향 보 (기둥 위)
		kb.box(KitMaterials.BEAM_TEAL, Transform3D(Basis.IDENTITY, Vector3((X0 + X1) * 0.5, HALL_H - 0.25, z)),
				Vector3(X1 - X0 - 0.4, 0.5, 0.3), 0.0, false)
	# 가로 보 (지붕 판 아래, 4 m 간격)
	var x: float = X0 + 4.0
	while x < X1 - 0.1:
		kb.box(KitMaterials.BEAM_TEAL, Transform3D(Basis.IDENTITY, Vector3(x, HALL_H - 0.18, (Z0 + Z1) * 0.5)),
				Vector3(0.2, 0.36, Z1 - Z0 - 0.4), 0.0, false)
		x += 4.0
	# 천장 크레인: 길이 방향 레일 두 줄 (z = -60.4 / -63.6) + 다리(교량) + 트롤리 + 늘어진 훅
	for z: float in [-60.4, -63.6]:
		kb.box(KitMaterials.BEAM_YELLOW, Transform3D(Basis.IDENTITY, Vector3((X0 + X1) * 0.5, 6.6, z)),
				Vector3(X1 - X0 - 0.6, 0.35, 0.25), 0.0, false)
	kb.box(KitMaterials.BEAM_YELLOW, Transform3D(Basis.IDENTITY, Vector3(-16.0, 6.95, -62.0)), Vector3(1.0, 0.45, 4.2), 0.03, false)
	kb.box(KitMaterials.METAL_CHIPPED, Transform3D(Basis.IDENTITY, Vector3(-16.0, 6.5, -62.0)), Vector3(1.2, 0.5, 1.2), 0.03, false)
	kb.box(KitMaterials.FLAT_METAL, Transform3D(Basis.IDENTITY, Vector3(-16.0, 5.2, -62.0)), Vector3(0.04, 2.1, 0.04), 0.0, false)
	kb.box(KitMaterials.BEAM_YELLOW, Transform3D(Basis.IDENTITY, Vector3(-16.0, 4.05, -62.0)), Vector3(0.45, 0.3, 0.25), 0.02, false)


## H 단면 기둥 (바닥판·머리판 포함). 충돌 0.4 x h x 0.4.
static func _h_column(kb: KitBuild, base: Vector3, h: float) -> void:
	kb.block(KitMaterials.METAL_PLATE, base, Vector3(0.6, 0.05, 0.6), 0.0, false)
	for sz: float in [-1.0, 1.0]:
		kb.block(KitMaterials.BEAM_TEAL, base + Vector3(0.0, 0.05, sz * 0.17), Vector3(0.36, h - 0.05, 0.035), 0.0, false)
	kb.block(KitMaterials.BEAM_TEAL, base + Vector3(0.0, 0.05, 0.0), Vector3(0.035, h - 0.05, 0.3), 0.0, false)
	kb.collide_box(Transform3D(Basis.IDENTITY, base + Vector3(0.0, h * 0.5, 0.0)), Vector3(0.4, h, 0.4))


## 북쪽 벽 캣워크 (x -43..-11, 높이 4 m) + 서쪽 끝 두 단 계단 (남 -> 북으로 오른다).
static func _catwalk(zb: ZoneBuilder) -> void:
	var x: float = -42.0
	while x < -11.0:
		zb.place_at(&"catwalk_4m", Vector3(x + 2.0, CATWALK_Y, CATWALK_Z))
		x += 4.0
	# 계단: 원점 = 아래 앞쪽, +Z로 오른다 -> 180도 돌려 -Z(북)로 오르게. 한 단 = 2 m 상승, 수평 약 3.9 m (끝 계단참 포함)
	var sx: float = -41.4
	zb.place_at(&"stairs_steel_2m", Vector3(sx, 0.0, -66.2), 180.0)
	zb.place_at(&"stairs_steel_2m", Vector3(sx, 2.0, -70.1), 180.0)
	# 계단 받침 (두 번째 단 아래 기둥)
	var kb: KitBuild = zb.custom("hall_stair_posts")
	for z: float in [-70.1, -73.9]:
		for dx: float in [-0.45, 0.45]:
			kb.block(KitMaterials.BEAM_YELLOW, Vector3(sx + dx, 0.0, z), Vector3(0.1, 2.0, 0.1), 0.0, false)
	# 캣워크 받침 기둥 (8 m 간격)
	x = -42.0
	while x <= -11.0:
		for dz: float in [-0.5, 0.5]:
			kb.block(KitMaterials.BEAM_YELLOW, Vector3(x, 0.0, CATWALK_Z + dz), Vector3(0.12, CATWALK_Y - 0.05, 0.12), 0.0, false)
		x += 8.0


## 소품: 구워질 정적 장식만 (엄폐·루팅 상자는 맵 코드가 둔다). 램프는 지붕 보에 매단다.
static func _props(zb: ZoneBuilder) -> void:
	for pos: Vector3 in [Vector3(-36, HALL_H - 0.4, -58), Vector3(-24, HALL_H - 0.4, -66), Vector3(-12, HALL_H - 0.4, -57),
			Vector3(-2, HALL_H - 0.4, -68), Vector3(-26, HALL_H - 0.4, -53), Vector3(-38, HALL_H - 0.4, -71)]:
		zb.place_at(&"lamp_sodium", pos)
	zb.place_at(&"lamp_emergency", Vector3(-43.6, 2.6, -60.0), 90.0)
	zb.place_at(&"electrical_cabinet", Vector3(7.4, 0.0, -56.0), -90.0)
	zb.place_at(&"electrical_cabinet", Vector3(7.4, 0.0, -57.0), -90.0)
	zb.place_at(&"cable_tray_4m", Vector3(5.8, 6.2, -56.5), 90.0)
	zb.place_at(&"fire_extinguisher", Vector3(-43.6, 0.0, -57.0), 90.0)
	zb.place_at(&"rubble_small", Vector3(5.0, 0.0, -49.5), 20.0)
	zb.place_at(&"rubble_large", Vector3(2.5, 0.0, -51.0), -15.0)
	zb.place_at(&"debris_planks", Vector3(-20.0, 0.0, -70.5), 30.0)
	zb.place_at(&"puddle_2m", Vector3(-20.0, 0.0, -62.0), 10.0)
	zb.place_at(&"puddle_2m", Vector3(-8.0, 0.0, -59.0), 70.0)
	zb.place_at(&"cable_hanging_4m", Vector3(-30.0, 6.4, -57.5), 0.0)
	_machines(zb)


## 엄폐 기계 (IndustrialFactory._COVER와 같은 자리·크기, 충돌 포함) + 지게차·팔레트·드럼통.
static func _machines(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("hall_machines")
	# 큰 프레스 기계: 몸통 + 위 작업대 + 옆 제어함
	var c0: Vector3 = Vector3(-12.0, 0.0, -64.0)
	kb.block(KitMaterials.METAL_CHIPPED, c0 + Vector3(0.0, 0.0, 0.0), Vector3(6.0, 0.5, 3.0))
	kb.block(KitMaterials.BEAM_TEAL, c0 + Vector3(0.0, 0.5, 0.0), Vector3(5.4, 2.1, 2.6))
	kb.block(KitMaterials.METAL_PLATE, c0 + Vector3(0.0, 2.6, 0.0), Vector3(5.2, 0.3, 2.4), -1.0, false)
	kb.block(KitMaterials.CABINET_GREY, c0 + Vector3(3.3, 0.0, 0.6), Vector3(0.6, 1.6, 0.8), -1.0, false)
	kb.block(KitMaterials.HAZARD, c0 + Vector3(0.0, 0.5, 1.31), Vector3(5.4, 0.12, 0.02), 0.0, false)
	# 펌프 상자
	kb.block(KitMaterials.CABINET_OLIVE, Vector3(-6.0, 0.0, -72.4), Vector3(3.0, 2.0, 2.4))
	kb.block(KitMaterials.VENT, Vector3(-6.0, 0.6, -71.19), Vector3(1.8, 0.8, 0.02), 0.0, false)
	# 낮은 콘크리트 받침
	kb.block(KitMaterials.CONCRETE_WALL, Vector3(-35.0, 0.0, -64.0), Vector3(2.4, 1.2, 1.6))
	zb.place_at(&"forklift", Vector3(-27.0, 0.0, -61.0), 20.0)
	zb.place_at(&"pallet", Vector3(-38.0, 0.0, -50.0))
	zb.place_at(&"pallet", Vector3(-38.0, 0.144, -50.0), 8.0)
	zb.place_at(&"pallet", Vector3(-37.0, 0.0, -52.5), 90.0)
	zb.place_at(&"crate_wood", Vector3(2.0, 0.0, -56.0), 5.0)
	zb.place_at(&"pallet", Vector3(-22.0, 0.0, -73.0), 10.0)
	for p: Vector3 in [Vector3(-3.0, 0, -73.5), Vector3(-2.3, 0, -73.9), Vector3(-3.4, 0, -74.2), Vector3(-42.0, 0, -70.0),
			Vector3(-42.6, 0, -69.4)]:
		zb.place_at(&"barrel" if int(p.x) % 2 == 0 else &"barrel_red", p, p.z * 37.0)
