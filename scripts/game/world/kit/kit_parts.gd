class_name KitParts
extends RefCounted
## 부품 정의들이 같이 쓰는 도우미 (난간·바퀴·구멍 난 벽·잔해 더미). 전부 KitBuild에 도형을 쌓기만 한다.

## 위치만 있는 변환.
static func at(pos: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos)


## 중심 기준 상자 (모따기·충돌 기본 없음).
static func slab(kb: KitBuild, id: StringName, center: Vector3, size: Vector3, collide: bool = false) -> void:
	kb.box(id, at(center), size, 0.0, collide)


## 아래 y가 pos.y인 상자 (바닥 중심 기준, 모따기 없음).
static func plain(kb: KitBuild, id: StringName, pos: Vector3, size: Vector3, collide: bool = false) -> void:
	kb.block(id, pos, size, 0.0, collide)


## 프로파일을 반시계로 (add_prism은 반시계를 가정한다).
static func ccw(profile: PackedVector2Array) -> PackedVector2Array:
	if not Geometry2D.is_polygon_clockwise(profile):
		return profile
	var out := PackedVector2Array()
	for i: int in range(profile.size() - 1, -1, -1):
		out.append(profile[i])
	return out


## Y축 원기둥을 dir 방향으로 눕힌 변환 (원기둥 가운데 = center).
static func along(center: Vector3, dir: Vector3) -> Transform3D:
	var d: Vector3 = dir.normalized()
	if absf(d.dot(Vector3.UP)) > 0.9999:
		return Transform3D(Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI), center)
	return Transform3D(Basis(Quaternion(Vector3.UP, d)), center)


## X축 방향 원기둥 (긴 파이프·형광관). 가운데 = center, 길이 = length.
static func cyl_x(kb: KitBuild, id: StringName, center: Vector3, radius: float, length: float, sides: int = 10,
		bevel: float = 0.0, collide: bool = false) -> void:
	kb.cylinder(id, along(center, Vector3.RIGHT), radius, length, sides, bevel, true, collide)


## Z축 방향 원기둥.
static func cyl_z(kb: KitBuild, id: StringName, center: Vector3, radius: float, length: float, sides: int = 10,
		bevel: float = 0.0, collide: bool = false) -> void:
	kb.cylinder(id, along(center, Vector3.BACK), radius, length, sides, bevel, true, collide)


## 난간: a -> b (수평) 사이 윗봉·중간봉·기둥. a, b는 바닥 높이의 점. 기둥은 양 끝 + spacing 간격.
static func railing(kb: KitBuild, id: StringName, a: Vector3, b: Vector3, height: float = 1.05, spacing: float = 2.0,
		thick: float = 0.05) -> void:
	var length: float = a.distance_to(b)
	var n: int = maxi(int(ceilf(length / spacing - 0.001)), 1)
	for i: int in range(n + 1):
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		kb.strut(id, p, p + Vector3(0.0, height, 0.0), thick)
	kb.strut(id, a + Vector3(0.0, height, 0.0), b + Vector3(0.0, height, 0.0), thick)
	kb.strut(id, a + Vector3(0.0, height * 0.5, 0.0), b + Vector3(0.0, height * 0.5, 0.0), thick * 0.8)


## 바퀴 (축 = 로컬 Z): 고무 타이어 + 금속 허브. center = 바퀴 중심.
static func wheel(kb: KitBuild, center: Vector3, radius: float, width: float, sides: int = 12) -> void:
	var rot := Basis(Vector3.RIGHT, PI * 0.5)
	kb.cylinder(KitMaterials.FLAT_RUBBER, Transform3D(rot, center), radius, width, sides, minf(0.04, radius * 0.1), false, false)
	kb.cylinder(KitMaterials.FLAT_METAL, Transform3D(rot, center), radius * 0.45, width + 0.02, maxi(sides - 4, 8), 0.0, false, false)


## 사각 틀 (구멍 둘레 막대 네 개). 구멍 안쪽 영역 [x0,x1]x[y0,y1] 바깥으로 w만큼 두른다. depth = Z 두께, z = 중심.
static func frame(kb: KitBuild, id: StringName, x0: float, x1: float, y0: float, y1: float, w: float, depth: float,
		z: float = 0.0, with_bottom: bool = true) -> void:
	var cx: float = (x0 + x1) * 0.5
	# 아래 막대가 없으면 (문틀) 기둥은 y0에서 시작한다
	var jy0: float = y0 - w if with_bottom else y0
	var jh: float = y1 + w - jy0
	slab(kb, id, Vector3(x0 - w * 0.5, jy0 + jh * 0.5, z), Vector3(w, jh, depth))
	slab(kb, id, Vector3(x1 + w * 0.5, jy0 + jh * 0.5, z), Vector3(w, jh, depth))
	slab(kb, id, Vector3(cx, y1 + w * 0.5, z), Vector3(x1 - x0, w, depth))
	if with_bottom:
		slab(kb, id, Vector3(cx, y0 - w * 0.5, z), Vector3(x1 - x0, w, depth))


## 구멍 난 벽 조각 (재질 하나, 단색): 로컬 X = 폭(가운데 0), 로컬 Y = 바닥에서 위, Z = 두께(가운데 0).
## 구멍 [ox0,ox1]x[oy0,oy1] 둘레 네 조각. 충돌은 같은 조각으로. parent로 위치·회전.
static func holed_wall(kb: KitBuild, id: StringName, parent: Transform3D, width: float, height: float, thick: float,
		ox0: float, ox1: float, oy0: float, oy1: float, collide: bool = true) -> void:
	var hw: float = width * 0.5
	var parts: Array[Rect2] = []
	parts.append(Rect2(-hw, 0.0, ox0 + hw, height))
	parts.append(Rect2(ox1, 0.0, hw - ox1, height))
	if oy0 > 0.001:
		parts.append(Rect2(ox0, 0.0, ox1 - ox0, oy0))
	if oy1 < height - 0.001:
		parts.append(Rect2(ox0, oy1, ox1 - ox0, height - oy1))
	for r: Rect2 in parts:
		if r.size.x < 0.001 or r.size.y < 0.001:
			continue
		var xf := parent * at(Vector3(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 0.0))
		kb.box(id, xf, Vector3(r.size.x, r.size.y, thick), 0.0, collide)



## 무작위 기울기·회전으로 놓인 조각 하나 (잔해). 바닥에 닿게 y를 올린다.
static func chunk(kb: KitBuild, id: StringName, rng: RandomNumberGenerator, pos_xz: Vector2, size: Vector3, base_y: float,
		tilt_deg: float = 20.0, as_prism: bool = false) -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-tilt_deg, tilt_deg)), rng.randf() * TAU,
			deg_to_rad(rng.randf_range(-tilt_deg, tilt_deg))))
	# 기울어진 조각의 가장 낮은 점이 base_y 바로 아래(2 cm 박힘)에 오도록 중심을 올린다
	var half := size * 0.5
	var lift: float = absf(basis.x.y) * half.x + absf(basis.y.y) * half.y + absf(basis.z.y) * half.z - 0.02
	var xf := Transform3D(basis, Vector3(pos_xz.x, base_y + lift, pos_xz.y))
	if as_prism:
		var hx: float = size.x * 0.5
		var hy: float = size.y * 0.5
		var profile := PackedVector2Array([Vector2(-hx, -hy), Vector2(hx * rng.randf_range(0.7, 1.0), -hy),
				Vector2(hx, hy * rng.randf_range(-0.2, 0.3)), Vector2(hx * rng.randf_range(0.0, 0.5), hy),
				Vector2(-hx * rng.randf_range(0.6, 1.0), hy * rng.randf_range(0.0, 0.6))])
		kb.prism(id, xf, profile, size.z)
	else:
		kb.box(id, xf, size, 0.0, false)


## 잔해 더미: 타원 안에 조각을 쌓는다 (가운데가 높다). 결정적 (rng는 부품마다 고정 시드).
static func rubble(kb: KitBuild, rng: RandomNumberGenerator, rx: float, rz: float, count: int, size_min: float,
		size_max: float, height: float, rebar: int) -> void:
	for i: int in range(count):
		var ang: float = rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * 0.92
		var px: float = cos(ang) * rx * dist
		var pz: float = sin(ang) * rz * dist
		var pile_y: float = height * (1.0 - dist) * rng.randf_range(0.5, 1.0)
		var s: float = rng.randf_range(size_min, size_max)
		var size := Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.7, 1.2))
		var mat: StringName = KitMaterials.CONCRETE_WALL if i % 5 == 4 else KitMaterials.FLAT_CONCRETE_DARK
		chunk(kb, mat, rng, Vector2(px, pz), size, pile_y, 25.0, i % 3 == 2)
	for j: int in range(rebar):
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.1, 0.6)
		var base := Vector3(cos(a) * rx * d, height * (1.0 - d) * 0.8, sin(a) * rz * d)
		var dir := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.6, 1.0), rng.randf_range(-0.5, 0.5)).normalized()
		kb.strut(KitMaterials.RUST, base, base + dir * rng.randf_range(0.4, 0.9), 0.025)
