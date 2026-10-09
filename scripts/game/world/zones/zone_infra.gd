class_name ZoneInfra
extends RefCounted
## 시설 구역 (담장·철길·배관 랙·타워 크레인·송전탑·감시탑). 빛 없음 (바깥 연무 속 역광 실루엣, ART.md 11.6 탱크 구역 정체성).
## 위치·충돌은 옛 IndustrialInfra/IndustrialSite._watchtower와 같다. 먼 풍경(build_skyline)은 옛 코드 그대로 (충돌 없는 실루엣).

const HALF: float = IndustrialMap.HALF
const RAIL_X: float = IndustrialInfra.RAIL_X
const WALL_H: float = IndustrialMap.WALL_H


static func build(zb: ZoneBuilder) -> void:
	zb.cell_m = 64.0
	_perimeter(zb)
	_railway(zb)
	var kb: KitBuild = zb.custom("infra_racks")
	_rack_x(kb, -40.0, 40.0, -31.0)
	_rack_z(kb, -64.0, -10.0, -52.0)
	_rack_x(kb, 44.0, 80.0, 40.0)
	kb = zb.custom("infra_cranes")
	_tower_crane(kb, Vector3(56.0, 0.0, -48.0), 38.0, 30.0, 180.0)
	_tower_crane(kb, Vector3(60.0, 0.0, 52.0), 30.0, 24.0, 205.0)
	_lattice_tower(kb, Vector3(73.0, 0.0, -52.0), 44.0)
	_watchtower(zb)


# --- 외곽 담장 ---

static func _perimeter(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("infra_perimeter")
	var t: float = 1.0
	var h: float = WALL_H
	# 충돌 몸통 (옛과 같은 다섯 토막)
	var parts: Array[Rect2] = [Rect2(-HALF - t, -HALF - t, HALF * 2.0 + t * 2.0, t),   # 북
			Rect2(-HALF - t, HALF, HALF + t - 7.0, t), Rect2(7.0, HALF, HALF + t - 7.0, t),   # 남 (정문 틈 7 m)
			Rect2(-HALF - t, -HALF, t, HALF * 2.0), Rect2(HALF, -HALF, t, HALF * 2.0)]   # 서·동
	for i: int in range(parts.size()):
		var r: Rect2 = parts[i]
		kb.box(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(r.position.x + r.size.x * 0.5, h * 0.5, r.position.y + r.size.y * 0.5)),
				Vector3(r.size.x, h, r.size.y), 0.0, true)
		kb.block(KitMaterials.SILL, Vector3(r.position.x + r.size.x * 0.5, h, r.position.y + r.size.y * 0.5),
				Vector3(r.size.x + (0.3 if r.size.x > r.size.y else 0.0), 0.2, r.size.y + (0.3 if r.size.y > r.size.x else 0.0)), 0.0, false)
	# 안쪽 면 골함석 판 (서·동·남): 기둥 사이 12 m마다
	var inner: float = HALF - 0.02
	var p: float = -HALF + 12.0
	while p < HALF - 5.0:
		kb.box(KitMaterials.METAL_CORRUGATED_TEAL, KitParts.at(Vector3(-inner + 0.0, 2.0, p)), Vector3(0.06, 3.4, 11.0), 0.0, false)
		kb.box(KitMaterials.METAL_CORRUGATED_TEAL, KitParts.at(Vector3(inner, 2.0, p)), Vector3(0.06, 3.4, 11.0), 0.0, false)
		if absf(p) > 12.0:
			kb.box(KitMaterials.METAL_CORRUGATED_TEAL, KitParts.at(Vector3(p, 2.0, inner)), Vector3(11.0, 3.4, 0.06), 0.0, false)
		p += 12.0
	# 기둥 (12 m마다) + 굽
	p = -HALF + 6.0
	while p < HALF:
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(p, 0.0, -HALF + 0.05), Vector3(0.7, h + 0.4, 0.5), 0.0, false, KitLayout.SILL)
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(-HALF + 0.05, 0.0, p), Vector3(0.5, h + 0.4, 0.7), 0.0, false, KitLayout.SILL)
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(HALF - 0.05, 0.0, p), Vector3(0.5, h + 0.4, 0.7), 0.0, false, KitLayout.SILL)
		if absf(p) > 8.0:
			kb.block(KitMaterials.CONCRETE_WALL, Vector3(p, 0.0, HALF - 0.05), Vector3(0.7, h + 0.4, 0.5), 0.0, false, KitLayout.SILL)
		p += 12.0
	# 윗선 (철조망 느낌)
	kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, h + 0.4, -HALF + 0.1)), Vector3(HALF * 2.0, 0.05, 0.05), 0.0, false)


# --- 철길 ---

static func _railway(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("infra_railway")
	var z0: float = -HALF + 4.0
	var z1: float = HALF - 4.0
	var length: float = z1 - z0
	zb.ground(KitMaterials.GROUND_GRAVEL, Rect2(RAIL_X - 2.8, z0, 5.6, length), 0.02, Color(1.0, 0.6, 1.0))
	for dx: float in [-0.72, 0.72]:
		kb.box(KitMaterials.RUST, KitParts.at(Vector3(RAIL_X + dx, 0.225, (z0 + z1) * 0.5)), Vector3(0.12, 0.15, length), 0.0, false)
	# 침목 (0.8 m 간격)
	var count: int = int(length / 0.8)
	for i: int in range(count):
		kb.box(KitMaterials.FLAT_WOOD, KitParts.at(Vector3(RAIL_X, 0.12, z0 + 0.4 + 0.8 * float(i))), Vector3(2.5, 0.14, 0.28), 0.0, false)
	# 선로 끝 정지대 (충돌 2.2 x 1.2 x 0.5)
	for z: float in [z0 - 0.4, z1 + 0.4]:
		kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(RAIL_X, 0.6, z)), Vector3(2.2, 1.2, 0.5), 0.0, true)
		kb.block(KitMaterials.HAZARD, Vector3(RAIL_X, 0.9, z + (-0.26 if z < 0.0 else 0.26)), Vector3(2.0, 0.25, 0.02), 0.0, false)
	ZoneProps.boxcar(zb, RAIL_X, -30.0, KitMaterials.METAL_CORRUGATED_RED)
	ZoneProps.boxcar(zb, RAIL_X, 22.0, KitMaterials.METAL_CORRUGATED_TEAL)
	ZoneProps.boxcar(zb, RAIL_X, 68.0, KitMaterials.METAL_CHIPPED)


# --- 배관 랙 ---

## 동서로 뻗은 배관 랙 (x0~x1, 중심 z): 10 m마다 문형 틀 + 파이프 3줄. 다리 충돌 0.35 x 5.8 x 0.35.
static func _rack_x(kb: KitBuild, x0: float, x1: float, z: float) -> void:
	var x: float = x0
	while x <= x1 + 0.1:
		for dz: float in [-1.1, 1.1]:
			kb.box(KitMaterials.BEAM_TEAL, KitParts.at(Vector3(x, 2.9, z + dz)), Vector3(0.35, 5.8, 0.35), 0.0, true)
			kb.block(KitMaterials.METAL_PLATE, Vector3(x, 0.0, z + dz), Vector3(0.6, 0.05, 0.6), 0.0, false)
		kb.box(KitMaterials.BEAM_TEAL, KitParts.at(Vector3(x, 5.8, z)), Vector3(0.3, 0.35, 2.9), 0.0, false)
		ZoneParts.beam(kb, KitMaterials.BEAM_TEAL, Vector3(x, 5.6, z - 1.1), Vector3(x, 4.2, z - 1.1 + 0.0), 0.12)
		for dz: float in [-1.1, 1.1]:
			ZoneParts.beam(kb, KitMaterials.BEAM_TEAL, Vector3(x, 4.2, z + dz), Vector3(x, 5.6, z + dz * 0.4), 0.1)
		x += 10.0
	var len: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	KitParts.cyl_x(kb, KitMaterials.PIPE_RED, Vector3(cx, 6.3, z - 0.8), 0.42, len, 12)
	KitParts.cyl_x(kb, KitMaterials.PIPE_TEAL, Vector3(cx, 6.2, z + 0.5), 0.3, len, 10)
	KitParts.cyl_x(kb, KitMaterials.PIPE_RED, Vector3(cx, 7.0, z), 0.25, len, 10)
	kb.box(KitMaterials.GRATE, KitParts.at(Vector3(cx, 5.975, z + 1.15)), Vector3(len, 0.05, 0.5), 0.0, false)
	x = x0 + 5.0
	while x < x1:
		KitParts.cyl_x(kb, KitMaterials.PIPE_JOINT, Vector3(x, 6.3, z - 0.8), 0.55, 0.1, 12)
		KitParts.cyl_x(kb, KitMaterials.PIPE_JOINT, Vector3(x, 6.2, z + 0.5), 0.42, 0.08, 10)
		x += 10.0


## 남북으로 뻗은 배관 랙.
static func _rack_z(kb: KitBuild, z0: float, z1: float, x: float) -> void:
	var z: float = z0
	while z <= z1 + 0.1:
		for dx: float in [-1.1, 1.1]:
			kb.box(KitMaterials.BEAM_TEAL, KitParts.at(Vector3(x + dx, 2.9, z)), Vector3(0.35, 5.8, 0.35), 0.0, true)
			kb.block(KitMaterials.METAL_PLATE, Vector3(x + dx, 0.0, z), Vector3(0.6, 0.05, 0.6), 0.0, false)
		kb.box(KitMaterials.BEAM_TEAL, KitParts.at(Vector3(x, 5.8, z)), Vector3(2.9, 0.35, 0.3), 0.0, false)
		z += 9.0
	var len: float = z1 - z0
	var cz: float = (z0 + z1) * 0.5
	KitParts.cyl_z(kb, KitMaterials.PIPE_RED, Vector3(x - 0.7, 6.3, cz), 0.4, len, 12)
	KitParts.cyl_z(kb, KitMaterials.PIPE_TEAL, Vector3(x + 0.6, 6.2, cz), 0.3, len, 10)
	KitParts.cyl_z(kb, KitMaterials.PIPE_RED, Vector3(x, 7.0, cz), 0.28, len, 10)
	z = z0 + 4.5
	while z < z1:
		KitParts.cyl_z(kb, KitMaterials.PIPE_JOINT, Vector3(x - 0.7, 6.3, z), 0.52, 0.1, 12)
		z += 9.0


# --- 격자 구조물 ---

static func _world(pos: Vector3, yaw_deg: float, local: Vector3) -> Vector3:
	return pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * local


## 타워 크레인: 격자 마스트 + 운전실 + 격자 붐(앞)과 균형추(뒤). 앞(붐 쪽)은 로컬 +x. 충돌은 마스트 밑동 상자 (옛과 같다).
static func _tower_crane(kb: KitBuild, pos: Vector3, mast_h: float, jib_len: float, yaw_deg: float) -> void:
	var mat: StringName = KitMaterials.BEAM_YELLOW
	var steel: StringName = KitMaterials.FLAT_METAL
	var w: float = 1.0
	var bay: float = 3.0
	var y: float = 0.0
	while y < mast_h - 0.01:
		var y2: float = minf(y + bay, mast_h)
		for sx: float in [-w, w]:
			for sz: float in [-w, w]:
				ZoneParts.beam(kb, mat, _world(pos, yaw_deg, Vector3(sx, y, sz)), _world(pos, yaw_deg, Vector3(sx, y2, sz)), 0.22)
		for pair: Array in [[Vector3(-w, y2, -w), Vector3(w, y2, -w)], [Vector3(-w, y2, w), Vector3(w, y2, w)],
				[Vector3(-w, y2, -w), Vector3(-w, y2, w)], [Vector3(w, y2, -w), Vector3(w, y2, w)],
				[Vector3(-w, y, -w), Vector3(w, y2, -w)], [Vector3(w, y, w), Vector3(-w, y2, w)],
				[Vector3(-w, y, w), Vector3(-w, y2, -w)], [Vector3(w, y, -w), Vector3(w, y2, w)]]:
			ZoneParts.beam(kb, steel, _world(pos, yaw_deg, pair[0] as Vector3), _world(pos, yaw_deg, pair[1] as Vector3), 0.1)
		y = y2
	kb.collide_box(KitParts.at(pos + Vector3(0.0, 3.0, 0.0)), Vector3(2.4, 6.0, 2.4))
	var top: float = mast_h
	var orientation: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	kb.box(steel, Transform3D(orientation, _world(pos, yaw_deg, Vector3(0.0, top + 1.2, 0.0))), Vector3(2.4, 2.4, 2.4), 0.03, false)
	kb.box(KitMaterials.FLAT_GLASS, Transform3D(orientation, _world(pos, yaw_deg, Vector3(1.22, top + 1.6, 0.0))), Vector3(0.04, 1.2, 1.8), 0.0, false)
	kb.box(mat, Transform3D(orientation, _world(pos, yaw_deg, Vector3(0.0, top + 3.2, 0.0))), Vector3(0.6, 2.4, 0.6), 0.0, false)
	var jib_y_low: float = top + 2.2
	var jib_y_top: float = top + 3.9
	var counter: float = jib_len * 0.32
	for sz: float in [-0.5, 0.5]:
		ZoneParts.beam(kb, mat, _world(pos, yaw_deg, Vector3(-counter, jib_y_low, sz)), _world(pos, yaw_deg, Vector3(jib_len, jib_y_low, sz)), 0.18)
	ZoneParts.beam(kb, steel, _world(pos, yaw_deg, Vector3(-counter, jib_y_low, 0.0)), _world(pos, yaw_deg, Vector3(0.0, jib_y_top, 0.0)), 0.14)
	ZoneParts.beam(kb, steel, _world(pos, yaw_deg, Vector3(0.0, jib_y_top, 0.0)), _world(pos, yaw_deg, Vector3(jib_len, jib_y_low, 0.0)), 0.14)
	var s: float = 0.0
	while s < jib_len - 3.0:
		ZoneParts.beam(kb, steel, _world(pos, yaw_deg, Vector3(s, jib_y_low, -0.5)), _world(pos, yaw_deg, Vector3(s + 1.5, jib_y_low, 0.5)), 0.08)
		ZoneParts.beam(kb, steel, _world(pos, yaw_deg, Vector3(s + 1.5, jib_y_low, 0.5)), _world(pos, yaw_deg, Vector3(s + 3.0, jib_y_low, -0.5)), 0.08)
		s += 3.0
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, Transform3D(orientation, _world(pos, yaw_deg, Vector3(-counter + 1.4, jib_y_low - 0.9, 0.0))), Vector3(2.6, 1.8, 2.0), 0.03, false)
	var trolley: float = jib_len * 0.6
	kb.box(steel, Transform3D(orientation, _world(pos, yaw_deg, Vector3(trolley, jib_y_low - 0.35, 0.0))), Vector3(1.2, 0.6, 1.4), 0.0, false)
	kb.box(steel, Transform3D(orientation, _world(pos, yaw_deg, Vector3(trolley, jib_y_low - 8.0, 0.0))), Vector3(0.05, 15.0, 0.05), 0.0, false)
	kb.box(KitMaterials.RUST, Transform3D(orientation, _world(pos, yaw_deg, Vector3(trolley, jib_y_low - 15.6, 0.0))), Vector3(0.7, 0.9, 0.5), 0.0, false)


## 격자 철탑: 위로 갈수록 좁아지는 4다리 + 단마다 가로·사선, 꼭대기 케이지. 충돌은 밑동 상자 (옛과 같다).
static func _lattice_tower(kb: KitBuild, pos: Vector3, height: float) -> void:
	var base_w: float = 3.4
	var top_w: float = 0.9
	var bays: int = 11
	var prev: Array[Vector3] = []
	var steel: StringName = KitMaterials.FLAT_METAL
	for i: int in range(bays + 1):
		var t: float = float(i) / float(bays)
		var w: float = lerpf(base_w, top_w, pow(t, 0.85))
		var y: float = height * t
		var ring: Array[Vector3] = [Vector3(-w, y, -w), Vector3(w, y, -w), Vector3(w, y, w), Vector3(-w, y, w)]
		for k: int in range(4):
			ZoneParts.beam(kb, steel, pos + ring[k], pos + ring[(k + 1) % 4], 0.12)
		if i > 0:
			for k: int in range(4):
				ZoneParts.beam(kb, KitMaterials.BEAM_TEAL, pos + prev[k], pos + ring[k], 0.2)
				ZoneParts.beam(kb, steel, pos + prev[k], pos + ring[(k + 1) % 4], 0.09)
		prev = ring
	kb.collide_box(KitParts.at(pos + Vector3(0.0, 3.0, 0.0)), Vector3(3.0, 6.0, 3.0))
	kb.box(steel, KitParts.at(pos + Vector3(0.0, height + 0.3, 0.0)), Vector3(2.4, 0.15, 2.4), 0.0, false)
	for k: int in range(4):
		var c: Vector3 = prev[k]
		kb.box(steel, KitParts.at(pos + Vector3(c.x * 1.3, height + 1.0, c.z * 1.3)), Vector3(0.06, 1.4, 0.06), 0.0, false)
	kb.box(steel, KitParts.at(pos + Vector3(0.0, height + 3.0, 0.0)), Vector3(0.12, 5.0, 0.12), 0.0, false)
	# 꼭대기 항공 표지등 (발광, 빛은 달지 않는다)
	kb.box(KitMaterials.FLUORO, KitParts.at(pos + Vector3(0.0, height + 5.6, 0.0)), Vector3(0.2, 0.2, 0.2), 0.0, false)


# --- 감시탑 ---

## 북서쪽 감시탑: 경사로 A(서쪽 도로에서) -> 중간 승강대 -> 경사로 B(북쪽) -> 높이 9 m 전망 데크. 옛 IndustrialSite._watchtower와 같은 충돌.
static func _watchtower(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("infra_watchtower")
	var deck_y: float = 9.0
	var mid_y: float = 4.5
	var steel: StringName = KitMaterials.METAL_PLATE
	var dark: StringName = KitMaterials.FLAT_CONCRETE_DARK
	# 전망 데크 + 모서리 기둥 + 가로·사선 보강
	kb.box(steel, KitParts.at(Vector3(-58.0, deck_y - 0.15, -62.0)), Vector3(7.0, 0.3, 7.0), 0.0, true, KitLayout.TREAD)
	for corner: Vector2 in [Vector2(-61.2, -65.2), Vector2(-54.8, -65.2), Vector2(-61.2, -58.8), Vector2(-54.8, -58.8)]:
		kb.box(dark, KitParts.at(Vector3(corner.x, (deck_y - 0.3) * 0.5, corner.y)), Vector3(0.5, deck_y - 0.3, 0.5), 0.0, true)
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(corner.x, 0.0, corner.y), Vector3(0.7, 0.8, 0.7), 0.0, false, KitLayout.SILL)
	for x: float in [-61.2, -54.8]:
		ZoneParts.beam(kb, KitMaterials.BEAM_YELLOW, Vector3(x, 1.0, -65.2), Vector3(x, deck_y - 0.4, -58.8), 0.18)
		ZoneParts.beam(kb, KitMaterials.BEAM_YELLOW, Vector3(x, 1.0, -58.8), Vector3(x, deck_y - 0.4, -65.2), 0.18)
	# 난간 벽 (엄폐): 북·동·서 + 남쪽은 경사로 입구를 남긴다 (충돌)
	for r: Rect2 in [Rect2(-61.5, -65.5, 7.0, 0.3), Rect2(-61.5, -65.5, 0.3, 7.0), Rect2(-54.8, -65.5, 0.3, 7.0),
			Rect2(-61.5, -58.8, 1.5, 0.3), Rect2(-57.0, -58.8, 2.5, 0.3)]:
		kb.box(dark, KitParts.at(Vector3(r.position.x + r.size.x * 0.5, deck_y + 0.55, r.position.y + r.size.y * 0.5)), Vector3(r.size.x, 1.1, r.size.y), 0.0, true)
		kb.block(KitMaterials.SILL, Vector3(r.position.x + r.size.x * 0.5, deck_y + 1.1, r.position.y + r.size.y * 0.5),
				Vector3(r.size.x + 0.1, 0.12, r.size.y + 0.1), 0.0, false)
	# 지붕 + 기둥 (충돌 없음)
	kb.box(KitMaterials.FLAT_ROOF, KitParts.at(Vector3(-58.0, deck_y + 3.55, -62.0)), Vector3(8.6, 0.3, 8.6), 0.0, false)
	for corner: Vector2 in [Vector2(-61.2, -65.2), Vector2(-54.8, -65.2)]:
		kb.box(KitMaterials.FLAT_METAL, KitParts.at(Vector3(corner.x, deck_y + 1.7, corner.y)), Vector3(0.25, 3.4, 0.25), 0.0, false)
	# 경사로 B (승강대 -> 데크), 중간 승강대 + 받침, 경사로 A (서쪽 도로 -> 승강대)
	ZoneParts.ramp_z(kb, -58.5, 2.6, -48.5, -58.5, mid_y, deck_y, steel, 0.3, KitLayout.TREAD)
	kb.box(steel, KitParts.at(Vector3(-58.5, mid_y - 0.15, -46.75)), Vector3(7.0, 0.3, 3.5), 0.0, true, KitLayout.TREAD)
	for corner: Vector2 in [Vector2(-61.7, -45.3), Vector2(-55.3, -45.3)]:
		kb.box(dark, KitParts.at(Vector3(corner.x, (mid_y - 0.3) * 0.5, corner.y)), Vector3(0.4, mid_y - 0.3, 0.4), 0.0, true)
	ZoneParts.ramp_x(kb, -46.8, 2.6, -71.0, -62.0, 0.0, mid_y, steel, 0.3, KitLayout.TREAD)
	# 경사로 손잡이 (충돌 없음)
	for sz: float in [-1.4, 1.4]:
		KitParts.railing(kb, KitMaterials.BEAM_YELLOW, Vector3(-71.0, 0.0, -46.8 + sz), Vector3(-62.0, mid_y, -46.8 + sz), 1.0, 3.0)
	for sx: float in [-1.4, 1.4]:
		KitParts.railing(kb, KitMaterials.BEAM_YELLOW, Vector3(-58.5 + sx, mid_y, -48.5), Vector3(-58.5 + sx, deck_y, -58.5), 1.0, 3.3)
	# 엄폐 상자 (옛 cover_box 2.4 x 1 x 1, 콘크리트) + 표지
	kb.box(dark, KitParts.at(Vector3(-62.0, 0.5, -55.0)), Vector3(2.4, 1.0, 1.0), 0.02, true)
	kb.block(KitMaterials.HAZARD, Vector3(-62.0, 1.0, -55.0), Vector3(2.4, 0.01, 0.4), 0.0, false)
