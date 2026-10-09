class_name IndustrialWarehouses
extends RefCounted
## 창고 구역 (동쪽): 큰 문이 뚫린 골판 창고 2동. 안에 선반 열·팔레트·지게차, 높은 창문 띠와 빛줄기, 매달린 램프.

const CORRUGATED: StringName = IndustrialMaterials.CORRUGATED
const STEEL: StringName = IndustrialMaterials.STEEL
const CONCRETE_DARK: StringName = IndustrialMaterials.CONCRETE_DARK
const WALL_T: float = 0.5
const HEIGHT: float = 8.5
const DOOR_H: float = 4.6


static func build(m: IndustrialMap) -> void:
	if m.add_zone(&"warehouses"):
		_gameplay(m, 40.0, 68.0, -34.0, -12.0, 0)
		_gameplay(m, 40.0, 68.0, 6.0, 28.0, 1)
		_fx(m, 40.0, 68.0, -34.0)
		_fx(m, 40.0, 68.0, 6.0)
		return
	_warehouse(m, 40.0, 68.0, -34.0, -12.0, 0)
	_warehouse(m, 40.0, 68.0, 6.0, 28.0, 1)


## 구역 씬(ZoneWarehouses)을 쓸 때: 지오메트리·충돌은 구역 씬이 맡고, 여기서는 엄폐 지점과 루팅만 둔다 (옛 _warehouse와 같은 자리).
static func _gameplay(m: IndustrialMap, x0: float, x1: float, z0: float, z1: float, index: int) -> void:
	var cx: float = (x0 + x1) * 0.5
	var mid_z: float = (z0 + z1) * 0.5
	var lane_a: float = z0 + 5.0 if index == 0 else z0 + 4.5
	var lane_b: float = z1 - 5.0 if index == 0 else z1 - 4.5
	IndustrialProps.cover_shelf(m, Vector3(x0 + 10.0, 0, lane_a + 1.0), 12.0, true)
	IndustrialProps.cover_shelf(m, Vector3(x0 + 10.0, 0, lane_b - 1.0), 12.0, true)
	IndustrialProps.cover_shelf(m, Vector3(x1 - 9.0, 0, lane_a + 1.0), 10.0, true)
	IndustrialProps.cover_shelf(m, Vector3(x1 - 9.0, 0, lane_b - 1.0), 10.0, true)
	IndustrialProps.cover_pallet_stack(m, Vector3(cx - 2.0, 0, mid_z), 0.0)
	IndustrialProps.cover_pallet_stack(m, Vector3(cx + 1.0, 0, mid_z + 1.0), 90.0)
	IndustrialProps.cover_forklift(m, Vector3(x1 - 4.0, 0, mid_z + 1.0))
	IndustrialProps.cover_barrels(m, Vector3(x0 + 2.0, 0, mid_z + (3.0 if index == 0 else -3.0)))
	if index == 0:
		m.loot(LootContainer.Kind.WEAPON_BOX, Vector3(x0 + 2.2, 0.0, z0 + 1.2), 0.0)
		m.loot(LootContainer.Kind.CRATE, Vector3(x1 - 2.0, 0.0, z0 + 1.2), 0.0)
	else:
		m.loot(LootContainer.Kind.DRAWER, Vector3(x1 - 1.0, 0.0, mid_z - 4.0), 270.0)
		m.loot(LootContainer.Kind.MEDBAG, Vector3(cx + 1.5, 0.0, z0 + 1.0), 0.0)
	IndustrialProps.cover_pallet_stack(m, Vector3(x0 - 3.0, 0, mid_z + 7.0), 90.0)


## 구역 씬을 쓸 때의 효과: 낮은 해가 북쪽 높은 창으로 들어오는 가는 빛줄기 (공장 홀과 같은 해 방향, 어두운 창고라 약하게).
static func _fx(m: IndustrialMap, x0: float, x1: float, z0: float) -> void:
	var dir := Vector3(0.52, 0.0, 0.84)
	var warm := Color(1.0, 0.82, 0.62)
	for i: int in range(4):
		var x: float = x0 + 5.0 + float(i) * 6.5
		m.light_shaft(Vector3(x - 1.4, 0, z0 + 0.3), Vector3(x + 1.4, 0, z0 + 0.3), 7.5, dir, 16.0, 0.05, 0.01, warm)


static func _warehouse(m: IndustrialMap, x0: float, x1: float, z0: float, z1: float, index: int) -> void:
	var cx: float = (x0 + x1) * 0.5
	# 벽: 서쪽(야적장 쪽)에 문 둘, 남·북에 문 하나씩
	var west_doors: Array[Vector2] = [Vector2(z0 + 6.0, 6.0), Vector2(z1 - 6.0, 6.0)]
	m.wall_z(z0, z1, x0, 0.0, HEIGHT, WALL_T, CORRUGATED, west_doors, DOOR_H)
	m.wall_z(z0, z1, x1, 0.0, HEIGHT, WALL_T, CORRUGATED, [], DOOR_H)
	m.wall_x(x0, x1, z0, 0.0, HEIGHT, WALL_T, CORRUGATED, [Vector2(cx, 7.0)], DOOR_H)
	m.wall_x(x0, x1, z1, 0.0, HEIGHT, WALL_T, CORRUGATED, [Vector2(cx, 7.0)], DOOR_H)
	# 지붕 (살짝 튀어나온 판 + 위 골)
	m.span(x0 - 0.5, x1 + 0.5, HEIGHT, HEIGHT + 0.35, z0 - 0.5, z1 + 0.5, STEEL)
	m.span(x0 - 0.3, x1 + 0.3, HEIGHT + 0.35, HEIGHT + 0.7, cx - 3.0, cx + 3.0, CONCRETE_DARK, false)
	# 높은 창문 띠: 긴 변(남·북)의 안쪽(밝음)·바깥쪽(희미)
	var y0: float = 6.1
	var y1: float = 7.7
	m.window_strip(Vector3(x0 + 1.0, 0, z0 + 0.28), Vector3(x1 - 1.0, 0, z0 + 0.28), y0, y1, Vector3(0, 0, 1), true)
	m.window_strip(Vector3(x0 + 1.0, 0, z0 - 0.28), Vector3(x1 - 1.0, 0, z0 - 0.28), y0, y1, Vector3(0, 0, -1), false)
	m.window_strip(Vector3(x0 + 1.0, 0, z1 - 0.28), Vector3(x1 - 1.0, 0, z1 - 0.28), y0, y1, Vector3(0, 0, -1), true)
	m.window_strip(Vector3(x0 + 1.0, 0, z1 + 0.28), Vector3(x1 - 1.0, 0, z1 + 0.28), y0, y1, Vector3(0, 0, 1), false)
	m.window_strip(Vector3(x1 - 0.28, 0, z0 + 1.0), Vector3(x1 - 0.28, 0, z1 - 1.0), y0, y1, Vector3(-1, 0, 0), true)
	# 빛줄기: 북쪽 창에서 안으로
	for i: int in range(5):
		var x: float = x0 + 4.0 + float(i) * 5.5
		m.light_shaft(Vector3(x - 1.3, 0, z0 + 0.4), Vector3(x + 1.3, 0, z0 + 0.4), y1, Vector3(0.25, 0, 1.0), 13.0)
	# 매달린 램프
	for pos: Vector3 in [Vector3(x0 + 6.0, HEIGHT - 0.2, (z0 + z1) * 0.5), Vector3(cx + 4.0, HEIGHT - 0.2, (z0 + z1) * 0.5 - 3.0),
			Vector3(x1 - 6.0, HEIGHT - 0.2, (z0 + z1) * 0.5 + 2.0)]:
		m.hanging_lamp(pos, 2.4)
	# 지붕 보 (장식)
	for x: float in [x0 + 7.0, x0 + 14.0, x0 + 21.0]:
		m.span(x - 0.2, x + 0.2, HEIGHT - 0.8, HEIGHT, z0 + 0.3, z1 - 0.3, STEEL, false, false)
	# 선반 열: 동서 방향 두 줄 (가운데 통로 남김)
	var lane_a: float = z0 + 5.0 if index == 0 else z0 + 4.5
	var lane_b: float = z1 - 5.0 if index == 0 else z1 - 4.5
	IndustrialProps.shelf(m, Vector3(x0 + 10.0, 0, lane_a + 1.0), 12.0, true, index * 10 + 1)
	IndustrialProps.shelf(m, Vector3(x0 + 10.0, 0, lane_b - 1.0), 12.0, true, index * 10 + 2)
	IndustrialProps.shelf(m, Vector3(x1 - 9.0, 0, lane_a + 1.0), 10.0, true, index * 10 + 3)
	IndustrialProps.shelf(m, Vector3(x1 - 9.0, 0, lane_b - 1.0), 10.0, true, index * 10 + 4)
	# 바닥 소품: 팔레트 더미, 지게차, 드럼통
	var mid_z: float = (z0 + z1) * 0.5
	IndustrialProps.pallet_stack(m, Vector3(cx - 2.0, 0, mid_z), 0.0, 2)
	IndustrialProps.pallet_stack(m, Vector3(cx + 1.0, 0, mid_z + 1.0), 90.0, 3, IndustrialMaterials.CONT_TEAL)
	IndustrialProps.pallet(m, Vector3(cx + 8.0, 0, mid_z - 2.0), 15.0)
	IndustrialProps.forklift(m, Vector3(x1 - 4.0, 0, mid_z + 1.0), 200.0 if index == 0 else 160.0)
	IndustrialProps.barrels(m, Vector3(x0 + 2.0, 0, mid_z + (3.0 if index == 0 else -3.0)), 3)
	if index == 0:
		m.loot(LootContainer.Kind.WEAPON_BOX, Vector3(x0 + 2.2, 0.0, z0 + 1.2), 0.0)
		m.loot(LootContainer.Kind.CRATE, Vector3(x1 - 2.0, 0.0, z0 + 1.2), 0.0)
	else:
		m.loot(LootContainer.Kind.DRAWER, Vector3(x1 - 1.0, 0.0, mid_z - 4.0), 270.0)
		m.loot(LootContainer.Kind.MEDBAG, Vector3(cx + 1.5, 0.0, z0 + 1.0), 0.0)
	# 바깥 문 앞 소품
	IndustrialProps.pallet_stack(m, Vector3(x0 - 3.0, 0, mid_z + 7.0), 90.0, 2)
