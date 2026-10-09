class_name KitBuild
extends RefCounted
## 부품 하나를 만드는 작업대 (ART.md 11.5). 부품 정의(KitCatalog)가 이걸로 도형·충돌·표식을 쌓고, finish()가 씬 루트를 낸다.
##   - 눈에 보이는 도형은 MeshBuilder 하나에 재질별 표면으로 모인다 (부품 하나 = MeshInstance3D 하나 = 그리기 호출이 재질 수만큼).
##   - 트림 재질(KitMaterials.is_trim)은 KitLayout 줄로 UV를 사상한다. 기본은 재질의 줄, 윗면·아랫면은 같은 시트의 다른 줄로 바꿀 수 있다.
##   - 단색·바닥 재질은 셰이더가 월드 투영을 하므로 UV는 신경 쓰지 않는다.
##   - 충돌은 상자 모양만 쓴다 (모바일 물리 비용, 내비메시 굽기와 맞춤). 도형과 따로 넣어 단순하게 유지한다.
##   - 표식(Marker3D): 빛 자리("LIGHT_<종류>"), 이어 붙임 자리("SNAP_<이름>"), 루팅 자리("LOOT") 같은 메타데이터.
## 좌표 규약: 단위 m, Y-up, 부품 원점 = 바닥 중심(벽 모듈은 벽 앞면 아래 가운데가 아니라 벽 두께 중심선의 아래 가운데).

## 모따기 기본값 (ART.md 11.2: 큰 덩어리 3~6 cm, 소품 1.5~3 cm).
const BEVEL_LARGE: float = 0.045
const BEVEL_SMALL: float = 0.02
## 이 두께보다 얇은 판·막대는 모따지 않는다 (삼각형 절약).
const BEVEL_MIN_THICK: float = 0.08

var piece_name: StringName
var mesh := MeshBuilder.new()
## 충돌 상자: [Transform3D, size(Vector3)].
var collision: Array[Array] = []
## 표식: [name(String), Transform3D].
var markers: Array[Array] = []
## 부품을 루팅 컨테이너 등으로 쓸 때 붙일 메타데이터 (씬 루트의 meta로 저장).
var meta: Dictionary[String, Variant] = {}


func _init(name_: StringName) -> void:
	piece_name = name_
	mesh.with_tangents = true
	mesh.trim_jitter = false


## 재질과 줄 배정. top/bottom이 비면 옆면 줄을 쓴다. 트림이 아니면 줄 사상을 끈다.
func use(id: StringName, top: StringName = &"", bottom: StringName = &"") -> void:
	mesh.surface(KitMaterials.get_material(id))
	if not KitMaterials.is_trim(id):
		mesh.trim_strips = PackedVector2Array()
		return
	var sheet: int = KitMaterials.sheet_of(id)
	var side_v: Vector2 = KitMaterials.v_range(id)
	var top_v: Vector2 = KitLayout.v_range(sheet, top) if top != &"" else side_v
	var bottom_v: Vector2 = KitLayout.v_range(sheet, bottom) if bottom != &"" else top_v
	mesh.trim_strips = TrimUv.side_top_bottom(side_v, top_v, bottom_v)
	mesh.trim_tile_m = KitLayout.TILE_M
	mesh.trim_axial = false


## 모따기 상자. bevel < 0이면 크기로 기본값을 고른다. collide가 true면 같은 상자로 충돌도 넣는다.
func box(id: StringName, xform: Transform3D, size: Vector3, bevel: float = -1.0, collide: bool = true,
		top: StringName = &"", bottom: StringName = &"") -> void:
	use(id, top, bottom)
	var small: float = minf(size.x, minf(size.y, size.z))
	var b: float = bevel
	if b < 0.0:
		b = BEVEL_LARGE if small >= 0.3 else BEVEL_SMALL
	if small < BEVEL_MIN_THICK and bevel < 0.0:
		b = 0.0
	b = minf(b, small * 0.35)
	mesh.add_box(xform, size, b, 2 if b >= 0.04 else 1)
	if collide:
		collide_box(xform, size)


## 바닥 중심 기준 상자 (pos = 바닥면 중심). 부품 정의에서 가장 흔한 꼴.
func block(id: StringName, pos: Vector3, size: Vector3, bevel: float = -1.0, collide: bool = true,
		top: StringName = &"", bottom: StringName = &"") -> void:
	box(id, Transform3D(Basis.IDENTITY, pos + Vector3(0.0, size.y * 0.5, 0.0)), size, bevel, collide, top, bottom)


## Y축 원기둥 (xform 원점 = 원기둥 가운데). axial이면 트림을 축 방향으로 (긴 파이프).
func cylinder(id: StringName, xform: Transform3D, radius: float, height: float, sides: int = 12,
		bevel: float = 0.0, axial: bool = false, collide: bool = true) -> void:
	use(id)
	mesh.trim_axial = axial
	mesh.add_cylinder(xform, radius, height, sides, bevel)
	mesh.trim_axial = false
	if collide:
		# 원기둥 충돌은 바깥 상자로 근사한다
		collide_box(xform, Vector3(radius * 1.8, height, radius * 1.8))


## 두 점을 잇는 각재 (트러스·버팀대·난간). 충돌은 기본으로 넣지 않는다 (가는 부재).
func strut(id: StringName, a: Vector3, b: Vector3, thick: float, collide: bool = false) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.001:
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	var xform := Transform3D(Basis.looking_at(dir.normalized(), up), (a + b) * 0.5)
	box(id, xform, Vector3(thick, thick, length), 0.0 if thick < BEVEL_MIN_THICK else BEVEL_SMALL, collide)


## 프로파일 압출 (로컬 XY 반시계, 로컬 Z 길이).
func prism(id: StringName, xform: Transform3D, profile: PackedVector2Array, length: float) -> void:
	use(id)
	mesh.add_prism(xform, profile, length)


func collide_box(xform: Transform3D, size: Vector3) -> void:
	collision.append([xform, size])


func marker(marker_name: String, xform: Transform3D) -> void:
	markers.append([marker_name, xform])


func triangle_count() -> int:
	return mesh.triangle_count


## 씬 루트: Node3D(부품 이름) > MeshInstance3D "Mesh" + StaticBody3D "Body"(상자 모양들) + 표식들.
## mesh_override가 있으면 그 메시를 쓴다 (도구가 UV2·LOD를 넣은 저장본).
func finish(mesh_override: Mesh = null) -> Node3D:
	var root := Node3D.new()
	root.name = String(piece_name).to_pascal_case()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh_override if mesh_override != null else mesh.build()
	mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	root.add_child(mi)
	if not collision.is_empty():
		var body := StaticBody3D.new()
		body.name = "Body"
		root.add_child(body)
		var i: int = 0
		for rec: Array in collision:
			var cs := CollisionShape3D.new()
			cs.name = "Shape%d" % i
			var shape := BoxShape3D.new()
			shape.size = rec[1] as Vector3
			cs.shape = shape
			cs.transform = rec[0] as Transform3D
			body.add_child(cs)
			i += 1
	for rec: Array in markers:
		var m := Marker3D.new()
		m.name = String(rec[0])
		m.transform = rec[1] as Transform3D
		root.add_child(m)
	for key: String in meta:
		root.set_meta(key, meta[key])
	return root
