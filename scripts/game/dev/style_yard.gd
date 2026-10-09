class_name StyleYard
extends RefCounted
## 스타일 비교 씬의 마당 소품: 컨테이너, 트럭, 방벽, 팔레트, 드럼통, 파이프 랙, 가로등, 울타리, 웅덩이, 잡초.
## 두 스타일이 같은 함수를 쓰고, 세부(법선 맵 대 지오메트리 주름, 분할 수)만 StyleKit의 is_a로 갈라진다.

const CONT_L: float = 6.06
const CONT_W: float = 2.44
const CONT_H: float = 2.59


# --- 컨테이너 ---

## 컨테이너 한 개. pos.y는 바닥 높이, 긴 변이 로컬 X, 문은 +X 끝.
static func container(k: StyleKit, pos: Vector3, yaw: float, teal: bool) -> void:
	var gr: MeshBuilder = k.g(&"containers")
	var base: Transform3D = StyleKit.xf(pos, yaw)
	var body_id: StringName = StyleMaterialSet.CONT_TEAL if teal else StyleMaterialSet.CONT_RED
	var paint_id: StringName = StyleMaterialSet.PAINT_TEAL if teal else StyleMaterialSet.PAINT_RED
	var center: Transform3D = StyleKit.loc(base, Vector3(0.0, CONT_H * 0.5, 0.0))
	if k.textured:
		# 법선 맵(A) 또는 픽셀 텍스처(C)가 주름을 담당한다
		k.box(gr, body_id, center, Vector3(CONT_L, CONT_H, CONT_W), 0.03 if k.is_a else 0.05)
	else:
		# 단순한 몸통 + 기하 주름 (사다리꼴 파형 압출)
		k.box(gr, body_id, center, Vector3(CONT_L - 0.02, CONT_H - 0.02, CONT_W - 0.16), 0.06)
		for side: int in [-1, 1]:
			_rib_side(k, gr, body_id, base, side)
	# 모서리 쇠 (corner casting)
	for sx: int in [-1, 1]:
		for sy: int in [0, 1]:
			for sz: int in [-1, 1]:
				var y: float = 0.09 if sy == 0 else CONT_H - 0.09
				k.box(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(sx * (CONT_L * 0.5 - 0.1), y, sz * (CONT_W * 0.5 - 0.09))),
						Vector3(0.22, 0.18, 0.2), 0.035)
	# 위아래 레일
	for sz: int in [-1, 1]:
		k.box(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(0.0, 0.07, sz * (CONT_W * 0.5 - 0.04))),
				Vector3(CONT_L - 0.45, 0.13, 0.09), 0.02)
		k.box(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(0.0, CONT_H - 0.05, sz * (CONT_W * 0.5 - 0.04))),
				Vector3(CONT_L - 0.45, 0.1, 0.09), 0.02)
	# 문 끝: 문짝 둘 + 잠금 막대 + 손잡이
	var door_x: float = CONT_L * 0.5 + 0.02
	for sz: int in [-1, 1]:
		k.box(gr, paint_id, StyleKit.loc(base, Vector3(door_x, CONT_H * 0.5, sz * (CONT_W * 0.25))),
				Vector3(0.06, CONT_H - 0.24, CONT_W * 0.5 - 0.1), 0.01)
		for bar: int in range(2):
			var bz: float = sz * (0.18 + bar * 0.52)
			var rot: Basis = base.basis
			k.cyl(gr, StyleMaterialSet.STEEL, Transform3D(rot, base * Vector3(door_x + 0.06, CONT_H * 0.5, bz)), 0.024,
					CONT_H - 0.3, 10, 5)
			k.box(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(door_x + 0.09, CONT_H * 0.5 + 0.05, bz)),
					Vector3(0.03, 0.18, 0.06), 0.0)
	# 문틀 가운데 이음
	k.box(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(door_x + 0.05, CONT_H * 0.5, 0.0)),
			Vector3(0.05, CONT_H - 0.2, 0.05), 0.0)


## 컨테이너 옆면 하나의 기하 주름 (스타일 B).
static func _rib_side(k: StyleKit, gr: MeshBuilder, id: StringName, base: Transform3D, side: int) -> void:
	var profile: PackedVector2Array = zigzag_profile(CONT_L - 0.3, 0.45, 0.07)
	var x_axis: Vector3 = Vector3(-1, 0, 0) if side > 0 else Vector3(1, 0, 0)
	var y_axis: Vector3 = Vector3(0, 0, 1) if side > 0 else Vector3(0, 0, -1)
	var local := Transform3D(Basis(x_axis, y_axis, Vector3.UP), Vector3(0.0, CONT_H * 0.5, side * (CONT_W * 0.5 - 0.1)))
	k.mats.apply(gr, id)
	gr.add_prism(base * local, profile, CONT_H - 0.26)


## 사다리꼴 주름 프로파일 (로컬 XY, 반시계). 아래변(y=-0.04)에서 시작해 오른쪽으로 갔다가 주름 윗선을 따라 왼쪽으로 돌아온다.
static func zigzag_profile(length: float, pitch: float, amp: float) -> PackedVector2Array:
	var count: int = maxi(int(length / pitch), 1)
	var p: float = length / float(count)
	var x0: float = -length * 0.5
	var top: Array[Vector2] = []
	for i: int in range(count):
		var x: float = x0 + p * i
		top.append(Vector2(x, 0.0))
		top.append(Vector2(x + p * 0.15, amp))
		top.append(Vector2(x + p * 0.5, amp))
		top.append(Vector2(x + p * 0.65, 0.0))
	top.append(Vector2(x0 + length, 0.0))
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, -0.04))
	pts.append(Vector2(x0 + length, -0.04))
	for i: int in range(top.size() - 1, -1, -1):
		pts.append(top[i])
	return pts


# --- 팔레트 / 상자 ---

static func pallet(k: StyleKit, gr: MeshBuilder, base: Transform3D) -> void:
	var wood: StringName = StyleMaterialSet.PALLET if k.is_d else StyleMaterialSet.WOOD
	var dark: StringName = StyleMaterialSet.PALLET_DARK if k.is_d else StyleMaterialSet.WOOD_DARK
	for z: float in [-0.35, 0.0, 0.35]:
		k.box(gr, dark, StyleKit.loc(base, Vector3(0.0, 0.011, z)), Vector3(1.2, 0.022, 0.1), 0.0)
	for x: float in [-0.55, 0.0, 0.55]:
		for z: float in [-0.35, 0.0, 0.35]:
			k.box(gr, dark, StyleKit.loc(base, Vector3(x, 0.067, z)), Vector3(0.1, 0.09, 0.1), 0.0)
	for i: int in range(7):
		var z: float = -0.36 + 0.12 * i
		k.box(gr, wood, StyleKit.loc(base, Vector3(0.0, 0.123, z)), Vector3(1.2, 0.022, 0.09), 0.0)


## 상자: 널빤지 몸통 + 모서리 각재 + 가로 띠.
static func crate(k: StyleKit, gr: MeshBuilder, base: Transform3D, size: Vector3) -> void:
	var wood: StringName = StyleMaterialSet.CRATE if k.is_d else StyleMaterialSet.WOOD
	var dark: StringName = StyleMaterialSet.CRATE_DARK if k.is_d else StyleMaterialSet.WOOD_DARK
	k.box(gr, wood, StyleKit.loc(base, Vector3(0.0, size.y * 0.5, 0.0)), size - Vector3(0.06, 0.0, 0.06), 0.0)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			k.box(gr, dark, StyleKit.loc(base, Vector3(sx * (size.x * 0.5 - 0.04), size.y * 0.5, sz * (size.z * 0.5 - 0.04))),
					Vector3(0.08, size.y + 0.02, 0.08), 0.0)
	for y: float in [0.06, size.y - 0.06]:
		for sx: int in [-1, 1]:
			k.box(gr, dark, StyleKit.loc(base, Vector3(sx * (size.x * 0.5 - 0.01), y, 0.0)), Vector3(0.04, 0.08, size.z - 0.02), 0.0)
		for sz: int in [-1, 1]:
			k.box(gr, dark, StyleKit.loc(base, Vector3(0.0, y, sz * (size.z * 0.5 - 0.01))), Vector3(size.x - 0.02, 0.08, 0.04), 0.0)
	# 대각 버팀
	k.box(gr, dark, StyleKit.loc(base, Vector3(0.0, size.y * 0.5, size.z * 0.5 + 0.005)),
			Vector3(size.x * 0.9, 0.06, 0.02), 0.0)


static func pallet_stack(k: StyleKit, pos: Vector3, yaw: float) -> void:
	var gr: MeshBuilder = k.g(&"pallets")
	var base: Transform3D = StyleKit.xf(pos, yaw)
	for i: int in range(4):
		var off := Vector3(0.02 * ((i * 7) % 3 - 1), i * 0.144, 0.025 * ((i * 5) % 3 - 1))
		pallet(k, gr, Transform3D(Basis(Vector3.UP, 0.04 * ((i * 3) % 3 - 1)) * base.basis, base * off))
	var top: Transform3D = StyleKit.loc(base, Vector3(0.0, 4 * 0.144, 0.0))
	crate(k, gr, StyleKit.loc(top, Vector3(0.0, 0.0, 0.0)), Vector3(0.95, 0.75, 0.8))
	# 옆에 하나 더 놓인 팔레트
	pallet(k, gr, StyleKit.xf(pos + Vector3(1.6, 0.0, 0.5), yaw + 0.5))
	pallet(k, gr, StyleKit.xf(pos + Vector3(1.7, 0.144, 0.45), yaw + 0.45))


# --- 방벽 ---

static func barrier(k: StyleKit, pos: Vector3, yaw: float) -> void:
	var gr: MeshBuilder = k.g(&"barriers")
	var base: Transform3D = StyleKit.xf(pos, yaw)
	# 저지 방벽 단면 (로컬 XY, 반시계): 아래가 넓고 위가 좁다
	var profile := PackedVector2Array([
		Vector2(-0.32, 0.0), Vector2(0.32, 0.0), Vector2(0.32, 0.12), Vector2(0.16, 0.5),
		Vector2(0.11, 0.82), Vector2(-0.11, 0.82), Vector2(-0.16, 0.5), Vector2(-0.32, 0.12)])
	if k.is_d:
		_barrier_trim(k, gr, base, profile)
		return
	k.mats.apply(gr, StyleMaterialSet.CONCRETE)
	gr.add_prism(base, profile, 3.0)
	if k.is_a:
		# 가장자리 떨어져 나간 모서리 느낌의 윗면 띠
		k.box(gr, StyleMaterialSet.CONCRETE_DARK, StyleKit.loc(base, Vector3(0.0, 0.8, 0.0)), Vector3(0.24, 0.04, 3.02), 0.01)
	else:
		# 경고 띠 (빗금 대신 단순한 주황 블록)
		for i: int in range(3):
			k.box(gr, StyleMaterialSet.HAZARD, StyleKit.loc(base, Vector3(0.0, 0.55, -1.0 + i * 1.0)), Vector3(0.4, 0.14, 0.34), 0.0)


## 스타일 D 방벽: 단면을 높이로 세 토막 내 콘크리트 - 경고 줄무늬 띠 - 콘크리트로 붙인다 (띠는 트림시트의 hazard 줄).
static func _barrier_trim(k: StyleKit, gr: MeshBuilder, base: Transform3D, profile: PackedVector2Array) -> void:
	var cuts: Array[Vector2] = [Vector2(-0.01, 0.3), Vector2(0.3, 0.56), Vector2(0.56, 0.9)]
	var ids: Array[StringName] = [StyleMaterialSet.CONCRETE, StyleMaterialSet.HAZARD, StyleMaterialSet.CONCRETE]
	for i: int in range(cuts.size()):
		var rect := PackedVector2Array([Vector2(-1.0, cuts[i].x), Vector2(1.0, cuts[i].x), Vector2(1.0, cuts[i].y), Vector2(-1.0, cuts[i].y)])
		var parts: Array[PackedVector2Array] = Geometry2D.intersect_polygons(profile, rect)
		if parts.is_empty():
			continue
		k.apply(gr, ids[i])
		gr.add_prism(base, parts[0], 3.0)


# --- 드럼통 ---

static func barrel(k: StyleKit, pos: Vector3, id: StringName, tipped: bool = false, yaw: float = 0.0) -> void:
	var gr: MeshBuilder = k.g(&"barrels")
	var base: Transform3D
	if tipped:
		base = Transform3D(Basis(Vector3.UP, yaw) * StyleKit.axis_z(), pos + Vector3(0.0, 0.3, 0.0))
	else:
		base = StyleKit.xf(pos + Vector3(0.0, 0.44, 0.0), yaw)
	k.cyl(gr, id, base, 0.29, 0.88, 18, 8, 0.035)
	for y: float in [-0.22, 0.22]:
		k.cyl(gr, id, StyleKit.loc(base, Vector3(0.0, y, 0.0)), 0.305, 0.05, 18, 8, 0.012)
	k.cyl(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(0.0, 0.44, 0.0)), 0.27, 0.025, 14, 8)
	k.cyl(gr, StyleMaterialSet.STEEL, StyleKit.loc(base, Vector3(0.12, 0.46, 0.08)), 0.05, 0.03, 8, 6)


static func barrel_group(k: StyleKit, pos: Vector3) -> void:
	barrel(k, pos + Vector3(0.0, 0.0, 0.0), StyleMaterialSet.BARREL_BLUE)
	barrel(k, pos + Vector3(0.66, 0.0, 0.1), StyleMaterialSet.BARREL_RED, false, 0.6)
	barrel(k, pos + Vector3(0.28, 0.0, 0.62), StyleMaterialSet.BARREL_OCHRE, false, 1.1)
	barrel(k, pos + Vector3(-0.55, 0.0, 0.5), StyleMaterialSet.BARREL_BLUE, false, 2.0)
	barrel(k, pos + Vector3(1.5, 0.0, 0.9), StyleMaterialSet.BARREL_RED, true, 0.4)


# --- 트럭 ---

## 버려진 트럭. 로컬 -Z가 앞.
static func truck(k: StyleKit, pos: Vector3, yaw: float) -> void:
	var gr: MeshBuilder = k.g(&"truck")
	var base: Transform3D = StyleKit.xf(pos, yaw)
	var cab_id: StringName = StyleMaterialSet.TRUCK_BODY
	var steel_d: StringName = StyleMaterialSet.STEEL_DARK
	# 차대
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 0.82, 0.3)), Vector3(1.4, 0.26, 6.9), 0.02)
	# 운전석
	k.box(gr, cab_id, StyleKit.loc(base, Vector3(0.0, 1.85, -2.7)), Vector3(2.3, 1.85, 1.95), 0.1)
	k.box(gr, cab_id, StyleKit.loc(base, Vector3(0.0, 1.15, -3.0)), Vector3(2.32, 0.55, 2.5), 0.07)
	k.box(gr, StyleMaterialSet.GLASS, StyleKit.loc(base, Vector3(0.0, 2.25, -3.69)), Vector3(1.95, 0.78, 0.05), 0.0)
	for sx: int in [-1, 1]:
		k.box(gr, StyleMaterialSet.GLASS, StyleKit.loc(base, Vector3(sx * 1.16, 2.25, -2.75)), Vector3(0.05, 0.7, 1.05), 0.0)
		# 미러
		k.box(gr, steel_d, StyleKit.loc(base, Vector3(sx * 1.4, 2.35, -3.45)), Vector3(0.12, 0.34, 0.2), 0.02)
		k.box(gr, steel_d, StyleKit.loc(base, Vector3(sx * 1.27, 2.35, -3.45)), Vector3(0.16, 0.04, 0.04), 0.0)
		# 헤드라이트
		k.box(gr, StyleMaterialSet.GLASS, StyleKit.loc(base, Vector3(sx * 0.82, 1.28, -4.27)), Vector3(0.34, 0.2, 0.06), 0.02)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 1.0, -4.28)), Vector3(1.2, 0.42, 0.06), 0.0)
	k.box(gr, StyleMaterialSet.STEEL, StyleKit.loc(base, Vector3(0.0, 0.7, -4.33)), Vector3(2.4, 0.26, 0.28), 0.04)
	# 짐칸 상자
	k.box(gr, StyleMaterialSet.CONT_TEAL, StyleKit.loc(base, Vector3(0.0, 2.55, 1.35)), Vector3(2.45, 2.7, 4.7), 0.07)
	k.box(gr, StyleMaterialSet.RUST, StyleKit.loc(base, Vector3(0.0, 1.45, 1.35)), Vector3(2.5, 0.36, 4.74), 0.03)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 1.14, 1.35)), Vector3(2.0, 0.16, 4.9), 0.02)
	# 뒷문 막대
	for sx: int in [-1, 1]:
		k.cyl(gr, StyleMaterialSet.STEEL, StyleKit.loc(base, Vector3(sx * 0.6, 2.55, 3.74)), 0.035, 2.5, 8, 5)
		k.box(gr, steel_d, StyleKit.loc(base, Vector3(sx * 0.6, 2.62, 3.78)), Vector3(0.08, 0.22, 0.05), 0.0)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 2.55, 3.72)), Vector3(0.05, 2.6, 0.05), 0.0)
	# 배기관, 연료통
	k.cyl(gr, steel_d, StyleKit.loc(base, Vector3(1.22, 2.4, -1.55)), 0.07, 2.7, 10, 6)
	k.cyl(gr, StyleMaterialSet.STEEL, Transform3D(base.basis * StyleKit.axis_z(), base * Vector3(-0.98, 0.78, -0.9)), 0.3, 1.3, 14, 8, 0.03)
	# 바퀴: 앞 2, 뒤 4 (한 개는 바람 빠짐)
	var wheel_spots: Array[Vector3] = [Vector3(-1.0, 0.55, -3.0), Vector3(1.0, 0.55, -3.0),
			Vector3(-1.0, 0.55, 1.0), Vector3(1.0, 0.55, 1.0), Vector3(-1.0, 0.55, 2.35), Vector3(1.0, 0.43, 2.35)]
	for w: int in range(wheel_spots.size()):
		var wp: Vector3 = wheel_spots[w]
		var radius: float = 0.55 if w != 5 else 0.43
		var wb := Transform3D(base.basis * StyleKit.axis_x(), base * wp)
		k.cyl(gr, StyleMaterialSet.RUBBER, wb, radius, 0.4, 20, 8, 0.07)
		var side: float = signf(wp.x)
		k.cyl(gr, StyleMaterialSet.STEEL, Transform3D(wb.basis, base * (wp + Vector3(side * 0.03, 0.0, 0.0))), radius * 0.52, 0.42, 14, 6, 0.02)
		k.cyl(gr, steel_d, Transform3D(wb.basis, base * (wp + Vector3(side * 0.05, 0.0, 0.0))), radius * 0.2, 0.44, 8, 5)
	# 흙받이
	for sx: int in [-1, 1]:
		k.box(gr, steel_d, StyleKit.loc(base, Vector3(sx * 1.0, 1.15, 1.7)), Vector3(0.5, 0.06, 1.9), 0.0)


# --- 파이프 랙 ---

static func pipe_rack(k: StyleKit, z: float) -> void:
	var gr: MeshBuilder = k.g(&"rack")
	var steel_d: StringName = StyleMaterialSet.STEEL_DARK
	var steel: StringName = StyleMaterialSet.STEEL
	var top: float = 6.2
	var xs: Array[float] = [-11.0, -6.0, 6.0, 11.0]
	for x: float in xs:
		for sz: int in [-1, 1]:
			var cz: float = z + sz * 0.62
			k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, top * 0.5, cz)), Vector3(0.24, top, 0.24), 0.02)
			k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, 0.03, cz)), Vector3(0.6, 0.06, 0.6), 0.01)
			# 앵커 볼트
			for bx: int in [-1, 1]:
				k.cyl(gr, steel, Transform3D(Basis.IDENTITY, Vector3(x + bx * 0.22, 0.09, cz + bx * 0.22)), 0.03, 0.06, 6, 5)
		# 가로보 + 대각 버팀
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, top + 0.1, z)), Vector3(0.22, 0.24, 1.7), 0.015)
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, 3.2, z)), Vector3(0.14, 0.14, 1.3), 0.0)
		k.strut(gr, steel_d, Vector3(x, 3.2, z - 0.62), Vector3(x, top, z + 0.62), 0.1)
		k.strut(gr, steel_d, Vector3(x, 3.2, z + 0.62), Vector3(x, top, z - 0.62), 0.1)
		k.strut(gr, steel_d, Vector3(x, 0.1, z - 0.62), Vector3(x, 3.2, z + 0.62), 0.1)
		k.strut(gr, steel_d, Vector3(x, 0.1, z + 0.62), Vector3(x, 3.2, z - 0.62), 0.1)
	# 종방향 보
	for sz: int in [-1, 1]:
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(0.0, top + 0.3, z + sz * 0.62)), Vector3(23.6, 0.14, 0.2), 0.0)
	# 파이프 세 줄 + 플랜지
	var specs: Array[Array] = [
		[-0.5, 0.32, StyleMaterialSet.PIPE_GREY], [0.0, 0.22, StyleMaterialSet.PIPE_ORANGE], [0.5, 0.27, StyleMaterialSet.PIPE_GREY]]
	for spec: Array in specs:
		var dz: float = spec[0]
		var r: float = spec[1]
		var pid: StringName = spec[2]
		var y: float = top + 0.37 + r
		k.cyl(gr, pid, Transform3D(StyleKit.axis_x(), Vector3(0.0, y, z + dz)), r, 23.6, 22, 8)
		for fx: float in [-8.0, -2.0, 3.0, 8.5]:
			k.cyl(gr, steel_d, Transform3D(StyleKit.axis_x(), Vector3(fx, y, z + dz)), r * 1.22, 0.1, 22, 8)
		for fx: float in xs:
			k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(fx, top + 0.45, z + dz)), Vector3(0.3, 0.14, r * 1.6), 0.0)


# --- 가로등, 울타리 ---

static func lamp_post(k: StyleKit, pos: Vector3, yaw: float) -> void:
	var gr: MeshBuilder = k.g(&"lamp_post")
	var base: Transform3D = StyleKit.xf(pos, yaw)
	k.cyl(gr, StyleMaterialSet.CONCRETE, StyleKit.loc(base, Vector3(0.0, 0.3, 0.0)), 0.26, 0.6, 12, 6, 0.04)
	k.cyl(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(0.0, 3.5, 0.0)), 0.1, 6.0, 14, 6, 0.0, 0.065)
	k.box(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(0.55, 6.45, 0.0)), Vector3(1.3, 0.09, 0.09), 0.01)
	k.box(gr, StyleMaterialSet.STEEL_DARK, StyleKit.loc(base, Vector3(1.25, 6.38, 0.0)), Vector3(0.75, 0.16, 0.34), 0.04)
	k.box(gr, StyleMaterialSet.LAMP, StyleKit.loc(base, Vector3(1.25, 6.29, 0.0)), Vector3(0.6, 0.03, 0.24), 0.0)


## 마당 동쪽 골판 울타리.
static func fence(k: StyleKit, x: float, z0: float, z1: float) -> void:
	var gr: MeshBuilder = k.g(&"fence")
	var length: float = z1 - z0
	k.box(gr, StyleMaterialSet.CONT_TEAL, Transform3D(Basis.IDENTITY, Vector3(x, 1.6, (z0 + z1) * 0.5)), Vector3(0.1, 3.0, length), 0.0)
	var posts: int = int(length / 3.0) + 1
	for i: int in range(posts + 1):
		var pz: float = z0 + length * float(i) / float(posts)
		k.box(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(x - 0.1, 1.65, pz)), Vector3(0.16, 3.3, 0.16), 0.01)
	k.box(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(x - 0.07, 3.2, (z0 + z1) * 0.5)), Vector3(0.1, 0.1, length), 0.0)
	k.box(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(x - 0.07, 0.15, (z0 + z1) * 0.5)), Vector3(0.1, 0.18, length), 0.0)
	if not k.textured:
		for i: int in range(int(length / 0.5)):
			k.box(gr, StyleMaterialSet.CONT_TEAL, Transform3D(Basis.IDENTITY, Vector3(x - 0.07, 1.6, z0 + 0.25 + i * 0.5)), Vector3(0.05, 2.8, 0.08), 0.0)


# --- 웅덩이 ---

## 불규칙한 납작한 물 모양 (삼각형 부채). 아스팔트 위 1.2 cm.
static func puddle(k: StyleKit, center: Vector3, radius_x: float, radius_z: float) -> void:
	var gr: MeshBuilder = k.g(&"puddle")
	k.mats.apply(gr, StyleMaterialSet.PUDDLE)
	var count: int = 28 if k.is_a else 14
	var pts: Array[Vector3] = []
	for i: int in range(count):
		var t: float = TAU * float(i) / float(count)
		var wob: float = 1.0 + 0.2 * sin(t * 3.0 + 0.8) + 0.1 * sin(t * 5.0 + 2.1) + 0.06 * sin(t * 9.0)
		pts.append(center + Vector3(cos(t) * radius_x * wob, 0.012, sin(t) * radius_z * wob))
	for i: int in range(count):
		gr.add_triangle(Transform3D.IDENTITY, center + Vector3(0.0, 0.012, 0.0), pts[i], pts[(i + 1) % count], Vector3.UP)


# --- 잡초 ---

static func weed_clump(k: StyleKit, pos: Vector3, seed_value: int, scale: float = 1.0) -> void:
	var gr: MeshBuilder = k.g(&"weeds")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	k.mats.apply(gr, StyleMaterialSet.FERN if k.is_d else StyleMaterialSet.WEED)
	if k.is_a or k.is_d:
		# 알파 컷 교차 판 3장: 단위 크기 판을 스케일로 키운다 (UV는 재질의 uv1_offset이 0..1로 맞춘다)
		var cards: int = 5 if k.is_d else 3
		for i: int in range(cards):
			var yaw: float = PI * float(i) / float(cards) + rng.randf() * 0.4
			var w: float = rng.randf_range(0.8, 1.15) * scale
			var h: float = rng.randf_range(0.7, 1.0) * scale
			var base := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(w, h, w)), pos)
			gr.add_quad(base, Vector3(-0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.5, 1.0, 0.0), Vector3(-0.5, 1.0, 0.0), Vector3.FORWARD)
	else:
		# 로우폴리: 휜 잎 12장 (삼각형 둘)
		for i: int in range(12):
			var ang: float = rng.randf() * TAU
			var lean: float = rng.randf_range(0.15, 0.55)
			var h: float = rng.randf_range(0.35, 0.8) * scale
			var w: float = 0.05 * scale
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var side := Vector3(-dir.z, 0.0, dir.x)
			var p0: Vector3 = pos + dir * rng.randf_range(0.0, 0.18)
			var mid: Vector3 = p0 + dir * lean * h * 0.4 + Vector3(0.0, h * 0.55, 0.0)
			var tip: Vector3 = p0 + dir * lean * h + Vector3(0.0, h, 0.0)
			var shade: Color = Color(0.85 + 0.15 * rng.randf(), 0.9 + 0.1 * rng.randf(), 0.8 + 0.2 * rng.randf())
			gr.color(k.mats.tint(StyleMaterialSet.WEED) * shade)
			gr.add_triangle(Transform3D.IDENTITY, p0 - side * w, p0 + side * w, mid - side * w * 0.5, dir)
			gr.add_triangle(Transform3D.IDENTITY, p0 + side * w, mid + side * w * 0.5, mid - side * w * 0.5, dir)
			gr.add_triangle(Transform3D.IDENTITY, mid - side * w * 0.5, mid + side * w * 0.5, tip, dir)
