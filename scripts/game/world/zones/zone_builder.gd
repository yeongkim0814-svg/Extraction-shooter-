class_name ZoneBuilder
extends RefCounted
## 구역 하나(= 라이트맵 굽기 단위, ART.md 11.6)를 부품으로 조립하는 작업대. 구역 정의(Zone*.build)가 부품을 놓고,
## 바닥·맞춤 지오메트리를 더하고, tools/build_zones.gd가 finish() 결과를 scenes/raid/zones/<구역>.tscn으로 저장한다.
##   - place(): 부품(KitCatalog)을 놓는다. 저장 때 부품 메시는 재질별·16 m 칸별로 합쳐진다 (부품마다 노드를 두면 그리기 호출이
##     부품 수 x 재질 수가 되어 모바일에서 감당이 안 된다). 충돌은 한 StaticBody3D에 모은다.
##     램프 부품의 LIGHT_<종류> 표식 자리에는 구역 빛 사양대로 OmniLight3D를 단다.
##   - custom(): 부품 라이브러리에 없는 이 구역만의 지오메트리(긴 보, 8 m 기둥 등)를 KitBuild로 만든다. 저장 때 메시 .res가 된다.
##   - ground(): 바닥 판 (KitMaterials 바닥 재질, 월드 투영). 굽기 도구가 8 m 칸으로 쪼갠다.
##   - 게임플레이(루팅·엄폐 표식·순찰·탈출)는 여기서 다루지 않는다. 맵 코드(IndustrialMap)가 그대로 맡는다.
## 좌표는 맵 좌표 그대로다 (구역 씬 원점 = 맵 원점). 그래서 맵은 구역 씬을 변환 없이 붙인다.

## 빛 종류별 사양: 색, 세기, 범위, 감쇠. 표식 이름 LIGHT_<종류>의 <종류>로 찾는다 (ART.md 11.4 빛 색).
const LIGHT_SPECS: Dictionary[String, Dictionary] = {
	"sodium": {"color": KitMaterials.LIGHT_SODIUM, "energy": 4.0, "range": 13.0, "attenuation": 1.3},
	"wall": {"color": KitMaterials.LIGHT_SODIUM, "energy": 1.6, "range": 7.0, "attenuation": 1.5},
	"fluoro": {"color": KitMaterials.LIGHT_FLUORESCENT, "energy": 1.8, "range": 8.0, "attenuation": 1.4},
	"emergency": {"color": KitMaterials.LIGHT_EMERGENCY, "energy": 1.4, "range": 6.0, "attenuation": 1.6},
}

var zone_name: StringName
## 놓은 부품: [부품 이름(StringName), Transform3D].
var pieces: Array[Array] = []
## 맞춤 지오메트리: 이름 -> KitBuild.
var customs: Dictionary[String, KitBuild] = {}
## 바닥: [재질 ID, Rect2(xz), y, 정점 색].
var grounds: Array[Array] = []
## 빛: [이름, 종류, Transform3D]. 램프 부품 표식에서 자동으로 채우고, light()로 직접 넣을 수도 있다.
var lights: Array[Array] = []
## 빛 세기 배율 (구역 분위기 조절).
var light_scale: float = 1.0
## 굽기 칸 크기 (m). 넓고 성긴 구역(바닥·시설)은 키워서 그리기 호출을 줄인다.
var cell_m: float = 16.0
## 칸 메시가 그림자를 드리울지 (바닥만 있는 구역은 끈다: 그림자 패스 그리기 호출 절감).
var cast_shadows: bool = true

var _kit_cache: Dictionary[StringName, KitBuild] = {}


func _init(name_: StringName) -> void:
	zone_name = name_


static func xf(pos: Vector3, yaw_deg: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)


## 부품 하나를 놓는다. 램프면 표식 자리에 빛을 단다.
func place(piece: StringName, xform: Transform3D) -> void:
	if KitCatalog.category_of(piece) == &"":
		push_warning("ZoneBuilder: 없는 부품 " + String(piece))
		return
	pieces.append([piece, xform])
	for rec: Array in _light_markers(piece):
		lights.append(["%s_%d" % [piece, lights.size()], rec[0], xform * (rec[1] as Transform3D)])


func place_at(piece: StringName, pos: Vector3, yaw_deg: float = 0.0) -> void:
	place(piece, xf(pos, yaw_deg))


## a에서 b까지 같은 부품을 step 간격으로 늘어놓는다 (벽 한 줄 등). 부품 가운데가 a + step/2부터 놓인다.
func row(piece: StringName, a: Vector3, b: Vector3, step: float, yaw_deg: float, y: float = 0.0) -> void:
	var dir: Vector3 = b - a
	var count: int = int(round(dir.length() / step))
	for i: int in range(count):
		var p: Vector3 = a + dir.normalized() * (step * (float(i) + 0.5))
		place_at(piece, Vector3(p.x, y, p.z), yaw_deg)


func custom(custom_name: String) -> KitBuild:
	if not customs.has(custom_name):
		customs[custom_name] = KitBuild.new(StringName(custom_name))
	return customs[custom_name]


## 바닥 판. tint = kit_ground 정점 색 (흰색 = 마른 맨바닥, R 낮춤 = 젖음, G 낮춤 = 흙, B 낮춤 = 이끼).
func ground(id: StringName, rect: Rect2, y: float = 0.015, tint: Color = Color.WHITE) -> void:
	grounds.append([id, rect, y, tint])


func light(light_name: String, kind: String, pos: Vector3) -> void:
	lights.append([light_name, kind, Transform3D(Basis.IDENTITY, pos)])


## 부품을 만든다 (부품 이름마다 한 번, 캐시). 메시·충돌·표식을 저장 도구가 재사용한다.
func kit(piece: StringName) -> KitBuild:
	if not _kit_cache.has(piece):
		_kit_cache[piece] = KitCatalog.build(piece)
	return _kit_cache[piece]


## 부품의 LIGHT_<종류> 표식: [[종류, 로컬 Transform3D], ...].
func _light_markers(piece: StringName) -> Array:
	var out: Array = []
	var kb: KitBuild = kit(piece)
	if kb == null:
		return out
	for rec: Array in kb.markers:
		var marker_name: String = rec[0]
		if marker_name.begins_with("LIGHT_"):
			out.append([marker_name.substr("LIGHT_".length()), rec[1]])
	return out


## OmniLight3D 하나 (구워질 정적 빛, 그림자 없음).
func make_light(light_name: String, kind: String, xform: Transform3D) -> OmniLight3D:
	var spec: Dictionary = LIGHT_SPECS.get(kind, LIGHT_SPECS["sodium"])
	var l := OmniLight3D.new()
	l.name = light_name.to_pascal_case()
	l.transform = Transform3D(Basis.IDENTITY, xform.origin)
	l.light_color = spec["color"] as Color
	l.light_energy = float(spec["energy"]) * light_scale
	l.omni_range = float(spec["range"])
	l.omni_attenuation = float(spec["attenuation"])
	l.shadow_enabled = false
	l.light_bake_mode = Light3D.BAKE_STATIC
	return l


## 바닥 메시 하나 (네 귀퉁이 판). 굽기 도구가 큰 판을 칸으로 쪼갠다.
func ground_mesh(rec: Array) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.with_tangents = true
	mb.surface(KitMaterials.get_material(rec[0] as StringName))
	mb.color(rec[3] as Color)
	var r: Rect2 = rec[1]
	var y: float = rec[2]
	mb.subdiv_max = 8.0
	mb.add_quad(Transform3D.IDENTITY, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y),
			Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y), Vector3.UP)
	return mb.build()
