class_name IndustrialSite
extends RefCounted
## 단지 나머지 구역: 사무동(서, 2층, 전원 레버) · 화물 엘리베이터 승강장 · 정문 경비초소와 정문 틀 · 주차장(남서) ·
## 컨테이너 야적장(중앙 동쪽) · 감시탑(북서, 경사로로 오른다) · 흩어진 차단벽.

const CONCRETE: StringName = IndustrialMaterials.CONCRETE
const CONCRETE_DARK: StringName = IndustrialMaterials.CONCRETE_DARK
const STEEL: StringName = IndustrialMaterials.STEEL
const RUST: StringName = IndustrialMaterials.RUST
const WOOD: StringName = IndustrialMaterials.WOOD
const PAINT_WHITE: StringName = IndustrialMaterials.PAINT_WHITE
const FONT: Font = preload("res://assets/fonts/NotoSansKR.ttf")

const OFFICE_X0: float = -48.0
const OFFICE_X1: float = -24.0
const OFFICE_Z0: float = 0.0
const OFFICE_Z1: float = 22.0
const STOREY: float = IndustrialMap.STOREY


static func build(m: IndustrialMap) -> void:
	_office(m)
	_freight_lift(m)
	_gate_and_guard_post(m)
	_parking(m)
	_container_yard(m)
	_watchtower(m)
	_open_ground_cover(m)


# --- 사무동 ---

static func _office(m: IndustrialMap) -> void:
	var x0: float = OFFICE_X0
	var x1: float = OFFICE_X1
	var z0: float = OFFICE_Z0
	var z1: float = OFFICE_Z1
	var t: float = 0.4
	var h: float = 3.0
	m.wall_x(x0, x1, z1, 0.0, h, t, CONCRETE, [Vector2(-36.0, 2.4)])
	m.wall_x(x0, x1, z0, 0.0, h, t, CONCRETE, [Vector2(-42.0, 1.8)])
	m.wall_z(z0, z1, x0, 0.0, h, t, CONCRETE, [])
	m.wall_z(z0, z1, x1, 0.0, h, t, CONCRETE, [Vector2(2.0, 1.8)])
	_partitions(m, 0.0, h, t)
	m.span(x0 - 0.2, x1 + 0.2, h, STOREY, z0 - 0.2, z1 + 0.2, CONCRETE_DARK)
	m.wall_x(x0, x1, z1, STOREY, h, t, CONCRETE, [])
	m.wall_x(x0, x1, z0, STOREY, h, t, CONCRETE, [])
	m.wall_z(z0, z1, x0, STOREY, h, t, CONCRETE, [])
	m.wall_z(z0, z1, x1, STOREY, h, t, CONCRETE, [Vector2(5.5, 2.0)])
	_partitions(m, STOREY, h, t)
	m.span(x0 - 0.2, x1 + 0.2, STOREY + h, STOREY + h + 0.4, z0 - 0.2, z1 + 0.2, CONCRETE_DARK)
	# 바깥 창 (어둡고 희미한 유리): 층마다 북·남·서쪽
	for base: float in [0.0, STOREY]:
		var y0: float = base + 1.0
		var y1: float = base + 2.1
		m.window_strip(Vector3(x0 + 1.0, 0, z1 + 0.23), Vector3(-38.0, 0, z1 + 0.23), y0, y1, Vector3(0, 0, 1), false)
		m.window_strip(Vector3(-34.0, 0, z1 + 0.23), Vector3(x1 - 1.0, 0, z1 + 0.23), y0, y1, Vector3(0, 0, 1), false)
		m.window_strip(Vector3(x0 + 1.0, 0, z0 - 0.23), Vector3(-44.0, 0, z0 - 0.23), y0, y1, Vector3(0, 0, -1), false)
		m.window_strip(Vector3(-40.0, 0, z0 - 0.23), Vector3(x1 - 1.0, 0, z0 - 0.23), y0, y1, Vector3(0, 0, -1), false)
		m.window_strip(Vector3(x0 - 0.23, 0, z0 + 1.0), Vector3(x0 - 0.23, 0, z1 - 1.0), y0, y1, Vector3(-1, 0, 0), false)
	# 동쪽 바깥 경사로: 지면(z=19)에서 2층 높이(z=7)까지, 위쪽 승강대에서 2층 동쪽 문으로
	m.ramp_z(-22.1, 3.4, 19.0, 7.0, 0.0, STOREY, CONCRETE)
	m.span(-23.8, -20.4, STOREY - 0.4, STOREY, 4.0, 7.0, CONCRETE)
	m.span(-23.8, -20.4, 0.0, STOREY - 0.4, 4.0, 7.0, CONCRETE_DARK)
	m.span(-23.8, -23.6, STOREY, STOREY + 1.0, 4.0, 7.0, STEEL)
	# 책상·캐비닛 (엄폐)
	for pos: Vector2 in [Vector2(-44.0, 8.0), Vector2(-30.0, 19.0), Vector2(-42.0, 14.0)]:
		m.cover_box(Vector3(pos.x, 0.4, pos.y), Vector3(2.0, 0.8, 0.9), WOOD)
		m.cover_box(Vector3(pos.x, STOREY + 0.4, pos.y), Vector3(2.0, 0.8, 0.9), WOOD)
	# 루팅: 의료 가방 3, 서랍장 2
	m.loot(LootContainer.Kind.MEDBAG, Vector3(-44.0, 0.0, 20.0), 0.0)
	m.loot(LootContainer.Kind.MEDBAG, Vector3(-32.0, STOREY, 3.0), 0.0)
	m.loot(LootContainer.Kind.MEDBAG, Vector3(-28.0, STOREY, 20.5), 0.0)
	m.loot(LootContainer.Kind.DRAWER, Vector3(-47.4, 0.0, 5.0), 90.0)
	m.loot(LootContainer.Kind.DRAWER, Vector3(-27.0, 0.0, 21.4), 0.0)
	# 전원 레버 (2층 북서 방)
	var lever := PowerLever.new()
	lever.name = "PowerLever"
	lever.position = Vector3(-47.5, STOREY, 3.0)
	lever.rotation.y = PI * 0.5
	m.add_loot_child(lever)
	m.lever = lever
	m.collider(Vector3(-47.5, STOREY + 0.6, 3.0), Vector3(0.25, 1.2, 0.7), false)


## 사무동 칸막이 (층마다 같은 배치): x=-36 세로벽, z=11 가로벽 두 조각.
static func _partitions(m: IndustrialMap, y0: float, h: float, t: float) -> void:
	m.wall_z(OFFICE_Z0, OFFICE_Z1, -36.0, y0, h, t, CONCRETE, [Vector2(6.0, 1.6), Vector2(16.0, 1.6)])
	m.wall_x(OFFICE_X0, -36.0, 11.0, y0, h, t, CONCRETE, [Vector2(-42.0, 1.6)])
	m.wall_x(-36.0, OFFICE_X1, 11.0, y0, h, t, CONCRETE, [Vector2(-30.0, 1.6)])


## 화물 엘리베이터 승강장 (사무동 서쪽): 세 면 벽 + 지붕 + 승강기 틀.
static func _freight_lift(m: IndustrialMap) -> void:
	m.span(-66.4, -65.6, 0.0, 4.0, 8.0, 20.0, STEEL)
	m.span(-66.0, -54.0, 0.0, 4.0, 7.6, 8.0, CONCRETE_DARK)
	m.span(-66.0, -54.0, 0.0, 4.0, 20.0, 20.4, CONCRETE_DARK)
	m.span(-66.4, -53.6, 4.0, 4.4, 7.6, 20.4, CONCRETE_DARK)
	for z: float in [11.0, 17.0]:
		m.box(Vector3(-54.2, 2.0, z), Vector3(0.4, 4.0, 0.4), STEEL)
	# 승강기 바닥 표시와 노란 안전 띠
	m.overlay(-62.0, -58.0, 12.0, 16.0, IndustrialMaterials.BAND_WHITE, 0.01)
	m.cover_box(Vector3(-56.0, 0.6, 9.5), Vector3(1.6, 1.2, 1.6), WOOD)


# --- 정문 ---

static func _gate_and_guard_post(m: IndustrialMap) -> void:
	var hh: float = IndustrialMap.HALF
	# 정문 틀과 닫힌 철문
	m.span(-7.0, -6.0, 0.0, 6.0, hh - 1.0, hh, CONCRETE)
	m.span(6.0, 7.0, 0.0, 6.0, hh - 1.0, hh, CONCRETE)
	m.span(-7.0, 7.0, 5.4, 6.1, hh - 1.0, hh, CONCRETE_DARK)
	m.span(-6.0, 6.0, 0.0, 4.2, hh - 0.6, hh - 0.2, STEEL)
	for x: float in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		m.box(Vector3(x, 2.1, hh - 0.75), Vector3(0.1, 4.2, 0.1), RUST, Basis.IDENTITY, false)
	var sign_label := Label3D.new()
	sign_label.text = "정문  ·  MAIN GATE"
	sign_label.font = FONT
	sign_label.font_size = 64
	sign_label.pixel_size = 0.012
	sign_label.position = Vector3(0.0, 5.75, hh - 1.05)
	sign_label.rotation.y = PI
	sign_label.modulate = Color(0.85, 0.82, 0.7, 0.85)
	sign_label.outline_size = 0
	sign_label.shaded = true
	m.add_child(sign_label)
	# 경비초소: x -20..-8, z 75..83, 동쪽(도로 쪽)에 문
	var t: float = 0.4
	m.wall_z(75.0, 83.0, -8.0, 0.0, 3.2, t, CONCRETE, [Vector2(79.0, 1.6)])
	m.wall_z(75.0, 83.0, -20.0, 0.0, 3.2, t, CONCRETE, [])
	m.wall_x(-20.0, -8.0, 75.0, 0.0, 3.2, t, CONCRETE, [])
	m.wall_x(-20.0, -8.0, 83.0, 0.0, 3.2, t, CONCRETE, [])
	m.span(-20.3, -7.7, 3.2, 3.7, 74.7, 83.3, CONCRETE_DARK)
	m.window_strip(Vector3(-18.0, 0, 74.77), Vector3(-10.0, 0, 74.77), 1.2, 2.4, Vector3(0, 0, -1), false)
	m.window_strip(Vector3(-18.0, 0, 83.23), Vector3(-10.0, 0, 83.23), 1.2, 2.4, Vector3(0, 0, 1), false)
	m.cover_box(Vector3(-14.0, 0.4, 79.0), Vector3(2.2, 0.8, 0.9), WOOD, false)
	m.loot(LootContainer.Kind.WEAPON_BOX, Vector3(-18.6, 0.0, 82.2), 0.0)
	m.loot(LootContainer.Kind.DRAWER, Vector3(-10.0, 0.0, 82.5), 0.0)
	# 차단 바와 검문 차단벽
	m.box(Vector3(4.0, 1.1, 74.0), Vector3(4.0, 0.12, 0.12), IndustrialMaterials.BAND_RED, Basis.IDENTITY, false)
	m.box(Vector3(6.2, 0.6, 74.0), Vector3(0.3, 1.2, 0.3), STEEL)
	for x: float in [-6.0, 7.0]:
		IndustrialProps.barrier(m, Vector3(x, 0.0, 66.0), true)
	IndustrialProps.barrier(m, Vector3(0.0, 0.0, 58.0), true)


# --- 주차장 ---

static func _parking(m: IndustrialMap) -> void:
	# 주차선 (바닥에 얹은 흰 띠): 칸막이 세로선 + 줄 양끝 가로선
	for row: Vector2 in [Vector2(31.0, 37.0), Vector2(53.0, 59.0)]:
		for i: int in range(13):
			var x: float = -64.0 + 3.2 * float(i)
			m.overlay(x - 0.05, x + 0.05, row.x, row.y, PAINT_WHITE, 0.01)
		for z: float in [row.x, row.y]:
			m.overlay(-64.0, -22.5, z - 0.05, z + 0.05, PAINT_WHITE, 0.01)
	IndustrialProps.truck(m, Vector3(-60.5, 0.0, 35.5), 180.0, IndustrialMaterials.CONT_RUST, IndustrialMaterials.CONT_TEAL)
	IndustrialProps.truck(m, Vector3(-47.0, 0.0, 34.5), 172.0, IndustrialMaterials.CONT_OCHRE, IndustrialMaterials.CORRUGATED)
	IndustrialProps.truck(m, Vector3(-36.0, 0.0, 55.5), 4.0, IndustrialMaterials.CONT_BLUE, IndustrialMaterials.CONT_RED)
	IndustrialProps.car(m, Vector3(-55.0, 0.0, 56.0), 95.0, IndustrialMaterials.CONT_BLUE)
	IndustrialProps.car(m, Vector3(-42.0, 0.0, 55.0), 6.0, IndustrialMaterials.CONT_RUST)
	IndustrialProps.car(m, Vector3(-29.0, 0.0, 35.0), 190.0, IndustrialMaterials.CONT_TEAL)
	IndustrialProps.car(m, Vector3(-64.0, 0.0, 55.0), 80.0, IndustrialMaterials.CONCRETE_DARK)
	IndustrialProps.forklift(m, Vector3(-30.0, 0.0, 46.0), 60.0)
	IndustrialProps.barrels(m, Vector3(-52.0, 0.0, 45.0), 3)
	m.loot(LootContainer.Kind.CRATE, Vector3(-52.5, 0.0, 39.0), 0.0)


# --- 컨테이너 야적장 ---

static func _container_yard(m: IndustrialMap) -> void:
	var mats: Array[StringName] = [IndustrialMaterials.CONT_RED, IndustrialMaterials.CONT_RUST, IndustrialMaterials.CONT_TEAL,
			IndustrialMaterials.CONT_BLUE, IndustrialMaterials.CONT_OCHRE]
	var rows: Array[float] = [-22.0, -12.0, -2.0, 8.0, 18.0, 28.0]
	var stacked: Array[Vector2] = [Vector2(14, -22), Vector2(30, -12), Vector2(14, -2), Vector2(30, 8), Vector2(14, 18),
			Vector2(30, 28), Vector2(30, -22), Vector2(14, 8)]
	var third: Array[Vector2] = [Vector2(14, -22), Vector2(30, 8)]
	var n: int = 0
	for z: float in rows:
		for x: float in [14.0, 30.0]:
			IndustrialProps.container(m, x, z, mats[n % mats.size()], 0, true)
			n += 1
			if stacked.has(Vector2(x, z)):
				IndustrialProps.container(m, x, z, mats[(n + 2) % mats.size()], 1, true, false)
				if third.has(Vector2(x, z)):
					IndustrialProps.container(m, x, z, mats[(n + 3) % mats.size()], 2, true, false)
	m.loot(LootContainer.Kind.CRATE, Vector3(22.0, 0.0, -17.0), 0.0)
	m.loot(LootContainer.Kind.CRATE, Vector3(22.0, 0.0, 13.0), 90.0)
	m.loot(LootContainer.Kind.WEAPON_BOX, Vector3(37.4, 0.0, 22.0), 90.0)


# --- 감시탑 ---

## 북서쪽 감시탑: 경사로 A(서쪽 도로에서) → 중간 승강대 → 경사로 B(북쪽) → 높이 9 m 전망 데크.
static func _watchtower(m: IndustrialMap) -> void:
	var deck_y: float = 9.0
	var mid_y: float = 4.5
	# 전망 데크: x -61.5..-54.5, z -65.5..-58.5
	m.span(-61.5, -54.5, deck_y - 0.3, deck_y, -65.5, -58.5, STEEL)
	for corner: Vector2 in [Vector2(-61.2, -65.2), Vector2(-54.8, -65.2), Vector2(-61.2, -58.8), Vector2(-54.8, -58.8)]:
		m.box(Vector3(corner.x, (deck_y - 0.3) * 0.5, corner.y), Vector3(0.5, deck_y - 0.3, 0.5), CONCRETE_DARK)
	for x: float in [-61.2, -54.8]:
		m.beam(Vector3(x, 1.0, -65.2), Vector3(x, deck_y - 0.4, -58.8), 0.18, STEEL)
		m.beam(Vector3(x, 1.0, -58.8), Vector3(x, deck_y - 0.4, -65.2), 0.18, STEEL)
	# 난간(엄폐): 북·동·서쪽 막고, 남쪽은 경사로 입구를 남긴다
	m.span(-61.5, -54.5, deck_y, deck_y + 1.1, -65.5, -65.2, CONCRETE_DARK)
	m.span(-61.5, -61.2, deck_y, deck_y + 1.1, -65.5, -58.5, CONCRETE_DARK)
	m.span(-54.8, -54.5, deck_y, deck_y + 1.1, -65.5, -58.5, CONCRETE_DARK)
	m.span(-61.5, -60.0, deck_y, deck_y + 1.1, -58.8, -58.5, CONCRETE_DARK)
	m.span(-57.0, -54.5, deck_y, deck_y + 1.1, -58.8, -58.5, CONCRETE_DARK)
	# 지붕 + 기둥
	m.span(-62.3, -53.7, deck_y + 3.4, deck_y + 3.7, -66.3, -57.7, STEEL, false)
	for corner: Vector2 in [Vector2(-61.2, -65.2), Vector2(-54.8, -65.2)]:
		m.box(Vector3(corner.x, deck_y + 1.7, corner.y), Vector3(0.25, 3.4, 0.25), STEEL, Basis.IDENTITY, false)
	# 경사로 B: 중간 승강대(z -48.5..-45)에서 데크 남쪽 가장자리까지 (북쪽으로 올라감)
	m.ramp_z(-58.5, 2.6, -48.5, -58.5, mid_y, deck_y, STEEL)
	# 중간 승강대 + 지지대
	m.span(-62.0, -55.0, mid_y - 0.3, mid_y, -48.5, -45.0, STEEL)
	for corner: Vector2 in [Vector2(-61.7, -45.3), Vector2(-55.3, -45.3)]:
		m.box(Vector3(corner.x, (mid_y - 0.3) * 0.5, corner.y), Vector3(0.4, mid_y - 0.3, 0.4), CONCRETE_DARK)
	# 경사로 A: 서쪽 도로(x=-71)에서 승강대 서쪽 가장자리(x=-62)까지
	m.ramp_x(-46.8, 2.6, -71.0, -62.0, 0.0, mid_y, STEEL)
	m.loot(LootContainer.Kind.WEAPON_BOX, Vector3(-56.5, deck_y, -64.2), 0.0)
	m.cover_markers(-58.0, -62.0, 3.5, 3.5, deck_y, 0.0)
	m.cover_box(Vector3(-62.0, 0.5, -55.0), Vector3(2.4, 1.0, 1.0), CONCRETE_DARK, false)
	m.loot(LootContainer.Kind.CRATE, Vector3(-64.0, 0.0, -57.0), 0.0)


# --- 흩어진 엄폐물 ---

static func _open_ground_cover(m: IndustrialMap) -> void:
	var barriers: Array[Vector3] = [Vector3(-14, 0, 62), Vector3(12, 0, 60), Vector3(-6, 0, 48), Vector3(24, 0, 54),
			Vector3(0, 0, 40), Vector3(6, 0, -34), Vector3(-18, 0, -34), Vector3(-10, 0, -8), Vector3(-16, 0, 30),
			Vector3(12, 0, 34), Vector3(40, 0, 36), Vector3(55, 0, 40), Vector3(-60, 0, -30), Vector3(-20, 0, -42),
			Vector3(48, 0, -42), Vector3(60, 0, -4), Vector3(-6, 0, 20), Vector3(-30, 0, 66)]
	for pos: Vector3 in barriers:
		IndustrialProps.barrier(m, pos, int(pos.x + pos.z) % 2 == 0)
	m.loot(LootContainer.Kind.CRATE, Vector3(28.0, 0.0, 70.0), 0.0)
	# 시작 지점 주변: 버려진 트럭·드럼통·팔레트
	IndustrialProps.truck(m, Vector3(40.0, 0.0, 77.0), 82.0, IndustrialMaterials.CONT_RED, IndustrialMaterials.CONT_RUST)
	IndustrialProps.barrels(m, Vector3(18.0, 0.0, 81.0), 3)
	IndustrialProps.pallet_stack(m, Vector3(32.0, 0.0, 72.0), 20.0, 2)
	IndustrialProps.pallet_stack(m, Vector3(46.0, 0.0, 44.0), 0.0, 2)
	IndustrialProps.pallet_stack(m, Vector3(-8.0, 0.0, 28.0), 90.0, 1)
	IndustrialProps.barrels(m, Vector3(62.0, 0.0, 58.0), 4)
	IndustrialProps.forklift(m, Vector3(6.0, 0.0, 33.0), 80.0)
