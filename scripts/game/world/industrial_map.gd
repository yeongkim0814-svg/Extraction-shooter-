class_name IndustrialMap
extends Node3D
## 산업단지 그레이박스 맵 (약 160 x 160 m, 원점 중심). 지오메트리는 전부 코드로 만든다.
## 상자 하나마다 StaticBody3D + BoxShape3D 충돌체를 두고, 눈에 보이는 면은 재질별로 하나의 ArrayMesh에 합쳐
## 메시 인스턴스 수(= 그리기 호출)를 재질 수 정도로 줄인다 (모바일). CSG는 쓰지 않는다.
## 구역: 정문 경비초소(북) · 대형 창고(북서) · 탱크·배관(북동) · 컨테이너 야적장(동) · 2층 사무동(중앙 남서) ·
##       화물 엘리베이터 승강장(서) · 하수구(동쪽 끝) · 플레이어 시작 구역(남).
## 좌표: +x 동쪽, -z 북쪽 (플레이어는 남쪽 가장자리에서 북쪽을 보고 시작한다). 높이 0 = 지면.

const HALF: float = 80.0
const WALL_H: float = 4.0
const DOOR_H: float = 2.6
const STOREY: float = 3.4   # 사무동 2층 바닥 높이
const NAV_CELL: float = 0.4
const NAV_CELL_HEIGHT: float = 0.2
const EXTRACT_WAIT: float = 7.0
const POWER_FLAG: StringName = &"power_on"

const COLORS: Dictionary[StringName, Color] = {
	&"concrete": Color(0.56, 0.57, 0.59),
	&"concrete_dark": Color(0.38, 0.39, 0.42),
	&"rust": Color(0.46, 0.27, 0.17),
	&"metal": Color(0.17, 0.19, 0.22),
	&"asphalt": Color(0.17, 0.18, 0.2),
	&"wood": Color(0.5, 0.38, 0.22),
	&"cont_red": Color(0.55, 0.2, 0.16),
	&"cont_blue": Color(0.18, 0.3, 0.5),
	&"cont_green": Color(0.2, 0.4, 0.28),
	&"cont_yellow": Color(0.7, 0.55, 0.15),
}


class BoxRec:
	var xform: Transform3D
	var size: Vector3


## 내비메시 굽기의 기준이 되는 지오메트리 영역 (모든 충돌 상자의 부모).
var region: NavigationRegion3D
var spawn_position: Vector3 = Vector3(0.0, 0.1, 74.0)
var containers: Array[LootContainer] = []
var extraction_zones: Array[ExtractionZone] = []
var lever: PowerLever
## 적 순찰 경로 (구역별 1개). 지점은 지면/바닥 높이의 좌표.
var enemy_routes: Array[PackedVector3Array] = []
var box_count: int = 0
var mesh_instance_count: int = 0
var cover_count: int = 0

var _materials: Dictionary[StringName, StandardMaterial3D] = {}
var _visual: Dictionary[StringName, Array] = {}
var _nav_boxes: Array[BoxRec] = []
var _shapes: Dictionary[Vector3, BoxShape3D] = {}
var _cover_root: Node3D
var _loot_root: Node3D


func _ready() -> void:
	_build()


# --- 전체 구성 ---

func _build() -> void:
	for id: StringName in COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLORS[id]
		mat.roughness = 0.92
		_materials[id] = mat
	region = NavigationRegion3D.new()
	region.name = "Geometry"
	add_child(region)
	_cover_root = Node3D.new()
	_cover_root.name = "CoverPoints"
	add_child(_cover_root)
	_loot_root = Node3D.new()
	_loot_root.name = "Loot"
	add_child(_loot_root)
	_build_ground_and_perimeter()
	_build_gate_and_guard_post()
	_build_warehouse()
	_build_tank_area()
	_build_container_yard()
	_build_office()
	_build_edges()
	_build_open_ground_cover()
	_build_routes()
	_build_extractions()
	_flush_meshes()


func _build_ground_and_perimeter() -> void:
	_box(Vector3(0, -0.2, 0), Vector3(HALF * 2.0, 0.4, HALF * 2.0), &"asphalt")
	var t: float = 1.0
	_span(-HALF - t, HALF + t, 0.0, WALL_H, -HALF - t, -HALF, &"concrete_dark")
	_span(-HALF - t, HALF + t, 0.0, WALL_H, HALF, HALF + t, &"concrete_dark")
	_span(-HALF - t, -HALF, 0.0, WALL_H, -HALF, HALF, &"concrete_dark")
	_span(HALF, HALF + t, 0.0, WALL_H, -HALF, HALF, &"concrete_dark")


func _build_gate_and_guard_post() -> void:
	# 정문: 북쪽 벽 가운데의 닫힌 철문 + 기둥 (탈출 지점은 문 앞)
	_span(-6.0, 6.0, 0.0, 3.6, -HALF + 0.1, -HALF + 0.5, &"metal")
	_span(-7.0, -6.0, 0.0, 5.0, -HALF - 0.1, -HALF + 1.0, &"concrete")
	_span(6.0, 7.0, 0.0, 5.0, -HALF - 0.1, -HALF + 1.0, &"concrete")
	_span(-7.0, 7.0, 4.6, 5.2, -HALF - 0.1, -HALF + 1.0, &"concrete")
	# 경비초소: x -14..-2, z -74..-66, 방 2개
	var wall_t: float = 0.4
	_wall_x(-14.0, -2.0, -66.0, 0.0, 3.2, wall_t, &"concrete", [Vector2(-11.0, 1.6), Vector2(-5.0, 1.6)])
	_wall_x(-14.0, -2.0, -74.0, 0.0, 3.2, wall_t, &"concrete", [])
	_wall_z(-74.0, -66.0, -14.0, 0.0, 3.2, wall_t, &"concrete", [Vector2(-70.0, 1.6)])
	_wall_z(-74.0, -66.0, -8.0, 0.0, 3.2, wall_t, &"concrete", [Vector2(-70.0, 1.4)])
	_wall_z(-74.0, -66.0, -2.0, 0.0, 3.2, wall_t, &"concrete", [])
	_span(-14.2, -1.8, 3.2, 3.6, -74.2, -65.8, &"concrete_dark")
	_cover_box(Vector3(-5.0, 0.4, -69.0), Vector3(2.2, 0.8, 0.9), &"wood", false)   # 책상
	_loot(LootContainer.Kind.WEAPON_BOX, Vector3(-12.2, 0.0, -72.8), 0.0)
	_loot(LootContainer.Kind.DRAWER, Vector3(-4.5, 0.0, -72.8), 0.0)
	# 검문 차단벽
	for x: float in [-9.0, 9.0]:
		_cover_box(Vector3(x, 0.5, -58.0), Vector3(3.0, 1.0, 0.7), &"concrete")
	_cover_box(Vector3(0.0, 0.5, -50.0), Vector3(3.0, 1.0, 0.7), &"concrete")


func _build_warehouse() -> void:
	var x0: float = -72.0
	var x1: float = -32.0
	var z0: float = -52.0
	var z1: float = -22.0
	var t: float = 0.6
	var h: float = 7.0
	_wall_x(x0, x1, z1, 0.0, h, t, &"concrete", [Vector2(-58.0, 5.0), Vector2(-42.0, 5.0)])
	_wall_x(x0, x1, z0, 0.0, h, t, &"concrete", [Vector2(-52.0, 4.0)])
	_wall_z(z0, z1, x0, 0.0, h, t, &"concrete", [])
	_wall_z(z0, z1, x1, 0.0, h, t, &"concrete", [Vector2(-37.0, 4.0)])
	_span(x0 - 0.3, x1 + 0.3, h, h + 0.4, z0 - 0.3, z1 + 0.3, &"concrete_dark")
	# 선반 열: z = -29, -36, -43 (서쪽 구간 + 동쪽 구간, 가운데 x -52..-46은 가로 통로)
	for z: float in [-29.0, -36.0, -43.0]:
		_shelf(-68.0, -52.0, z)
		_shelf(-46.0, -36.0, z)
	# 북쪽 통로의 나무 상자 더미 (엄폐)
	for pos: Vector2 in [Vector2(-60.0, -48.0), Vector2(-44.0, -47.5), Vector2(-66.0, -33.0)]:
		_cover_box(Vector3(pos.x, 0.6, pos.y), Vector3(1.6, 1.2, 1.6), &"wood")
	_loot(LootContainer.Kind.WEAPON_BOX, Vector3(-69.0, 0.0, -48.0), 90.0)
	_loot(LootContainer.Kind.WEAPON_BOX, Vector3(-35.0, 0.0, -49.0), 0.0)
	_loot(LootContainer.Kind.CRATE, Vector3(-60.0, 0.0, -32.5), 0.0)
	_loot(LootContainer.Kind.CRATE, Vector3(-40.0, 0.0, -39.5), 0.0)
	_loot(LootContainer.Kind.TOOLBOX, Vector3(-70.5, 0.0, -26.0), 90.0)


func _shelf(xa: float, xb: float, z: float) -> void:
	_span(xa, xb, 0.0, 3.2, z - 0.5, z + 0.5, &"rust")
	_cover_markers((xa + xb) * 0.5, z, (xb - xa) * 0.5, 0.5, 0.0, 1.4)


func _build_tank_area() -> void:
	var tanks: Array[Vector3] = [Vector3(36, 5, -58), Vector3(52, 5, -58), Vector3(68, 5, -58), Vector3(60, 4, -42)]
	for tank: Vector3 in tanks:
		var mesh := CylinderMesh.new()
		mesh.top_radius = tank.y
		mesh.bottom_radius = tank.y
		mesh.height = 9.0
		mesh.radial_segments = 20
		mesh.rings = 1
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = _materials[&"rust"]
		node.position = Vector3(tank.x, 4.5, tank.z)
		add_child(node)
		mesh_instance_count += 1
		_collider(Vector3(tank.x, 4.5, tank.z), Vector3(tank.y * 2.0, 9.0, tank.y * 2.0))
	# 높이 3.5 m의 배관 (아래로 지나갈 수 있다): 남북 한 줄, 동서 한 줄
	_box(Vector3(44.0, 3.6, -43.0), Vector3(0.6, 0.6, 18.0), &"metal")
	_box(Vector3(51.0, 3.4, -35.0), Vector3(42.0, 0.6, 0.6), &"metal")
	for z: float in [-52.0, -43.0, -34.0]:
		_box(Vector3(44.0, 1.8, z), Vector3(0.4, 3.6, 0.4), &"metal")
	for x: float in [40.0, 50.0, 60.0, 70.0]:
		_box(Vector3(x, 1.7, -35.0), Vector3(0.4, 3.4, 0.4), &"metal")
	# 펌프실: x 30..38, z -42..-36
	_wall_x(30.0, 38.0, -36.0, 0.0, 3.4, 0.4, &"concrete", [Vector2(34.0, 1.8)])
	_wall_x(30.0, 38.0, -42.0, 0.0, 3.4, 0.4, &"concrete", [])
	_wall_z(-42.0, -36.0, 30.0, 0.0, 3.4, 0.4, &"concrete", [])
	_wall_z(-42.0, -36.0, 38.0, 0.0, 3.4, 0.4, &"concrete", [])
	_span(29.8, 38.2, 3.4, 3.8, -42.2, -35.8, &"concrete_dark")
	# 드럼통 (엄폐)
	for pos: Vector2 in [Vector2(49.5, -48.5), Vector2(50.8, -48.5), Vector2(49.5, -47.2), Vector2(42.0, -45.0),
			Vector2(72.0, -38.0)]:
		_cover_box(Vector3(pos.x, 0.6, pos.y), Vector3(0.9, 1.2, 0.9), &"rust")
	_loot(LootContainer.Kind.TOOLBOX, Vector3(33.0, 0.0, -40.5), 0.0)
	_loot(LootContainer.Kind.TOOLBOX, Vector3(62.0, 0.0, -33.0), 0.0)
	_loot(LootContainer.Kind.CRATE, Vector3(44.0, 0.0, -56.0), 0.0)


func _build_container_yard() -> void:
	var mats: Array[StringName] = [&"cont_red", &"cont_blue", &"cont_green", &"cont_yellow"]
	var rows: Array[Dictionary] = [
		{"z": -20.0, "xs": [20.0, 36.0, 52.0, 68.0], "stack": [36.0, 68.0]},
		{"z": -12.0, "xs": [20.0, 36.0, 52.0, 68.0], "stack": [20.0, 52.0]},
		{"z": -2.0, "xs": [28.0, 44.0, 60.0], "stack": [44.0]},
		{"z": 8.0, "xs": [20.0, 36.0, 52.0, 68.0], "stack": [36.0, 68.0]},
		{"z": 16.0, "xs": [44.0, 60.0], "stack": []},
	]
	var n: int = 0
	for row: Dictionary in rows:
		var z: float = row["z"]
		for x: float in (row["xs"] as Array):
			_shipping(x, z, mats[n % mats.size()], 0)
			n += 1
			if (row["stack"] as Array).has(x):
				_shipping(x, z, mats[(n + 1) % mats.size()], 1)
	_loot(LootContainer.Kind.CRATE, Vector3(45.0, 0.0, -14.0), 0.0)
	_loot(LootContainer.Kind.CRATE, Vector3(60.0, 0.0, -18.2), 0.0)
	_loot(LootContainer.Kind.CRATE, Vector3(50.0, 0.0, 5.5), 0.0)


## 12 x 2.4 m 선적 컨테이너 (동서 방향). layer 1이면 한 칸 위에 쌓는다.
func _shipping(cx: float, cz: float, mat: StringName, layer: int) -> void:
	var size := Vector3(12.0, 2.5, 2.4)
	var center := Vector3(cx, 1.25 + 2.5 * layer, cz)
	_box(center, size, mat)
	if layer == 0:
		_cover_markers(cx, cz, 6.0, 1.2, 0.0, 0.9)


func _build_office() -> void:
	var x0: float = -26.0
	var x1: float = -2.0
	var z0: float = 0.0
	var z1: float = 22.0
	var t: float = 0.4
	var h: float = 3.0
	# 1층 외벽 + 칸막이
	_wall_x(x0, x1, z1, 0.0, h, t, &"concrete", [Vector2(-14.0, 2.4)])
	_wall_x(x0, x1, z0, 0.0, h, t, &"concrete", [Vector2(-20.0, 1.8)])
	_wall_z(z0, z1, x0, 0.0, h, t, &"concrete", [])
	_wall_z(z0, z1, x1, 0.0, h, t, &"concrete", [Vector2(2.0, 1.8)])
	_partitions(0.0, h, t)
	# 바닥판(2층 바닥) 과 2층 외벽 + 칸막이
	_span(x0 - 0.2, x1 + 0.2, h, STOREY, z0 - 0.2, z1 + 0.2, &"concrete_dark")
	_wall_x(x0, x1, z1, STOREY, h, t, &"concrete", [])
	_wall_x(x0, x1, z0, STOREY, h, t, &"concrete", [])
	_wall_z(z0, z1, x0, STOREY, h, t, &"concrete", [])
	_wall_z(z0, z1, x1, STOREY, h, t, &"concrete", [Vector2(5.5, 2.0)])
	_partitions(STOREY, h, t)
	_span(x0 - 0.2, x1 + 0.2, STOREY + h, STOREY + h + 0.4, z0 - 0.2, z1 + 0.2, &"concrete_dark")
	# 동쪽 바깥 경사로: 지면(z=19)에서 2층 높이(z=7)까지, 위쪽 승강대에서 2층 동쪽 문으로 이어진다
	var run_len: float = 12.0
	var angle: float = atan2(STOREY, run_len)
	var length: float = sqrt(run_len * run_len + STOREY * STOREY)
	var ramp_t: float = 0.3
	var ramp_center := Vector3(-0.1, STOREY * 0.5 - ramp_t * 0.5 / cos(angle), 13.0)
	_box(ramp_center, Vector3(3.4, ramp_t, length), &"concrete", Basis(Vector3.RIGHT, angle))
	_span(-1.8, 1.6, STOREY - 0.4, STOREY, 4.0, 7.0, &"concrete")
	_span(-1.8, 1.6, 0.0, STOREY - 0.4, 4.0, 7.0, &"concrete_dark")
	_span(-1.8, -1.6, STOREY, STOREY + 1.0, 4.0, 7.0, &"metal")   # 난간 없음 → 안쪽 모서리만 막음
	# 책상·캐비닛 (엄폐)
	for pos: Vector2 in [Vector2(-22.0, 8.0), Vector2(-8.0, 19.0), Vector2(-20.0, 14.0)]:
		_cover_box(Vector3(pos.x, 0.4, pos.y), Vector3(2.0, 0.8, 0.9), &"wood")
		_cover_box(Vector3(pos.x, STOREY + 0.4, pos.y), Vector3(2.0, 0.8, 0.9), &"wood")
	# 루팅: 의료 가방 3, 서랍장 2
	_loot(LootContainer.Kind.MEDBAG, Vector3(-22.0, 0.0, 20.0), 0.0)
	_loot(LootContainer.Kind.MEDBAG, Vector3(-10.0, STOREY, 3.0), 0.0)
	_loot(LootContainer.Kind.MEDBAG, Vector3(-6.0, STOREY, 20.5), 0.0)
	_loot(LootContainer.Kind.DRAWER, Vector3(-25.4, 0.0, 5.0), 90.0)
	_loot(LootContainer.Kind.DRAWER, Vector3(-5.0, 0.0, 21.4), 0.0)
	# 전원 레버 (2층 북서 방)
	lever = PowerLever.new()
	lever.name = "PowerLever"
	lever.position = Vector3(-25.5, STOREY, 3.0)
	lever.rotation.y = PI * 0.5
	_loot_root.add_child(lever)
	_collider(Vector3(-25.5, STOREY + 0.6, 3.0), Vector3(0.25, 1.2, 0.7), false)


## 사무동 칸막이 (층마다 같은 배치): x=-14 세로벽, z=11 가로벽 두 조각.
func _partitions(y0: float, h: float, t: float) -> void:
	_wall_z(0.0, 22.0, -14.0, y0, h, t, &"concrete", [Vector2(6.0, 1.6), Vector2(16.0, 1.6)])
	_wall_x(-26.0, -14.0, 11.0, y0, h, t, &"concrete", [Vector2(-20.0, 1.6)])
	_wall_x(-14.0, -2.0, 11.0, y0, h, t, &"concrete", [Vector2(-8.0, 1.6)])


func _build_edges() -> void:
	# 화물 엘리베이터 승강장 (서쪽): 세 면 벽 + 지붕 + 승강기 틀
	_span(-70.4, -69.6, 0.0, 4.0, 8.0, 20.0, &"metal")
	_span(-70.0, -58.0, 0.0, 4.0, 7.6, 8.0, &"concrete_dark")
	_span(-70.0, -58.0, 0.0, 4.0, 20.0, 20.4, &"concrete_dark")
	_span(-70.4, -57.6, 4.0, 4.4, 7.6, 20.4, &"concrete_dark")
	for z: float in [11.0, 17.0]:
		_box(Vector3(-58.2, 2.0, z), Vector3(0.4, 4.0, 0.4), &"metal")
	_cover_box(Vector3(-52.0, 0.6, 14.0), Vector3(1.6, 1.2, 1.6), &"wood")
	# 하수구 (동쪽 끝): 콘크리트 벽에 박힌 배수 터널 입구
	_span(78.0, 79.6, 0.0, 3.4, 32.0, 44.0, &"concrete_dark")
	_span(68.0, 79.6, 0.0, 3.4, 31.6, 32.0, &"concrete")
	_span(68.0, 79.6, 0.0, 3.4, 44.0, 44.4, &"concrete")
	_span(66.0, 79.6, 3.4, 3.8, 31.6, 44.4, &"concrete")
	# 시작 구역 창고 (남서): 정면(남쪽 z=56)이 트인 헛간
	_wall_x(-44.0, -32.0, 64.0, 0.0, 3.0, 0.4, &"concrete", [])
	_wall_z(56.0, 64.0, -44.0, 0.0, 3.0, 0.4, &"concrete", [])
	_wall_z(56.0, 64.0, -32.0, 0.0, 3.0, 0.4, &"concrete", [])
	_span(-44.2, -31.8, 3.0, 3.4, 55.8, 64.2, &"concrete_dark")
	_loot(LootContainer.Kind.CRATE, Vector3(-40.0, 0.0, 62.5), 0.0)
	_loot(LootContainer.Kind.TOOLBOX, Vector3(-34.5, 0.0, 61.0), 0.0)


func _build_open_ground_cover() -> void:
	var barriers: Array[Vector3] = [Vector3(-8, 0, 62), Vector3(10, 0, 60), Vector3(-20, 0, 50), Vector3(24, 0, 54),
			Vector3(0, 0, 46), Vector3(-6, 0, -8), Vector3(6, 0, -30), Vector3(-15, 0, -35), Vector3(14, 0, -55),
			Vector3(-20, 0, -12), Vector3(-5, 0, -20), Vector3(-10, 0, 35), Vector3(12, 0, 30), Vector3(22, 0, 42),
			Vector3(40, 0, 30), Vector3(55, 0, 45)]
	for pos: Vector3 in barriers:
		_cover_box(Vector3(pos.x, 0.5, pos.z), Vector3(3.0, 1.0, 0.7), &"concrete")
	_loot(LootContainer.Kind.CRATE, Vector3(28.0, 0.0, 66.0), 0.0)


func _build_routes() -> void:
	enemy_routes.append(PackedVector3Array([Vector3(-66, 0, -25), Vector3(-38, 0, -25), Vector3(-49, 0, -38),
			Vector3(-66, 0, -47), Vector3(-40, 0, -47)]))
	enemy_routes.append(PackedVector3Array([Vector3(-9, 0, -62), Vector3(9, 0, -62), Vector3(9, 0, -72)]))
	enemy_routes.append(PackedVector3Array([Vector3(32, 0, -47), Vector3(44, 0, -46), Vector3(66, 0, -33),
			Vector3(44, 0, -33)]))
	enemy_routes.append(PackedVector3Array([Vector3(8, 0, -16), Vector3(76, 0, -16), Vector3(76, 0, 3),
			Vector3(8, 0, 3)]))
	enemy_routes.append(PackedVector3Array([Vector3(-8, 0, 5), Vector3(-8, 0, 16), Vector3(-20, 0, 16),
			Vector3(-20, 0, 6)]))
	enemy_routes.append(PackedVector3Array([Vector3(-8, STOREY, 5), Vector3(-8, STOREY, 16),
			Vector3(-20, STOREY, 16), Vector3(-20, STOREY, 6)]))


func _build_extractions() -> void:
	var specs: Array[Dictionary] = [
		{"id": &"main_gate", "name": "정문", "pos": Vector3(0, 0, -75), "flag": &""},
		{"id": &"sewer", "name": "하수구", "pos": Vector3(73, 0, 38), "flag": &""},
		{"id": &"freight_lift", "name": "화물 엘리베이터", "pos": Vector3(-64, 0, 14), "flag": POWER_FLAG},
	]
	for spec: Dictionary in specs:
		var zone: ExtractionZone = ExtractionZone.create(spec["id"], spec["name"], EXTRACT_WAIT, spec["flag"])
		zone.position = spec["pos"]
		add_child(zone)
		zone.set_open(spec["flag"] == &"")
		extraction_zones.append(zone)


# --- 건설 도우미 ---

func _box(center: Vector3, size: Vector3, mat: StringName, orientation: Basis = Basis.IDENTITY,
		collide: bool = true) -> void:
	var xform := Transform3D(orientation, center)
	if collide:
		_collider_at(xform, size)
	else:
		_record_nav(xform, size)
	var rec := BoxRec.new()
	rec.xform = xform
	rec.size = size
	if not _visual.has(mat):
		_visual[mat] = []
	(_visual[mat] as Array).append(rec)


## 눈에 안 보이는 충돌 상자 (탱크 등 따로 그려지는 것). add_body가 false면 내비메시 기준으로만 기록한다.
func _collider(center: Vector3, size: Vector3, add_body: bool = true) -> void:
	var xform := Transform3D(Basis.IDENTITY, center)
	if add_body:
		_collider_at(xform, size)
	else:
		_record_nav(xform, size)


func _collider_at(xform: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.transform = xform
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	shape_node.shape = _shape_for(size)
	body.add_child(shape_node)
	region.add_child(body)
	box_count += 1
	_record_nav(xform, size)


func _record_nav(xform: Transform3D, size: Vector3) -> void:
	var rec := BoxRec.new()
	rec.xform = xform
	rec.size = size
	_nav_boxes.append(rec)


func _shape_for(size: Vector3) -> BoxShape3D:
	if not _shapes.has(size):
		var shape := BoxShape3D.new()
		shape.size = size
		_shapes[size] = shape
	return _shapes[size]


## 최소·최대 좌표로 상자를 만든다.
func _span(xa: float, xb: float, ya: float, yb: float, za: float, zb: float, mat: StringName) -> void:
	if xb - xa < 0.01 or yb - ya < 0.01 or zb - za < 0.01:
		return
	_box(Vector3((xa + xb) * 0.5, (ya + yb) * 0.5, (za + zb) * 0.5), Vector3(xb - xa, yb - ya, zb - za), mat)


## 동서 방향 벽 (z 고정). openings는 Vector2(중심 x, 폭) 문 구멍.
func _wall_x(xa: float, xb: float, z: float, y0: float, h: float, t: float, mat: StringName,
		openings: Array[Vector2]) -> void:
	var cursor: float = xa
	for opening: Vector2 in _sorted(openings):
		var left: float = opening.x - opening.y * 0.5
		var right: float = opening.x + opening.y * 0.5
		_span(cursor, left, y0, y0 + h, z - t * 0.5, z + t * 0.5, mat)
		_span(left, right, y0 + DOOR_H, y0 + h, z - t * 0.5, z + t * 0.5, mat)
		cursor = right
	_span(cursor, xb, y0, y0 + h, z - t * 0.5, z + t * 0.5, mat)


## 남북 방향 벽 (x 고정). openings는 Vector2(중심 z, 폭).
func _wall_z(za: float, zb: float, x: float, y0: float, h: float, t: float, mat: StringName,
		openings: Array[Vector2]) -> void:
	var cursor: float = za
	for opening: Vector2 in _sorted(openings):
		var left: float = opening.x - opening.y * 0.5
		var right: float = opening.x + opening.y * 0.5
		_span(x - t * 0.5, x + t * 0.5, y0, y0 + h, cursor, left, mat)
		_span(x - t * 0.5, x + t * 0.5, y0 + DOOR_H, y0 + h, left, right, mat)
		cursor = right
	_span(x - t * 0.5, x + t * 0.5, y0, y0 + h, cursor, zb, mat)


static func _sorted(openings: Array[Vector2]) -> Array[Vector2]:
	var copy: Array[Vector2] = openings.duplicate()
	copy.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return copy


## 엄폐용 상자 + 양옆 엄폐 지점. 짧은 변 쪽에 마커를 둔다.
func _cover_box(center: Vector3, size: Vector3, mat: StringName, markers: bool = true) -> void:
	_box(center, size, mat)
	if markers:
		_cover_markers(center.x, center.z, size.x * 0.5, size.z * 0.5, center.y - size.y * 0.5, 0.9)


## (cx, cz) 상자의 짧은 변 양쪽 gap 거리에 엄폐 지점(cover_point 그룹)을 둔다.
func _cover_markers(cx: float, cz: float, half_x: float, half_z: float, y: float, gap: float) -> void:
	var offsets: Array[Vector3] = []
	if half_z <= half_x:
		offsets = [Vector3(0, 0, half_z + gap), Vector3(0, 0, -half_z - gap)]
	else:
		offsets = [Vector3(half_x + gap, 0, 0), Vector3(-half_x - gap, 0, 0)]
	for offset: Vector3 in offsets:
		var marker := Marker3D.new()
		marker.position = Vector3(cx, y, cz) + offset
		marker.add_to_group(&"cover_point")
		_cover_root.add_child(marker)
		cover_count += 1


func _loot(kind: LootContainer.Kind, pos: Vector3, yaw_deg: float) -> void:
	var container: LootContainer = LootContainer.create(kind)
	container.position = pos
	container.rotation.y = deg_to_rad(yaw_deg)
	_loot_root.add_child(container)
	containers.append(container)
	var body: Vector3 = LootContainer.BODY_SIZES[kind]
	_record_nav(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos + Vector3.UP * body.y * 0.5), body)


# --- 메시 합치기 ---

func _flush_meshes() -> void:
	for mat_id: StringName in _visual:
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		for rec: BoxRec in (_visual[mat_id] as Array):
			_append_box(verts, normals, indices, rec.xform, rec.size)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _materials[mat_id])
		var node := MeshInstance3D.new()
		node.name = "Mesh_%s" % String(mat_id)
		node.mesh = mesh
		add_child(node)
		mesh_instance_count += 1
	_visual.clear()


## 상자의 6개 면(바깥에서 봤을 때 시계 방향 = Godot 앞면)을 정점 배열에 추가한다.
static func _append_box(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		xform: Transform3D, size: Vector3) -> void:
	var half: Vector3 = size * 0.5
	for axis: int in range(3):
		var u_axis: int = (axis + 1) % 3
		var v_axis: int = (axis + 2) % 3
		for sign_value: int in [1, -1]:
			var base: int = verts.size()
			var normal: Vector3 = Vector3.ZERO
			normal[axis] = float(sign_value)
			var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1)]
			if sign_value < 0:
				corners = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			for corner: Vector2 in corners:
				var p: Vector3 = Vector3.ZERO
				p[axis] = half[axis] * float(sign_value)
				p[u_axis] = half[u_axis] * corner.x
				p[v_axis] = half[v_axis] * corner.y
				verts.append(xform * p)
				normals.append((xform.basis * normal).normalized())
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


# --- 내비메시 ---

## 충돌 상자 면으로 내비메시를 동기로 굽는다 (웹 빌드는 스레드가 없다). 폴리곤 수를 돌려준다.
func bake_navmesh() -> int:
	var map: RID = region.get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, NAV_CELL)
	NavigationServer3D.map_set_cell_height(map, NAV_CELL_HEIGHT)
	var navmesh := NavigationMesh.new()
	navmesh.cell_size = NAV_CELL
	navmesh.cell_height = NAV_CELL_HEIGHT
	navmesh.agent_max_climb = NAV_CELL_HEIGHT
	navmesh.agent_radius = 0.4
	navmesh.agent_height = 1.8
	navmesh.agent_max_slope = 40.0
	var source := NavigationMeshSourceGeometryData3D.new()
	var to_region: Transform3D = region.global_transform.affine_inverse()
	var mesh := BoxMesh.new()
	var last_size := Vector3.ZERO
	for rec: BoxRec in _nav_boxes:
		if rec.size != last_size:
			mesh.size = rec.size
			last_size = rec.size
		source.add_faces(mesh.get_faces(), to_region * global_transform * rec.xform)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	region.navigation_mesh = navmesh
	return navmesh.get_polygon_count()
