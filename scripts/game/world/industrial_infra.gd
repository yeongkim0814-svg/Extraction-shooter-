class_name IndustrialInfra
extends RefCounted
## 단지 기반 시설: 지면·외곽 담장·도로 순환로·웅덩이, 철길(동쪽 가장자리), 배관 랙, 타워 크레인 2기, 철탑,
## 먼 풍경(충돌 없는 평평한 실루엣: 굴뚝·크레인·숲·낮은 산).

const GROUND: StringName = IndustrialMaterials.GROUND
const ASPHALT: StringName = IndustrialMaterials.ASPHALT
const CONCRETE: StringName = IndustrialMaterials.CONCRETE
const CONCRETE_DARK: StringName = IndustrialMaterials.CONCRETE_DARK
const CORRUGATED: StringName = IndustrialMaterials.CORRUGATED
const STEEL: StringName = IndustrialMaterials.STEEL
const RUST: StringName = IndustrialMaterials.RUST
const WOOD: StringName = IndustrialMaterials.WOOD
const PUDDLE: StringName = IndustrialMaterials.PUDDLE
const PAINT_WHITE: StringName = IndustrialMaterials.PAINT_WHITE
const SILHOUETTE: StringName = IndustrialMaterials.SILHOUETTE
const SILHOUETTE_FAR: StringName = IndustrialMaterials.SILHOUETTE_FAR
const HALF: float = IndustrialMap.HALF
const RAIL_X: float = 81.9


# --- 지면·담장·도로 ---

static func build_ground(m: IndustrialMap) -> void:
	m.box(Vector3(0, -0.2, 0), Vector3(HALF * 2.0, 0.4, HALF * 2.0), GROUND)
	_perimeter(m)
	# 콘크리트 판 (야적장·공장 앞마당·창고 앞)
	m.overlay(6.0, 38.0, -27.0, 33.0, CONCRETE, 0.0)
	m.overlay(-46.0, 12.0, -48.0, -37.0, CONCRETE, 0.0)
	m.overlay(-70.0, -52.0, 5.0, 24.0, CONCRETE, 0.0)
	# 도로 순환로 (폭 8 m)
	m.overlay(-78.0, 78.0, -46.0, -38.0, ASPHALT)
	m.overlay(-78.0, 78.0, 64.0, 72.0, ASPHALT)
	m.overlay(-78.0, -70.0, -46.0, 72.0, ASPHALT)
	m.overlay(70.0, 78.0, -46.0, 72.0, ASPHALT)
	m.overlay(-4.0, 4.0, -38.0, 64.0, ASPHALT)       # 중앙 남북 도로
	m.overlay(-5.0, 5.0, 72.0, HALF - 1.0, ASPHALT)  # 정문 진입로
	m.overlay(-66.0, -22.0, 30.0, 62.0, ASPHALT)     # 주차장
	m.overlay(36.0, 70.0, -12.0, 6.0, ASPHALT)       # 창고 사이 도로
	# 중앙 도로 점선
	var z: float = -34.0
	while z < 60.0:
		m.overlay(-0.08, 0.08, z, z + 1.8, PAINT_WHITE, 0.01)
		z += 4.0
	_puddles(m)
	# 잡초 구간 (담장 안쪽 가장자리, 철길 옆, 건물 밑동)
	var e: float = HALF - 1.6
	m.weed_lines.append_array([Vector3(-e, 0, -e), Vector3(e, 0, -e), Vector3(-e, 0, e), Vector3(-7, 0, e),
			Vector3(7, 0, e), Vector3(e, 0, e), Vector3(-e, 0, -e), Vector3(-e, 0, e), Vector3(e, 0, -e),
			Vector3(e, 0, e), Vector3(78.6, 0, -80), Vector3(78.6, 0, 80), Vector3(-44, 0, -46.5), Vector3(8, 0, -46.5),
			Vector3(6, 0, -27), Vector3(38, 0, -27), Vector3(6, 0, 33), Vector3(38, 0, 33), Vector3(-66, 0, 63),
			Vector3(-22, 0, 63), Vector3(40, 0, -11), Vector3(68, 0, -11), Vector3(-80, 0, -37), Vector3(-80, 0, 60)])


static func _perimeter(m: IndustrialMap) -> void:
	var t: float = 1.0
	var h: float = IndustrialMap.WALL_H
	m.span(-HALF - t, HALF + t, 0.0, h, -HALF - t, -HALF, CONCRETE_DARK)
	m.span(-HALF - t, -7.0, 0.0, h, HALF, HALF + t, CORRUGATED)
	m.span(7.0, HALF + t, 0.0, h, HALF, HALF + t, CORRUGATED)
	m.span(-HALF - t, -HALF, 0.0, h, -HALF, HALF, CORRUGATED)
	m.span(HALF, HALF + t, 0.0, h, -HALF, HALF, CORRUGATED)
	# 기둥(장식, 12 m마다)과 철조망 느낌의 윗선
	var p: float = -HALF + 6.0
	while p < HALF:
		m.box(Vector3(p, h * 0.5, -HALF + 0.05), Vector3(0.7, h + 0.4, 0.5), CONCRETE_DARK, Basis.IDENTITY, false)
		m.box(Vector3(p, h * 0.5, HALF - 0.05), Vector3(0.7, h + 0.4, 0.5), CONCRETE_DARK, Basis.IDENTITY, false)
		m.box(Vector3(-HALF + 0.05, h * 0.5, p), Vector3(0.5, h + 0.4, 0.7), CONCRETE_DARK, Basis.IDENTITY, false)
		m.box(Vector3(HALF - 0.05, h * 0.5, p), Vector3(0.5, h + 0.4, 0.7), CONCRETE_DARK, Basis.IDENTITY, false)
		p += 12.0
	m.span(-HALF, HALF, h + 0.1, h + 0.16, -HALF + 0.1, -HALF + 0.14, STEEL, false, false)


## 웅덩이: 도로·주차장·마당 위에 납작한 타원 원반 (반사가 강한 재질).
static func _puddles(m: IndustrialMap) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424
	var areas: Array[Rect2] = [Rect2(-76, -45, 150, 6), Rect2(-76, 65, 150, 6), Rect2(-77, -40, 6, 100),
			Rect2(71, -40, 6, 100), Rect2(-3, -36, 6, 98), Rect2(-4, 74, 8, 12), Rect2(-64, 31, 40, 30),
			Rect2(38, -11, 30, 16), Rect2(7, -26, 30, 56), Rect2(-44, -47, 50, 8)]
	var counts: Array[int] = [5, 5, 4, 4, 5, 2, 4, 2, 6, 3]
	for i: int in range(areas.size()):
		var r: Rect2 = areas[i]
		for k: int in range(counts[i]):
			var x: float = rng.randf_range(r.position.x, r.end.x)
			var z: float = rng.randf_range(r.position.y, r.end.y)
			var rx: float = rng.randf_range(0.8, 3.2)
			var rz: float = rng.randf_range(0.6, 2.2)
			var yaw: float = rng.randf_range(0.0, PI)
			var orientation: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(rx, 1.0, rz))
			m.cylinder(Vector3(x, IndustrialMap.OVERLAY_Y + 0.011, z), 1.0, 1.0, 0.02, PUDDLE, 14, orientation,
					Vector3.ZERO, false, true)


# --- 철길·배관 랙·크레인·철탑 ---

static func build(m: IndustrialMap) -> void:
	_railway(m)
	_rack_x(m, -40.0, 40.0, -31.0)
	_rack_z(m, -64.0, -10.0, -52.0)
	_rack_x(m, 44.0, 80.0, 40.0)
	_tower_crane(m, Vector3(56.0, 0.0, -48.0), 38.0, 30.0, 180.0)
	_tower_crane(m, Vector3(60.0, 0.0, 52.0), 30.0, 24.0, 205.0)
	_lattice_tower(m, Vector3(73.0, 0.0, -52.0), 44.0)


static func _railway(m: IndustrialMap) -> void:
	var z0: float = -HALF + 4.0
	var z1: float = HALF - 4.0
	var length: float = z1 - z0
	m.span(RAIL_X - 2.8, RAIL_X + 2.8, 0.0, 0.07, z0, z1, CONCRETE_DARK, false, false)   # 자갈 도상
	for dx: float in [-0.72, 0.72]:
		m.span(RAIL_X + dx - 0.06, RAIL_X + dx + 0.06, 0.15, 0.3, z0, z1, RUST, false, false)
	# 침목: MultiMesh (인스턴스 하나의 그리기 호출)
	var count: int = int(length / 0.8)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.5, 0.14, 0.28)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	for i: int in range(count):
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(RAIL_X, 0.12, z0 + 0.4 + 0.8 * float(i))))
	var node := MultiMeshInstance3D.new()
	node.name = "Sleepers"
	node.multimesh = multi
	node.material_override = IndustrialMaterials.get_material(WOOD)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(node)
	m.mesh_instance_count += 1
	# 선로 끝 정지대
	m.box(Vector3(RAIL_X, 0.6, z0 - 0.4), Vector3(2.2, 1.2, 0.5), RUST)
	m.box(Vector3(RAIL_X, 0.6, z1 + 0.4), Vector3(2.2, 1.2, 0.5), RUST)
	IndustrialProps.boxcar(m, RAIL_X, -30.0, IndustrialMaterials.CONT_RUST)
	IndustrialProps.boxcar(m, RAIL_X, 22.0, IndustrialMaterials.CONT_TEAL)
	IndustrialProps.boxcar(m, RAIL_X, 68.0, IndustrialMaterials.CONT_RED)
	m.loot(LootContainer.Kind.CRATE, Vector3(78.6, 0.0, 34.0), 0.0)


## 동서로 뻗은 배관 랙 (x0~x1, 중심 z): 10 m마다 문형 프레임 + 파이프 3줄.
static func _rack_x(m: IndustrialMap, x0: float, x1: float, z: float) -> void:
	var x: float = x0
	while x <= x1 + 0.1:
		for dz: float in [-1.1, 1.1]:
			m.box(Vector3(x, 2.9, z + dz), Vector3(0.35, 5.8, 0.35), STEEL)
		m.box(Vector3(x, 5.8, z), Vector3(0.3, 0.35, 2.9), STEEL, Basis.IDENTITY, false)
		m.beam(Vector3(x, 5.6, z - 1.1), Vector3(x, 4.2, z - 1.1 + 0.0), 0.12, STEEL)
		x += 10.0
	m.pipe_x(x0, x1, 6.3, z - 0.8, 0.42, RUST, 10)
	m.pipe_x(x0, x1, 6.2, z + 0.5, 0.3, IndustrialMaterials.CONT_OCHRE, 8)
	m.pipe_x(x0, x1, 7.0, z, 0.25, STEEL, 8)
	m.span(x0, x1, 5.95, 6.0, z + 0.9, z + 1.4, STEEL, false, false)


## 남북으로 뻗은 배관 랙.
static func _rack_z(m: IndustrialMap, z0: float, z1: float, x: float) -> void:
	var z: float = z0
	while z <= z1 + 0.1:
		for dx: float in [-1.1, 1.1]:
			m.box(Vector3(x + dx, 2.9, z), Vector3(0.35, 5.8, 0.35), STEEL)
		m.box(Vector3(x, 5.8, z), Vector3(2.9, 0.35, 0.3), STEEL, Basis.IDENTITY, false)
		z += 9.0
	m.pipe_z(z0, z1, 6.3, x - 0.7, 0.4, RUST, 10)
	m.pipe_z(z0, z1, 6.2, x + 0.6, 0.3, STEEL, 8)
	m.pipe_z(z0, z1, 7.0, x, 0.28, IndustrialMaterials.CONT_OCHRE, 8)


# --- 격자 구조물 ---

static func _world(pos: Vector3, yaw_deg: float, local: Vector3) -> Vector3:
	return pos + Basis(Vector3.UP, deg_to_rad(yaw_deg)) * local


## 타워 크레인: 격자 마스트 + 운전실 + 격자 붐(앞)과 균형추(뒤). 앞(붐 쪽)은 로컬 +x.
static func _tower_crane(m: IndustrialMap, pos: Vector3, mast_h: float, jib_len: float, yaw_deg: float) -> void:
	var mat: StringName = IndustrialMaterials.CONT_OCHRE
	var w: float = 1.0
	var bay: float = 3.0
	var y: float = 0.0
	while y < mast_h - 0.01:
		var y2: float = minf(y + bay, mast_h)
		for sx: float in [-w, w]:
			for sz: float in [-w, w]:
				m.beam(_world(pos, yaw_deg, Vector3(sx, y, sz)), _world(pos, yaw_deg, Vector3(sx, y2, sz)), 0.22, mat)
		# 가로 링 + 면마다 사선
		m.beam(_world(pos, yaw_deg, Vector3(-w, y2, -w)), _world(pos, yaw_deg, Vector3(w, y2, -w)), 0.1, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(-w, y2, w)), _world(pos, yaw_deg, Vector3(w, y2, w)), 0.1, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(-w, y2, -w)), _world(pos, yaw_deg, Vector3(-w, y2, w)), 0.1, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(w, y2, -w)), _world(pos, yaw_deg, Vector3(w, y2, w)), 0.1, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(-w, y, -w)), _world(pos, yaw_deg, Vector3(w, y2, -w)), 0.1, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(w, y, w)), _world(pos, yaw_deg, Vector3(-w, y2, w)), 0.1, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(-w, y, w)), _world(pos, yaw_deg, Vector3(-w, y2, -w)), 0.1, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(w, y, -w)), _world(pos, yaw_deg, Vector3(w, y2, w)), 0.1, STEEL)
		y = y2
	m.collider(pos + Vector3(0, 3.0, 0), Vector3(2.4, 6.0, 2.4))
	# 운전실과 붐
	var top: float = mast_h
	var orientation: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
	m.box(_world(pos, yaw_deg, Vector3(0.0, top + 1.2, 0.0)), Vector3(2.4, 2.4, 2.4), STEEL, orientation, false)
	m.box(_world(pos, yaw_deg, Vector3(1.2, top + 1.6, 1.3)), Vector3(1.4, 1.5, 0.1), IndustrialMaterials.GLASS_DARK,
			orientation, false, false)
	m.box(_world(pos, yaw_deg, Vector3(0.0, top + 3.2, 0.0)), Vector3(0.6, 2.4, 0.6), mat, orientation, false)
	var jib_y_low: float = top + 2.2
	var jib_y_top: float = top + 3.9
	var counter: float = jib_len * 0.32
	for sz: float in [-0.5, 0.5]:
		m.beam(_world(pos, yaw_deg, Vector3(-counter, jib_y_low, sz)), _world(pos, yaw_deg, Vector3(jib_len, jib_y_low, sz)), 0.18, mat)
	m.beam(_world(pos, yaw_deg, Vector3(-counter, jib_y_low, 0.0)), _world(pos, yaw_deg, Vector3(0.0, jib_y_top, 0.0)), 0.14, STEEL)
	m.beam(_world(pos, yaw_deg, Vector3(0.0, jib_y_top, 0.0)), _world(pos, yaw_deg, Vector3(jib_len, jib_y_low, 0.0)), 0.14, STEEL)
	var s: float = 0.0
	while s < jib_len - 3.0:
		m.beam(_world(pos, yaw_deg, Vector3(s, jib_y_low, -0.5)), _world(pos, yaw_deg, Vector3(s + 1.5, jib_y_low, 0.5)), 0.08, STEEL)
		m.beam(_world(pos, yaw_deg, Vector3(s + 1.5, jib_y_low, 0.5)), _world(pos, yaw_deg, Vector3(s + 3.0, jib_y_low, -0.5)), 0.08, STEEL)
		s += 3.0
	m.box(_world(pos, yaw_deg, Vector3(-counter + 1.4, jib_y_low - 0.9, 0.0)), Vector3(2.6, 1.8, 2.0),
			IndustrialMaterials.CONCRETE_DARK, orientation, false)
	# 트롤리와 훅 케이블
	var trolley: float = jib_len * 0.6
	m.box(_world(pos, yaw_deg, Vector3(trolley, jib_y_low - 0.35, 0.0)), Vector3(1.2, 0.6, 1.4), STEEL, orientation, false)
	m.box(_world(pos, yaw_deg, Vector3(trolley, jib_y_low - 8.0, 0.0)), Vector3(0.05, 15.0, 0.05), STEEL, orientation, false, false)
	m.box(_world(pos, yaw_deg, Vector3(trolley, jib_y_low - 15.6, 0.0)), Vector3(0.7, 0.9, 0.5), RUST, orientation, false)


## 송전탑 비슷한 격자 철탑: 위로 갈수록 좁아지는 4다리 + 단마다 가로·사선, 꼭대기 난간.
static func _lattice_tower(m: IndustrialMap, pos: Vector3, height: float) -> void:
	var base_w: float = 3.4
	var top_w: float = 0.9
	var bays: int = 11
	var prev: Array[Vector3] = []
	for i: int in range(bays + 1):
		var t: float = float(i) / float(bays)
		var w: float = lerpf(base_w, top_w, pow(t, 0.85))
		var y: float = height * t
		var ring: Array[Vector3] = [Vector3(-w, y, -w), Vector3(w, y, -w), Vector3(w, y, w), Vector3(-w, y, w)]
		for k: int in range(4):
			m.beam(pos + ring[k], pos + ring[(k + 1) % 4], 0.12, STEEL)
		if i > 0:
			for k: int in range(4):
				m.beam(pos + prev[k], pos + ring[k], 0.2, STEEL)
				m.beam(pos + prev[k], pos + ring[(k + 1) % 4], 0.09, STEEL)
		prev = ring
	m.collider(pos + Vector3(0, 3.0, 0), Vector3(3.0, 6.0, 3.0))
	# 꼭대기 케이지와 안테나
	m.box(pos + Vector3(0, height + 0.3, 0), Vector3(2.4, 0.15, 2.4), STEEL, Basis.IDENTITY, false)
	for k: int in range(4):
		var c: Vector3 = prev[k]
		m.box(pos + Vector3(c.x * 1.3, height + 1.0, c.z * 1.3), Vector3(0.06, 1.4, 0.06), STEEL, Basis.IDENTITY, false)
	m.box(pos + Vector3(0, height + 3.0, 0), Vector3(0.12, 5.0, 0.12), STEEL, Basis.IDENTITY, false)


# --- 먼 풍경 (충돌 없음, 그림자 없음, 안개에 녹는 평평한 실루엣) ---

static func build_skyline(m: IndustrialMap) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# 먼 산: 큰 반경의 띠 (SILHOUETTE_FAR, 안개에 많이 묻힌다)
	_ridge(m, 380.0, 55.0, 70.0, 0.9, SILHOUETTE_FAR, 3)
	_ridge(m, 250.0, 14.0, 24.0, 1.6, SILHOUETTE, 8)
	# 숲: 층층이 쌓인 삼각형 침엽수 (담장 밖)
	for i: int in range(170):
		var ang: float = TAU * float(i) / 170.0 + rng.randf_range(-0.02, 0.02)
		var r: float = rng.randf_range(104.0, 138.0)
		var h: float = rng.randf_range(10.0, 19.0)
		var w: float = h * rng.randf_range(0.2, 0.3)
		var c := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var side_dir := Vector3(-sin(ang), 0.0, cos(ang))
		for tier: int in range(3):
			var t0: float = float(tier) * 0.28
			var base_y: float = h * t0
			var tier_w: float = w * (1.0 - float(tier) * 0.28)
			var tier_h: float = h * (1.0 - t0)
			m.quad(SILHOUETTE, c + side_dir * -tier_w + Vector3(0, base_y, 0), c + side_dir * tier_w + Vector3(0, base_y, 0),
					c + Vector3(0, base_y + tier_h, 0), c + Vector3(0, base_y + tier_h, 0))
	# 먼 공장과 크레인: 북·동·서쪽
	_far_plant(m, Vector3(-70.0, 0.0, -190.0), 1.0)
	_far_plant(m, Vector3(40.0, 0.0, -215.0), 1.25)
	_far_plant(m, Vector3(215.0, 0.0, -30.0), 1.1)
	_far_plant(m, Vector3(-210.0, 0.0, 60.0), 1.0)
	_far_crane(m, Vector3(-120.0, 0.0, -170.0), 52.0, 20.0)
	_far_crane(m, Vector3(150.0, 0.0, -150.0), 60.0, 26.0)
	_far_crane(m, Vector3(-175.0, 0.0, -40.0), 44.0, 18.0)
	_far_crane(m, Vector3(190.0, 0.0, 90.0), 48.0, 20.0)


## 산등성이 띠: 반지름 radius, 높이 base~peak (노이즈로 들쭉날쭉).
static func _ridge(m: IndustrialMap, radius: float, base_h: float, peak_h: float, freq: float, mat: StringName,
		seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = freq
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var steps: int = 120
	var prev_top: Vector3 = Vector3.ZERO
	var prev_bottom: Vector3 = Vector3.ZERO
	for i: int in range(steps + 1):
		var ang: float = TAU * float(i) / float(steps)
		var n: float = noise.get_noise_2d(cos(ang) * 4.0, sin(ang) * 4.0) * 0.5 + 0.5
		var h: float = lerpf(base_h * 0.5, peak_h, n)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var bottom: Vector3 = dir * radius + Vector3(0, -6.0, 0)
		var top: Vector3 = dir * radius + Vector3(0, h, 0)
		if i > 0:
			m.quad(mat, prev_bottom, bottom, top, prev_top)
		prev_top = top
		prev_bottom = bottom


## 먼 공장 한 무리: 굴뚝 몇 개 + 낮은 건물 덩어리 (평평한 어두운 모양).
static func _far_plant(m: IndustrialMap, center: Vector3, scale: float) -> void:
	var heights: Array[float] = [62.0, 48.0, 70.0, 40.0]
	var xs: Array[float] = [-18.0, -6.0, 8.0, 22.0]
	for i: int in range(4):
		var h: float = heights[i] * scale
		m.cylinder(center + Vector3(xs[i] * scale, h * 0.5, 0.0), 1.6 * scale, 2.6 * scale, h, SILHOUETTE, 8, Basis.IDENTITY,
				Vector3.ZERO, false, false)
	m.box(center + Vector3(0, 11.0 * scale, 0), Vector3(56.0, 22.0, 18.0) * scale, SILHOUETTE, Basis.IDENTITY, false, false)
	m.box(center + Vector3(-30.0 * scale, 7.0 * scale, 6.0), Vector3(24.0, 14.0, 14.0) * scale, SILHOUETTE, Basis.IDENTITY,
			false, false)
	m.box(center + Vector3(0, 28.0 * scale, 0), Vector3(30.0, 12.0, 12.0) * scale, SILHOUETTE, Basis.IDENTITY, false, false)


## 먼 타워 크레인 실루엣: 마스트 + 가로 붐.
static func _far_crane(m: IndustrialMap, base: Vector3, height: float, jib: float) -> void:
	var dir: Vector3 = Vector3(base.x, 0.0, base.z).normalized()
	var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	m.box(base + Vector3(0, height * 0.5, 0), Vector3(1.6, height, 1.6), SILHOUETTE, Basis.IDENTITY, false, false)
	m.beam(base + Vector3(0, height, 0) - side * jib * 0.5, base + Vector3(0, height, 0) + side * jib, 0.9, SILHOUETTE, false, false)
	m.beam(base + Vector3(0, height + 4.0, 0), base + Vector3(0, height, 0) + side * jib * 0.8, 0.4, SILHOUETTE, false, false)
	m.beam(base + Vector3(0, height + 4.0, 0), base + Vector3(0, height, 0) - side * jib * 0.4, 0.4, SILHOUETTE, false, false)
	m.box(base + Vector3(0, height + 2.0, 0), Vector3(0.8, 4.0, 0.8), SILHOUETTE, Basis.IDENTITY, false, false)
