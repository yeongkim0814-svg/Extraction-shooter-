class_name KitPiecesDressing
extends RefCounted
## 장식 부품 (잔해·종이·케이블·식물 카드 등). 원점 = 바닥 중심. 난수는 부품마다 고정 시드라 구울 때마다 같다.


static func build(piece: StringName, kb: KitBuild) -> bool:
	match piece:
		&"rubble_small":
			rubble_small(kb)
		&"rubble_large":
			rubble_large(kb)
		&"debris_planks":
			debris_planks(kb)
		&"cable_hanging_4m":
			cable_hanging_4m(kb)
		&"puddle_2m":
			puddle_2m(kb)
		_:
			return false
	return true


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 작은 잔해 더미 (약 1.4 x 1.2, 높이 0.35): 위로 걸어 넘을 수 있는 낮은 충돌.
static func rubble_small(kb: KitBuild) -> void:
	KitParts.rubble(kb, _rng(1101), 0.7, 0.6, 12, 0.14, 0.3, 0.2, 2)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.12, 0.0)), Vector3(1.2, 0.24, 1.0))


## 큰 잔해 더미 (약 3.2 x 2.8, 높이 1.2): 막는 충돌.
static func rubble_large(kb: KitBuild) -> void:
	KitParts.rubble(kb, _rng(1202), 1.6, 1.4, 34, 0.25, 0.65, 0.7, 5)
	kb.collide_box(KitParts.at(Vector3(0.0, 0.5, 0.0)), Vector3(2.6, 1.0, 2.2))


## 흩어진 나무 널판 다섯 장 (충돌 없음). 한 장은 살짝 기울어 있다.
static func debris_planks(kb: KitBuild) -> void:
	var rng := _rng(1303)
	var spots: Array[Vector2] = [Vector2(-0.6, -0.3), Vector2(0.3, 0.5), Vector2(0.7, -0.5), Vector2(-0.3, 0.6), Vector2(0.05, -0.05)]
	for i: int in range(spots.size()):
		var plank_len: float = rng.randf_range(0.9, 1.6)
		var size := Vector3(plank_len, 0.03, rng.randf_range(0.1, 0.16))
		var yaw: float = rng.randf() * PI
		var lean: float = 0.0
		if i == 4:
			lean = deg_to_rad(7.0)
		# 살짝 기운 널도 가장 낮은 점이 바닥에 닿게 중심을 올린다
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, lean)
		var rise: float = absf(basis.x.y) * plank_len * 0.5 + absf(basis.y.y) * size.y * 0.5 + absf(basis.z.y) * size.z * 0.5
		var xf := Transform3D(basis, Vector3(spots[i].x, rise, spots[i].y))
		kb.box(KitMaterials.FLAT_WOOD, xf, size, 0.0, false)
	# 이어진 짧은 토막과 못
	kb.box(KitMaterials.FLAT_WOOD, Transform3D(Basis(Vector3.UP, 0.7), Vector3(-0.9, 0.02, 0.5)), Vector3(0.45, 0.04, 0.08), 0.0, false)


## 늘어진 케이블 4 m: 원점 = 왼쪽 끝(높이 0), 오른쪽 끝도 높이 0, 가운데가 0.6 m 처진다. 두 가닥, 마디 8개.
static func cable_hanging_4m(kb: KitBuild) -> void:
	var sags: Array[float] = [0.6, 0.45]
	var zs: Array[float] = [0.0, 0.07]
	var thicks: Array[float] = [0.04, 0.03]
	for c: int in range(2):
		var pts: Array[Vector3] = []
		for i: int in range(9):
			var t: float = float(i) / 8.0
			var drop: float = sags[c] * (1.0 - pow(2.0 * t - 1.0, 2.0))
			pts.append(Vector3(4.0 * t, -drop, zs[c]))
		for i: int in range(8):
			kb.strut(KitMaterials.CABLE, pts[i], pts[i + 1], thicks[c])
	for sx: float in [0.0, 4.0]:
		KitParts.slab(kb, KitMaterials.FLAT_METAL, Vector3(sx, 0.02, 0.035), Vector3(0.08, 0.1, 0.16))


## 웅덩이 지름 약 2 m: 바닥 콘크리트 재질 위에 얇게 깐 불규칙 다각형. 정점 색 (0,1,1) = 젖음 1 (kit_ground 규약: 젖음 = 1 - COLOR.r).
static func puddle_2m(kb: KitBuild) -> void:
	var rng := _rng(1404)
	var n: int = 12
	var ring: Array[Vector3] = []
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n)
		var rr: float = rng.randf_range(0.65, 1.0) * (1.0 if i % 3 != 0 else 0.8)
		ring.append(Vector3(cos(a) * rr * 1.0 * 1.0, 0.01, sin(a) * rr * 0.75))
	var old_tint: Color = kb.mesh.tint
	kb.mesh.tint = Color(0.0, 1.0, 1.0)
	kb.use(KitMaterials.GROUND_CONCRETE)
	for i: int in range(n):
		kb.mesh.add_triangle(Transform3D.IDENTITY, Vector3(0.0, 0.01, 0.0), ring[i], ring[(i + 1) % n], Vector3.UP)
	kb.mesh.tint = old_tint
