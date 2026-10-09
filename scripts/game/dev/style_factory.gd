class_name StyleFactory
extends RefCounted
## 스타일 비교 씬의 공장: 전면 벽(창 띠·큰 문), 어두운 내부(지게차·상자·선반·크레인·매단 램프·빛줄기).
## 좌표: 마당은 z > WALL_Z, 공장 내부는 z < WALL_Z (뒷벽 z = BACK_Z). 문은 x = DOOR_X0..DOOR_X1.

const WALL_Z: float = -11.0
const BACK_Z: float = -25.0
const WALL_T: float = 0.6
const WALL_H: float = 9.4
const DOOR_X0: float = -2.4
const DOOR_X1: float = 2.6
const DOOR_H: float = 4.6
const HALF_W: float = 12.3
const WINDOW_X: Array[float] = [-8.9, -5.1, -1.4, 1.6, 5.2, 8.9]
const PILASTER_X: Array[float] = [-10.8, -7.0, -3.15, 3.35, 7.0, 10.8]
## 벽 안쪽 빛줄기가 들어오는 서쪽 벽 창 (z 범위, y 범위).
const SIDE_WINDOW_Z0: float = -18.0
const SIDE_WINDOW_Z1: float = -14.5
const SIDE_WINDOW_Y0: float = 5.2
const SIDE_WINDOW_Y1: float = 7.4


## 최소·최대 모서리로 슬래브 하나.
static func slab(k: StyleKit, gr: MeshBuilder, id: StringName, lo: Vector3, hi: Vector3, bevel: float = 0.0) -> void:
	k.box(gr, id, Transform3D(Basis.IDENTITY, (lo + hi) * 0.5), hi - lo, bevel)


static func build_shell(k: StyleKit) -> void:
	var gr: MeshBuilder = k.g(&"factory")
	var brick: StringName = StyleMaterialSet.BRICK
	var conc: StringName = StyleMaterialSet.CONCRETE
	var front_in: float = WALL_Z - WALL_T * 0.5
	var front_out: float = WALL_Z + WALL_T * 0.5
	# 전면 벽: 문 양옆과 문 위
	slab(k, gr, brick, Vector3(-HALF_W, 0.0, front_in), Vector3(DOOR_X0, WALL_H, front_out))
	slab(k, gr, brick, Vector3(DOOR_X1, 0.0, front_in), Vector3(HALF_W, WALL_H, front_out))
	slab(k, gr, brick, Vector3(DOOR_X0, DOOR_H, front_in), Vector3(DOOR_X1, WALL_H, front_out))
	# 콘크리트 기단, 중간 띠, 처마
	slab(k, gr, conc, Vector3(-HALF_W - 0.1, 0.0, front_out - 0.3), Vector3(DOOR_X0 - 0.2, 1.0, front_out + 0.12), 0.03)
	slab(k, gr, conc, Vector3(DOOR_X1 + 0.2, 0.0, front_out - 0.3), Vector3(HALF_W + 0.1, 1.0, front_out + 0.12), 0.03)
	slab(k, gr, conc, Vector3(-HALF_W - 0.1, 5.55, front_out - 0.3), Vector3(HALF_W + 0.1, 5.9, front_out + 0.1), 0.03)
	slab(k, gr, conc, Vector3(-HALF_W - 0.2, WALL_H, front_in - 0.3), Vector3(HALF_W + 0.2, WALL_H + 0.45, front_out + 0.35), 0.05)
	# 벽기둥
	for x: float in PILASTER_X:
		slab(k, gr, conc, Vector3(x - 0.3, 1.0, front_out - 0.2), Vector3(x + 0.3, WALL_H, front_out + 0.28), 0.03)
	# 창 띠: 창틀 + 유리 + 문설주 + 창턱
	var lit: Array[int] = [1, 2, 4, 5, 8, 9, 10]
	var pane_index: int = 0
	for wx: float in WINDOW_X:
		var zf: float = front_out + 0.05
		k.box(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(wx, 7.0, zf)), Vector3(2.7, 2.2, 0.12), 0.01)
		for col: int in range(2):
			for row: int in range(2):
				var id: StringName = StyleMaterialSet.GLASS_LIT if lit.has(pane_index) else StyleMaterialSet.GLASS
				pane_index += 1
				k.box(gr, id, Transform3D(Basis.IDENTITY, Vector3(wx - 0.62 + col * 1.24, 6.5 + row * 1.0, zf + 0.08)),
						Vector3(1.14, 0.9, 0.04), 0.0)
		k.box(gr, conc, Transform3D(Basis.IDENTITY, Vector3(wx, 5.95, zf + 0.12)), Vector3(2.95, 0.1, 0.3), 0.02)
	# 문틀과 미닫이 문짝
	var steel_d: StringName = StyleMaterialSet.STEEL_DARK
	for x: float in [DOOR_X0 - 0.12, DOOR_X1 + 0.12]:
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, DOOR_H * 0.5, front_out + 0.02)), Vector3(0.24, DOOR_H, 0.34), 0.02)
	k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3((DOOR_X0 + DOOR_X1) * 0.5, DOOR_H + 0.12, front_out + 0.02)),
			Vector3(DOOR_X1 - DOOR_X0 + 0.48, 0.26, 0.34), 0.02)
	var leaf_x: float = DOOR_X1 + 1.75
	k.box(gr, StyleMaterialSet.CONT_TEAL, Transform3D(Basis.IDENTITY, Vector3(leaf_x, 2.3, front_out + 0.3)), Vector3(3.2, 4.4, 0.1), 0.02)
	k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(leaf_x - 0.4, 4.78, front_out + 0.3)), Vector3(7.0, 0.14, 0.18), 0.0)
	for rx: float in [leaf_x - 1.3, leaf_x + 1.3]:
		k.cyl(gr, steel_d, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(rx, 4.66, front_out + 0.3)), 0.12, 0.14, 12, 6)
	k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(leaf_x - 1.45, 1.6, front_out + 0.38)), Vector3(0.08, 1.1, 0.08), 0.0)
	if not k.textured:
		# 문짝 주름 (기하 리브)
		for i: int in range(10):
			k.box(gr, StyleMaterialSet.CONT_TEAL, Transform3D(Basis.IDENTITY, Vector3(leaf_x - 1.4 + i * 0.31, 2.3, front_out + 0.37)),
					Vector3(0.12, 4.2, 0.06), 0.0)
	# 문 앞 콘크리트 단
	slab(k, gr, conc, Vector3(DOOR_X0 - 0.6, 0.0, front_out), Vector3(DOOR_X1 + 0.6, 0.18, front_out + 1.4), 0.03)
	# 옆벽, 뒷벽, 지붕, 바닥
	var west_x: float = -HALF_W
	slab(k, gr, brick, Vector3(west_x, 0.0, BACK_Z), Vector3(west_x + WALL_T, SIDE_WINDOW_Y0, front_in))
	slab(k, gr, brick, Vector3(west_x, SIDE_WINDOW_Y1, BACK_Z), Vector3(west_x + WALL_T, WALL_H, front_in))
	slab(k, gr, brick, Vector3(west_x, SIDE_WINDOW_Y0, SIDE_WINDOW_Z1), Vector3(west_x + WALL_T, SIDE_WINDOW_Y1, front_in))
	slab(k, gr, brick, Vector3(west_x, SIDE_WINDOW_Y0, BACK_Z), Vector3(west_x + WALL_T, SIDE_WINDOW_Y1, SIDE_WINDOW_Z0))
	slab(k, gr, brick, Vector3(HALF_W - WALL_T, 0.0, BACK_Z), Vector3(HALF_W, WALL_H, front_in))
	slab(k, gr, brick, Vector3(-HALF_W, 0.0, BACK_Z), Vector3(HALF_W, WALL_H, BACK_Z + WALL_T))
	slab(k, gr, StyleMaterialSet.CONCRETE_DARK, Vector3(-HALF_W - 0.2, WALL_H, BACK_Z - 0.2), Vector3(HALF_W + 0.2, WALL_H + 0.4, front_in), 0.04)
	slab(k, gr, StyleMaterialSet.CONCRETE_DARK, Vector3(-HALF_W + WALL_T, -0.3, BACK_Z + WALL_T), Vector3(HALF_W - WALL_T, 0.0, front_in))
	# 서쪽 창: 밝은 하늘빛 유리
	k.box(gr, StyleMaterialSet.GLASS_LIT, Transform3D(Basis.IDENTITY, Vector3(west_x + 0.15, (SIDE_WINDOW_Y0 + SIDE_WINDOW_Y1) * 0.5, (SIDE_WINDOW_Z0 + SIDE_WINDOW_Z1) * 0.5)),
			Vector3(0.05, SIDE_WINDOW_Y1 - SIDE_WINDOW_Y0, SIDE_WINDOW_Z1 - SIDE_WINDOW_Z0), 0.0)
	for z: float in [-15.6, -16.9]:
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(west_x + 0.2, 6.3, z)), Vector3(0.08, 2.2, 0.06), 0.0)
	k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(west_x + 0.2, 6.3, -16.25)), Vector3(0.08, 0.06, 3.5), 0.0)
	# 뒷벽 창 (밝은 배경 빛)
	for wx: float in [-7.0, 0.0, 7.0]:
		k.box(gr, StyleMaterialSet.GLASS_LIT, Transform3D(Basis.IDENTITY, Vector3(wx, 6.4, BACK_Z + WALL_T + 0.03)), Vector3(3.0, 1.8, 0.05), 0.0)
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(wx, 6.4, BACK_Z + WALL_T + 0.05)), Vector3(0.07, 1.8, 0.05), 0.0)
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(wx, 6.4, BACK_Z + WALL_T + 0.05)), Vector3(3.0, 0.07, 0.05), 0.0)
	# 지붕 위 환풍구
	for vx: float in [-6.0, 2.0, 8.5]:
		k.box(gr, StyleMaterialSet.STEEL, Transform3D(Basis.IDENTITY, Vector3(vx, WALL_H + 0.9, -17.0)), Vector3(1.6, 1.0, 1.6), 0.05)


## 내부 구조: 기둥, 지붕 보, 천장 크레인, 선반.
static func build_interior_structure(k: StyleKit) -> void:
	var gr: MeshBuilder = k.g(&"interior")
	var steel_d: StringName = StyleMaterialSet.STEEL_DARK
	for x: float in [-6.5, 6.5]:
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, 4.2, -19.0)), Vector3(0.5, 8.4, 0.5), 0.02)
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, 0.05, -19.0)), Vector3(0.9, 0.1, 0.9), 0.01)
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, 0.9, -19.0)), Vector3(0.7, 0.9, 0.7), 0.03)
	# 지붕 보 (트러스풍)
	for z: float in [-14.5, -19.0, -23.5]:
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(0.0, 9.1, z)), Vector3(23.4, 0.3, 0.3), 0.0)
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(0.0, 8.3, z)), Vector3(23.4, 0.3, 0.3), 0.0)
		var n: int = k.pick_i(14, 8)
		for i: int in range(n):
			var x0: float = -11.7 + 23.4 * float(i) / float(n)
			var x1: float = -11.7 + 23.4 * float(i + 1) / float(n)
			if i % 2 == 0:
				k.strut(gr, steel_d, Vector3(x0, 8.3, z), Vector3(x1, 9.1, z), 0.12)
			else:
				k.strut(gr, steel_d, Vector3(x0, 9.1, z), Vector3(x1, 8.3, z), 0.12)
	# 천장 크레인: 레일 둘 + 다리 보 + 호이스트 + 갈고리
	for x: float in [-9.0, 9.0]:
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, 7.4, -19.0)), Vector3(0.34, 0.4, 14.0), 0.0)
		k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(x, 7.9, -19.0)), Vector3(0.7, 0.3, 14.0), 0.0)
	k.box(gr, StyleMaterialSet.FORKLIFT, Transform3D(Basis.IDENTITY, Vector3(0.0, 7.0, -17.5)), Vector3(18.4, 0.55, 0.6), 0.03)
	k.box(gr, StyleMaterialSet.FORKLIFT, Transform3D(Basis.IDENTITY, Vector3(3.2, 6.3, -17.5)), Vector3(1.0, 0.8, 1.2), 0.05)
	k.cyl(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(3.2, 5.0, -17.5)), 0.03, 1.8, 6, 4)
	k.box(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(3.2, 4.0, -17.5)), Vector3(0.2, 0.3, 0.2), 0.03)
	# 선반: 동쪽 벽 따라
	for bay: int in range(3):
		var z0: float = -14.2 - bay * 2.6
		for sz: int in [0, 1]:
			var rz: float = z0 - sz * 2.4
			for sx: int in [0, 1]:
				k.box(gr, StyleMaterialSet.RUST, Transform3D(Basis.IDENTITY, Vector3(9.9 + sx * 1.1, 1.8, rz)), Vector3(0.1, 3.6, 0.1), 0.0)
		for level: int in range(3):
			var y: float = 0.5 + level * 1.2
			k.box(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(10.45, y, z0 - 1.2)), Vector3(1.3, 0.06, 2.5), 0.0)
	# 가운데 매단 램프의 사슬·갓
	k.cyl(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(1.2, 7.6, -15.5)), 0.015, 2.8, 6, 4)
	k.cyl(gr, steel_d, Transform3D(Basis.IDENTITY, Vector3(1.2, 6.1, -15.5)), 0.5, 0.36, 16, 8, 0.0, 0.14)
	k.cyl(gr, StyleMaterialSet.LAMP, Transform3D(Basis.IDENTITY, Vector3(1.2, 5.88, -15.5)), 0.17, 0.12, 12, 6)


## 지게차 (로컬 -Z가 앞).
static func forklift(k: StyleKit, pos: Vector3, yaw: float) -> void:
	var gr: MeshBuilder = k.g(&"forklift")
	var base: Transform3D = StyleKit.xf(pos, yaw)
	var body: StringName = StyleMaterialSet.FORKLIFT
	var steel_d: StringName = StyleMaterialSet.STEEL_DARK
	k.box(gr, body, StyleKit.loc(base, Vector3(0.0, 0.7, 0.05)), Vector3(1.1, 0.7, 1.9), 0.07)
	k.box(gr, body, StyleKit.loc(base, Vector3(0.0, 0.85, 1.0)), Vector3(1.16, 0.9, 0.7), 0.1)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 1.15, 0.2)), Vector3(0.55, 0.12, 0.5), 0.03)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 1.45, 0.42)), Vector3(0.55, 0.55, 0.1), 0.03)
	for sx: int in [-1, 1]:
		for sz: int in [0, 1]:
			k.box(gr, steel_d, StyleKit.loc(base, Vector3(sx * 0.5, 1.6, -0.35 + sz * 0.95)), Vector3(0.07, 1.2, 0.07), 0.0)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 2.2, 0.1)), Vector3(1.2, 0.07, 1.25), 0.02)
	k.cyl(gr, steel_d, Transform3D(base.basis * Basis(Vector3.RIGHT, 0.6), base * Vector3(0.0, 1.2, -0.3)), 0.025, 0.55, 6, 4)
	# 마스트와 포크
	for sx: int in [-1, 1]:
		k.box(gr, steel_d, StyleKit.loc(base, Vector3(sx * 0.3, 1.4, -1.0)), Vector3(0.1, 2.5, 0.12), 0.0)
		k.box(gr, StyleMaterialSet.STEEL, StyleKit.loc(base, Vector3(sx * 0.3, 0.1, -1.55)), Vector3(0.11, 0.05, 1.25), 0.0)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 0.4, -1.08)), Vector3(0.95, 0.4, 0.06), 0.0)
	k.box(gr, steel_d, StyleKit.loc(base, Vector3(0.0, 2.5, -1.0)), Vector3(0.75, 0.1, 0.1), 0.0)
	for w: Array in [[-0.55, 0.3, -0.5, 0.3], [0.55, 0.3, -0.5, 0.3], [-0.5, 0.23, 1.0, 0.23], [0.5, 0.23, 1.0, 0.23]]:
		var wb := Transform3D(base.basis * StyleKit.axis_x(), base * Vector3(w[0], w[1], w[2]))
		k.cyl(gr, StyleMaterialSet.RUBBER, wb, w[3], 0.24, 16, 8, 0.04)
		k.cyl(gr, steel_d, Transform3D(wb.basis, base * Vector3(w[0] + signf(w[0]) * 0.02, w[1], w[2])), w[3] * 0.5, 0.26, 10, 5)


## 내부 소품: 지게차, 상자 더미, 팔레트, 드럼통.
static func build_interior_props(k: StyleKit) -> void:
	forklift(k, Vector3(-3.6, 0.0, -17.0), 0.5)
	var gr: MeshBuilder = k.g(&"crates")
	StyleYard.crate(k, gr, StyleKit.xf(Vector3(6.2, 0.0, -14.4), 0.2), Vector3(1.2, 1.0, 1.0))
	StyleYard.crate(k, gr, StyleKit.xf(Vector3(6.3, 1.0, -14.5), -0.15), Vector3(0.9, 0.8, 0.9))
	StyleYard.crate(k, gr, StyleKit.xf(Vector3(7.6, 0.0, -15.9), 0.5), Vector3(1.0, 0.9, 1.0))
	StyleYard.crate(k, gr, StyleKit.xf(Vector3(-8.2, 0.0, -21.0), 0.1), Vector3(1.3, 1.1, 1.1))
	StyleYard.crate(k, gr, StyleKit.xf(Vector3(-9.6, 0.0, -20.4), 0.7), Vector3(1.0, 0.85, 1.0))
	StyleYard.crate(k, gr, StyleKit.xf(Vector3(-1.8, 0.0, -21.8), 0.3), Vector3(1.1, 1.0, 1.1))
	# 선반 위 상자
	for bay: int in range(3):
		for level: int in range(3):
			if (bay + level) % 2 == 0:
				StyleYard.crate(k, gr, StyleKit.xf(Vector3(10.45, 0.53 + level * 1.2, -15.4 - bay * 2.6), 0.05 * level), Vector3(0.9, 0.7, 1.2))
	var pg: MeshBuilder = k.g(&"pallets")
	StyleYard.pallet(k, pg, StyleKit.xf(Vector3(2.8, 0.0, -20.6), 0.4))
	StyleYard.pallet(k, pg, StyleKit.xf(Vector3(-5.2, 0.0, -13.4), -0.3))
	StyleYard.barrel(k, Vector3(-10.4, 0.0, -14.2), StyleMaterialSet.BARREL_RED)
	StyleYard.barrel(k, Vector3(-10.9, 0.0, -15.0), StyleMaterialSet.BARREL_BLUE, false, 1.0)


## 빛줄기 둘: 서쪽 창에서 비스듬히, 그리고 지붕 천창에서 문 안쪽 바닥으로. 바닥에는 빛무리를 깐다.
static func build_light_shaft(k: StyleKit) -> void:
	var x: float = -HALF_W + WALL_T + 0.02
	_shaft(k, [
		Vector3(x, SIDE_WINDOW_Y1, SIDE_WINDOW_Z1), Vector3(x, SIDE_WINDOW_Y1, SIDE_WINDOW_Z0),
		Vector3(x, SIDE_WINDOW_Y0, SIDE_WINDOW_Z0), Vector3(x, SIDE_WINDOW_Y0, SIDE_WINDOW_Z1)], Vector3(7.2, 0.0, 1.6))
	# 천창 (지붕 보 사이) 과 그 빛줄기
	var sky: float = WALL_H - 0.28
	var gr: MeshBuilder = k.g(&"interior")
	k.box(gr, StyleMaterialSet.GLASS_LIT, Transform3D(Basis.IDENTITY, Vector3(-1.6, sky + 0.02, -20.8)), Vector3(2.0, 0.05, 2.4), 0.0)
	_shaft(k, [
		Vector3(-2.6, sky, -19.6), Vector3(-0.6, sky, -19.6), Vector3(-0.6, sky, -22.0), Vector3(-2.6, sky, -22.0)], Vector3(5.0, 0.0, -0.4))


static func _shaft(k: StyleKit, top: Array[Vector3], shift: Vector3) -> void:
	var gr: MeshBuilder = k.g(&"shaft")
	gr.set_gradient(0.0, 9.2, 0.92)
	k.mats.apply(gr, StyleMaterialSet.SHAFT)
	gr.color(Color(0.62, 0.7, 0.8, 1.0) if k.is_a else (Color(0.5, 0.42, 0.3, 1.0) if k.is_c else Color(0.8, 0.82, 0.74, 1.0)))
	var bottom: Array[Vector3] = []
	for t: Vector3 in top:
		var f: float = t.y / 7.4 if shift.y == 0.0 and t.y < 8.0 else 1.0
		bottom.append(Vector3(t.x + shift.x * f, 0.03, t.z + shift.z * f))
	for i: int in range(4):
		var j: int = (i + 1) % 4
		gr.add_quad(Transform3D.IDENTITY, top[i], top[j], bottom[j], bottom[i], Vector3.UP)
	var glow: MeshBuilder = k.g(&"glow")
	glow.set_gradient(0.0, 0.0, 0.0)
	k.mats.apply(glow, StyleMaterialSet.SHAFT)
	glow.color(Color(0.42, 0.48, 0.55, 1.0) if k.is_a else (Color(0.4, 0.34, 0.24, 1.0) if k.is_c else Color(0.55, 0.55, 0.48, 1.0)))
	glow.add_quad(Transform3D.IDENTITY, bottom[0], bottom[1], bottom[2], bottom[3], Vector3.UP)
