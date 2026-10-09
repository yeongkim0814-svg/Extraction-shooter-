class_name LootContainer
extends StaticBody3D
## 월드의 루팅 컨테이너 (상자·공구함·서랍장·무기 상자·의료 가방). 도형은 종류별 크기·색의 임시 상자.
## 내용물은 레이드 시작 때 roll_contents로 굴려 권한자에 수색 가능 컨테이너로 등록한다.
## 이름 글자(Label3D)는 6 m 안에서만 보인다 (visibility_range).

enum Kind { CRATE, TOOLBOX, DRAWER, WEAPON_BOX, MEDBAG }

const FONT: Font = preload("res://assets/fonts/NotoSansKR.ttf")
const LABEL_RANGE: float = 6.0

## 종류별 표시 이름·그리드 크기(칸)·몸체 크기(m)·색.
const NAMES: Dictionary[Kind, String] = {
	Kind.CRATE: "나무 상자", Kind.TOOLBOX: "공구함", Kind.DRAWER: "서랍장",
	Kind.WEAPON_BOX: "무기 상자", Kind.MEDBAG: "의료 가방",
}
const GRID_SIZES: Dictionary[Kind, Vector2i] = {
	Kind.CRATE: Vector2i(4, 3), Kind.TOOLBOX: Vector2i(3, 2), Kind.DRAWER: Vector2i(4, 2),
	Kind.WEAPON_BOX: Vector2i(5, 3), Kind.MEDBAG: Vector2i(3, 3),
}
const BODY_SIZES: Dictionary[Kind, Vector3] = {
	Kind.CRATE: Vector3(1.3, 0.9, 0.9), Kind.TOOLBOX: Vector3(0.8, 0.5, 0.4),
	Kind.DRAWER: Vector3(1.2, 1.1, 0.55), Kind.WEAPON_BOX: Vector3(1.4, 0.5, 0.6),
	Kind.MEDBAG: Vector3(0.6, 0.35, 0.4),
}
const COLORS: Dictionary[Kind, Color] = {
	Kind.CRATE: Color(0.55, 0.4, 0.22), Kind.TOOLBOX: Color(0.75, 0.2, 0.15),
	Kind.DRAWER: Color(0.42, 0.44, 0.48), Kind.WEAPON_BOX: Color(0.25, 0.32, 0.2),
	Kind.MEDBAG: Color(0.85, 0.85, 0.85),
}

static var _mesh_cache: Dictionary[Kind, BoxMesh] = {}
static var _material_cache: Dictionary[Kind, StandardMaterial3D] = {}

var kind: Kind = Kind.CRATE
## 권한자가 발급한 키. 내용물을 굴리기 전에는 &"".
var loot_key: StringName = &""

var _grid: ItemGrid


## 노드를 만든다 (씬 트리에 넣기 전). 위치·방향은 호출자가 정한다.
static func create(p_kind: Kind) -> LootContainer:
	var container := LootContainer.new()
	container.kind = p_kind
	container.name = "Loot%s" % String(Kind.keys()[p_kind]).capitalize()
	return container


static func kind_name(p_kind: Kind) -> String:
	return NAMES[p_kind]


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var size: Vector3 = BODY_SIZES[kind]
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _shared_mesh(kind)
	mesh_node.material_override = _shared_material(kind)
	mesh_node.position.y = size.y * 0.5
	add_child(mesh_node)
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position.y = size.y * 0.5
	add_child(shape_node)
	var label := Label3D.new()
	label.text = NAMES[kind]
	label.font = FONT
	label.font_size = 36
	label.pixel_size = 0.006
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = size.y + 0.4
	label.visibility_range_end = LABEL_RANGE
	add_child(label)


## 상호작용 기준점 (몸체 중심).
func interact_position() -> Vector3:
	return global_position + Vector3.UP * (BODY_SIZES[kind].y * 0.5)


## 내용물을 굴려 권한자에 수색 가능한 컨테이너로 등록하고 키를 돌려준다. 이미 등록했으면 기존 키.
func roll_contents(authority: GameAuthority, rng: RandomNumberGenerator) -> StringName:
	if loot_key != &"":
		return loot_key
	var size: Vector2i = GRID_SIZES[kind]
	_grid = ItemGrid.new(size.x, size.y)
	RaidLoot.table_for(kind, authority.content).fill_grid(_grid, rng, authority)
	loot_key = authority.register_container(_grid, NAMES[kind], true)
	return loot_key


func item_count() -> int:
	return _grid.get_items().size() if _grid != null else 0


static func _shared_mesh(p_kind: Kind) -> BoxMesh:
	if not _mesh_cache.has(p_kind):
		var mesh := BoxMesh.new()
		mesh.size = BODY_SIZES[p_kind]
		_mesh_cache[p_kind] = mesh
	return _mesh_cache[p_kind]


static func _shared_material(p_kind: Kind) -> StandardMaterial3D:
	if not _material_cache.has(p_kind):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLORS[p_kind]
		mat.roughness = 0.85
		_material_cache[p_kind] = mat
	return _material_cache[p_kind]
