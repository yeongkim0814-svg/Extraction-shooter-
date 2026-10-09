class_name ZoneParts
extends RefCounted
## 구역 정의가 같이 쓰는 맞춤 지오메트리 도우미 (부품 라이브러리에 없는 이 맵 전용 큰 덩어리): 벽돌 굴뚝, 큰 탱크, 건물 덩어리,
## 창, 옥상 설비. 전부 KitBuild에 도형을 쌓는다. 넓은 면은 단색 재질, 트림은 마디·띠·틀에만 쓴다 (ART.md 11.3).


## 중심 변환 상자 (모따기·충돌 기본 없음).
static func slab(kb: KitBuild, id: StringName, xf: Transform3D, local_center: Vector3, size: Vector3) -> void:
	kb.box(id, xf * Transform3D(Basis.IDENTITY, local_center), size, 0.0, false)


## 건물 덩어리 한 채: 단색 몸통 + 아래 굽(트림) + 윗단 어두운 띠 + 갓돌. rect = x, z 범위 (Rect2: position = 최소, size = 폭·깊이).
## collide가 true면 몸통 크기 충돌 상자 하나.
static func block_building(kb: KitBuild, rect: Rect2, height: float, y0: float = 0.0, body: StringName = KitMaterials.FLAT_CONCRETE,
		collide: bool = true) -> void:
	var c := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	var w: float = rect.size.x
	var d: float = rect.size.y
	kb.box(body, KitParts.at(Vector3(c.x, y0 + height * 0.5, c.y)), Vector3(w, height, d), 0.0, false)
	# 굽 (트림, 높이 1.2): 위쪽은 SILL 줄
	kb.block(KitMaterials.CONCRETE_WALL, Vector3(c.x, y0, c.y), Vector3(w + 0.16, 1.2, d + 0.16), 0.0, false, KitLayout.SILL)
	# 윗단 어두운 띠 (처마 밑) + 갓돌
	kb.block(KitMaterials.FLAT_CONCRETE_DARK, Vector3(c.x, y0 + height - 2.0, c.y), Vector3(w + 0.1, 1.7, d + 0.1), 0.0, false)
	kb.block(KitMaterials.SILL, Vector3(c.x, y0 + height - 0.3, c.y), Vector3(w + 0.5, 0.3, d + 0.5), 0.0, false)
	if collide:
		kb.collide_box(KitParts.at(Vector3(c.x, y0 + height * 0.5, c.y)), Vector3(w, height, d))


## 가로 띠 (벽돌 줄 높이 0.56 = 늘어나지 않는 자연 높이). 네 면을 두른다.
static func belt(kb: KitBuild, rect: Rect2, y: float, id: StringName = KitMaterials.BRICK, out: float = 0.06, h: float = 0.56) -> void:
	var c := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y * 0.5)
	kb.block(id, Vector3(c.x, y, c.y), Vector3(rect.size.x + out * 2.0, h, rect.size.y + out * 2.0), 0.0, false)


## 벽에 붙는 창 하나. xf = 벽면 위 창 가운데 (로컬 +Z = 바깥). 강철 틀 + 십자 창살 + 어두운 유리 + 아래 턱.
static func window(kb: KitBuild, xf: Transform3D, w: float = 2.4, h: float = 1.5, frame: StringName = KitMaterials.METAL_PLATE) -> void:
	var f: float = 0.08
	slab(kb, KitMaterials.FLAT_GLASS, xf, Vector3(0.0, 0.0, 0.01), Vector3(w, h, 0.02))
	slab(kb, frame, xf, Vector3(0.0, h * 0.5 + f * 0.5, 0.05), Vector3(w + f * 2.0, f, 0.12))
	slab(kb, frame, xf, Vector3(0.0, -h * 0.5 - f * 0.5, 0.05), Vector3(w + f * 2.0, f, 0.12))
	for sx: float in [-1.0, 1.0]:
		slab(kb, frame, xf, Vector3(sx * (w * 0.5 + f * 0.5), 0.0, 0.05), Vector3(f, h, 0.12))
	slab(kb, frame, xf, Vector3(0.0, 0.0, 0.04), Vector3(0.05, h, 0.06))
	slab(kb, frame, xf, Vector3(0.0, 0.0, 0.04), Vector3(w, 0.05, 0.06))
	slab(kb, KitMaterials.SILL, xf, Vector3(0.0, -h * 0.5 - f - 0.05, 0.1), Vector3(w + 0.3, 0.1, 0.25))


## 창 줄: 벽 한 면에 같은 높이로 n개. start = 첫 창 가운데 (벽면 위), step = 다음 창으로 가는 벡터, yaw = 바깥 방향 (0 = +Z).
static func window_row(kb: KitBuild, start: Vector3, step: Vector3, count: int, yaw_deg: float, w: float = 2.4, h: float = 1.5) -> void:
	for i: int in range(count):
		window(kb, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), start + step * float(i)), w, h)


## 옥상 설비 상자 (환기구 격자 한 면 포함).
static func rooftop_unit(kb: KitBuild, rect: Rect2, y: float, height: float) -> void:
	var c := Vector3(rect.position.x + rect.size.x * 0.5, y, rect.position.y + rect.size.y * 0.5)
	kb.block(KitMaterials.FLAT_METAL, c, Vector3(rect.size.x, height, rect.size.y), 0.0, false)
	kb.block(KitMaterials.SILL, c + Vector3(0.0, height, 0.0), Vector3(rect.size.x + 0.2, 0.12, rect.size.y + 0.2), 0.0, false)
	kb.block(KitMaterials.VENT, c + Vector3(0.0, 0.5, rect.size.y * 0.5 + 0.02), Vector3(minf(rect.size.x - 0.6, 2.4), height - 0.9, 0.04), 0.0, false)
	kb.block(KitMaterials.DUCT, c + Vector3(rect.size.x * 0.5 + 0.02, 0.5, 0.0), Vector3(0.04, height - 0.9, minf(rect.size.y - 0.6, 2.4)), 0.0, false)


## 키 큰 굴뚝: 밑동(콘크리트) + 벽돌 마디(아래) + 단색 몸통(위) + 쇠 띠 + 위 테두리. r0 -> r1은 밑에서 꼭대기까지 선형.
## 벽돌 줄이 늘어나지 않도록 마디는 0.75 m 간격. bands = 꼭대기 쪽 빨강·흰 띠를 두를 높이 (0 = 없음).
## 충돌은 밑동 상자 하나 (collide_h 높이, 폭 collide_w).
static func smokestack(kb: KitBuild, base: Vector3, total: float, r0: float, r1: float, brick_h: float, bands: float,
		collide_w: float, collide_h: float) -> void:
	var base_h: float = 1.6
	kb.block(KitMaterials.CONCRETE_WALL, base, Vector3(r0 * 2.0 + 0.5, base_h, r0 * 2.0 + 0.5), KitBuild.BEVEL_LARGE, false, KitLayout.SILL)
	var rim_h: float = 0.5
	var body_top: float = total - rim_h
	# 벽돌 마디
	kb.use(KitMaterials.BRICK)
	var seg: float = 0.75
	var n: int = maxi(int(roundf((brick_h - base_h) / seg)), 1)
	var step: float = (brick_h - base_h) / float(n)
	for i: int in range(n):
		var ya: float = base_h + step * float(i)
		var yb: float = ya + step
		kb.mesh.add_revolve(KitParts.at(base), PackedVector2Array([Vector2(lerpf(r0, r1, (ya) / total), ya), Vector2(lerpf(r0, r1, (yb) / total), yb)]), 14)
	# 단색 몸통 (벽돌 위 -> 꼭대기 테두리 아래), 띠 구간은 따로
	var flat_top: float = body_top - bands
	kb.use(KitMaterials.FLAT_CONCRETE_DARK)
	var upper: PackedVector2Array = PackedVector2Array([Vector2(lerpf(r0, r1, (brick_h) / total), brick_h), Vector2(lerpf(r0, r1, (flat_top) / total), flat_top)])
	kb.mesh.add_revolve(KitParts.at(base), upper, 14)
	# 꼭대기 빨강·흰 띠 (4 m씩)
	if bands > 0.0:
		var count: int = int(roundf(bands / 4.0))
		var bh: float = bands / float(count)
		for b: int in range(count):
			var ya: float = flat_top + bh * float(b)
			var yb: float = ya + bh
			kb.use(KitMaterials.BAND_RED if b % 2 == 0 else KitMaterials.BAND_WHITE)
			kb.mesh.add_revolve(KitParts.at(base), PackedVector2Array([Vector2(lerpf(r0, r1, (ya) / total) + 0.03, ya),
					Vector2(lerpf(r0, r1, (yb) / total) + 0.03, yb)]), 14)
	# 쇠 띠 (간격 약 8 m)
	var y: float = brick_h + 3.0
	while y < body_top - 1.0:
		kb.cylinder(KitMaterials.FLAT_METAL, Transform3D(Basis.IDENTITY, base + Vector3(0.0, y, 0.0)), lerpf(r0, r1, (y) / total) + 0.06, 0.12, 14, 0.0, false, false)
		y += 8.0
	# 위 테두리: 위로 벌어진 띠 + 안쪽 어두운 뚜껑
	var rt: float = lerpf(r0, r1, (body_top) / total)
	kb.use(KitMaterials.SILL)
	kb.mesh.add_cylinder(Transform3D(Basis.IDENTITY, base + Vector3(0.0, body_top + rim_h * 0.5, 0.0)), rt + 0.05, rim_h, 14, 0.0, rt + 0.35)
	kb.cylinder(KitMaterials.FLAT_CONCRETE_DARK, Transform3D(Basis.IDENTITY, base + Vector3(0.0, total - 0.04, 0.0)), rt + 0.1, 0.02, 14, 0.0, false, false)
	kb.collide_box(KitParts.at(base + Vector3(0.0, collide_h * 0.5, 0.0)), Vector3(collide_w, collide_h, collide_w))


## 큰 세로 탱크: 콘크리트 받침 + 단색 몸통(낮은 원뿔 지붕까지 회전체 하나) + 이음 띠 + 사다리. 충돌 = 몸통 바깥 상자.
## collide_w = 충돌 상자 폭 (0 = 충돌 없음). body = 몸통 단색 재질. band_id = 위쪽 도장 띠 (BAND_RED 등, 빈 이름이면 없음).
static func tank(kb: KitBuild, base: Vector3, r: float, h: float, body: StringName, sides: int = 20, band_id: StringName = &"",
		ladder_yaw_deg: float = 0.0, collide_w: float = 0.0) -> void:
	var base_h: float = 0.5
	kb.cylinder(KitMaterials.CONCRETE_WALL, Transform3D(Basis.IDENTITY, base + Vector3(0.0, base_h * 0.5, 0.0)), r + 0.15, base_h, sides, 0.04, false, false)
	kb.use(body)
	kb.mesh.add_revolve(KitParts.at(base), PackedVector2Array([Vector2(0.0, base_h), Vector2(r, base_h), Vector2(r, h - 0.6),
			Vector2(r * 0.18, h), Vector2(0.0, h)]), sides)
	# 이음 띠 (약 3 m 간격)
	var y: float = base_h + 2.4
	while y < h - 1.0:
		kb.cylinder(KitMaterials.FLAT_METAL, Transform3D(Basis.IDENTITY, base + Vector3(0.0, y, 0.0)), r + 0.03, 0.08, sides, 0.0, false, false)
		y += 3.0
	if band_id != &"":
		kb.cylinder(band_id, Transform3D(Basis.IDENTITY, base + Vector3(0.0, h - 1.6, 0.0)), r + 0.05, 0.9, sides, 0.0, false, false)
	# 사다리 (바깥 +Z 방향을 yaw만큼 돌려서)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(ladder_yaw_deg)), base)
	var zl: float = r + 0.2
	for sx: float in [-1.0, 1.0]:
		kb.box(KitMaterials.BEAM_YELLOW, xf * Transform3D(Basis.IDENTITY, Vector3(sx * 0.25, (base_h + h - 0.6) * 0.5, zl)), Vector3(0.05, h - 1.1, 0.05), 0.0, false)
	var rung: float = base_h + 0.6
	while rung < h - 1.2:
		kb.box(KitMaterials.FLAT_METAL, xf * Transform3D(Basis.IDENTITY, Vector3(0.0, rung, zl)), Vector3(0.5, 0.03, 0.03), 0.0, false)
		rung += 0.5
	# 충돌: collide_w가 0이면 없음 (맵 코드가 따로 둔다), 아니면 상자 하나
	if collide_w > 0.0:
		kb.collide_box(KitParts.at(base + Vector3(0.0, h * 0.5, 0.0)), Vector3(collide_w, h, collide_w))


## 직선 벽 (옛 IndustrialMap.wall_x/wall_z와 같은 충돌): 고정 좌표 fixed, a~b 구간, 바닥 높이 y0, 높이 h, 두께 t, openings = Vector2(중심, 폭), 문 높이 door_h.
## along_x가 true면 x 방향 벽 (z = fixed), false면 z 방향 벽 (x = fixed). 문 둘레는 frame 재질 틀 (hazard면 문턱 경고 띠).
## plinth = 아래 콘크리트 굽, cap = 위 갓돌. 몸통은 panel 재질 (골함석은 세로 줄이라 세로로 늘어나도 괜찮다).
static func panel_wall(kb: KitBuild, along_x: bool, fixed: float, a: float, b: float, h: float, t: float, panel: StringName,
		openings: Array[Vector2], door_h: float, y0: float = 0.0, frame: StringName = KitMaterials.BEAM_YELLOW, hazard: bool = true,
		plinth: bool = true, cap: bool = true) -> void:
	var sorted: Array[Vector2] = openings.duplicate()
	sorted.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var cursor: float = a
	var solid: Array[Vector2] = []   # (시작, 끝) 통짜 구간 (전체 높이)
	var lintels: Array[Vector2] = []  # 문 위
	for o: Vector2 in sorted:
		solid.append(Vector2(cursor, o.x - o.y * 0.5))
		lintels.append(Vector2(o.x - o.y * 0.5, o.x + o.y * 0.5))
		cursor = o.x + o.y * 0.5
	solid.append(Vector2(cursor, b))
	for seg: Vector2 in solid:
		_wall_box(kb, along_x, fixed, seg.x, seg.y, y0, y0 + h, t, panel, true)
		if plinth and seg.y - seg.x > 0.5:
			_wall_box(kb, along_x, fixed, seg.x, seg.y, y0, y0 + 0.6, t + 0.08, KitMaterials.CONCRETE_WALL, false)
	for seg: Vector2 in lintels:
		_wall_box(kb, along_x, fixed, seg.x, seg.y, y0 + door_h, y0 + h, t, panel, true)
		for edge: float in [seg.x, seg.y]:
			_wall_box(kb, along_x, fixed, edge - 0.1, edge + 0.1, y0, y0 + door_h, t + 0.1, frame, false)
		_wall_box(kb, along_x, fixed, seg.x - 0.1, seg.y + 0.1, y0 + door_h - 0.2, y0 + door_h, t + 0.1, frame, false)
		if hazard:
			_wall_box(kb, along_x, fixed, seg.x, seg.y, y0, y0 + 0.02, t + 0.3, KitMaterials.HAZARD, false)
	if cap:
		_wall_box(kb, along_x, fixed, a - 0.1, b + 0.1, y0 + h - 0.2, y0 + h, t + 0.12, KitMaterials.SILL, false)


static func _wall_box(kb: KitBuild, along_x: bool, fixed: float, a: float, b: float, y0: float, y1: float, t: float, id: StringName,
		collide: bool) -> void:
	if b - a < 0.01 or y1 - y0 < 0.005:
		return
	var center := Vector3((a + b) * 0.5, (y0 + y1) * 0.5, fixed) if along_x else Vector3(fixed, (y0 + y1) * 0.5, (a + b) * 0.5)
	var size := Vector3(b - a, y1 - y0, t) if along_x else Vector3(t, y1 - y0, b - a)
	kb.box(id, KitParts.at(center), size, 0.0, collide)


## z 방향 경사로 (IndustrialMap.ramp_z와 같은 기울기·충돌). z_low에서 높이 y_low, z_high에서 y_high. 윗면 재질 id, 윗면 줄 top_strip.
static func ramp_z(kb: KitBuild, x: float, width: float, z_low: float, z_high: float, y_low: float, y_high: float, id: StringName,
		thick: float = 0.3, top_strip: StringName = &"") -> void:
	var run: float = absf(z_high - z_low)
	var rise: float = y_high - y_low
	var angle: float = atan2(absf(rise), run)
	var length: float = sqrt(run * run + rise * rise)
	var sign_value: float = -1.0 if z_high < z_low else 1.0
	var tilt: float = angle * (-sign_value) * (1.0 if rise > 0.0 else -1.0)
	var mid_y: float = (y_low + y_high) * 0.5 - thick * 0.5 / cos(angle)
	kb.box(id, Transform3D(Basis(Vector3.RIGHT, tilt), Vector3(x, mid_y, (z_low + z_high) * 0.5)), Vector3(width, thick, length), 0.0, true, top_strip)


## x 방향 경사로 (IndustrialMap.ramp_x와 같은 기울기·충돌).
static func ramp_x(kb: KitBuild, z: float, width: float, x_low: float, x_high: float, y_low: float, y_high: float, id: StringName,
		thick: float = 0.3, top_strip: StringName = &"") -> void:
	var run: float = absf(x_high - x_low)
	var rise: float = y_high - y_low
	var angle: float = atan2(absf(rise), run)
	var length: float = sqrt(run * run + rise * rise)
	var toward_east: float = 1.0 if x_high > x_low else -1.0
	var tilt: float = angle * toward_east * (1.0 if rise > 0.0 else -1.0)
	var mid_y: float = (y_low + y_high) * 0.5 - thick * 0.5 / cos(angle)
	kb.box(id, Transform3D(Basis(Vector3.BACK, tilt), Vector3((x_low + x_high) * 0.5, mid_y, z)), Vector3(length, thick, width), 0.0, true, top_strip)


## 책상: 상판 + 양옆 판 + 서랍 (충돌 = 전체 상자 size). 로컬 x가 길이.
static func desk(kb: KitBuild, pos: Vector3, size: Vector3) -> void:
	var f: StringName = KitMaterials.FLAT_WOOD
	kb.box(f, KitParts.at(pos + Vector3(0.0, size.y - 0.04, 0.0)), Vector3(size.x, 0.08, size.z), 0.01, false)
	for sx: float in [-1.0, 1.0]:
		kb.box(f, KitParts.at(pos + Vector3(sx * (size.x * 0.5 - 0.04), (size.y - 0.08) * 0.5, 0.0)), Vector3(0.08, size.y - 0.08, size.z - 0.06), 0.0, false)
	kb.box(KitMaterials.CABINET_GREY, KitParts.at(pos + Vector3(size.x * 0.25, (size.y - 0.08) * 0.5, 0.0)), Vector3(size.x * 0.4, size.y - 0.1, size.z - 0.1), 0.01, false)
	kb.collide_box(KitParts.at(pos + Vector3(0.0, size.y * 0.5, 0.0)), size)


## a에서 b까지 이어지는 가는 각재 (격자 탑·크레인 붐·사선 보강용, 모따기 없음). collide가 true면 같은 상자로 충돌도.
static func beam(kb: KitBuild, id: StringName, a: Vector3, b: Vector3, thick: float, collide: bool = false) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.01:
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	kb.box(id, Transform3D(Basis.looking_at(dir.normalized(), up), (a + b) * 0.5), Vector3(thick, thick, length), 0.0, collide)
