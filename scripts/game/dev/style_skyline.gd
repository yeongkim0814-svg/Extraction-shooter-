class_name StyleSkyline
extends RefCounted
## 스타일 비교 씬의 먼 배경: 굴뚝(빨강/흰 띠 하나), 타워 크레인, 격자 철탑, 먼 공장 덩어리, 어두운 낮은 언덕.
## 충돌 없음. 라이팅과 안개를 그대로 받아 거리감이 생긴다.


static func build(k: StyleKit) -> void:
	var gr: MeshBuilder = k.g(&"skyline")
	gr.set_gradient(0.0, 0.0, 0.0)
	_hills(k, gr)
	_factory_blocks(k, gr)
	_stack(k, gr, Vector3(-44.0, 0.0, -78.0), 46.0, 2.1, 1.35, true)
	_stack(k, gr, Vector3(-37.0, 0.0, -74.0), 36.0, 1.7, 1.15, false)
	_stack(k, gr, Vector3(-52.0, 0.0, -82.0), 30.0, 1.5, 1.05, false)
	_crane(k, gr, Vector3(46.0, 0.0, -72.0), 40.0)
	_lattice_tower(k, gr, Vector3(74.0, 0.0, -44.0), 48.0, 6.0, 1.2)
	_stack(k, gr, Vector3(30.0, 0.0, -90.0), 38.0, 1.8, 1.2, false)
	if k.is_c:
		_smoke_plume(k, gr, Vector3(-44.0, 47.0, -78.0), 16)
		_smoke_plume(k, gr, Vector3(-37.0, 37.0, -74.0), 12)


## 굴뚝: 위가 가늘어지는 원기둥. banded면 빨강/흰 띠.
static func _stack(k: StyleKit, gr: MeshBuilder, pos: Vector3, height: float, r0: float, r1: float, banded: bool) -> void:
	var far: StringName = StyleMaterialSet.SKY_NEAR
	var segs: int = 7 if banded else 1
	for i: int in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var rr0: float = lerpf(r0, r1, t0)
		var rr1: float = lerpf(r0, r1, t1)
		var id: StringName = far
		if banded:
			id = StyleMaterialSet.BAND_RED if i % 2 == 1 and i >= 3 else (StyleMaterialSet.BAND_WHITE if i >= 3 else far)
		k.cyl(gr, id, Transform3D(Basis.IDENTITY, pos + Vector3(0.0, height * (t0 + t1) * 0.5, 0.0)), rr0, height / float(segs),
				k.pick_i(16, 8), k.pick_i(16, 8), 0.0, rr1)
	k.cyl(gr, StyleMaterialSet.SKY_MID, Transform3D(Basis.IDENTITY, pos + Vector3(0.0, height + 0.2, 0.0)), r1 * 1.12, 0.5, k.pick_i(16, 8), 8)


static func _factory_blocks(k: StyleKit, gr: MeshBuilder) -> void:
	var blocks: Array[Array] = [
		[Vector3(-30.0, 8.0, -88.0), Vector3(40.0, 16.0, 14.0)],
		[Vector3(10.0, 6.0, -84.0), Vector3(30.0, 12.0, 12.0)],
		[Vector3(-62.0, 5.0, -70.0), Vector3(16.0, 10.0, 22.0)],
		[Vector3(58.0, 7.0, -68.0), Vector3(20.0, 14.0, 16.0)],
		[Vector3(-22.0, 13.0, -95.0), Vector3(14.0, 26.0, 10.0)],
	]
	for b: Array in blocks:
		var c: Vector3 = b[0]
		var s: Vector3 = b[1]
		k.box(gr, StyleMaterialSet.SKY_MID, Transform3D(Basis.IDENTITY, c), s, 0.6)
		k.box(gr, StyleMaterialSet.SKY_FAR, Transform3D(Basis.IDENTITY, c + Vector3(s.x * 0.2, s.y * 0.5 + 1.2, 0.0)), Vector3(s.x * 0.35, 2.4, s.z * 0.5), 0.2)


## 격자 철탑: 네 다리가 위로 좁아지고 각 칸에 X 버팀대.
static func _lattice_tower(k: StyleKit, gr: MeshBuilder, pos: Vector3, height: float, base_w: float, top_w: float) -> void:
	var panels: int = k.pick_i(14, 7)
	var id: StringName = StyleMaterialSet.SKY_NEAR
	var thick: float = 0.34
	for i: int in range(panels):
		var f0: float = float(i) / float(panels)
		var f1: float = float(i + 1) / float(panels)
		var w0: float = lerpf(base_w, top_w, f0) * 0.5
		var w1: float = lerpf(base_w, top_w, f1) * 0.5
		var y0: float = height * f0
		var y1: float = height * f1
		var c0: Array[Vector3] = [Vector3(-w0, y0, -w0), Vector3(w0, y0, -w0), Vector3(w0, y0, w0), Vector3(-w0, y0, w0)]
		var c1: Array[Vector3] = [Vector3(-w1, y1, -w1), Vector3(w1, y1, -w1), Vector3(w1, y1, w1), Vector3(-w1, y1, w1)]
		for j: int in range(4):
			var n: int = (j + 1) % 4
			k.strut(gr, id, pos + c0[j], pos + c1[j], thick)
			k.strut(gr, id, pos + c1[j], pos + c1[n], thick * 0.7)
			k.strut(gr, id, pos + c0[j], pos + c1[n], thick * 0.5)
			if k.is_a:
				k.strut(gr, id, pos + c0[n], pos + c1[j], thick * 0.5)
	k.box(gr, id, Transform3D(Basis.IDENTITY, pos + Vector3(0.0, height + 1.2, 0.0)), Vector3(1.6, 2.4, 1.6), 0.0)


## 타워 크레인: 격자 마스트, 앞 지브, 뒤 균형추, 운전실, 갈고리.
static func _crane(k: StyleKit, gr: MeshBuilder, pos: Vector3, height: float) -> void:
	var id: StringName = StyleMaterialSet.SKY_NEAR
	var panels: int = k.pick_i(16, 8)
	var w: float = 2.4
	for i: int in range(panels):
		var y0: float = height * float(i) / float(panels)
		var y1: float = height * float(i + 1) / float(panels)
		var cs: Array[Vector3] = [Vector3(-w, 0, -w), Vector3(w, 0, -w), Vector3(w, 0, w), Vector3(-w, 0, w)]
		for j: int in range(4):
			var n: int = (j + 1) % 4
			k.strut(gr, id, pos + cs[j] * 0.5 + Vector3(0, y0, 0), pos + cs[j] * 0.5 + Vector3(0, y1, 0), 0.26)
			k.strut(gr, id, pos + cs[j] * 0.5 + Vector3(0, y1, 0), pos + cs[n] * 0.5 + Vector3(0, y1, 0), 0.18)
			k.strut(gr, id, pos + cs[j] * 0.5 + Vector3(0, y0, 0), pos + cs[n] * 0.5 + Vector3(0, y1, 0), 0.16)
	var top: Vector3 = pos + Vector3(0.0, height, 0.0)
	# 지브 (앞, +X 방향이 아니라 -Z 쪽으로 뻗는다) 와 균형추 지브
	var jib_len: float = 34.0
	var back_len: float = 11.0
	k.box(gr, id, Transform3D(Basis.IDENTITY, top + Vector3(0.0, 0.7, -jib_len * 0.5 + 4.0)), Vector3(0.5, 0.5, jib_len), 0.0)
	k.box(gr, id, Transform3D(Basis.IDENTITY, top + Vector3(0.0, 2.4, -jib_len * 0.5 + 4.0)), Vector3(0.2, 0.2, jib_len), 0.0)
	var spans: int = k.pick_i(12, 6)
	for i: int in range(spans):
		var z0: float = top.z + 4.0 - jib_len * float(i) / float(spans)
		var z1: float = top.z + 4.0 - jib_len * float(i + 1) / float(spans)
		var up: bool = i % 2 == 0
		k.strut(gr, id, Vector3(top.x, top.y + (0.7 if up else 2.4), z0), Vector3(top.x, top.y + (2.4 if up else 0.7), z1), 0.14)
	k.box(gr, id, Transform3D(Basis.IDENTITY, top + Vector3(0.0, 0.7, back_len * 0.5 + 4.0)), Vector3(0.5, 0.5, back_len), 0.0)
	k.box(gr, id, Transform3D(Basis.IDENTITY, top + Vector3(0.0, 0.2, back_len + 2.5)), Vector3(2.2, 1.8, 2.4), 0.1)
	k.box(gr, id, Transform3D(Basis.IDENTITY, top + Vector3(0.0, 3.5, 0.0)), Vector3(0.3, 3.4, 0.3), 0.0)
	k.strut(gr, id, top + Vector3(0.0, 5.0, 0.0), top + Vector3(0.0, 2.4, -jib_len + 4.0), 0.1)
	k.strut(gr, id, top + Vector3(0.0, 5.0, 0.0), top + Vector3(0.0, 0.7, back_len + 4.0), 0.1)
	k.box(gr, StyleMaterialSet.SKY_MID, Transform3D(Basis.IDENTITY, top + Vector3(1.6, 0.4, 3.0)), Vector3(2.0, 2.0, 2.4), 0.12)
	# 갈고리 케이블과 짐
	k.box(gr, id, Transform3D(Basis.IDENTITY, top + Vector3(0.0, -6.0, -22.0)), Vector3(0.07, 14.0, 0.07), 0.0)
	k.box(gr, StyleMaterialSet.SKY_MID, Transform3D(Basis.IDENTITY, top + Vector3(0.0, -13.4, -22.0)), Vector3(2.4, 1.2, 1.2), 0.1)


## 어두운 낮은 언덕 고리. A는 노이즈 능선 한 겹+먼 겹, B는 단순한 두 겹의 각진 능선.
static func _hills(k: StyleKit, gr: MeshBuilder) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var layers: Array[Array] = [
		[StyleMaterialSet.HILL_FAR, 170.0, 34.0, 1.0],
		[StyleMaterialSet.HILL, 118.0, 20.0, 2.0],
	]
	var steps: int = k.pick_i(96, 36)
	for layer: Array in layers:
		var id: StringName = layer[0]
		var radius: float = layer[1]
		var peak: float = layer[2]
		var phase: float = layer[3]
		k.mats.apply(gr, id)
		var prev_top: Vector3 = Vector3.ZERO
		var prev_bot: Vector3 = Vector3.ZERO
		for i: int in range(steps + 1):
			var a: float = TAU * float(i) / float(steps)
			var h: float = peak * (0.45 + 0.55 * (noise.get_noise_2d(cos(a) * 80.0 + phase * 50.0, sin(a) * 80.0) * 0.5 + 0.5))
			if not k.is_a:
				h = round(h / 3.0) * 3.0
			var dir := Vector3(cos(a), 0.0, sin(a))
			var bot: Vector3 = dir * radius + Vector3(0.0, -2.0, 0.0)
			var top: Vector3 = dir * (radius - 6.0) + Vector3(0.0, h, 0.0)
			if i > 0:
				gr.add_quad(Transform3D.IDENTITY, prev_bot, bot, top, prev_top, -Vector3(dir.x, 0.0, dir.z))
			prev_top = top
			prev_bot = bot


## 스타일 C 연기 기둥: 굴뚝 끝에서 바람(+X)을 따라 비스듬히 올라가며 커지는 각진 덩어리. 아래는 짙고 위는 흐려진다.
static func _smoke_plume(k: StyleKit, gr: MeshBuilder, top: Vector3, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(top.x * 7.0) + 11
	for i: int in range(count):
		var t: float = float(i) / float(count - 1)
		var pos: Vector3 = top + Vector3(t * 46.0 + rng.randf_range(-1.0, 1.0), t * 24.0 + rng.randf_range(-1.0, 1.0), rng.randf_range(-2.0, 2.0))
		var size: float = lerpf(2.4, 9.0, t) * rng.randf_range(0.85, 1.15)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		k.mats.apply(gr, StyleMaterialSet.SKY_NEAR)
		var shade: float = lerpf(0.1, 0.32, t)
		gr.color(Color(shade, shade * 1.02, shade * 1.08))
		gr.add_box(Transform3D(basis, pos), Vector3(size, size * rng.randf_range(0.7, 1.0), size * rng.randf_range(0.8, 1.1)), size * 0.12, 1)
