class_name IndustrialProps
extends RefCounted
## 산업단지 소품 (박스·원통 조합): 팔레트·드럼통·지게차·트럭·승용차·선반·컨테이너·화물차.
## 모두 IndustrialMap의 건설 도우미로 만든다 (재질별 메시에 합쳐진다). 방향(yaw)은 도 단위, 로컬 앞쪽은 -z.

const STEEL: StringName = IndustrialMaterials.STEEL
const WOOD: StringName = IndustrialMaterials.WOOD
const RUST: StringName = IndustrialMaterials.RUST
const GLASS_DARK: StringName = IndustrialMaterials.GLASS_DARK
const CONCRETE: StringName = IndustrialMaterials.CONCRETE

const CRATE_MATS: Array[StringName] = [
	IndustrialMaterials.WOOD, IndustrialMaterials.CONT_RUST, IndustrialMaterials.WOOD, IndustrialMaterials.CONT_TEAL,
	IndustrialMaterials.WOOD, IndustrialMaterials.CONT_OCHRE,
]


static func _basis(yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg))


## 로컬 좌표(앞 = -z)를 월드로.
static func _at(pos: Vector3, yaw_deg: float, local: Vector3) -> Vector3:
	return pos + _basis(yaw_deg) * local


## 부품 상자 하나 (로컬 중심·크기). 충돌은 따로 상자 하나로 둔다.
static func _part(m: IndustrialMap, pos: Vector3, yaw_deg: float, local: Vector3, size: Vector3, mat: StringName) -> void:
	m.box(_at(pos, yaw_deg, local), size, mat, _basis(yaw_deg), false)


static func _wheel(m: IndustrialMap, pos: Vector3, yaw_deg: float, local: Vector3, radius: float, width: float) -> void:
	# 바퀴 축 = 로컬 x → y축 원통을 z축 둘레로 90도 돌린다
	var orientation: Basis = _basis(yaw_deg) * Basis(Vector3.BACK, PI * 0.5)
	m.cylinder(_at(pos, yaw_deg, local), radius, radius, width, STEEL, 8, orientation, Vector3.ZERO, true, true)


## 팔레트 한 장 (엄폐 아님, 장식).
static func pallet(m: IndustrialMap, pos: Vector3, yaw_deg: float) -> void:
	m.box(pos + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 0.8), WOOD, _basis(yaw_deg), false)


## 팔레트 위에 상자를 쌓은 더미 (엄폐). layers 1~3.
static func pallet_stack(m: IndustrialMap, pos: Vector3, yaw_deg: float, layers: int = 2, mat: StringName = WOOD,
		markers: bool = true) -> void:
	pallet(m, pos, yaw_deg)
	var h: float = 0.55 * float(layers)
	var size := Vector3(1.1, h, 0.7)
	m.box(pos + Vector3(0, 0.14 + h * 0.5, 0), size, mat, _basis(yaw_deg))
	if markers:
		var yaw_i: int = int(round(yaw_deg)) % 180
		var half := Vector2(0.55, 0.35) if yaw_i == 0 else Vector2(0.35, 0.55)
		m.cover_markers(pos.x, pos.z, half.x, half.y, pos.y, 0.9)


## 드럼통 (녹슨 철, 충돌 있음).
static func barrel(m: IndustrialMap, pos: Vector3, mat: StringName = RUST) -> void:
	m.cylinder(pos + Vector3(0, 0.45, 0), 0.3, 0.3, 0.9, mat, 8, Basis.IDENTITY, Vector3(0.6, 0.9, 0.6))


## 드럼통 무리.
static func barrels(m: IndustrialMap, pos: Vector3, count: int = 3) -> void:
	var mats: Array[StringName] = [RUST, IndustrialMaterials.CONT_RED, IndustrialMaterials.CONT_BLUE]
	var offsets: Array[Vector2] = [Vector2(0, 0), Vector2(0.75, 0.1), Vector2(0.3, 0.7), Vector2(-0.5, 0.6)]
	for i: int in range(mini(count, offsets.size())):
		barrel(m, pos + Vector3(offsets[i].x, 0, offsets[i].y), mats[i % mats.size()])
	m.cover_markers(pos.x + 0.2, pos.z + 0.3, 0.9, 0.7, pos.y, 0.8)


## 콘크리트 차단벽 (3 x 1 x 0.7). east_west가 false면 남북 방향.
static func barrier(m: IndustrialMap, pos: Vector3, east_west: bool = true) -> void:
	var size := Vector3(3.0, 1.0, 0.7) if east_west else Vector3(0.7, 1.0, 3.0)
	m.cover_box(Vector3(pos.x, pos.y + 0.5, pos.z), size, CONCRETE)


## 지게차 (노란 차체, 앞 = -z).
static func forklift(m: IndustrialMap, pos: Vector3, yaw_deg: float) -> void:
	var body: StringName = IndustrialMaterials.CONT_OCHRE
	_part(m, pos, yaw_deg, Vector3(0, 0.7, 0.3), Vector3(1.1, 0.8, 1.7), body)
	_part(m, pos, yaw_deg, Vector3(0, 0.45, 1.05), Vector3(1.1, 0.8, 0.5), STEEL)   # 카운터웨이트
	for x: float in [-0.5, 0.5]:
		_part(m, pos, yaw_deg, Vector3(x, 1.6, 0.0), Vector3(0.06, 1.0, 0.06), STEEL)   # 운전석 기둥
		_part(m, pos, yaw_deg, Vector3(x * 0.6, 1.1, -0.95), Vector3(0.1, 2.3, 0.1), STEEL)   # 마스트
		_part(m, pos, yaw_deg, Vector3(x * 0.55, 0.05, -1.5), Vector3(0.12, 0.06, 1.2), STEEL)   # 포크
	_part(m, pos, yaw_deg, Vector3(0, 2.15, 0.0), Vector3(1.2, 0.06, 1.2), STEEL)   # 지붕
	_part(m, pos, yaw_deg, Vector3(0, 0.95, -0.95), Vector3(0.9, 0.08, 0.1), STEEL)
	for corner: Vector2 in [Vector2(-0.55, -0.35), Vector2(0.55, -0.35), Vector2(-0.55, 0.6), Vector2(0.55, 0.6)]:
		_wheel(m, pos, yaw_deg, Vector3(corner.x, 0.3, corner.y), 0.3, 0.2)
	m.collider(_at(pos, yaw_deg, Vector3(0, 0.9, 0.0)), Vector3(1.3, 1.8, 2.6), true, _basis(yaw_deg))
	m.cover_markers(pos.x, pos.z, 0.7, 1.4, pos.y, 0.9)


## 버려진 트럭: 운전석 + 화물칸 + 차대 + 바퀴 6개. 앞 = -z.
static func truck(m: IndustrialMap, pos: Vector3, yaw_deg: float, cab_mat: StringName, cargo_mat: StringName) -> void:
	_part(m, pos, yaw_deg, Vector3(0, 0.75, 0), Vector3(2.2, 0.3, 8.0), STEEL)   # 차대
	_part(m, pos, yaw_deg, Vector3(0, 1.65, -3.0), Vector3(2.3, 1.7, 1.9), cab_mat)   # 운전석
	_part(m, pos, yaw_deg, Vector3(0, 2.1, -3.95), Vector3(2.0, 0.7, 0.06), GLASS_DARK)   # 앞유리
	_part(m, pos, yaw_deg, Vector3(0, 2.35, 0.9), Vector3(2.5, 2.7, 5.6), cargo_mat)   # 화물칸
	for z: float in [-3.0, 1.2, 3.0]:
		for x: float in [-1.1, 1.1]:
			_wheel(m, pos, yaw_deg, Vector3(x, 0.55, z), 0.55, 0.35)
	m.collider(_at(pos, yaw_deg, Vector3(0, 2.0, 0.9)), Vector3(2.5, 3.4, 5.6), true, _basis(yaw_deg))
	m.collider(_at(pos, yaw_deg, Vector3(0, 1.3, -3.0)), Vector3(2.3, 2.1, 1.9), true, _basis(yaw_deg))
	m.cover_markers(pos.x, pos.z, 1.3, 3.8, pos.y, 1.0)


## 버려진 승용차. 앞 = -z.
static func car(m: IndustrialMap, pos: Vector3, yaw_deg: float, mat: StringName) -> void:
	_part(m, pos, yaw_deg, Vector3(0, 0.6, 0), Vector3(1.8, 0.6, 4.2), mat)
	_part(m, pos, yaw_deg, Vector3(0, 1.05, 0.2), Vector3(1.6, 0.5, 2.2), GLASS_DARK)
	_part(m, pos, yaw_deg, Vector3(0, 1.32, 0.2), Vector3(1.55, 0.06, 2.0), mat)
	for z: float in [-1.35, 1.35]:
		for x: float in [-0.9, 0.9]:
			_wheel(m, pos, yaw_deg, Vector3(x, 0.32, z), 0.32, 0.22)
	m.collider(_at(pos, yaw_deg, Vector3(0, 0.75, 0)), Vector3(1.9, 1.3, 4.2), true, _basis(yaw_deg))


## 선반 한 열: 동서(east_west) 또는 남북 방향, 길이 length, 위에서 보아 깊이 1 m. 칸마다 상자.
static func shelf(m: IndustrialMap, center: Vector3, length: float, east_west: bool, seed_value: int = 0) -> void:
	var yaw: float = 0.0 if east_west else 90.0
	var bays: int = maxi(1, int(length / 3.0))
	var bay_len: float = length / float(bays)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_value
	for i: int in range(bays + 1):
		var offset: float = -length * 0.5 + bay_len * float(i)
		for side: float in [-0.45, 0.45]:
			_part(m, center, yaw, Vector3(offset, 1.5, side), Vector3(0.1, 3.0, 0.1), STEEL)
	for level: int in range(3):
		var y: float = 0.5 + 1.0 * float(level)
		_part(m, center, yaw, Vector3(0, y, -0.45), Vector3(length, 0.08, 0.08), RUST)
		_part(m, center, yaw, Vector3(0, y, 0.45), Vector3(length, 0.08, 0.08), RUST)
		_part(m, center, yaw, Vector3(0, y + 0.02, 0), Vector3(length, 0.04, 0.9), WOOD)
		for i: int in range(bays):
			if rng.randf() < 0.75:
				var mat: StringName = CRATE_MATS[rng.randi() % CRATE_MATS.size()]
				var w: float = rng.randf_range(0.9, bay_len - 0.5)
				var h: float = rng.randf_range(0.4, 0.8)
				var cx: float = -length * 0.5 + bay_len * (float(i) + 0.5) + rng.randf_range(-0.2, 0.2)
				_part(m, center, yaw, Vector3(cx, y + 0.04 + h * 0.5, 0), Vector3(w, h, 0.7), mat)
	var size := Vector3(length, 3.0, 1.0) if east_west else Vector3(1.0, 3.0, length)
	m.collider(center + Vector3(0, 1.5, 0), size)
	m.cover_markers(center.x, center.z, size.x * 0.5, size.z * 0.5, center.y, 0.9)


## 12 x 2.5 x 2.4 선적 컨테이너. layer 1이면 한 칸 위. east_west=false면 남북 방향.
static func container(m: IndustrialMap, cx: float, cz: float, mat: StringName, layer: int = 0, east_west: bool = true,
		markers: bool = true) -> void:
	var size := Vector3(12.0, 2.5, 2.4) if east_west else Vector3(2.4, 2.5, 12.0)
	var center := Vector3(cx, 1.25 + 2.5 * float(layer), cz)
	m.box(center, size, mat)
	# 문 쪽 마구리 틀 (짙은 강철 세로 막대 2개)
	var end_dir: Vector3 = Vector3.RIGHT if east_west else Vector3.BACK
	var half: float = 6.0
	var bar := Vector3(0.12, 2.5, 0.1) if east_west else Vector3(0.1, 2.5, 0.12)
	for side: float in [-0.5, 0.5]:
		var lateral: Vector3 = Vector3.BACK if east_west else Vector3.RIGHT
		m.box(center + end_dir * (half + 0.02) + lateral * side, bar, STEEL, Basis.IDENTITY, false)
	if layer == 0 and markers:
		if east_west:
			m.cover_markers(cx, cz, 6.0, 1.2, 0.0, 0.9)
		else:
			m.cover_markers(cx, cz, 1.2, 6.0, 0.0, 0.9)


## 화물차(박스카): 철길 위, 길이 14 (남북).
static func boxcar(m: IndustrialMap, cx: float, cz: float, mat: StringName) -> void:
	m.box(Vector3(cx, 0.75, cz), Vector3(2.8, 0.4, 14.0), STEEL, Basis.IDENTITY, false)
	m.box(Vector3(cx, 2.4, cz), Vector3(3.0, 2.9, 13.6), mat)
	m.box(Vector3(cx, 3.95, cz), Vector3(3.2, 0.2, 14.0), STEEL, Basis.IDENTITY, false)
	# 미닫이 문 틀
	for side: float in [-1.52, 1.52]:
		m.box(Vector3(cx + side, 2.3, cz), Vector3(0.1, 2.3, 3.4), STEEL, Basis.IDENTITY, false)
	for dz: float in [-4.6, 4.6]:
		for dx: float in [-0.9, 0.9]:
			var orientation := Basis(Vector3.BACK, PI * 0.5)
			m.cylinder(Vector3(cx + dx, 0.5, cz + dz), 0.5, 0.5, 0.2, STEEL, 8, orientation, Vector3.ZERO, true, true)
	m.cover_markers(cx, cz, 1.5, 6.8, 0.0, 1.0)
