class_name ZoneWarehouses
extends RefCounted
## 창고 구역 (동쪽 2동). 빛 정체성 (ART.md 11.6): 어둠, 청록 비상등, 손전등이 필요한 곳 -> 비상등 몇 개 + 나트륨 램프 하나만.
## 위치·문·충돌은 옛 IndustrialWarehouses와 같다: 골함석 벽 0.5 m, 높이 8.5 m, 서쪽(야적장 쪽) 문 둘 6 x 4.6, 남북 문 하나 7 x 4.6.
## 엄폐·루팅은 맵 코드가 그대로 둔다 (선반·팔레트·지게차·드럼통은 충돌 포함해서 여기서 같은 자리에 둔다).

const WALL_T: float = 0.5
const HEIGHT: float = 8.5
const DOOR_H: float = 4.6


static func build(zb: ZoneBuilder) -> void:
	zb.cell_m = 32.0
	_warehouse(zb, 40.0, 68.0, -34.0, -12.0, 0)
	_warehouse(zb, 40.0, 68.0, 6.0, 28.0, 1)


static func _warehouse(zb: ZoneBuilder, x0: float, x1: float, z0: float, z1: float, index: int) -> void:
	var cx: float = (x0 + x1) * 0.5
	var mid_z: float = (z0 + z1) * 0.5
	var panel: StringName = KitMaterials.METAL_CORRUGATED_TEAL if index == 0 else KitMaterials.METAL_CORRUGATED_RED
	var kb: KitBuild = zb.custom("warehouse_%d" % index)
	# 벽: 서쪽 문 둘, 동쪽 막힘, 남북 문 하나씩
	var west_doors: Array[Vector2] = [Vector2(z0 + 6.0, 6.0), Vector2(z1 - 6.0, 6.0)]
	var none: Array[Vector2] = []
	ZoneParts.panel_wall(kb, false, x0, z0, z1, HEIGHT, WALL_T, panel, west_doors, DOOR_H)
	ZoneParts.panel_wall(kb, false, x1, z0, z1, HEIGHT, WALL_T, panel, none, DOOR_H)
	ZoneParts.panel_wall(kb, true, z0, x0, x1, HEIGHT, WALL_T, panel, [Vector2(cx, 7.0)] as Array[Vector2], DOOR_H)
	ZoneParts.panel_wall(kb, true, z1, x0, x1, HEIGHT, WALL_T, panel, [Vector2(cx, 7.0)] as Array[Vector2], DOOR_H)
	# 모서리 기둥 (장식)
	for c: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		kb.block(KitMaterials.CONCRETE_WALL, Vector3(c.x, 0.0, c.y), Vector3(0.8, 1.0, 0.8), 0.0, false, KitLayout.SILL)
		kb.block(KitMaterials.BEAM_YELLOW, Vector3(c.x, 1.0, c.y), Vector3(0.45, HEIGHT - 1.0, 0.45), 0.0, false)
	# 지붕 (옛 충돌판과 같은 크기, 위에 가운데 능선 띠) + 안쪽 트러스
	kb.box(KitMaterials.FLAT_ROOF, KitParts.at(Vector3(cx, HEIGHT + 0.175, mid_z)), Vector3(x1 - x0 + 1.0, 0.35, z1 - z0 + 1.0), 0.0, true)
	kb.box(KitMaterials.FLAT_CONCRETE_DARK, KitParts.at(Vector3(cx, HEIGHT + 0.525, mid_z)), Vector3(x1 - x0 + 0.6, 0.35, 6.0), 0.0, false)
	for tz: float in [z0 + 5.5, mid_z, z1 - 5.5]:
		for tx: float in [x0 + 4.0, x0 + 12.0, x0 + 20.0]:
			zb.place_at(&"roof_truss_8m", Vector3(tx, HEIGHT - 1.25, tz))
		zb.place_at(&"roof_truss_8m", Vector3(x1 - 2.0, HEIGHT - 1.25, tz))
	# 높은 창 띠 (남북 긴 변 바깥쪽): 유리 + 틀, 아래에 턱
	for z: float in [z0, z1]:
		var out: float = -1.0 if z == z0 else 1.0
		var yaw: float = 180.0 if z == z0 else 0.0
		for i: int in range(6):
			ZoneParts.window(kb, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(x0 + 3.5 + 4.6 * float(i), 6.9, z + out * WALL_T * 0.5)), 3.0, 1.2)
	# 바닥 (실내 콘크리트 + 서쪽 앞마당)
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(x0, z0, x1 - x0, z1 - z0))
	zb.ground(KitMaterials.GROUND_CONCRETE, Rect2(x0 - 6.0, z0, 6.0, z1 - z0))
	# 문 옆 표지판
	for dz: float in [z0 + 6.0, z1 - 6.0]:
		kb.box(KitMaterials.SIGN, KitParts.at(Vector3(x0 - WALL_T * 0.5 - 0.05, 2.2, dz + 3.7)), Vector3(0.04, 0.7, 0.7), 0.0, false)
	# 빛: 비상등 (문 위·안쪽 모서리), 나트륨 램프 하나
	zb.place_at(&"lamp_emergency", Vector3(x0 + 0.3, 3.4, z0 + 3.0), 90.0)
	zb.place_at(&"lamp_emergency", Vector3(x0 + 0.3, 3.4, z1 - 3.0), 90.0)
	zb.place_at(&"lamp_emergency", Vector3(x1 - 0.3, 3.4, mid_z), -90.0)
	zb.place_at(&"lamp_emergency", Vector3(cx, 3.4, z0 + 0.3), 0.0)
	zb.place_at(&"lamp_sodium", Vector3(cx + 4.0, HEIGHT - 0.2, mid_z - 3.0))
	_props(zb, x0, x1, z0, z1, index)


static func _props(zb: ZoneBuilder, x0: float, x1: float, z0: float, z1: float, index: int) -> void:
	var cx: float = (x0 + x1) * 0.5
	var mid_z: float = (z0 + z1) * 0.5
	# 선반 열: 동서 방향 두 줄 (가운데 통로 남김)
	var lane_a: float = z0 + 5.0 if index == 0 else z0 + 4.5
	var lane_b: float = z1 - 5.0 if index == 0 else z1 - 4.5
	ZoneProps.shelf(zb, Vector3(x0 + 10.0, 0, lane_a + 1.0), 12.0, true, index * 10 + 1)
	ZoneProps.shelf(zb, Vector3(x0 + 10.0, 0, lane_b - 1.0), 12.0, true, index * 10 + 2)
	ZoneProps.shelf(zb, Vector3(x1 - 9.0, 0, lane_a + 1.0), 10.0, true, index * 10 + 3)
	ZoneProps.shelf(zb, Vector3(x1 - 9.0, 0, lane_b - 1.0), 10.0, true, index * 10 + 4)
	# 바닥 소품
	ZoneProps.pallet_stack(zb, Vector3(cx - 2.0, 0, mid_z), 0.0, 2)
	ZoneProps.pallet_stack(zb, Vector3(cx + 1.0, 0, mid_z + 1.0), 90.0, 3, KitMaterials.METAL_CORRUGATED_TEAL)
	ZoneProps.pallet(zb, Vector3(cx + 8.0, 0, mid_z - 2.0), 15.0)
	ZoneProps.forklift(zb, Vector3(x1 - 4.0, 0, mid_z + 1.0), 200.0 if index == 0 else 160.0)
	ZoneProps.barrels(zb, Vector3(x0 + 2.0, 0, mid_z + (3.0 if index == 0 else -3.0)), 3)
	# 바깥 문 앞 팔레트 더미
	ZoneProps.pallet_stack(zb, Vector3(x0 - 3.0, 0, mid_z + 7.0), 90.0, 2)
	zb.place_at(&"puddle_2m", Vector3(x0 - 3.5, 0.015, mid_z - 4.0), 20.0)
