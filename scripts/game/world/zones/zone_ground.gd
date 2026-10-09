class_name ZoneGround
extends RefCounted
## 지면 구역 (맵 전체 바닥). 옛 IndustrialInfra.build_ground와 같은 도로·판 배치를 kit_ground 재질로 깐다.
##   - 자갈(흙 약간) = 포장 안 된 마당·가장자리, 콘크리트 = 마당·앞마당 판, 아스팔트 = 도로·주차장 (살짝 젖음 = 정점 색).
##   - 높이 겹침: 자갈 0.0 < 콘크리트 0.015 < 아스팔트 0.03 < 표시 선 / 웅덩이. 발 밑 충돌은 맵 코드가 높이 0 판으로 그대로 둔다.
##   - 구역 칸을 88 m로(맵 4등분) 키워 넓은 바닥이 칸 수만큼 그리기 호출을 늘리지 않게 한다.

const HALF: float = IndustrialMap.HALF
const Y_GRAVEL: float = 0.0
const Y_CONCRETE: float = 0.015
const Y_ASPHALT: float = 0.03
## kit_ground 정점 색: (1 - 젖음, 1 - 흙, 1 - 이끼).
const TINT_GRAVEL: Color = Color(1.0, 0.72, 1.0)
const TINT_ASPHALT: Color = Color(0.78, 1.0, 1.0)

## 도로 (x0, x1, z0, z1): IndustrialInfra.build_ground와 같다.
const ROADS: Array[Rect2] = [
	Rect2(-78.0, -46.0, 156.0, 8.0),
	Rect2(-78.0, 64.0, 156.0, 8.0),
	Rect2(-78.0, -46.0, 8.0, 118.0),
	Rect2(70.0, -46.0, 8.0, 118.0),
	Rect2(-4.0, -38.0, 8.0, 102.0),
	Rect2(-5.0, 72.0, 10.0, HALF - 1.0 - 72.0),
	Rect2(-66.0, 30.0, 44.0, 32.0),
	Rect2(36.0, -12.0, 34.0, 18.0),
]
## 콘크리트 판 (야적장·공장 앞마당·승강장).
const PADS: Array[Rect2] = [
	Rect2(6.0, -27.0, 32.0, 60.0),
	Rect2(-46.0, -48.0, 58.0, 11.0),
	Rect2(-70.0, 5.0, 18.0, 19.0),
]


static func build(zb: ZoneBuilder) -> void:
	zb.cell_m = 88.0
	zb.cast_shadows = false
	zb.ground(KitMaterials.GROUND_GRAVEL, Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0), Y_GRAVEL, TINT_GRAVEL)
	for r: Rect2 in PADS:
		zb.ground(KitMaterials.GROUND_CONCRETE, r, Y_CONCRETE)
	for r: Rect2 in ROADS:
		zb.ground(KitMaterials.GROUND_ASPHALT, r, Y_ASPHALT, TINT_ASPHALT)
	_markings(zb)
	_puddles(zb)


## 도로 중앙 점선 + 주차선 (얇은 흰 띠 상자, 충돌 없음).
static func _markings(zb: ZoneBuilder) -> void:
	var kb: KitBuild = zb.custom("ground_markings")
	var y: float = Y_ASPHALT + 0.012
	var z: float = -34.0
	while z < 60.0:
		kb.box(KitMaterials.BAND_WHITE, KitParts.at(Vector3(0.0, y, z + 0.9)), Vector3(0.16, 0.024, 1.8), 0.0, false)
		z += 4.0
	for row: Vector2 in [Vector2(31.0, 37.0), Vector2(53.0, 59.0)]:
		for i: int in range(13):
			var x: float = -64.0 + 3.2 * float(i)
			kb.box(KitMaterials.BAND_WHITE, KitParts.at(Vector3(x, y, (row.x + row.y) * 0.5)), Vector3(0.1, 0.024, row.y - row.x), 0.0, false)
		for zz: float in [row.x, row.y]:
			kb.box(KitMaterials.BAND_WHITE, KitParts.at(Vector3(-43.25, y, zz)), Vector3(41.5, 0.024, 0.1), 0.0, false)


## 웅덩이: 도로·마당 위 (옛 시드 424와 같은 영역·개수, 납작한 타원). 정점 색 웅덩이는 puddle_2m 부품.
static func _puddles(zb: ZoneBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424
	var areas: Array[Rect2] = [Rect2(-76, -45, 150, 6), Rect2(-76, 65, 150, 6), Rect2(-77, -40, 6, 100),
			Rect2(71, -40, 6, 100), Rect2(-3, -36, 6, 98), Rect2(-4, 74, 8, 12), Rect2(-64, 31, 40, 30),
			Rect2(38, -11, 30, 16), Rect2(7, -26, 30, 56), Rect2(-44, -47, 50, 8)]
	var counts: Array[int] = [4, 4, 3, 3, 4, 2, 3, 2, 5, 2]
	for i: int in range(areas.size()):
		var r: Rect2 = areas[i]
		for k: int in range(counts[i]):
			var x: float = rng.randf_range(r.position.x, r.end.x)
			var z: float = rng.randf_range(r.position.y, r.end.y)
			var rx: float = rng.randf_range(0.8, 3.2) / 1.6
			var rz: float = rng.randf_range(0.6, 2.2) / 1.1
			var yaw: float = rng.randf_range(0.0, PI)
			var basis: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(rx, 1.0, rz))
			zb.place(&"puddle_2m", Transform3D(basis, Vector3(x, Y_ASPHALT, z)))
