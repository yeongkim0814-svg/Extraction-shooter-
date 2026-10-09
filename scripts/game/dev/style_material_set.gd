class_name StyleMaterialSet
extends RefCounted
## 스타일 비교 씬의 재질 모음 (기반 클래스). 두 스타일이 같은 ID로 재질을 요청하고, 구현이 서로 다르다.
##   SemirealMaterials : PBR 텍스처(알베도·법선·거칠기) 재질
##   LowpolyMaterials  : 텍스처 없는 팔레트(정점 색) 재질
## ID 상수는 여기에 모아 둔다. 색(tint)은 정점 색으로 들어가므로 빌더에 같이 넘긴다 (apply).

const CONCRETE: StringName = &"concrete"
const CONCRETE_DARK: StringName = &"concrete_dark"
const GROUND: StringName = &"ground"
const ASPHALT: StringName = &"asphalt"
const BRICK: StringName = &"brick"
const CONT_RED: StringName = &"cont_red"
const CONT_TEAL: StringName = &"cont_teal"
const PAINT_RED: StringName = &"paint_red"
const PAINT_TEAL: StringName = &"paint_teal"
const STEEL: StringName = &"steel"
const STEEL_DARK: StringName = &"steel_dark"
const RUST: StringName = &"rust"
const WOOD: StringName = &"wood"
const WOOD_DARK: StringName = &"wood_dark"
const RUBBER: StringName = &"rubber"
const GLASS: StringName = &"glass"
const GLASS_LIT: StringName = &"glass_lit"
const LAMP: StringName = &"lamp"
const SHAFT: StringName = &"shaft"
const PUDDLE: StringName = &"puddle"
const WEED: StringName = &"weed"
const FORKLIFT: StringName = &"forklift"
const TRUCK_BODY: StringName = &"truck_body"
const BARREL_BLUE: StringName = &"barrel_blue"
const BARREL_RED: StringName = &"barrel_red"
const BARREL_OCHRE: StringName = &"barrel_ochre"
const PIPE_ORANGE: StringName = &"pipe_orange"
const PIPE_GREY: StringName = &"pipe_grey"
const BAND_RED: StringName = &"band_red"
const BAND_WHITE: StringName = &"band_white"
const SKY_NEAR: StringName = &"sky_near"
const SKY_MID: StringName = &"sky_mid"
const SKY_FAR: StringName = &"sky_far"
const HILL: StringName = &"hill"
const HILL_FAR: StringName = &"hill_far"
const HAZARD: StringName = &"hazard"
## 스타일 D 전용: 팔레트·넓은 포장·담쟁이·고사리 (다른 스타일 재질 모음은 쓰지 않는다).
const PALLET: StringName = &"pallet"
const PALLET_DARK: StringName = &"pallet_dark"
const PAVING: StringName = &"paving"
const IVY: StringName = &"ivy"
const SHAFT_WARM: StringName = &"shaft_warm"
const FERN: StringName = &"fern"
const WINDOW_STRIP: StringName = &"window_strip"
const WINDOW_DARK: StringName = &"window_dark"
const VENT_STRIP: StringName = &"vent_strip"
const CRATE: StringName = &"crate"
const CRATE_DARK: StringName = &"crate_dark"

var _cache: Dictionary[StringName, Material] = {}


## 재질 ID로 공유 재질을 얻는다.
func get_material(id: StringName) -> Material:
	if not _cache.has(id):
		_cache[id] = _create(id)
	return _cache[id]


## 정점 색(팔레트). 텍스처 스타일은 흰색이다.
func tint(_id: StringName) -> Color:
	return Color.WHITE


## 빌더의 현재 표면을 이 ID의 재질·색으로 맞춘다.
func apply(builder: MeshBuilder, id: StringName) -> void:
	builder.surface(get_material(id))
	builder.color(tint(id))


## 하위 클래스가 구현한다.
func _create(_id: StringName) -> Material:
	return StandardMaterial3D.new()
