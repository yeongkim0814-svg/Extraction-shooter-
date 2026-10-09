class_name ZoneSite
extends RefCounted
## 단지 구역 (사무동·승강장·정문·경비초소·주차장·컨테이너 야적장·흩어진 차단벽). 감시탑·철길·담장은 ZoneInfra.
## 빛 정체성 (ART.md 11.6): 사무동 = 형광등 (깜빡임은 램프 부품 하나하나가 아니라 구역 분위기), 야적장 = 램프 없음 (흐린 하늘 확산광).
## 위치·크기·충돌은 옛 IndustrialSite와 같다. 엄폐·루팅·전원 레버는 맵 코드가 그대로 둔다.

const OFFICE_X0: float = -48.0
const OFFICE_X1: float = -24.0
const OFFICE_Z0: float = 0.0
const OFFICE_Z1: float = 22.0
const STOREY: float = IndustrialMap.STOREY
const OT: float = 0.4
const OH: float = 3.0

## 컨테이너 야적장 (옛 IndustrialSite._container_yard와 같은 배치).
const YARD_ROWS: Array[float] = [-22.0, -12.0, -2.0, 8.0, 18.0, 28.0]
const YARD_STACKED: Array[Vector2] = [Vector2(14, -22), Vector2(30, -12), Vector2(14, -2), Vector2(30, 8), Vector2(14, 18),
		Vector2(30, 28), Vector2(30, -22), Vector2(14, 8)]
const YARD_THIRD: Array[Vector2] = [Vector2(14, -22), Vector2(30, 8)]
const YARD_PIECES: Array[StringName] = [&"container_20ft_red", &"container_20ft_red", &"container_20ft_teal", &"container_20ft_teal",
		&"container_20ft_olive"]
## 흩어진 차단벽 (옛 _open_ground_cover).
const BARRIERS: Array[Vector3] = [Vector3(-14, 0, 62), Vector3(12, 0, 60), Vector3(-6, 0, 48), Vector3(24, 0, 54),
		Vector3(0, 0, 40), Vector3(6, 0, -34), Vector3(-18, 0, -34), Vector3(-10, 0, -8), Vector3(-16, 0, 30),
		Vector3(12, 0, 34), Vector3(40, 0, 36), Vector3(55, 0, 40), Vector3(-60, 0, -30), Vector3(-20, 0, -42),
		Vector3(48, 0, -42), Vector3(60, 0, -4), Vector3(-6, 0, 20), Vector3(-30, 0, 66)]


static func build(zb: ZoneBuilder) -> void:
	zb.cell_m = 44.0
	_office(zb)
	_freight_lift(zb)
	_gate(zb)
	_guard_post(zb)
	_parking(zb)
	_container_yard(zb)
	_open_ground(zb)


# --- 사무동 ---

static func _office(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("site_office")
	var wall: StringName = KitMaterials.FLAT_CONCRETE
	var door: StringName = KitMaterials.DOOR_STEEL
	var cx: float = (OFFICE_X0 + OFFICE_X1) * 0.5
	var cz: float = (OFFICE_Z0 + OFFICE_Z1) * 0.5
	for floor_i: int in range(2):
		var y0: float = 0.0 if floor_i == 0 else STOREY
		var n_open: Array[Vector2] = []
		var s_open: Array[Vector2] = []
		var e_open: Array[Vector2] = []
		var no_open: Array[Vector2] = []
		if floor_i == 0:
			n_open.append(Vector2(-36.0, 2.4))
			s_open.append(Vector2(-42.0, 1.8))
			e_open.append(Vector2(2.0, 1.8))
		else:
			e_open.append(Vector2(5.5, 2.0))
		var low: bool = floor_i == 0
		ZoneParts.panel_wall(kb, true, OFFICE_Z1, OFFICE_X0, OFFICE_X1, OH, OT, wall, n_open, 2.6, y0, door, false, low, false)
		ZoneParts.panel_wall(kb, true, OFFICE_Z0, OFFICE_X0, OFFICE_X1, OH, OT, wall, s_open, 2.6, y0, door, false, low, false)
		ZoneParts.panel_wall(kb, false, OFFICE_X0, OFFICE_Z0, OFFICE_Z1, OH, OT, wall, no_open, 2.6, y0, door, false, low, false)
		ZoneParts.panel_wall(kb, false, OFFICE_X1, OFFICE_Z0, OFFICE_Z1, OH, OT, wall, e_open, 2.6, y0, door, false, low, false)
		# 칸막이: x = -36 세로벽, z = 11 가로벽 두 조각
		ZoneParts.panel_wall(kb, false, -36.0, OFFICE_Z0, OFFICE_Z1, OH, OT, wall,
				[Vector2(6.0, 1.6), Vector2(16.0, 1.6)] as Array[Vector2], 2.6, y0, door, false, false, false)
		ZoneParts.panel_wall(kb, true, 11.0, OFFICE_X0, -36.0, OH, OT, wall, [Vector2(-42.0, 1.6)] as Array[Vector2], 2.6, y0, door, false, false, false)
		ZoneParts.panel_wall(kb, true, 11.0, -36.0, OFFICE_X1, OH, OT, wall, [Vector2(-30.0, 1.6)] as Array[Vector2], 2.6, y0, door, false, false, false)
		_office_windows(kb, y0)
		# 책상 (엄폐): 층마다 세 개
		for pos: Vector2 in [Vector2(-44.0, 8.0), Vector2(-30.0, 19.0), Vector2(-42.0, 14.0)]:
			ZoneParts.desk(kb, Vector3(pos.x, y0, pos.y), Vector3(2.0, 0.8, 0.9))
	# 2층 바닥판 (옛 충돌판) + 지붕판 + 처마 띠
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(cx, (OH + STOREY) * 0.5, cz)), Vector3(OFFICE_X1 - OFFICE_X0 + 0.4, STOREY - OH, OFFICE_Z1 - OFFICE_Z0 + 0.4), 0.0, true)
	kb.box(KitMaterials.FLAT_ROOF, KitParts.at(Vector3(cx, STOREY + OH + 0.2, cz)), Vector3(OFFICE_X1 - OFFICE_X0 + 0.4, 0.4, OFFICE_Z1 - OFFICE_Z0 + 0.4), 0.0, true)
	kb.block(KitMaterials.SILL, Vector3(cx, STOREY + OH + 0.4, cz), Vector3(OFFICE_X1 - OFFICE_X0 + 0.7, 0.2, OFFICE_Z1 - OFFICE_Z0 + 0.7), 0.0, false)
	kb.block(KitMaterials.CONCRETE_WALL, Vector3(cx, STOREY - 0.2, cz), Vector3(OFFICE_X1 - OFFICE_X0 + 0.6, 0.5, OFFICE_Z1 - OFFICE_Z0 + 0.6), 0.0, false, KitLayout.SILL)
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(OFFICE_X0, OFFICE_Z0, OFFICE_X1 - OFFICE_X0, OFFICE_Z1 - OFFICE_Z0))
	# 동쪽 바깥 경사로 (지면 z=19 -> 2층 z=7) + 승강대 + 받침 + 낮은 벽 + 난간
	ZoneParts.ramp_z(kb, -22.1, 3.4, 19.0, 7.0, 0.0, STOREY, KitMaterials.FLAT_CONCRETE_DARK)
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(-22.1, STOREY - 0.2, 5.5)), Vector3(3.4, 0.4, 3.0), 0.0, true)
	kb.box(KitMaterials.FLAT_CONCRETE, KitParts.at(Vector3(-22.1, (STOREY - 0.4) * 0.5, 5.5)), Vector3(3.4, STOREY - 0.4, 3.0), 0.0, true)
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(-23.7, STOREY + 0.5, 5.5)), Vector3(0.2, 1.0, 3.0), 0.0, true)
	for side: float in [-1.0, 1.0]:
		KitParts.railing(kb, KitMaterials.BEAM_YELLOW, Vector3(-22.1 + side * 1.65, 0.0, 19.0), Vector3(-22.1 + side * 1.65, STOREY, 7.0), 1.0, 3.0)
	# 형광등: 1층 셋, 2층 셋 (구역 빛 = 깜빡이는 형광등 정체성)
	for p: Vector3 in [Vector3(-42.0, OH, 16.5), Vector3(-30.0, OH, 5.0), Vector3(-30.0, OH, 16.5),
			Vector3(-43.0, STOREY + OH, 5.0), Vector3(-30.0, STOREY + OH, 5.5), Vector3(-30.0, STOREY + OH, 16.5)]:
		zb.place_at(&"lamp_fluoro", p)
	zb.place_at(&"cable_hanging_4m", Vector3(-46.0, OH - 0.3, 2.0), 90.0)


static func _office_windows(kb: KitBuild, y0: float) -> void:
	var yc: float = y0 + 1.55
	var north: float = OFFICE_Z1 + OT * 0.5
	var south: float = OFFICE_Z0 - OT * 0.5
	for x: float in [-45.5, -42.5, -39.5, -32.5, -29.5, -26.5]:
		ZoneParts.window(kb, Transform3D(Basis(Vector3.UP, 0.0), Vector3(x, yc, north)), 2.0, 1.1)
	for x: float in [-45.5, -38.5, -35.5, -32.5, -29.5, -26.5]:
		ZoneParts.window(kb, Transform3D(Basis(Vector3.UP, PI), Vector3(x, yc, south)), 2.0, 1.1)
	for z: float in [3.0, 7.0, 15.0, 19.0]:
		ZoneParts.window(kb, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(OFFICE_X0 - OT * 0.5, yc, z)), 2.0, 1.1)


# --- 화물 엘리베이터 승강장 ---

static func _freight_lift(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("site_lift")
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(-66.0, 2.0, 14.0)), Vector3(0.8, 4.0, 12.0), 0.0, true)
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(-60.0, 2.0, 7.8)), Vector3(12.0, 4.0, 0.4), 0.0, true)
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(-60.0, 2.0, 20.2)), Vector3(12.0, 4.0, 0.4), 0.0, true)
	kb.box(KitMaterials.FLAT_ROOF, KitParts.at(Vector3(-60.0, 4.2, 14.0)), Vector3(12.8, 0.4, 12.8), 0.0, true)
	for z: float in [11.0, 17.0]:
		kb.box(KitMaterials.BEAM_YELLOW, KitParts.at(Vector3(-54.2, 2.0, z)), Vector3(0.4, 4.0, 0.4), 0.0, true)
		kb.block(KitMaterials.METAL_PLATE, Vector3(-54.2, 0.0, z), Vector3(0.7, 0.06, 0.7), 0.0, false)
	# 승강기 바닥 표시: 경고 띠 네 줄 + 안쪽 철판
	kb.block(KitMaterials.METAL_PLATE, Vector3(-60.0, 0.03, 14.0), Vector3(3.9, 0.02, 3.9), 0.0, false, KitLayout.TREAD)
	for z: float in [12.0, 16.0]:
		kb.block(KitMaterials.HAZARD, Vector3(-60.0, 0.04, z), Vector3(4.0, 0.02, 0.25), 0.0, false)
	for x: float in [-62.0, -58.0]:
		kb.block(KitMaterials.HAZARD, Vector3(x, 0.04, 14.0), Vector3(0.25, 0.02, 4.0), 0.0, false)
	# 엄폐 상자 (옛 cover_box 1.6 x 1.2 x 1.6, 나무)
	kb.box(KitMaterials.FLAT_WOOD, KitParts.at(Vector3(-56.0, 0.6, 9.5)), Vector3(1.6, 1.2, 1.6), 0.02, true)
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(-56.0, 0.6, 9.5)), Vector3(1.64, 0.08, 1.64), 0.0, false)
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(-66.0, 8.0, 12.0, 12.0))


# --- 정문과 경비초소 ---

static func _gate(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("site_gate")
	var hh: float = IndustrialMap.HALF
	for sx: float in [-6.5, 6.5]:
		kb.box(KitMaterials.FLAT_CONCRETE, KitParts.at(Vector3(sx, 3.0, hh - 0.5)), Vector3(1.0, 6.0, 1.0), 0.0, true)
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(sx, 0.0, hh - 0.5), Vector3(1.16, 1.0, 1.16), 0.0, false, KitLayout.SILL)
		kb.block(KitMaterials.SILL, Vector3(sx, 5.8, hh - 0.5), Vector3(1.3, 0.2, 1.3), 0.0, false)
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(0.0, 5.75, hh - 0.5)), Vector3(14.0, 0.7, 1.0), 0.0, true)
	# 닫힌 철문: 충돌 12 x 4.2 x 0.4 + 세로 쇠창살 + 위·아래 가로대
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, 2.1, hh - 0.4)), Vector3(12.0, 4.2, 0.4), 0.0, true)
	for x: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		kb.box(KitMaterials.RUST, KitParts.at(Vector3(x, 2.1, hh - 0.75)), Vector3(0.1, 4.2, 0.1), 0.0, false)
	for y: float in [0.3, 2.1, 3.9]:
		kb.box(KitMaterials.RUST, KitParts.at(Vector3(0.0, y, hh - 0.75)), Vector3(12.0, 0.12, 0.1), 0.0, false)
	kb.block(KitMaterials.HAZARD, Vector3(0.0, 0.0, hh - 1.4), Vector3(10.0, 0.02, 0.3), 0.0, false)
	# 차단 바 + 받침대
	kb.box(KitMaterials.BAND_RED, KitParts.at(Vector3(4.0, 1.1, 74.0)), Vector3(4.0, 0.12, 0.12), 0.0, false)
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(6.2, 0.6, 74.0)), Vector3(0.3, 1.2, 0.3), 0.0, true)
	kb.block(KitMaterials.HAZARD, Vector3(6.2, 0.9, 74.0 - 0.16), Vector3(0.3, 0.2, 0.02), 0.0, false)
	for x: float in [-6.0, 7.0]:
		ZoneProps.barrier(zb, Vector3(x, 0.0, 66.0), true)
	ZoneProps.barrier(zb, Vector3(0.0, 0.0, 58.0), true)


static func _guard_post(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("site_guard_post")
	var wall: StringName = KitMaterials.FLAT_CONCRETE
	var none: Array[Vector2] = []
	ZoneParts.panel_wall(kb, false, -8.0, 75.0, 83.0, 3.2, 0.4, wall, [Vector2(79.0, 1.6)] as Array[Vector2], 2.6, 0.0, KitMaterials.DOOR_STEEL, false, true, false)
	ZoneParts.panel_wall(kb, false, -20.0, 75.0, 83.0, 3.2, 0.4, wall, none, 2.6, 0.0, KitMaterials.DOOR_STEEL, false, true, false)
	ZoneParts.panel_wall(kb, true, 75.0, -20.0, -8.0, 3.2, 0.4, wall, none, 2.6, 0.0, KitMaterials.DOOR_STEEL, false, true, false)
	ZoneParts.panel_wall(kb, true, 83.0, -20.0, -8.0, 3.2, 0.4, wall, none, 2.6, 0.0, KitMaterials.DOOR_STEEL, false, true, false)
	kb.box(KitMaterials.FLAT_ROOF, KitParts.at(Vector3(-14.0, 3.45, 79.0)), Vector3(12.6, 0.5, 8.6), 0.0, true)
	kb.block(KitMaterials.SILL, Vector3(-14.0, 3.7, 79.0), Vector3(12.9, 0.2, 8.9), 0.0, false)
	for x: float in [-16.5, -11.5]:
		ZoneParts.window(kb, Transform3D(Basis(Vector3.UP, PI), Vector3(x, 1.8, 74.8)), 2.4, 1.2)
		ZoneParts.window(kb, Transform3D(Basis.IDENTITY, Vector3(x, 1.8, 83.2)), 2.4, 1.2)
	ZoneParts.desk(kb, Vector3(-14.0, 0.0, 79.0), Vector3(2.2, 0.8, 0.9))
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(-21.0, 74.0, 14.0, 10.0))
	zb.place_at(&"lamp_fluoro", Vector3(-14.0, 3.2, 79.0))


# --- 주차장 ---

static func _parking(zb: ZoneBuilder) -> void:
	ZoneProps.truck(zb, Vector3(-60.5, 0.0, 35.5), 180.0, KitMaterials.METAL_CORRUGATED_TEAL)
	ZoneProps.truck(zb, Vector3(-47.0, 0.0, 34.5), 172.0, KitMaterials.METAL_CHIPPED)
	ZoneProps.truck(zb, Vector3(-36.0, 0.0, 55.5), 4.0, KitMaterials.METAL_CORRUGATED_RED)
	ZoneProps.car(zb, Vector3(-55.0, 0.0, 56.0), 95.0, &"car_sedan_teal")
	ZoneProps.car(zb, Vector3(-42.0, 0.0, 55.0), 6.0, &"car_sedan_red")
	ZoneProps.car(zb, Vector3(-29.0, 0.0, 35.0), 190.0, &"car_sedan_olive")
	ZoneProps.car(zb, Vector3(-64.0, 0.0, 55.0), 80.0, &"car_sedan_teal")
	ZoneProps.forklift(zb, Vector3(-30.0, 0.0, 46.0), 60.0)
	ZoneProps.barrels(zb, Vector3(-52.0, 0.0, 45.0), 3)


# --- 컨테이너 야적장 ---

static func _container_yard(zb: ZoneBuilder) -> void:
	var n: int = 0
	for z: float in YARD_ROWS:
		for x: float in [14.0, 30.0]:
			ZoneProps.container(zb, x, z, YARD_PIECES[n % YARD_PIECES.size()], 0, true)
			n += 1
			if YARD_STACKED.has(Vector2(x, z)):
				ZoneProps.container(zb, x, z, YARD_PIECES[(n + 2) % YARD_PIECES.size()], 1, true)
				if YARD_THIRD.has(Vector2(x, z)):
					ZoneProps.container(zb, x, z, YARD_PIECES[(n + 3) % YARD_PIECES.size()], 2, true)


# --- 흩어진 엄폐물과 시작 지점 소품 ---

static func _open_ground(zb: ZoneBuilder) -> void:
	for pos: Vector3 in BARRIERS:
		ZoneProps.barrier(zb, pos, int(pos.x + pos.z) % 2 == 0)
	ZoneProps.truck(zb, Vector3(40.0, 0.0, 77.0), 82.0, KitMaterials.METAL_CORRUGATED_RED)
	ZoneProps.barrels(zb, Vector3(18.0, 0.0, 81.0), 3)
	ZoneProps.pallet_stack(zb, Vector3(32.0, 0.0, 72.0), 20.0, 2)
	ZoneProps.pallet_stack(zb, Vector3(46.0, 0.0, 44.0), 0.0, 2)
	ZoneProps.pallet_stack(zb, Vector3(-8.0, 0.0, 28.0), 90.0, 1)
	ZoneProps.barrels(zb, Vector3(62.0, 0.0, 58.0), 4)
	ZoneProps.forklift(zb, Vector3(6.0, 0.0, 33.0), 80.0)
