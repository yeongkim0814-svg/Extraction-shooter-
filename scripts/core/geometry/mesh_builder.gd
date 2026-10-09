class_name MeshBuilder
extends RefCounted
## 코드로 만드는 지오메트리 도우미: 모따기(chamfer) 박스·회전체(원기둥/원뿔대)·프로파일 압출을 한 ArrayMesh에 모은다.
## 재질별 표면(surface)으로 나뉘며, 한 빌더 = 한 MeshInstance3D (그리기 호출 절감).
## 순수 지오메트리라 노드·씬 트리에 의존하지 않는다 (헤드리스 테스트 가능).
##
## 규약
## - 삼각형 감김은 Godot 전면 규약(시계 방향)을 따른다. 바깥 법선 힌트로 자동 보정한다.
## - UV는 변환 전 로컬 좌표(미터)를 면 방향에 따라 투영한다 (박스 투영). 재질의 uv1_scale로 타일 크기를 정한다.
## - flat_shading이 true면 면마다 하나의 법선(로우폴리), false면 모따기 부분을 부드럽게 잇는다.
## - 정점 색은 tint(팔레트)와 높이 그라데이션(아래쪽을 어둡게)을 곱해 넣는다. 정점 색을 안 쓰는 재질엔 영향이 없다.

## 한 재질에 해당하는 정점 배열 묶음.
class Surface:
	var material: Material
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()

## 면마다 법선 하나 (true) 또는 모따기를 부드럽게 (false).
var flat_shading: bool = false
## 법선 맵용 탄젠트를 만들지 (법선 맵을 쓰는 재질에만 필요).
var with_tangents: bool = false
## 정점 색에 곱하는 기본 색 (팔레트).
var tint: Color = Color.WHITE
## 높이 그라데이션: y_low에서 low_color, y_high에서 white 쪽으로 (둘 다 0이면 끔). 변환 후(프롭 로컬) 높이 기준.
var gradient_low: float = 0.0
var gradient_high: float = 0.0
var gradient_dark: float = 0.0

var _surfaces: Array[Surface] = []
var _index: Dictionary[Material, int] = {}
var _current: Surface
var triangle_count: int = 0


## 이후 도형을 이 재질 표면에 넣는다.
func surface(material: Material) -> MeshBuilder:
	if not _index.has(material):
		var s := Surface.new()
		s.material = material
		_index[material] = _surfaces.size()
		_surfaces.append(s)
	_current = _surfaces[_index[material]]
	return self


## 정점 색 팔레트를 정한다.
func color(c: Color) -> MeshBuilder:
	tint = c
	return self


## 아래쪽을 dark(0~1)만큼 어둡게 만드는 높이 그라데이션을 켠다. dark가 0이면 끈다.
func set_gradient(y_low: float, y_high: float, dark: float) -> MeshBuilder:
	gradient_low = y_low
	gradient_high = y_high
	gradient_dark = dark
	return self


## 만든 표면 수.
func surface_count() -> int:
	return _surfaces.size()


# --- 박스 ---

## 모따기 박스. chamfer가 0이면 평평한 상자. segments가 1이면 45도 면 하나, 2 이상이면 둥글게.
func add_box(xform: Transform3D, size: Vector3, chamfer: float = 0.0, segments: int = 1) -> void:
	var h: Vector3 = size * 0.5
	var c: float = minf(chamfer, minf(h.x, minf(h.y, h.z)) * 0.98)
	if c <= 0.0005:
		_plain_box(xform, h)
		return
	var s: int = maxi(segments, 1)
	var inner: Vector3 = h - Vector3(c, c, c)
	# 모서리 8곳: 팔분원 격자
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			for sz: int in [-1, 1]:
				var sign_v := Vector3(sx, sy, sz)
				var center: Vector3 = sign_v * inner
				for i: int in range(s):
					for j: int in range(s - i):
						_octant_tri(xform, center, sign_v, c, s, i, j, i + 1, j, i, j + 1)
						if i + j <= s - 2:
							_octant_tri(xform, center, sign_v, c, s, i + 1, j, i + 1, j + 1, i, j + 1)
	# 모서리 12개: 두 팔분원 호를 잇는 띠
	for axis: int in range(3):
		var b: int = (axis + 1) % 3
		var cc: int = (axis + 2) % 3
		for sb: int in [-1, 1]:
			for sc: int in [-1, 1]:
				for k: int in range(s):
					var n0: Vector3 = _arc_dir(b, cc, s, k)
					var n1: Vector3 = _arc_dir(b, cc, s, k + 1)
					var pts: Array[Vector3] = []
					var nrm: Array[Vector3] = []
					for sa: int in [-1, 1]:
						var sign_v := Vector3.ZERO
						sign_v[axis] = sa
						sign_v[b] = sb
						sign_v[cc] = sc
						var center: Vector3 = sign_v * inner
						for n: Vector3 in [n0, n1]:
							var sn: Vector3 = _signed(n, sign_v)
							pts.append(center + sn * c)
							nrm.append(sn)
					# pts: [(-,n0), (-,n1), (+,n0), (+,n1)]
					_emit(xform, pts[0], pts[1], pts[2], nrm[0], nrm[1], nrm[2])
					_emit(xform, pts[1], pts[3], pts[2], nrm[1], nrm[3], nrm[2])
	# 면 6개: 꼭짓점 법선이 면 법선인 사각형
	for axis: int in range(3):
		var b: int = (axis + 1) % 3
		var cc: int = (axis + 2) % 3
		for sa: int in [-1, 1]:
			var quad: Array[Vector3] = []
			for sb: int in [-1, 1]:
				for sc: int in [-1, 1]:
					var p := Vector3.ZERO
					p[axis] = sa * h[axis]
					p[b] = sb * inner[b]
					p[cc] = sc * inner[cc]
					quad.append(p)
			var nf := Vector3.ZERO
			nf[axis] = sa
			_emit(xform, quad[0], quad[1], quad[2], nf, nf, nf)
			_emit(xform, quad[1], quad[3], quad[2], nf, nf, nf)


## 팔분원 호 위의 방향 (축 b·c 사이, 나머지 성분 0). k = 0..s.
func _arc_dir(b: int, cc: int, s: int, k: int) -> Vector3:
	var d := Vector3.ZERO
	d[b] = float(s - k)
	d[cc] = float(k)
	return d.normalized()


func _signed(n: Vector3, sign_v: Vector3) -> Vector3:
	return Vector3(n.x * sign_v.x, n.y * sign_v.y, n.z * sign_v.z)


func _octant_tri(xform: Transform3D, center: Vector3, sign_v: Vector3, c: float, s: int,
		i0: int, j0: int, i1: int, j1: int, i2: int, j2: int) -> void:
	var ns: Array[Vector3] = []
	var ps: Array[Vector3] = []
	for ij: Vector2i in [Vector2i(i0, j0), Vector2i(i1, j1), Vector2i(i2, j2)]:
		var w := Vector3(float(s - ij.x - ij.y), float(ij.x), float(ij.y)).normalized()
		var n: Vector3 = _signed(w, sign_v)
		ns.append(n)
		ps.append(center + n * c)
	_emit(xform, ps[0], ps[1], ps[2], ns[0], ns[1], ns[2])


func _plain_box(xform: Transform3D, h: Vector3) -> void:
	for axis: int in range(3):
		var b: int = (axis + 1) % 3
		var cc: int = (axis + 2) % 3
		for sa: int in [-1, 1]:
			var quad: Array[Vector3] = []
			for sb: int in [-1, 1]:
				for sc: int in [-1, 1]:
					var p := Vector3.ZERO
					p[axis] = sa * h[axis]
					p[b] = sb * h[b]
					p[cc] = sc * h[cc]
					quad.append(p)
			var nf := Vector3.ZERO
			nf[axis] = sa
			_emit(xform, quad[0], quad[1], quad[2], nf, nf, nf)
			_emit(xform, quad[1], quad[3], quad[2], nf, nf, nf)


# --- 회전체 ---

## Y축 회전체. profile은 (반지름, y) 점 목록 (아래에서 위로). 반지름 0인 끝은 마개 중심이 된다.
## 원기둥·원뿔대·모따기 통을 모두 이걸로 만든다.
func add_revolve(xform: Transform3D, profile: PackedVector2Array, sides: int) -> void:
	var n: int = maxi(sides, 3)
	for k: int in range(profile.size() - 1):
		var a: Vector2 = profile[k]
		var b: Vector2 = profile[k + 1]
		# 이 프로파일 구간의 바깥 법선 (r, y 평면)
		var seg: Vector2 = b - a
		var out2 := Vector2(seg.y, -seg.x).normalized()
		for i: int in range(n):
			var t0: float = TAU * float(i) / float(n)
			var t1: float = TAU * float(i + 1) / float(n)
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p10 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p01 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			var n0 := Vector3(cos(t0) * out2.x, out2.y, sin(t0) * out2.x)
			var n1 := Vector3(cos(t1) * out2.x, out2.y, sin(t1) * out2.x)
			if a.x <= 0.00001:
				_emit(xform, p00, p11, p01, n0, n1, n0)
			elif b.x <= 0.00001:
				_emit(xform, p00, p10, p01, n0, n1, n0)
			else:
				_emit(xform, p00, p10, p01, n0, n1, n0)
				_emit(xform, p10, p11, p01, n1, n1, n0)


## 원기둥 (Y축, 가운데가 원점). bevel > 0이면 양 끝을 모따기한다.
func add_cylinder(xform: Transform3D, radius: float, height: float, sides: int, bevel: float = 0.0,
		top_radius: float = -1.0) -> void:
	var hh: float = height * 0.5
	var rt: float = radius if top_radius < 0.0 else top_radius
	var b: float = minf(bevel, minf(radius, rt) * 0.9)
	var prof := PackedVector2Array()
	if b > 0.0005:
		prof.append_array(PackedVector2Array([Vector2(0.0, -hh), Vector2(radius - b, -hh), Vector2(radius, -hh + b),
				Vector2(rt, hh - b), Vector2(rt - b, hh), Vector2(0.0, hh)]))
	else:
		prof.append_array(PackedVector2Array([Vector2(0.0, -hh), Vector2(radius, -hh), Vector2(rt, hh), Vector2(0.0, hh)]))
	add_revolve(xform, prof, sides)


# --- 프로파일 압출 ---

## 2D 프로파일(로컬 XY, 반시계)을 로컬 Z로 length만큼 (가운데 기준) 압출한다. 항상 면마다 법선 하나.
func add_prism(xform: Transform3D, profile: PackedVector2Array, length: float) -> void:
	var hz: float = length * 0.5
	var count: int = profile.size()
	for i: int in range(count):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % count]
		var edge: Vector2 = b - a
		if edge.length() < 0.00001:
			continue
		var out2 := Vector2(edge.y, -edge.x).normalized()
		var nf := Vector3(out2.x, out2.y, 0.0)
		var p0 := Vector3(a.x, a.y, -hz)
		var p1 := Vector3(b.x, b.y, -hz)
		var p2 := Vector3(a.x, a.y, hz)
		var p3 := Vector3(b.x, b.y, hz)
		_emit(xform, p0, p1, p2, nf, nf, nf)
		_emit(xform, p1, p3, p2, nf, nf, nf)
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(profile)
	for t: int in range(0, tris.size(), 3):
		var q0: Vector2 = profile[tris[t]]
		var q1: Vector2 = profile[tris[t + 1]]
		var q2: Vector2 = profile[tris[t + 2]]
		_emit(xform, Vector3(q0.x, q0.y, hz), Vector3(q1.x, q1.y, hz), Vector3(q2.x, q2.y, hz), Vector3.BACK, Vector3.BACK, Vector3.BACK)
		_emit(xform, Vector3(q0.x, q0.y, -hz), Vector3(q1.x, q1.y, -hz), Vector3(q2.x, q2.y, -hz), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD)


## 임의 사각형 한 장 (바깥쪽 법선 힌트 필요). 정점은 a-b-c-d 순서.
func add_quad(xform: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_emit(xform, a, b, c, outward, outward, outward)
	_emit(xform, a, c, d, outward, outward, outward)


## 임의 삼각형 한 장.
func add_triangle(xform: Transform3D, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	_emit(xform, a, b, c, outward, outward, outward)


# --- 방출 ---

## 삼각형 하나를 현재 표면에 넣는다. hint 법선은 바깥 방향 판정과 부드러운 법선에 쓴다.
func _emit(xform: Transform3D, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var face: Vector3 = (b - a).cross(c - a)
	if face.length_squared() < 1e-12:
		return
	var hint: Vector3 = na + nb + nc
	# Godot 전면은 시계 방향: (b-a)x(c-a)가 바깥을 보면 반시계이므로 b, c를 바꾼다.
	if face.dot(hint) > 0.0:
		var tp: Vector3 = b
		b = c
		c = tp
		var tn: Vector3 = nb
		nb = nc
		nc = tn
		face = -face
	var flat_n: Vector3 = -face.normalized()
	var surf: Surface = _current
	var basis_n: Basis = xform.basis
	var pts: Array[Vector3] = [a, b, c]
	var nrm: Array[Vector3] = [na, nb, nc]
	for v: int in range(3):
		var p: Vector3 = pts[v]
		var wp: Vector3 = xform * p
		surf.verts.append(wp)
		var nl: Vector3 = flat_n if flat_shading else nrm[v].normalized()
		surf.normals.append((basis_n * nl).normalized())
		surf.uvs.append(_project_uv(p, flat_n))
		surf.colors.append(_vertex_color(wp.y))
	triangle_count += 1


static func _project_uv(p: Vector3, n: Vector3) -> Vector2:
	var ax: float = absf(n.x)
	var ay: float = absf(n.y)
	var az: float = absf(n.z)
	if az >= ax and az >= ay:
		return Vector2(p.x, -p.y)
	if ax >= ay:
		return Vector2(p.z, -p.y)
	return Vector2(p.x, p.z)


func _vertex_color(y: float) -> Color:
	if gradient_dark <= 0.0 or gradient_high <= gradient_low:
		return tint
	var t: float = clampf((y - gradient_low) / (gradient_high - gradient_low), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var k: float = 1.0 - gradient_dark * (1.0 - t)
	return Color(tint.r * k, tint.g * k, tint.b * k, tint.a)


# --- 결과 ---

## 모은 도형을 ArrayMesh 하나로 만든다 (재질별 표면).
func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surf: Surface in _surfaces:
		if surf.verts.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surf.verts
		arrays[Mesh.ARRAY_NORMAL] = surf.normals
		arrays[Mesh.ARRAY_TEX_UV] = surf.uvs
		arrays[Mesh.ARRAY_COLOR] = surf.colors
		if with_tangents:
			var st := SurfaceTool.new()
			st.create_from_arrays(arrays)
			st.generate_tangents()
			arrays = st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surf.material)
	return mesh
