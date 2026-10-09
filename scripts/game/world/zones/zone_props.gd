class_name ZoneProps
extends RefCounted
## 구역 씬용 소품 조립 도우미. IndustrialProps(옛 박스 조합)의 부품판이다: 같은 자리·같은 방향·같은 충돌 크기로 부품을 놓는다.
## 엄폐 표식은 여기서 만들지 않는다 (맵 코드의 IndustrialProps.cover_* 가 같은 자리에 단다).
## 옛 소품의 앞쪽은 -z, 부품 지게차·트럭·승용차의 앞쪽은 +x다 -> 부품 yaw = 옛 yaw + 90.

const _BARREL_PIECES: Array[StringName] = [&"barrel", &"barrel_red", &"barrel_teal"]
const _BARREL_OFFSETS: Array[Vector2] = [Vector2(0, 0), Vector2(0.75, 0.1), Vector2(0.3, 0.7), Vector2(-0.5, 0.6)]
const CAR_PIECES: Array[StringName] = [&"car_sedan_teal", &"car_sedan_red", &"car_sedan_olive"]


static func basis_of(yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg))


## 드럼통 무리 (IndustrialProps.barrels와 같은 배치).
static func barrels(zb: ZoneBuilder, pos: Vector3, count: int = 3) -> void:
	for i: int in range(mini(count, _BARREL_OFFSETS.size())):
		var p: Vector3 = pos + Vector3(_BARREL_OFFSETS[i].x, 0.0, _BARREL_OFFSETS[i].y)
		zb.place_at(_BARREL_PIECES[i % _BARREL_PIECES.size()], p, p.x * 53.0 + p.z * 17.0)


static func pallet(zb: ZoneBuilder, pos: Vector3, yaw_deg: float) -> void:
	zb.place_at(&"pallet", pos, yaw_deg)


## 팔레트 위 짐 더미 (1.1 x 0.55*층 x 0.7, 충돌 하나). mat = 겉면 트림/단색 (나무·청회 골함석·붉은 골함석).
static func pallet_stack(zb: ZoneBuilder, pos: Vector3, yaw_deg: float, layers: int, mat: StringName = KitMaterials.FLAT_WOOD) -> void:
	pallet(zb, pos, yaw_deg)
	var kb: KitBuild = zb.custom("props_cargo")
	var basis: Basis = basis_of(yaw_deg)
	var layer_h: float = 0.55
	for i: int in range(layers):
		var center: Vector3 = pos + Vector3(0.0, 0.14 + layer_h * (float(i) + 0.5), 0.0)
		kb.box(mat, Transform3D(basis, center), Vector3(1.1, layer_h - 0.02, 0.7), 0.02, false)
		# 결속 띠
		kb.box(KitMaterials.FLAT_METAL, Transform3D(basis, center), Vector3(0.05, layer_h, 0.72), 0.0, false)
	var total: float = layer_h * float(layers)
	kb.collide_box(Transform3D(basis, pos + Vector3(0.0, 0.14 + total * 0.5, 0.0)), Vector3(1.1, total, 0.7))


## 지게차 (옛 yaw 기준, 앞 = -z).
static func forklift(zb: ZoneBuilder, pos: Vector3, yaw_deg: float) -> void:
	zb.place_at(&"forklift", pos, yaw_deg + 90.0)


## 차단벽 3 x 1 x 0.7 (east_west가 false면 남북).
static func barrier(zb: ZoneBuilder, pos: Vector3, east_west: bool = true) -> void:
	zb.place_at(&"barrier_concrete", pos, 0.0 if east_west else 90.0)


## 버려진 승용차 (옛 yaw 기준).
static func car(zb: ZoneBuilder, pos: Vector3, yaw_deg: float, piece: StringName) -> void:
	zb.place_at(piece, pos, yaw_deg + 90.0)


## 버려진 트럭: 평상 트럭 부품 + 화물 상자. 화물 상자는 옛 트럭 화물칸과 같은 높이·바닥 면적 근처 (충돌 포함).
static func truck(zb: ZoneBuilder, pos: Vector3, yaw_deg: float, cargo_mat: StringName) -> void:
	var xf: Transform3D = ZoneBuilder.xf(pos, yaw_deg + 90.0)
	zb.place(&"truck_flatbed", xf)
	var kb: KitBuild = zb.custom("props_truck_cargo")
	# 부품 로컬: 짐칸 바닥 윗면 y = 1.02, x -3.6..0.9 -> 화물 상자 4.3 x 2.4 x 2.3
	var local := Transform3D(Basis.IDENTITY, Vector3(-1.35, 1.02 + 1.2, 0.0))
	kb.box(cargo_mat, xf * local, Vector3(4.3, 2.4, 2.3), 0.03, true)
	kb.box(KitMaterials.FLAT_METAL, xf * Transform3D(Basis.IDENTITY, Vector3(-1.35, 1.02 + 2.43, 0.0)), Vector3(4.4, 0.08, 2.4), 0.0, false)
	for sx: float in [-3.45, -1.35, 0.75]:
		kb.box(KitMaterials.FLAT_METAL, xf * Transform3D(Basis.IDENTITY, Vector3(sx, 1.02 + 1.2, 0.0)), Vector3(0.08, 2.42, 2.34), 0.0, false)


## 컨테이너 (옛 12 x 2.5 x 2.4 하나 = 20ft 둘). layer 0 = 땅, 1 = 한 칸 위. east_west true = 동서 (길이 축 x).
## 문 끝은 양 끝 바깥쪽을 보게 두 개를 마주 놓는다.
static func container(zb: ZoneBuilder, cx: float, cz: float, piece: StringName, layer: int = 0, east_west: bool = true) -> void:
	var y: float = 2.59 * float(layer)
	var half_len: float = 3.05
	if east_west:
		zb.place_at(piece, Vector3(cx - half_len, y, cz), 0.0)
		zb.place_at(piece, Vector3(cx + half_len, y, cz), 180.0)
	else:
		zb.place_at(piece, Vector3(cx, y, cz - half_len), 90.0)
		zb.place_at(piece, Vector3(cx, y, cz + half_len), -90.0)


## 화물차(박스카) 14 m (남북, 철길 위). 몸통 3.0 x 2.9 x 13.6 충돌은 옛과 같다.
static func boxcar(zb: ZoneBuilder, cx: float, cz: float, panel: StringName) -> void:
	var kb: KitBuild = zb.custom("props_boxcar")
	var f: StringName = KitMaterials.FLAT_METAL
	# 차대 + 지붕 + 몸통 (아래 굽 단색, 옆판 골함석 패널은 칸 사이마다)
	kb.box(f, Transform3D(Basis.IDENTITY, Vector3(cx, 0.75, cz)), Vector3(2.8, 0.4, 14.0), 0.0, false)
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, Transform3D(Basis.IDENTITY, Vector3(cx, 2.4, cz)), Vector3(2.96, 2.9, 13.56), 0.0, false)
	kb.collide_box(Transform3D(Basis.IDENTITY, Vector3(cx, 2.4, cz)), Vector3(3.0, 2.9, 13.6))
	kb.box(KitMaterials.FLAT_ROOF, Transform3D(Basis.IDENTITY, Vector3(cx, 3.95, cz)), Vector3(3.2, 0.2, 14.0), 0.03, false)
	# 옆판: 골함석 패널 세 칸 (문 둘레를 비운다)
	for side: float in [-1.0, 1.0]:
		var x: float = cx + side * 1.5
		for pz: float in [-4.9, 0.0, 4.9]:
			var len: float = 3.6 if pz == 0.0 else 4.2
			kb.box(panel, Transform3D(Basis.IDENTITY, Vector3(x, 2.4, cz + pz)), Vector3(0.08, 2.7, len), 0.0, false)
		# 미닫이 문 틀 + 문짝 (가운데)
		kb.box(f, Transform3D(Basis.IDENTITY, Vector3(x + side * 0.06, 2.3, cz)), Vector3(0.1, 2.3, 3.4), 0.0, false)
		kb.box(KitMaterials.DOOR_STEEL, Transform3D(Basis.IDENTITY, Vector3(x + side * 0.13, 2.3, cz + 0.55)), Vector3(0.05, 2.1, 1.6), 0.0, false)
		# 아래 굽 띠
		kb.box(KitMaterials.CONCRETE_WALL, Transform3D(Basis.IDENTITY, Vector3(x, 1.0, cz)), Vector3(0.1, 0.4, 13.6), 0.0, false, KitLayout.SILL)
	# 바퀴 (대차 둘, 레일 쪽)
	for dz: float in [-4.6, 4.6]:
		for dx: float in [-0.9, 0.9]:
			kb.cylinder(KitMaterials.FLAT_RUBBER, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(cx + dx, 0.5, cz + dz)), 0.5, 0.2, 12,
					0.03, false, false)


## 선반 한 열 (옛 IndustrialProps.shelf와 같은 칸 수·상자 배치, 같은 충돌): 동서(east_west) 또는 남북, 깊이 1 m, 높이 3 m, 칸마다 짐.
static func shelf(zb: ZoneBuilder, center: Vector3, length: float, east_west: bool, seed_value: int = 0) -> void:
	var kb: KitBuild = zb.custom("props_shelves")
	var basis: Basis = basis_of(0.0 if east_west else 90.0)
	var bays: int = maxi(1, int(length / 3.0))
	var bay_len: float = length / float(bays)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_value
	var crate_mats: Array[StringName] = [KitMaterials.FLAT_WOOD, KitMaterials.METAL_CORRUGATED_RED, KitMaterials.FLAT_WOOD,
			KitMaterials.METAL_CORRUGATED_TEAL, KitMaterials.FLAT_WOOD, KitMaterials.METAL_CHIPPED]
	for i: int in range(bays + 1):
		var offset: float = -length * 0.5 + bay_len * float(i)
		for side: float in [-0.45, 0.45]:
			kb.box(KitMaterials.BEAM_TEAL, _at(basis, center, Vector3(offset, 1.5, side)), Vector3(0.1, 3.0, 0.1), 0.0, false)
	for level: int in range(3):
		var y: float = 0.5 + 1.0 * float(level)
		for side: float in [-0.45, 0.45]:
			kb.box(KitMaterials.BEAM_YELLOW, _at(basis, center, Vector3(0.0, y, side)), Vector3(length, 0.08, 0.08), 0.0, false)
		kb.box(KitMaterials.FLAT_WOOD, _at(basis, center, Vector3(0.0, y + 0.02, 0.0)), Vector3(length, 0.04, 0.9), 0.0, false)
		for i: int in range(bays):
			if rng.randf() < 0.75:
				var mat: StringName = crate_mats[rng.randi() % crate_mats.size()]
				var w: float = rng.randf_range(0.9, bay_len - 0.5)
				var h: float = rng.randf_range(0.4, 0.8)
				var cx: float = -length * 0.5 + bay_len * (float(i) + 0.5) + rng.randf_range(-0.2, 0.2)
				kb.box(mat, _at(basis, center, Vector3(cx, y + 0.04 + h * 0.5, 0.0)), Vector3(w, h, 0.7), 0.01, false)
	var size := Vector3(length, 3.0, 1.0) if east_west else Vector3(1.0, 3.0, length)
	kb.collide_box(Transform3D(Basis.IDENTITY, center + Vector3(0.0, 1.5, 0.0)), size)


static func _at(basis: Basis, center: Vector3, p: Vector3) -> Transform3D:
	return Transform3D(basis, center + basis * p)
