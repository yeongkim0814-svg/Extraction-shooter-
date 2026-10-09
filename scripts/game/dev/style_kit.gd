class_name StyleKit
extends RefCounted
## 스타일 비교 씬의 공통 도구: 스타일 구분, 재질 모음, 그룹별 MeshBuilder, 박스·원기둥·버팀대 도우미.
## 같은 배치 코드가 두 스타일을 모두 만든다. 스타일마다 다른 곳(모따기 크기·분할 수·재질)은 여기서 흡수한다.

## 그림자를 드리우지 않는 그룹 (먼 배경, 빛줄기).
const NO_SHADOW_GROUPS: Array[StringName] = [&"skyline", &"shaft", &"glow", &"far_ground"]
## 스타일 B의 아래쪽 어둡게 하는 높이 그라데이션 (m, 강도).
const B_GRADIENT_TOP: float = 5.0
const B_GRADIENT_DARK: float = 0.34

## 스타일 종류 (StyleCompare.Style의 값과 같다: 0 = A, 1 = B, 2 = C).
const KIND_A: int = 0
const KIND_B: int = 1
const KIND_C: int = 2

## A "반실사" (법선 맵 텍스처). B·C는 로우폴리 지오메트리라 is_a가 false.
var is_a: bool
## C "레트로 로우폴리" (픽셀 텍스처 + 월드 UV). 지오메트리는 B와 같은 로우폴리 틀을 쓰되 세부는 텍스처가 맡는다.
var is_c: bool
## 표면 세부(골판 주름·문짝 리브·울타리 살)를 텍스처가 맡는가 (A, C). false면 기하 주름을 만든다 (B).
var textured: bool
var mats: StyleMaterialSet
var groups: Dictionary[StringName, MeshBuilder] = {}


func _init(kind: int) -> void:
	is_a = kind == KIND_A
	is_c = kind == KIND_C
	textured = is_a or is_c
	match kind:
		KIND_A:
			mats = SemirealMaterials.new()
		KIND_C:
			mats = RetroMaterials.new()
		_:
			mats = LowpolyMaterials.new()


## 그룹 이름의 빌더 (처음이면 스타일에 맞게 설정해 만든다).
func g(group_name: StringName) -> MeshBuilder:
	if not groups.has(group_name):
		var b := MeshBuilder.new()
		b.flat_shading = not is_a
		b.with_tangents = is_a and group_name != &"skyline" and group_name != &"shaft"
		b.world_uv = is_c
		if not is_a and not is_c:
			b.set_gradient(0.0, B_GRADIENT_TOP, B_GRADIENT_DARK)
		groups[group_name] = b
	return groups[group_name]


static func xf(pos: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


## base 좌표계의 offset 위치, 같은 방향.
static func loc(base: Transform3D, offset: Vector3) -> Transform3D:
	return Transform3D(base.basis, base * offset)


## 스타일별 값 선택.
func pick(a_value: float, b_value: float) -> float:
	return a_value if is_a else b_value


func pick_i(a_value: int, b_value: int) -> int:
	return a_value if is_a else b_value


## 모따기 박스. bevel은 스타일 A 기준 m, B는 더 굵게 (면이 또렷하게 갈라지게).
func box(builder: MeshBuilder, id: StringName, xform: Transform3D, size: Vector3, bevel: float = 0.0) -> void:
	mats.apply(builder, id)
	if is_a:
		builder.add_box(xform, size, bevel, 2 if bevel >= 0.05 else 1)
	else:
		builder.add_box(xform, size, bevel * 1.5 if bevel > 0.0 else 0.0, 1)


## 원기둥/원뿔대 (Y축). sides_a/sides_b = 스타일별 옆면 수.
func cyl(builder: MeshBuilder, id: StringName, xform: Transform3D, radius: float, height: float,
		sides_a: int, sides_b: int, bevel: float = 0.0, top_radius: float = -1.0) -> void:
	mats.apply(builder, id)
	builder.add_cylinder(xform, radius, height, sides_a if is_a else sides_b, bevel, top_radius)


## 두 점을 잇는 각재 (트러스 버팀대·파이프).
func strut(builder: MeshBuilder, id: StringName, a: Vector3, b: Vector3, thick: float) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.001:
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	var basis: Basis = Basis.looking_at(dir.normalized(), up)
	mats.apply(builder, id)
	builder.add_box(Transform3D(basis, (a + b) * 0.5), Vector3(thick, thick, length), 0.0, 1)


## Y축 원기둥을 X축 방향으로 눕히는 기저.
static func axis_x() -> Basis:
	return Basis(Vector3.BACK, -PI / 2.0)


## Y축 원기둥을 Z축 방향으로 눕히는 기저.
static func axis_z() -> Basis:
	return Basis(Vector3.RIGHT, PI / 2.0)


## 완성된 그룹을 MeshInstance3D로 부모 아래에 붙인다. 반환: 만든 노드 수.
func commit(parent: Node3D) -> int:
	var count: int = 0
	for group_name: StringName in groups:
		var builder: MeshBuilder = groups[group_name]
		var instance := MeshInstance3D.new()
		instance.name = String(group_name).capitalize().replace(" ", "")
		instance.mesh = builder.build()
		if NO_SHADOW_GROUPS.has(group_name):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
		count += 1
	return count


## 총 삼각형 수 (보고용).
func triangle_total() -> int:
	var total: int = 0
	for builder: MeshBuilder in groups.values():
		total += builder.triangle_count
	return total
