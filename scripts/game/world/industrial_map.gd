class_name IndustrialMap
extends Node3D
## 산업단지 맵 (약 176 x 176 m, 원점 중심). 지오메트리는 전부 코드로 만든다 (M10: 흐린 산업단지 무드).
## 상자·원통 하나마다 충돌 모양을 두고(한 StaticBody3D에 모음), 눈에 보이는 면은 재질별로 하나의 ArrayMesh에 합쳐
## 메시 인스턴스 수(= 그리기 호출)를 재질 수 정도로 줄인다 (모바일). 재질은 IndustrialMaterials의 공유 재질(삼면 매핑).
## CSG는 쓰지 않는다. 구역별 건설은 industrial_factory / _warehouses / _site / _infra / _atmosphere 가 이 클래스의
## 건설 도우미(box·span·wall_x·cylinder·beam·quad …)를 불러서 한다.
## 구역: 공장 단지(북) · 창고 구역(동, 창고 2동) · 사무동(서) · 주차장(남서) · 정문(남) · 컨테이너 야적장(중앙 동쪽) ·
##       도로 순환로 · 철길(동쪽 가장자리) · 감시탑(북서) · 배관 랙·크레인·송전탑.
## 좌표: +x 동쪽, -z 북쪽 (플레이어는 남쪽 정문 근처에서 북쪽 공장을 보고 시작한다). 높이 0 = 지면.

const HALF: float = 88.0
const WALL_H: float = 4.5
const DOOR_H: float = 2.6
const STOREY: float = 3.4   # 사무동 2층 바닥 높이
const NAV_CELL: float = 0.4
const NAV_CELL_HEIGHT: float = 0.2
const EXTRACT_WAIT: float = 7.0
const POWER_FLAG: StringName = &"power_on"
## 지면 위에 깔리는 도로·표시 판의 높이 (m). 발 밑 충돌은 0이라 이 정도는 무시된다.
const OVERLAY_Y: float = 0.02


class Batch:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()


class BoxRec:
	var xform: Transform3D
	var size: Vector3


## 내비메시 굽기의 기준이 되는 지오메트리 영역 (모든 충돌 모양의 부모).
var region: NavigationRegion3D
var spawn_position: Vector3 = Vector3(26.0, 0.1, 78.0)
var containers: Array[LootContainer] = []
var extraction_zones: Array[ExtractionZone] = []
var lever: PowerLever
## 적 순찰 경로 (구역별 1개). 지점은 지면/바닥 높이의 좌표.
var enemy_routes: Array[PackedVector3Array] = []
## 개발용 시점 목록 {name, pos, yaw_deg, pitch_deg} (V 키, 스크린샷용).
var view_points: Array[Dictionary] = []
var box_count: int = 0
var mesh_instance_count: int = 0
var cover_count: int = 0
## 천장 램프(발광 전구) 위치: 분위기·측정용.
var lamp_count: int = 0
## 연기를 피울 굴뚝 꼭대기 위치.
var smoke_points: Array[Vector3] = []
## 잡초를 심을 가장자리 구간 (시작, 끝) 쌍. industrial_atmosphere가 읽는다.
var weed_lines: Array[Vector3] = []

var _batches: Dictionary[StringName, Batch] = {}
var _nav_boxes: Array[BoxRec] = []
var _shapes: Dictionary[Vector3, BoxShape3D] = {}
var _solid: StaticBody3D
var _cover_root: Node3D
var _loot_root: Node3D


func _ready() -> void:
	_build()


# --- 전체 구성 ---

func _build() -> void:
	region = NavigationRegion3D.new()
	region.name = "Geometry"
	add_child(region)
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	_solid.collision_layer = 1
	_solid.collision_mask = 0
	region.add_child(_solid)
	_cover_root = Node3D.new()
	_cover_root.name = "CoverPoints"
	add_child(_cover_root)
	_loot_root = Node3D.new()
	_loot_root.name = "Loot"
	add_child(_loot_root)
	IndustrialInfra.build_ground(self)
	IndustrialFactory.build(self)
	IndustrialWarehouses.build(self)
	IndustrialSite.build(self)
	IndustrialInfra.build(self)
	IndustrialInfra.build_skyline(self)
	_build_routes()
	_build_extractions()
	_build_views()
	_flush_meshes()
	IndustrialAtmosphere.build(self)


func _build_routes() -> void:
	# 0 공장 홀 (바닥층 순찰)
	enemy_routes.append(PackedVector3Array([Vector3(-38, 0, -52), Vector3(-6, 0, -52), Vector3(-6, 0, -70),
			Vector3(-30, 0, -70), Vector3(-40, 0, -62)]))
	# 1 창고 A (북동)
	enemy_routes.append(PackedVector3Array([Vector3(44, 0, -30), Vector3(64, 0, -30), Vector3(64, 0, -16),
			Vector3(46, 0, -16)]))
	# 2 창고 B (동)
	enemy_routes.append(PackedVector3Array([Vector3(44, 0, 10), Vector3(64, 0, 10), Vector3(64, 0, 24),
			Vector3(44, 0, 24)]))
	# 3 컨테이너 야적장 + 중앙 도로
	enemy_routes.append(PackedVector3Array([Vector3(2, 0, -30), Vector3(22, 0, -30), Vector3(22, 0, 38),
			Vector3(2, 0, 38)]))
	# 4 공장 앞 도로 + 감시탑 쪽
	enemy_routes.append(PackedVector3Array([Vector3(-66, 0, -42), Vector3(-30, 0, -42), Vector3(-30, 0, -36),
			Vector3(-66, 0, -36)]))
	# 5 사무동 2층 (전원 레버 방)
	enemy_routes.append(PackedVector3Array([Vector3(-30, STOREY, 5), Vector3(-30, STOREY, 16),
			Vector3(-42, STOREY, 16), Vector3(-42, STOREY, 6)]))


func _build_extractions() -> void:
	var specs: Array[Dictionary] = [
		{"id": &"main_gate", "name": "정문", "pos": Vector3(0, 0, 81), "flag": &""},
		{"id": &"railway", "name": "철길", "pos": Vector3(81.5, 0, 46), "flag": &""},
		{"id": &"freight_lift", "name": "화물 엘리베이터", "pos": Vector3(-60, 0, 14), "flag": POWER_FLAG},
	]
	for spec: Dictionary in specs:
		var zone: ExtractionZone = ExtractionZone.create(spec["id"], spec["name"], EXTRACT_WAIT, spec["flag"])
		zone.position = spec["pos"]
		add_child(zone)
		zone.set_open(spec["flag"] == &"")
		extraction_zones.append(zone)


func _build_views() -> void:
	view_points.append({"name": "factory", "pos": Vector3(-6.0, 0.1, -20.0), "yaw_deg": 0.0, "pitch_deg": 3.0})
	view_points.append({"name": "interior", "pos": Vector3(-34.0, 0.1, -54.0), "yaw_deg": -45.0, "pitch_deg": 2.0})
	view_points.append({"name": "yard", "pos": Vector3(0.0, 0.1, 44.0), "yaw_deg": -62.0, "pitch_deg": 4.0})
	view_points.append({"name": "warehouse", "pos": Vector3(35.0, 0.1, -28.0), "yaw_deg": -90.0, "pitch_deg": 2.0})
	view_points.append({"name": "railway", "pos": Vector3(66.0, 0.1, 30.0), "yaw_deg": -90.0, "pitch_deg": 2.0})


# --- 건설 도우미: 상자 ---

## 상자 하나. collide가 true면 충돌(과 내비메시 지오메트리)도 만든다. cast가 false면 그림자를 드리우지 않는다.
func box(center: Vector3, size: Vector3, mat: StringName, orientation: Basis = Basis.IDENTITY,
		collide: bool = true, cast: bool = true) -> void:
	var xform := Transform3D(orientation, center)
	if collide:
		_collider_at(xform, size)
	_append_box(_batch(mat, cast), xform, size)


## 눈에 안 보이는 충돌 상자. add_body가 false면 내비메시 기준으로만 기록한다.
func collider(center: Vector3, size: Vector3, add_body: bool = true, orientation: Basis = Basis.IDENTITY) -> void:
	var xform := Transform3D(orientation, center)
	if add_body:
		_collider_at(xform, size)
	else:
		_record_nav(xform, size)


func _collider_at(xform: Transform3D, size: Vector3) -> void:
	var shape_node := CollisionShape3D.new()
	shape_node.shape = _shape_for(size)
	shape_node.transform = xform
	_solid.add_child(shape_node)
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
func span(xa: float, xb: float, ya: float, yb: float, za: float, zb: float, mat: StringName,
		collide: bool = true, cast: bool = true) -> void:
	if xb - xa < 0.01 or yb - ya < 0.01 or zb - za < 0.01:
		return
	box(Vector3((xa + xb) * 0.5, (ya + yb) * 0.5, (za + zb) * 0.5), Vector3(xb - xa, yb - ya, zb - za), mat,
			Basis.IDENTITY, collide, cast)


## 지면에 깔리는 얇은 판 (도로·주차선·웅덩이 받침). 충돌 없음, 그림자 없음.
func overlay(xa: float, xb: float, za: float, zb: float, mat: StringName, lift: float = 0.0) -> void:
	span(xa, xb, 0.0, OVERLAY_Y + lift, za, zb, mat, false, false)


## 동서 방향 벽 (z 고정). openings는 Vector2(중심 x, 폭) 문 구멍, door_h는 문 높이.
func wall_x(xa: float, xb: float, z: float, y0: float, h: float, t: float, mat: StringName,
		openings: Array[Vector2], door_h: float = DOOR_H) -> void:
	var cursor: float = xa
	for opening: Vector2 in _sorted(openings):
		var left: float = opening.x - opening.y * 0.5
		var right: float = opening.x + opening.y * 0.5
		span(cursor, left, y0, y0 + h, z - t * 0.5, z + t * 0.5, mat)
		span(left, right, y0 + door_h, y0 + h, z - t * 0.5, z + t * 0.5, mat)
		cursor = right
	span(cursor, xb, y0, y0 + h, z - t * 0.5, z + t * 0.5, mat)


## 남북 방향 벽 (x 고정). openings는 Vector2(중심 z, 폭).
func wall_z(za: float, zb: float, x: float, y0: float, h: float, t: float, mat: StringName,
		openings: Array[Vector2], door_h: float = DOOR_H) -> void:
	var cursor: float = za
	for opening: Vector2 in _sorted(openings):
		var left: float = opening.x - opening.y * 0.5
		var right: float = opening.x + opening.y * 0.5
		span(x - t * 0.5, x + t * 0.5, y0, y0 + h, cursor, left, mat)
		span(x - t * 0.5, x + t * 0.5, y0 + door_h, y0 + h, left, right, mat)
		cursor = right
	span(x - t * 0.5, x + t * 0.5, y0, y0 + h, cursor, zb, mat)


static func _sorted(openings: Array[Vector2]) -> Array[Vector2]:
	var copy: Array[Vector2] = openings.duplicate()
	copy.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	return copy


## 엄폐용 상자 + 양옆 엄폐 지점. 짧은 변 쪽에 마커를 둔다.
func cover_box(center: Vector3, size: Vector3, mat: StringName, markers: bool = true) -> void:
	box(center, size, mat)
	if markers:
		cover_markers(center.x, center.z, size.x * 0.5, size.z * 0.5, center.y - size.y * 0.5, 0.9)


## (cx, cz) 상자의 짧은 변 양쪽 gap 거리에 엄폐 지점(cover_point 그룹)을 둔다.
func cover_markers(cx: float, cz: float, half_x: float, half_z: float, y: float, gap: float) -> void:
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


func loot(kind: LootContainer.Kind, pos: Vector3, yaw_deg: float) -> void:
	var container: LootContainer = LootContainer.create(kind)
	container.position = pos
	container.rotation.y = deg_to_rad(yaw_deg)
	_loot_root.add_child(container)
	containers.append(container)
	var body: Vector3 = LootContainer.BODY_SIZES[kind]
	_record_nav(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos + Vector3.UP * body.y * 0.5), body)


## 노드를 맵 아래에 붙인다 (전원 레버 등).
func add_loot_child(node: Node) -> void:
	_loot_root.add_child(node)


# --- 건설 도우미: 빔·원통·경사로·판 ---

## a에서 b까지 이어지는 가는 빔 (격자 탑·난간·사선 보강용).
func beam(a: Vector3, b: Vector3, thick: float, mat: StringName, collide: bool = false, cast: bool = true) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.01:
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var orientation: Basis = Basis.looking_at(dir.normalized(), up)
	box((a + b) * 0.5, Vector3(thick, thick, length), mat, orientation, collide, cast)


## 세운 원통(또는 원뿔대). collide_size가 0이 아니면 같은 중심에 상자 충돌을 둔다.
func cylinder(center: Vector3, r_top: float, r_bottom: float, height: float, mat: StringName, segments: int = 12,
		orientation: Basis = Basis.IDENTITY, collide_size: Vector3 = Vector3.ZERO, cast: bool = true,
		caps: bool = true) -> void:
	var xform := Transform3D(orientation, center)
	if collide_size != Vector3.ZERO:
		_collider_at(xform, collide_size)
	_append_cylinder(_batch(mat, cast), xform, r_top, r_bottom, height, segments, caps)


## x축으로 누운 원통 (배관).
func pipe_x(xa: float, xb: float, y: float, z: float, radius: float, mat: StringName, segments: int = 8) -> void:
	var orientation := Basis(Vector3.FORWARD, PI * 0.5)   # y축 → x축
	cylinder(Vector3((xa + xb) * 0.5, y, z), radius, radius, absf(xb - xa), mat, segments, orientation, Vector3.ZERO,
			true, false)


## z축으로 누운 원통 (배관).
func pipe_z(za: float, zb: float, y: float, x: float, radius: float, mat: StringName, segments: int = 8) -> void:
	var orientation := Basis(Vector3.RIGHT, PI * 0.5)   # y축 → z축
	cylinder(Vector3(x, y, (za + zb) * 0.5), radius, radius, absf(zb - za), mat, segments, orientation, Vector3.ZERO,
			true, false)


## z 방향 경사로 (폭 width, 중심 x). z_low에서 높이 y_low, z_high에서 y_high. 위쪽 면이 두 끝 높이를 지난다.
func ramp_z(x: float, width: float, z_low: float, z_high: float, y_low: float, y_high: float, mat: StringName,
		thick: float = 0.3) -> void:
	var run: float = absf(z_high - z_low)
	var rise: float = y_high - y_low
	var angle: float = atan2(absf(rise), run)
	var length: float = sqrt(run * run + rise * rise)
	var sign_value: float = -1.0 if z_high < z_low else 1.0
	# 북쪽(-z)으로 올라가는 경사는 +X 축 양의 회전
	var tilt: float = angle * (-sign_value) * (1.0 if rise > 0.0 else -1.0)
	var mid_y: float = (y_low + y_high) * 0.5 - thick * 0.5 / cos(angle)
	box(Vector3(x, mid_y, (z_low + z_high) * 0.5), Vector3(width, thick, length), mat, Basis(Vector3.RIGHT, tilt))


## x 방향 경사로 (폭 width, 중심 z). x_low에서 y_low, x_high에서 y_high.
func ramp_x(z: float, width: float, x_low: float, x_high: float, y_low: float, y_high: float, mat: StringName,
		thick: float = 0.3) -> void:
	var run: float = absf(x_high - x_low)
	var rise: float = y_high - y_low
	var angle: float = atan2(absf(rise), run)
	var length: float = sqrt(run * run + rise * rise)
	var toward_east: float = 1.0 if x_high > x_low else -1.0
	var tilt: float = angle * toward_east * (1.0 if rise > 0.0 else -1.0)
	var mid_y: float = (y_low + y_high) * 0.5 - thick * 0.5 / cos(angle)
	box(Vector3((x_low + x_high) * 0.5, mid_y, z), Vector3(length, thick, width), mat, Basis(Vector3.BACK, tilt))


## 네 점 평면 판(사각형). 법선은 (p1-p0)x(p3-p0) 방향. UV는 uv_rep만큼 반복. 색은 꼭짓점별 (그림자 없음).
func quad(mat: StringName, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, uv_rep: Vector2 = Vector2.ONE,
		c0: Color = Color.WHITE, c1: Color = Color.WHITE, c2: Color = Color.WHITE, c3: Color = Color.WHITE) -> void:
	var normal: Vector3 = (p1 - p0).cross(p3 - p0).normalized()
	var tangent: Vector3 = (p1 - p0).normalized()
	var batch: Batch = _batch(mat, false)
	var base: int = batch.verts.size()
	var pts: Array[Vector3] = [p0, p1, p2, p3]
	var cols: Array[Color] = [c0, c1, c2, c3]
	var uv_list: Array[Vector2] = [Vector2(0, uv_rep.y), Vector2(uv_rep.x, uv_rep.y), Vector2(uv_rep.x, 0), Vector2(0, 0)]
	for i: int in range(4):
		batch.verts.append(pts[i])
		batch.normals.append(normal)
		batch.tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1.0]))
		batch.uvs.append(uv_list[i])
		batch.colors.append(cols[i])
	# 앞면 = 시계 방향: (p0,p2,p1), (p0,p3,p2)가 법선 쪽에서 본 시계 방향
	batch.indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


## 벽 표면에 붙는 창문 띠: 시작점 a에서 끝점 b(같은 높이)까지, 높이 y0~y1. normal 쪽을 향한다.
## lit이 true면 안쪽(밝게 빛나는 유리), false면 바깥쪽(어둡고 희미한 유리).
func window_strip(a: Vector3, b: Vector3, y0: float, y1: float, normal: Vector3, lit: bool) -> void:
	var along: Vector3 = b - a
	var length: float = along.length()
	if length < 0.1:
		return
	var offset: Vector3 = normal.normalized() * 0.03
	var p0 := Vector3(a.x, y0, a.z) + offset
	var p1 := Vector3(b.x, y0, b.z) + offset
	var p2 := Vector3(b.x, y1, b.z) + offset
	var p3 := Vector3(a.x, y1, a.z) + offset
	var facing: Vector3 = (p1 - p0).cross(p3 - p0)
	var mat: StringName = IndustrialMaterials.GLASS_LIT if lit else IndustrialMaterials.GLASS_DARK
	var rep := Vector2(length / ((y1 - y0) * 2.0), 1.0)
	if facing.dot(normal) < 0.0:
		quad(mat, p1, p0, p3, p2, rep)
	else:
		quad(mat, p0, p1, p2, p3, rep)


## 가장자리가 부드럽게 사라지는 빛줄기 카드 (가산 혼합). 위·아래 두 변(왼·오른 끝)과 가운데 알파를 받는다.
## 열 3개(왼 끝 알파 0, 가운데 alpha, 오른 끝 알파 0) x 행 2개로 만든다.
func soft_card(top_l: Vector3, top_r: Vector3, bot_l: Vector3, bot_r: Vector3, alpha_top: float, alpha_bottom: float,
		tint: Color) -> void:
	var batch: Batch = _batch(IndustrialMaterials.SHAFT, false)
	var base: int = batch.verts.size()
	var normal: Vector3 = (top_r - top_l).cross(bot_l - top_l).normalized()
	var tangent: Vector3 = (top_r - top_l).normalized()
	var pts: Array[Vector3] = [top_l, (top_l + top_r) * 0.5, top_r, bot_l, (bot_l + bot_r) * 0.5, bot_r]
	var alphas: Array[float] = [0.0, alpha_top, 0.0, 0.0, alpha_bottom, 0.0]
	for i: int in range(6):
		batch.verts.append(pts[i])
		batch.normals.append(normal)
		batch.tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1.0]))
		batch.uvs.append(Vector2.ZERO)
		batch.colors.append(Color(tint.r, tint.g, tint.b, alphas[i]))
	batch.indices.append_array(PackedInt32Array([base, base + 1, base + 4, base, base + 4, base + 3,
			base + 1, base + 2, base + 5, base + 1, base + 5, base + 4]))


## 창에서 바닥으로 비스듬히 내려오는 빛줄기 카드. 창 가로선 a~b(높이 y_top)에서 dir 쪽으로 reach만큼 간다.
func light_shaft(a: Vector3, b: Vector3, y_top: float, dir: Vector3, reach: float, alpha_top: float = 0.1,
		alpha_bottom: float = 0.035, tint: Color = Color(0.75, 0.85, 1.0)) -> void:
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized() * reach
	var ta := Vector3(a.x, y_top, a.z)
	var tb := Vector3(b.x, y_top, b.z)
	var ba: Vector3 = Vector3(a.x, 0.06, a.z) + flat
	var bb: Vector3 = Vector3(b.x, 0.06, b.z) + flat
	soft_card(ta, tb, ba, bb, alpha_top, alpha_bottom, tint)


## 매달린 램프: 줄 + 갓 + 발광 전구 + 아래로 번지는 따뜻한 빛 번짐. pos는 천장 매다는 점.
func hanging_lamp(pos: Vector3, drop: float = 2.2) -> void:
	var steel: StringName = IndustrialMaterials.STEEL
	box(pos - Vector3(0, drop * 0.5, 0), Vector3(0.04, drop, 0.04), steel, Basis.IDENTITY, false, false)
	var shade_y: float = pos.y - drop
	cylinder(Vector3(pos.x, shade_y - 0.12, pos.z), 0.12, 0.5, 0.3, steel, 8, Basis.IDENTITY, Vector3.ZERO, false, false)
	cylinder(Vector3(pos.x, shade_y - 0.3, pos.z), 0.12, 0.12, 0.12, IndustrialMaterials.LAMP, 6, Basis.IDENTITY,
			Vector3.ZERO, false, false)
	# 빛 번짐: 램프 아래로 넓어지는 십자 카드 두 장
	var warm := Color(1.0, 0.76, 0.42)
	var lamp_top := Vector3(pos.x, shade_y - 0.3, pos.z)
	var floor_pt := Vector3(pos.x, 0.06, pos.z)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		soft_card(lamp_top - axis * 0.2, lamp_top + axis * 0.2, floor_pt - axis * 2.8, floor_pt + axis * 2.8, 0.13, 0.05, warm)
	lamp_count += 1


# --- 메시 합치기 ---

## 이 재질들은 늘 그림자를 드리우지 않는다 (얇은 판·발광·유리·먼 풍경). 나머지는 항상 드리워 같은 메시로 합친다
## (그림자 유무별로 메시를 나누면 그리기 호출이 는다).
const NO_CAST_MATERIALS: Array[StringName] = [
	IndustrialMaterials.GROUND, IndustrialMaterials.ASPHALT, IndustrialMaterials.PAINT_WHITE, IndustrialMaterials.PUDDLE,
	IndustrialMaterials.GLASS_LIT, IndustrialMaterials.GLASS_DARK, IndustrialMaterials.SHAFT, IndustrialMaterials.LAMP,
	IndustrialMaterials.SILHOUETTE, IndustrialMaterials.SILHOUETTE_FAR,
]


func _batch(mat: StringName, _cast: bool) -> Batch:
	var cast: bool = not NO_CAST_MATERIALS.has(mat)
	var key: StringName = mat if cast else StringName(String(mat) + "|nocast")
	if not _batches.has(key):
		_batches[key] = Batch.new()
	return _batches[key]


func _flush_meshes() -> void:
	for key: StringName in _batches:
		var batch: Batch = _batches[key]
		if batch.verts.is_empty():
			continue
		var parts: PackedStringArray = String(key).split("|")
		var mat_id := StringName(parts[0])
		var cast: bool = parts.size() == 1
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batch.verts
		arrays[Mesh.ARRAY_NORMAL] = batch.normals
		arrays[Mesh.ARRAY_TANGENT] = batch.tangents
		arrays[Mesh.ARRAY_COLOR] = batch.colors
		arrays[Mesh.ARRAY_TEX_UV] = batch.uvs
		arrays[Mesh.ARRAY_INDEX] = batch.indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, IndustrialMaterials.get_material(mat_id))
		var node := MeshInstance3D.new()
		node.name = "Mesh_%s" % String(key).replace("|", "_")
		node.mesh = mesh
		if not cast:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		mesh_instance_count += 1
	_batches.clear()


static func _append_vertex(batch: Batch, p: Vector3, n: Vector3, t: Vector3, uv: Vector2) -> void:
	batch.verts.append(p)
	batch.normals.append(n)
	batch.tangents.append_array(PackedFloat32Array([t.x, t.y, t.z, 1.0]))
	batch.uvs.append(uv)
	batch.colors.append(Color.WHITE)


## 상자의 6개 면(바깥에서 봤을 때 시계 방향 = Godot 앞면)을 정점 배열에 추가한다.
static func _append_box(batch: Batch, xform: Transform3D, size: Vector3) -> void:
	var half: Vector3 = size * 0.5
	for axis: int in range(3):
		var u_axis: int = (axis + 1) % 3
		var v_axis: int = (axis + 2) % 3
		for sign_value: int in [1, -1]:
			var base: int = batch.verts.size()
			var normal: Vector3 = Vector3.ZERO
			normal[axis] = float(sign_value)
			var tangent_local: Vector3 = Vector3.ZERO
			tangent_local[u_axis] = 1.0
			var world_normal: Vector3 = (xform.basis * normal).normalized()
			var world_tangent: Vector3 = (xform.basis * tangent_local).normalized()
			var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1)]
			if sign_value < 0:
				corners = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
			for corner: Vector2 in corners:
				var p: Vector3 = Vector3.ZERO
				p[axis] = half[axis] * float(sign_value)
				p[u_axis] = half[u_axis] * corner.x
				p[v_axis] = half[v_axis] * corner.y
				_append_vertex(batch, xform * p, world_normal, world_tangent, Vector2.ZERO)
			batch.indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## 세운 원통(위 반지름 r_top, 아래 r_bottom). 옆면 + 위·아래 뚜껑.
static func _append_cylinder(batch: Batch, xform: Transform3D, r_top: float, r_bottom: float, height: float,
		segments: int, caps: bool) -> void:
	var half_h: float = height * 0.5
	var slope: float = (r_bottom - r_top) / maxf(height, 0.001)
	for i: int in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var a := Vector3(d0.x * r_bottom, -half_h, d0.z * r_bottom)
		var b := Vector3(d0.x * r_top, half_h, d0.z * r_top)
		var c := Vector3(d1.x * r_top, half_h, d1.z * r_top)
		var d := Vector3(d1.x * r_bottom, -half_h, d1.z * r_bottom)
		var n0: Vector3 = (xform.basis * Vector3(d0.x, slope, d0.z)).normalized()
		var n1: Vector3 = (xform.basis * Vector3(d1.x, slope, d1.z)).normalized()
		var t0: Vector3 = (xform.basis * Vector3(-d0.z, 0.0, d0.x)).normalized()
		var t1: Vector3 = (xform.basis * Vector3(-d1.z, 0.0, d1.x)).normalized()
		var base: int = batch.verts.size()
		_append_vertex(batch, xform * a, n0, t0, Vector2.ZERO)
		_append_vertex(batch, xform * b, n0, t0, Vector2.ZERO)
		_append_vertex(batch, xform * c, n1, t1, Vector2.ZERO)
		_append_vertex(batch, xform * d, n1, t1, Vector2.ZERO)
		batch.indices.append_array(PackedInt32Array([base, base + 3, base + 2, base, base + 2, base + 1]))
		if caps:
			var up: Vector3 = (xform.basis * Vector3.UP).normalized()
			var tangent: Vector3 = (xform.basis * Vector3.RIGHT).normalized()
			var top_c := Vector3(0.0, half_h, 0.0)
			var bot_c := Vector3(0.0, -half_h, 0.0)
			var tb: int = batch.verts.size()
			_append_vertex(batch, xform * top_c, up, tangent, Vector2.ZERO)
			_append_vertex(batch, xform * b, up, tangent, Vector2.ZERO)
			_append_vertex(batch, xform * c, up, tangent, Vector2.ZERO)
			batch.indices.append_array(PackedInt32Array([tb, tb + 1, tb + 2]))
			var bb: int = batch.verts.size()
			_append_vertex(batch, xform * bot_c, -up, tangent, Vector2.ZERO)
			_append_vertex(batch, xform * a, -up, tangent, Vector2.ZERO)
			_append_vertex(batch, xform * d, -up, tangent, Vector2.ZERO)
			batch.indices.append_array(PackedInt32Array([bb, bb + 2, bb + 1]))


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
