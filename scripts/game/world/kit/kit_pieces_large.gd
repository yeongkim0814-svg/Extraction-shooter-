class_name KitPiecesLarge
extends RefCounted
## 대형 부품 (탱크·배관 랙·컨테이너·차량 등). 원점 = 바닥 중심.


static func build(piece: StringName, kb: KitBuild) -> bool:
	match piece:
		&"container_20ft_red":
			container_20ft(kb, KitMaterials.METAL_CORRUGATED_RED)
		&"container_20ft_teal":
			container_20ft(kb, KitMaterials.METAL_CORRUGATED_TEAL)
		&"container_20ft_olive":
			container_20ft(kb, KitMaterials.METAL_CHIPPED)
		&"car_sedan_teal":
			car_sedan(kb, KitMaterials.METAL_PLATE)
		&"car_sedan_red":
			car_sedan(kb, KitMaterials.BAND_RED)
		&"car_sedan_olive":
			car_sedan(kb, KitMaterials.METAL_CHIPPED)
		&"tank_vertical":
			tank_vertical(kb)
		&"pipe_rack_8m":
			pipe_rack_8m(kb)
		&"chimney":
			chimney(kb)
		&"truck_flatbed":
			truck_flatbed(kb)
		&"forklift":
			forklift(kb)
		&"guard_booth":
			guard_booth(kb)
		_:
			return false
	return true


## 20피트 컨테이너 6.06 (X) x 2.59 (높이) x 2.44 (Z). 문 쪽 = -X 끝. 옆판 재질(panel)만 다르게 두 색이 같은 함수를 쓴다.
static func container_20ft(kb: KitBuild, panel: StringName) -> void:
	var l: float = 6.06
	var h: float = 2.59
	var w: float = 2.44
	var f: StringName = KitMaterials.FLAT_METAL
	var rail: float = 0.12
	# 옆판 두 장 (골함석), 위 덮개, 아래 바닥판 (속이 비어 보이지 않게)
	for sz: float in [-1.0, 1.0]:
		KitParts.plain(kb, panel, Vector3(0.0, 0.1, sz * (w * 0.5 - 0.04)), Vector3(l - rail * 2.0, h - 0.2, 0.05))
	KitParts.plain(kb, panel, Vector3(l * 0.5 - 0.05, 0.1, 0.0), Vector3(0.05, h - 0.2, w - rail * 2.0))
	KitParts.plain(kb, f, Vector3(0.0, h - 0.1, 0.0), Vector3(l - 0.1, 0.06, w - 0.1))
	KitParts.plain(kb, f, Vector3(0.0, 0.1, 0.0), Vector3(l - 0.1, 0.05, w - 0.1))
	# 모서리 기둥 넷 + 위·아래 테두리 (길이·폭 방향)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kb.block(f, Vector3(sx * (l * 0.5 - rail * 0.5), 0.0, sz * (w * 0.5 - rail * 0.5)), Vector3(rail, h, rail), 0.0, false)
	for y: float in [0.0, h - rail]:
		for sz: float in [-1.0, 1.0]:
			kb.block(f, Vector3(0.0, y, sz * (w * 0.5 - rail * 0.5)), Vector3(l - rail * 2.0, rail, rail), 0.0, false)
		for sx: float in [-1.0, 1.0]:
			kb.block(f, Vector3(sx * (l * 0.5 - rail * 0.5), y, 0.0), Vector3(rail, rail, w - rail * 2.0), 0.0, false)
	# 문 끝 (-X): 문짝 두 장 + 가운데 틈 + 잠금봉 넷 + 손잡이
	var dx: float = -l * 0.5 + 0.03
	for sz: float in [-1.0, 1.0]:
		KitParts.plain(kb, panel, Vector3(dx, 0.1, sz * 0.54), Vector3(0.05, h - 0.2, 1.06))
	KitParts.plain(kb, f, Vector3(dx - 0.01, 0.1, 0.0), Vector3(0.05, h - 0.2, 0.04))
	for i: int in range(4):
		var z: float = (float(i) - 1.5) * 0.5
		kb.cylinder(KitMaterials.PIPE_TEAL, KitParts.at(Vector3(dx - 0.05, h * 0.5, z)), 0.018, h - 0.3, 8, 0.0, true, false)
		kb.box(f, KitParts.at(Vector3(dx - 0.085, 1.2, z)), Vector3(0.04, 0.12, 0.05), 0.0, false)
		for y: float in [0.22, h - 0.22]:
			kb.box(f, KitParts.at(Vector3(dx - 0.035, y, z)), Vector3(0.05, 0.06, 0.07), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, h * 0.5, 0.0)), Vector3(l, h, w))


## 수직 저장 탱크: 지름 4 m, 높이 6 m, 24각. 콘크리트 받침 0.4 m, 낮은 원뿔 지붕, 사다리(우리 포함), 플랜지 달린 관 토막.
static func tank_vertical(kb: KitBuild) -> void:
	var r: float = 2.0
	var base_h: float = 0.4
	kb.cylinder(KitMaterials.CONCRETE_WALL, KitParts.at(Vector3(0.0, base_h * 0.5, 0.0)), r + 0.1, base_h, 24, 0.03, false, false)
	# 몸통 + 낮은 원뿔 지붕을 회전체 하나로
	kb.use(KitMaterials.FLAT_TANK_WHITE)
	kb.mesh.add_revolve(Transform3D.IDENTITY, PackedVector2Array([Vector2(0.0, base_h), Vector2(r, base_h), Vector2(r, 5.6),
			Vector2(0.5, 6.0), Vector2(0.0, 6.0)]), 24)
	# 이음 띠 세 줄
	for y: float in [1.7, 3.0, 4.3]:
		kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, y, 0.0)), r + 0.015, 0.05, 24, 0.0, false, false)
	# 사다리 (+Z 면): 세로대·가로대·벽 고정쇠·우리 고리
	var zl: float = r + 0.22
	for sx: float in [-1.0, 1.0]:
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(sx * 0.22, 0.4, zl), Vector3(0.04, 5.3, 0.04), 0.0, false)
		for y: float in [0.9, 2.4, 3.9, 5.2]:
			kb.block(KitMaterials.BEAM_YELLOW, Vector3(sx * 0.22, y, r - 0.02), Vector3(0.04, 0.04, 0.26), 0.0, false)
	for i: int in range(17):
		kb.block(KitMaterials.FLAT_METAL, Vector3(0.0, 0.55 + 0.3 * float(i), zl), Vector3(0.44, 0.025, 0.025), 0.0, false)
	for y: float in [2.6, 3.4, 4.2, 5.0]:
		var hoop: Array[Vector3] = []
		for k: int in range(5):
			var a: float = PI * float(k) / 4.0
			hoop.append(Vector3(cos(a) * 0.4, y, zl + sin(a) * 0.4))
		for k: int in range(4):
			kb.strut(KitMaterials.BEAM_YELLOW, hoop[k], hoop[k + 1], 0.03)
	kb.block(KitMaterials.BEAM_YELLOW, Vector3(0.0, 2.6, zl + 0.4), Vector3(0.03, 2.4, 0.03), 0.0, false)
	# 관 토막 + 플랜지 (수평 반지름 방향)
	var stubs: Array[Vector3] = [Vector3(-60.0, 1.1, 0.12), Vector3(150.0, 4.8, 0.1), Vector3(20.0, 0.9, 0.14)]
	for st: Vector3 in stubs:
		var dir := Vector3(cos(deg_to_rad(st.x)), 0.0, sin(deg_to_rad(st.x)))
		var at_wall: Vector3 = dir * r + Vector3(0.0, st.y, 0.0)
		kb.cylinder(KitMaterials.PIPE_JOINT, KitParts.along(at_wall + dir * 0.3, dir), st.z, 0.6, 10, 0.0, true, false)
		kb.cylinder(KitMaterials.PIPE_JOINT, KitParts.along(at_wall + dir * 0.58, dir), st.z * 1.7, 0.05, 10, 0.0, false, false)
	kb.collide_box(KitParts.at(Vector3(0.0, 3.0, 0.0)), Vector3(3.7, 6.0, 3.7))
	kb.collide_box(KitParts.at(Vector3(0.0, base_h * 0.5, 0.0)), Vector3(4.2, base_h, 4.2))


## 배관 랙 8 m (X): x = +-3.5에 문형 틀(다리 둘 + 위 보 + 중간 보 + 버팀대), 위에 관 세 가닥, 4 m마다 플랜지.
static func pipe_rack_8m(kb: KitBuild) -> void:
	var legs_z: float = 1.5
	var top: float = 5.0
	var m: StringName = KitMaterials.BEAM_TEAL
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * 3.5
		for sz: float in [-1.0, 1.0]:
			kb.block(m, Vector3(x, 0.0, sz * legs_z), Vector3(0.22, top, 0.22), KitBuild.BEVEL_SMALL, true)
			kb.block(KitMaterials.METAL_PLATE, Vector3(x, 0.0, sz * legs_z), Vector3(0.4, 0.04, 0.4), 0.0, false)
		kb.block(m, Vector3(x, top, 0.0), Vector3(0.22, 0.25, legs_z * 2.0 + 0.3), KitBuild.BEVEL_SMALL, false)
		kb.block(m, Vector3(x, 3.4, 0.0), Vector3(0.16, 0.2, legs_z * 2.0 - 0.2), 0.0, false)
		for sz: float in [-1.0, 1.0]:
			kb.strut(m, Vector3(x, 3.4, sz * (legs_z - 0.11)), Vector3(x, top, sz * 0.6), 0.1)
	# 가로 보 (X 방향) 둘: 문형 틀 사이를 이어 준다
	for sz: float in [-1.0, 1.0]:
		kb.box(m, KitParts.at(Vector3(0.0, 3.5, sz * legs_z)), Vector3(7.0, 0.14, 0.14), 0.0, false)
	var radii: Array[float] = [0.25, 0.2, 0.15]
	var ids: Array[StringName] = [KitMaterials.PIPE_RED, KitMaterials.PIPE_TEAL, KitMaterials.PIPE_TEAL]
	var zs: Array[float] = [-0.8, 0.0, 0.8]
	for i: int in range(3):
		var y: float = top + 0.125 + radii[i]
		KitParts.cyl_x(kb, ids[i], Vector3(0.0, y, zs[i]), radii[i], 8.0, 12)
		for fx: float in [-2.0, 2.0]:
			KitParts.cyl_x(kb, KitMaterials.PIPE_JOINT, Vector3(fx, y, zs[i]), radii[i] * 1.35, 0.08, 12)
		for sx: float in [-1.0, 1.0]:
			kb.block(KitMaterials.FLAT_METAL, Vector3(sx * 3.5, top + 0.125, zs[i]), Vector3(0.12, radii[i], 0.12), 0.0, false)


## 굴뚝 18 m: 벽돌 몸통 (밑 지름 1.6 -> 위 1.2), 콘크리트 밑동, 쇠띠, 위 테두리.
## 벽돌 줄이 0.75 m마다 한 바퀴씩 반복되도록 마디를 쌓는다.
static func chimney(kb: KitBuild) -> void:
	var base_h: float = 1.0
	var total: float = 18.0
	var r0: float = 0.8
	var r1: float = 0.6
	var body_top: float = total - 0.5
	kb.block(KitMaterials.CONCRETE_WALL, Vector3.ZERO, Vector3(2.4, base_h, 2.4), KitBuild.BEVEL_LARGE, false, KitLayout.SILL)
	kb.use(KitMaterials.BRICK)
	var seg: float = 0.75
	var n: int = int(roundf((body_top - base_h) / seg))
	var step: float = (body_top - base_h) / float(n)
	for i: int in range(n):
		var ya: float = base_h + step * float(i)
		var yb: float = ya + step
		var ra: float = lerpf(r0, r1, (ya - base_h) / (total - base_h))
		var rb: float = lerpf(r0, r1, (yb - base_h) / (total - base_h))
		kb.mesh.add_revolve(Transform3D.IDENTITY, PackedVector2Array([Vector2(ra, ya), Vector2(rb, yb)]), 14)
	for y: float in [4.0, 8.5, 13.0]:
		var rr: float = lerpf(r0, r1, (y - base_h) / (total - base_h)) + 0.02
		kb.cylinder(KitMaterials.FLAT_METAL, KitParts.at(Vector3(0.0, y, 0.0)), rr, 0.08, 14, 0.0, false, false)
	# 위 테두리: 위로 약간 벌어진 띠 + 안쪽 어두운 뚜껑
	var rt: float = lerpf(r0, r1, (body_top - base_h) / (total - base_h))
	kb.use(KitMaterials.SILL)
	kb.mesh.add_cylinder(KitParts.at(Vector3(0.0, body_top + 0.25, 0.0)), rt, 0.5, 14, 0.0, rt + 0.1)
	kb.cylinder(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(0.0, total - 0.04, 0.0)), rt + 0.03, 0.02, 14, 0.0, false, false)
	kb.collide_box(KitParts.at(Vector3(0.0, base_h * 0.5, 0.0)), Vector3(2.4, base_h, 2.4))
	kb.collide_box(KitParts.at(Vector3(0.0, base_h + (total - base_h) * 0.5, 0.0)), Vector3(1.3, total - base_h, 1.3))


## 평상 트럭 7.2 (X, 앞 = +X) x 2.5 (Z) x 2.9: 올리브 운전실 + 보닛, 어두운 차대, 짐칸, 바퀴 여섯.
static func truck_flatbed(kb: KitBuild) -> void:
	var cab: StringName = KitMaterials.METAL_CHIPPED
	var f: StringName = KitMaterials.FLAT_METAL
	# 차대: 긴 보 둘 + 가로대
	for sz: float in [-1.0, 1.0]:
		kb.block(f, Vector3(-0.05, 0.55, sz * 0.75), Vector3(7.1, 0.25, 0.16), 0.0, false)
	for x: float in [-3.3, -1.0, 1.2, 3.2]:
		kb.block(f, Vector3(x, 0.55, 0.0), Vector3(0.2, 0.2, 1.5), 0.0, false)
	# 짐칸: 바닥 + 낮은 옆·뒤 판
	kb.block(KitMaterials.METAL_PLATE, Vector3(-1.35, 0.8, 0.0), Vector3(4.5, 0.22, 2.5), 0.0, false, KitLayout.TREAD)
	for sz: float in [-1.0, 1.0]:
		kb.block(KitMaterials.METAL_PLATE, Vector3(-1.35, 1.02, sz * 1.22), Vector3(4.5, 0.4, 0.06), 0.0, false)
	kb.block(KitMaterials.METAL_PLATE, Vector3(-3.57, 1.02, 0.0), Vector3(0.06, 0.4, 2.38), 0.0, false)
	# 운전실 + 보닛
	kb.block(cab, Vector3(1.7, 0.8, 0.0), Vector3(1.6, 2.1, 2.4), KitBuild.BEVEL_SMALL, false)
	kb.block(cab, Vector3(2.9, 0.8, 0.0), Vector3(1.4, 1.2, 2.3), KitBuild.BEVEL_SMALL, false)
	# 유리: 앞 유리, 옆 유리 둘, 뒤 유리
	KitParts.plain(kb, KitMaterials.FLAT_GLASS, Vector3(2.505, 2.05, 0.0), Vector3(0.02, 0.65, 2.0))
	for sz: float in [-1.0, 1.0]:
		KitParts.plain(kb, KitMaterials.FLAT_GLASS, Vector3(1.7, 2.05, sz * 1.205), Vector3(1.0, 0.65, 0.02))
	KitParts.plain(kb, KitMaterials.FLAT_GLASS, Vector3(0.895, 2.0, 0.0), Vector3(0.02, 0.6, 1.2))
	# 범퍼·그릴·전조등
	kb.block(f, Vector3(3.52, 0.5, 0.0), Vector3(0.2, 0.3, 2.5), 0.0, false)
	KitParts.plain(kb, KitMaterials.VENT, Vector3(3.605, 1.0, 0.0), Vector3(0.02, 0.5, 1.4))
	for sz: float in [-1.0, 1.0]:
		KitParts.plain(kb, KitMaterials.FLUORO, Vector3(3.605, 1.15, sz * 0.95), Vector3(0.03, 0.15, 0.25))
	# 바퀴: 앞 한 축, 뒤 두 축 (z = +-1.05)
	for x: float in [2.6, -1.6, -2.9]:
		for sz: float in [-1.0, 1.0]:
			KitParts.wheel(kb, Vector3(x, 0.5, sz * 1.04), 0.5, 0.32, 12)
	# 앞 흙받이
	for sz: float in [-1.0, 1.0]:
		kb.block(cab, Vector3(2.6, 1.0, sz * 1.04), Vector3(1.2, 0.08, 0.4), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(1.7, 1.55, 0.0)), Vector3(1.6, 2.1, 2.4))
	kb.collide_box(KitParts.at(Vector3(2.9, 1.1, 0.0)), Vector3(1.4, 1.2, 2.3))
	kb.collide_box(KitParts.at(Vector3(-1.35, 0.85, 0.0)), Vector3(4.5, 0.7, 2.5))


## 지게차 2.3 (X, 포크 = +X) x 1.2 (Z) x 2.1: 노란 몸통, 마스트, 포크, 머리 보호대, 바퀴 넷.
static func forklift(kb: KitBuild) -> void:
	var y: StringName = KitMaterials.BEAM_YELLOW
	var f: StringName = KitMaterials.FLAT_METAL
	kb.block(y, Vector3(-0.2, 0.28, 0.0), Vector3(1.2, 0.5, 1.0), KitBuild.BEVEL_SMALL, false)
	kb.block(y, Vector3(-0.62, 0.78, 0.0), Vector3(0.5, 0.5, 0.98), KitBuild.BEVEL_SMALL, false)
	kb.block(KitMaterials.FLAT_RUBBER, Vector3(-0.1, 0.78, 0.0), Vector3(0.45, 0.1, 0.5), 0.0, false)
	kb.block(KitMaterials.FLAT_RUBBER, Vector3(-0.3, 0.88, 0.0), Vector3(0.1, 0.4, 0.5), 0.0, false)
	kb.cylinder(f, KitParts.at(Vector3(0.25, 1.0, 0.0)), 0.12, 0.03, 10, 0.0, false, false)
	kb.strut(f, Vector3(0.45, 0.78, 0.0), Vector3(0.28, 1.0, 0.0), 0.04)
	# 머리 보호대: 기둥 넷 + 윗틀 + 가로 살 셋
	for px: float in [-0.5, 0.4]:
		for pz: float in [-0.42, 0.42]:
			kb.strut(f, Vector3(px, 0.8, pz), Vector3(px, 2.05, pz), 0.04)
	kb.block(f, Vector3(-0.05, 2.05, 0.0), Vector3(1.0, 0.04, 0.9), 0.0, false)
	for i: int in range(3):
		kb.block(f, Vector3(-0.35 + 0.3 * float(i), 2.09, 0.0), Vector3(0.04, 0.03, 0.9), 0.0, false)
	# 마스트와 포크
	for sz: float in [-1.0, 1.0]:
		kb.block(f, Vector3(0.72, 0.1, sz * 0.22), Vector3(0.08, 1.9, 0.07), 0.0, false)
		kb.block(f, Vector3(0.9, 0.05, sz * 0.32), Vector3(0.9, 0.04, 0.12), 0.0, false)
		kb.block(f, Vector3(0.82, 0.05, sz * 0.32), Vector3(0.06, 0.6, 0.12), 0.0, false)
	kb.block(f, Vector3(0.78, 0.2, 0.0), Vector3(0.04, 0.4, 0.8), 0.0, false)
	kb.block(f, Vector3(0.72, 1.85, 0.0), Vector3(0.06, 0.08, 0.5), 0.0, false)
	# 바퀴: 앞 둘 (큰 것), 뒤 둘
	for sz: float in [-1.0, 1.0]:
		KitParts.wheel(kb, Vector3(0.4, 0.3, sz * 0.5), 0.3, 0.2, 10)
		KitParts.wheel(kb, Vector3(-0.65, 0.25, sz * 0.5), 0.25, 0.18, 10)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.7, 0.0)), Vector3(2.3, 1.4, 1.2))


## 경비초소 2.4 x 2.4 (벽 바깥) x 2.8: 콘크리트 벽 0.2 두께, 앞(+Z) 문 틈 1.0 x 2.1, 뒤·양옆 창, 지붕 슬래브(0.2 튀어나옴).
static func guard_booth(kb: KitBuild) -> void:
	var s: float = 2.4
	var t: float = 0.2
	var wall_h: float = 2.6
	var c: StringName = KitMaterials.FLAT_CONCRETE
	# 앞벽 (문 틈 -0.5..0.5, 높이 2.1): 왼쪽·오른쪽·위
	KitParts.holed_wall(kb, c, KitParts.at(Vector3(0.0, 0.0, s * 0.5 - t * 0.5)), s, wall_h, t, -0.5, 0.5, 0.0, 2.1)
	# 뒤벽 / 양옆 벽 (창 1.2 x 0.9, 창턱 1.0): 충돌은 통짜
	var win: Array[float] = [-0.6, 0.6, 1.0, 1.9]
	var back := KitParts.at(Vector3(0.0, 0.0, -s * 0.5 + t * 0.5))
	KitParts.holed_wall(kb, c, back, s, wall_h, t, win[0], win[1], win[2], win[3], false)
	kb.collide_box(KitParts.at(Vector3(0.0, wall_h * 0.5, -s * 0.5 + t * 0.5)), Vector3(s, wall_h, t))
	var side_len: float = s - t * 2.0
	for sx: float in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (s * 0.5 - t * 0.5), 0.0, 0.0))
		KitParts.holed_wall(kb, c, xf, side_len, wall_h, t, win[0], win[1], win[2], win[3], false)
		kb.collide_box(KitParts.at(Vector3(sx * (s * 0.5 - t * 0.5), wall_h * 0.5, 0.0)), Vector3(t, wall_h, side_len))
	# 유리 + 창턱 띠 (바깥으로 튀어나옴)
	var sill_z: float = s * 0.5
	KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(0.0, 1.45, -s * 0.5 + t * 0.5), Vector3(1.2, 0.9, 0.012))
	kb.block(KitMaterials.SILL, Vector3(0.0, 0.92, -sill_z - 0.04), Vector3(1.5, 0.08, 0.3), 0.0, false)
	for sx: float in [-1.0, 1.0]:
		KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(sx * (s * 0.5 - t * 0.5), 1.45, 0.0), Vector3(0.012, 0.9, 1.2))
		kb.block(KitMaterials.SILL, Vector3(sx * (sill_z + 0.04), 0.92, 0.0), Vector3(0.3, 0.08, 1.5), 0.0, false)
	# 아래 굽 띠 (네 면)
	for sx: float in [-1.0, 1.0]:
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(sx * 0.865, 0.0, s * 0.5 - 0.1), Vector3(0.73 + 0.03, 0.3, 0.26), 0.0, false, KitLayout.SILL)
	kb.block(KitMaterials.CONCRETE_WALL, Vector3(0.0, 0.0, -s * 0.5 + 0.1), Vector3(s + 0.06, 0.3, 0.26), 0.0, false, KitLayout.SILL)
	for sx: float in [-1.0, 1.0]:
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(sx * (s * 0.5 - 0.1), 0.0, 0.0), Vector3(0.26, 0.3, s - 0.4), 0.0, false, KitLayout.SILL)
	# 지붕: 옆면 콘크리트, 윗면 지붕 재질
	var roof: float = s + 0.4
	kb.block(KitMaterials.CONCRETE_WALL, Vector3(0.0, wall_h, 0.0), Vector3(roof, 0.14, roof), KitBuild.BEVEL_SMALL, false, KitLayout.SILL)
	kb.block(KitMaterials.FLAT_ROOF, Vector3(0.0, wall_h + 0.14, 0.0), Vector3(roof - 0.1, 0.06, roof - 0.1), 0.0, false)
	kb.collide_box(KitParts.at(Vector3(0.0, wall_h + 0.1, 0.0)), Vector3(roof, 0.2, roof))
	# 바닥판 (안쪽)
	kb.block(KitMaterials.FLAT_CONCRETE_DARK, Vector3.ZERO, Vector3(s - t * 2.0, 0.05, s - t * 2.0), 0.0, false)


## 버려진 승용차 4.2 (X, 앞 = +X) x 1.8 (Z) x 1.45: 페인트 차체(아래) + 유리 캐빈 + 지붕, 범퍼·전조등, 바퀴 넷.
## paint = 차체 트림 재질 (청회·빨강·올리브). 충돌은 상자 하나.
static func car_sedan(kb: KitBuild, paint: StringName) -> void:
	var f: StringName = KitMaterials.FLAT_METAL
	# 차체 아래 (바퀴 위까지) + 보닛·트렁크 윗면
	kb.block(paint, Vector3(0.0, 0.28, 0.0), Vector3(4.2, 0.5, 1.8), KitBuild.BEVEL_SMALL, false)
	kb.block(paint, Vector3(1.25, 0.78, 0.0), Vector3(1.5, 0.1, 1.74), 0.0, false)
	kb.block(paint, Vector3(-1.5, 0.78, 0.0), Vector3(1.1, 0.1, 1.74), 0.0, false)
	# 캐빈: 기둥 네 개 + 유리 (앞·뒤·옆) + 지붕
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			kb.strut(paint, Vector3(0.45 * sx - 0.15, 0.85, 0.78 * sz), Vector3(0.38 * sx - 0.15, 1.38, 0.7 * sz), 0.07)
	KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(0.62, 1.12, 0.0), Vector3(0.03, 0.5, 1.4))
	KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(-0.97, 1.12, 0.0), Vector3(0.03, 0.5, 1.4))
	for sz: float in [-1.0, 1.0]:
		KitParts.slab(kb, KitMaterials.FLAT_GLASS, Vector3(-0.15, 1.12, sz * 0.75), Vector3(1.3, 0.48, 0.02))
	kb.block(paint, Vector3(-0.17, 1.36, 0.0), Vector3(1.4, 0.06, 1.46), KitBuild.BEVEL_SMALL, false)
	# 범퍼·그릴·전조등·번호판 자리
	for sx: float in [-1.0, 1.0]:
		kb.block(f, Vector3(sx * 2.12, 0.15, 0.0), Vector3(0.1, 0.18, 1.7), 0.0, false)
	for sz: float in [-1.0, 1.0]:
		KitParts.plain(kb, KitMaterials.FLUORO, Vector3(2.11, 0.5, sz * 0.62), Vector3(0.03, 0.12, 0.28))
		KitParts.plain(kb, KitMaterials.FLAT_RUBBER, Vector3(-2.11, 0.5, sz * 0.62), Vector3(0.03, 0.12, 0.28))
	KitParts.plain(kb, KitMaterials.VENT, Vector3(2.11, 0.3, 0.0), Vector3(0.03, 0.14, 0.8))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KitParts.wheel(kb, Vector3(sx * 1.3, 0.3, sz * 0.82), 0.3, 0.22, 10)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.7, 0.0)), Vector3(4.2, 1.4, 1.8))
