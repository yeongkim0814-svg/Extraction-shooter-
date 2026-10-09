class_name KitMaterials
extends RefCounted
## 텍스처 v2 재질 라이브러리 (docs/ART.md 11장). 트림시트 3장(tools/gen_textures_v2.py) + 단색 넓은 면 + 바닥 3종.
## 재질 ID는 "공유 재질 + 정점 색" 쌍이다 (그리기 호출 절감: 페인트 색마다 재질을 나누면 칸 하나에 재질 수십 개가 생긴다).
##   트림: 시트마다 재질 하나(발광 변형만 따로), 정점 색 RGB = 페인트 색(sRGB). 단색: 금속/비금속 재질 둘, 정점 색 RGB = 색, A = 거칠기.
##   바닥: 텍스처마다 재질 하나, 정점 색은 kit_ground 규약(흰색 = 마른 맨바닥).
## get_material(id)는 공유 재질, vertex_color(id)는 그 ID의 정점 색. KitBuild.use가 둘 다 메시 빌더에 넣는다.
## 트림 ID는 (시트, 줄)을 알려 주므로 메시 빌더가 KitLayout으로 UV를 맞출 수 있다.
## 텍스처가 없으면 push_warning을 남기고 자리표시자를 쓴다 (충돌하지 않는다).

const DIR: String = "res://assets/textures/v2/"
const SHADER_TRIM: String = "res://assets/shaders/kit_trim.gdshader"
const SHADER_FLAT: String = "res://assets/shaders/kit_flat.gdshader"
const SHADER_GROUND: String = "res://assets/shaders/kit_ground.gdshader"
## 저장된 재질(.tres) 폴더. tools/build_kit.gd가 모든 ID를 여기에 저장하고 부품 메시가 이 파일을 참조한다 (부품끼리 재질 공유).
const SAVED_DIR: String = "res://assets/materials/kit/"

## 팔레트 (ART.md 11.4). 페인트는 옅은 바탕(~#CDCBC4)에 곱해지므로 결과는 이보다 약간 어둡다.
const PAINT_RUST_RED: Color = Color("B3452B")
const PAINT_TEAL_GREY: Color = Color("5C8589")
const PAINT_OLIVE: Color = Color("757F45")
const PAINT_WARNING_YELLOW: Color = Color("FFB32E")
const PAINT_FADED_WHITE: Color = Color("EBE6D1")
const CONCRETE: Color = Color("8C8984")
const CONCRETE_DARK: Color = Color("5E5C59")
const METAL_BASE: Color = Color("6E737A")
const RUST_DARK: Color = Color("70391C")
const RUST_LIGHT: Color = Color("96542A")
## 빛 색 (조명 배치용).
const LIGHT_SKY: Color = Color("9AA8B4")
const LIGHT_SUN: Color = Color("FFC9A0")
const LIGHT_SODIUM: Color = Color("FF9E4F")
const LIGHT_EMERGENCY: Color = Color("40D9FF")
const LIGHT_FLUORESCENT: Color = Color("E6F2FF")

## 트림 재질 ID.
const CONCRETE_WALL: StringName = &"concrete_wall"
const CONCRETE_PANEL: StringName = &"concrete_panel"
const BRICK: StringName = &"brick"
const BAND_WHITE: StringName = &"band_white"
const BAND_RED: StringName = &"band_red"
const HAZARD: StringName = &"hazard"
const WINDOW: StringName = &"window"
const SHUTTER: StringName = &"shutter"
const SILL: StringName = &"sill"
const METAL_CORRUGATED_RED: StringName = &"metal_corrugated_red"
const METAL_CORRUGATED_TEAL: StringName = &"metal_corrugated_teal"
const METAL_PLATE: StringName = &"metal_plate"
const METAL_CHIPPED: StringName = &"metal_chipped"
const RUST: StringName = &"rust"
const GRATE: StringName = &"grate"
const PIPE_RED: StringName = &"pipe_red"
const PIPE_TEAL: StringName = &"pipe_teal"
const BEAM_YELLOW: StringName = &"beam_yellow"
const BEAM_TEAL: StringName = &"beam_teal"
const TREAD: StringName = &"tread"
const VENT: StringName = &"vent"
const PIPE_JOINT: StringName = &"pipe_joint"
const CABLE: StringName = &"cable"
const CABINET_OLIVE: StringName = &"cabinet_olive"
const CABINET_GREY: StringName = &"cabinet_grey"
const SIGN: StringName = &"sign"
const FLUORO: StringName = &"fluoro"
const DOOR_STEEL: StringName = &"door_steel"
const DUCT: StringName = &"duct"
## 발광 줄을 나트륨·비상등 색으로 쓰는 변형 (램프 전구·비상등 몸체).
const FLUORO_SODIUM: StringName = &"fluoro_sodium"
const EMERGENCY: StringName = &"emergency"
## 단색 넓은 면 ID.
const FLAT_CONCRETE: StringName = &"flat_concrete"
const FLAT_CONCRETE_DARK: StringName = &"flat_concrete_dark"
const FLAT_METAL: StringName = &"flat_metal"
const FLAT_ROOF: StringName = &"flat_roof"
const FLAT_TANK_WHITE: StringName = &"flat_tank_white"
const FLAT_GLASS: StringName = &"flat_glass"
const FLAT_WOOD: StringName = &"flat_wood"
const FLAT_RUBBER: StringName = &"flat_rubber"
## 바닥 ID.
const GROUND_ASPHALT: StringName = &"ground_asphalt"
const GROUND_CONCRETE: StringName = &"ground_concrete"
const GROUND_GRAVEL: StringName = &"ground_gravel"

## 트림 사양: ID -> [시트, 줄, 페인트 색, 추가 설정]. 추가 설정 키: tint(Color), rough(float), metal(float), emit(float), normal(float).
const _TRIM: Dictionary[StringName, Array] = {
	CONCRETE_WALL: [1, &"wall", Color.WHITE, {}],
	CONCRETE_PANEL: [1, &"panel", Color.WHITE, {}],
	BRICK: [1, &"brick", Color.WHITE, {}],
	BAND_WHITE: [1, &"band", PAINT_FADED_WHITE, {}],
	BAND_RED: [1, &"band", PAINT_RUST_RED, {}],
	HAZARD: [1, &"hazard", Color.WHITE, {}],
	WINDOW: [1, &"window", PAINT_FADED_WHITE, {}],
	SHUTTER: [1, &"shutter", PAINT_TEAL_GREY, {}],
	SILL: [1, &"sill", Color.WHITE, {}],
	METAL_CORRUGATED_RED: [2, &"corrugated", PAINT_RUST_RED, {}],
	METAL_CORRUGATED_TEAL: [2, &"corrugated", PAINT_TEAL_GREY, {}],
	METAL_PLATE: [2, &"plate", PAINT_TEAL_GREY, {}],
	METAL_CHIPPED: [2, &"chipped", PAINT_OLIVE, {}],
	RUST: [2, &"rust", Color.WHITE, {}],
	GRATE: [2, &"grate", Color.WHITE, {}],
	PIPE_RED: [2, &"pipe", PAINT_RUST_RED, {}],
	PIPE_TEAL: [2, &"pipe", PAINT_TEAL_GREY, {}],
	BEAM_YELLOW: [2, &"beam", PAINT_WARNING_YELLOW, {}],
	BEAM_TEAL: [2, &"beam", PAINT_TEAL_GREY, {}],
	TREAD: [2, &"tread", Color.WHITE, {}],
	VENT: [3, &"vent", PAINT_FADED_WHITE, {}],
	PIPE_JOINT: [3, &"pipe_joint", PAINT_RUST_RED, {}],
	CABLE: [3, &"cable", Color.WHITE, {}],
	CABINET_OLIVE: [3, &"cabinet", PAINT_OLIVE, {}],
	CABINET_GREY: [3, &"cabinet", Color("8A8F95"), {}],
	SIGN: [3, &"sign", PAINT_WARNING_YELLOW, {}],
	FLUORO: [3, &"fluoro", PAINT_FADED_WHITE, {"emit": 2.0}],
	FLUORO_SODIUM: [3, &"fluoro", PAINT_FADED_WHITE, {"emit": 3.0, "emit_color": LIGHT_SODIUM}],
	EMERGENCY: [3, &"fluoro", PAINT_FADED_WHITE, {"emit": 3.0, "emit_color": LIGHT_EMERGENCY}],
	DOOR_STEEL: [3, &"door_hw", PAINT_TEAL_GREY, {}],
	DUCT: [3, &"duct", Color.WHITE, {}],
}

## 단색 사양: ID -> [색, 거칠기, 금속성].
const _FLAT: Dictionary[StringName, Array] = {
	FLAT_CONCRETE: [CONCRETE, 0.92, 0.0],
	FLAT_CONCRETE_DARK: [CONCRETE_DARK, 0.94, 0.0],
	FLAT_METAL: [METAL_BASE, 0.6, 0.5],
	FLAT_ROOF: [Color("55524F"), 0.88, 0.05],
	FLAT_TANK_WHITE: [PAINT_FADED_WHITE, 0.55, 0.2],
	FLAT_GLASS: [Color("1C2226"), 0.08, 0.0],
	FLAT_WOOD: [Color("7A5A3C"), 0.85, 0.0],
	FLAT_RUBBER: [Color("1A1A1C"), 0.9, 0.0],
}

## 바닥 사양: ID -> [텍스처 이름 조각, 틴트].
const _GROUND: Dictionary[StringName, Array] = {
	GROUND_ASPHALT: ["asphalt", Color.WHITE],
	GROUND_CONCRETE: ["concrete", Color.WHITE],
	GROUND_GRAVEL: ["gravel", Color.WHITE],
}

static var _cache: Dictionary[StringName, Material] = {}
static var _tex_cache: Dictionary[String, Texture2D] = {}
static var _shaders: Dictionary[String, Shader] = {}


## 모든 재질 ID.
static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(_TRIM.keys())
	out.append_array(_FLAT.keys())
	out.append_array(_GROUND.keys())
	return out


static func trim_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(_TRIM.keys())
	return out


static func is_trim(id: StringName) -> bool:
	return _TRIM.has(id)


static func is_flat(id: StringName) -> bool:
	return _FLAT.has(id)


static func is_ground(id: StringName) -> bool:
	return _GROUND.has(id)


## 트림 ID의 시트 번호 (트림이 아니면 0).
static func sheet_of(id: StringName) -> int:
	if _TRIM.has(id):
		return (_TRIM[id] as Array)[0]
	return 0


## 트림 ID의 줄 이름 (트림이 아니면 빈 이름).
static func strip_of(id: StringName) -> StringName:
	if _TRIM.has(id):
		return (_TRIM[id] as Array)[1]
	return &""


## 트림 ID의 줄 V 범위 (메시 UV 사상용). 트림이 아니면 시트 전체.
static func v_range(id: StringName) -> Vector2:
	return KitLayout.v_range(sheet_of(id), strip_of(id))


## 저장된 재질을 먼저 쓸지. 굽기 도구는 false로 두고 사양에서 새로 만든다.
static var prefer_saved: bool = true


## 이 ID가 쓰는 공유 재질의 키 (저장 파일 이름이기도 하다).
static func material_key(id: StringName) -> StringName:
	if _TRIM.has(id):
		var extra: Dictionary = _TRIM[id][3]
		if extra.has("emit"):
			return StringName("trim%d_%s" % [int(_TRIM[id][0]), String(id)])
		return StringName("trim%d" % int(_TRIM[id][0]))
	if _FLAT.has(id):
		return &"flat_metal" if float(_FLAT[id][2]) > 0.25 else &"flat"
	if _GROUND.has(id):
		return StringName(String(id))
	return &"fallback"


## 모든 공유 재질 키.
static func material_keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in all_ids():
		var key: StringName = material_key(id)
		if not out.has(key):
			out.append(key)
	return out


## 이 ID의 정점 색 (sRGB, 셰이더가 렌더러에 맞게 선형으로 바꾼다). 트림 = 페인트, 단색 = 색 + A 거칠기, 바닥 = 흰색.
static func vertex_color(id: StringName) -> Color:
	if _TRIM.has(id):
		var paint: Color = _TRIM[id][2]
		return Color(paint.r, paint.g, paint.b, 1.0)
	if _FLAT.has(id):
		var c: Color = _FLAT[id][0]
		return Color(c.r, c.g, c.b, float(_FLAT[id][1]))
	return Color.WHITE


static func get_material(id: StringName) -> Material:
	var key: StringName = material_key(id)
	if _cache.has(key):
		return _cache[key]
	var m: Material = null
	var saved: String = saved_path(key)
	if prefer_saved and ResourceLoader.exists(saved):
		m = load(saved) as Material
	if m == null:
		m = _create(id)
		m.resource_name = String(key)
	_cache[key] = m
	return m


static func saved_path(id: StringName) -> String:
	return SAVED_DIR + String(id) + ".tres"


static func clear_cache() -> void:
	_cache.clear()
	_tex_cache.clear()


static func _create(id: StringName) -> Material:
	if _TRIM.has(id):
		return _make_trim(id)
	if _FLAT.has(id):
		return _make_flat(id)
	if _GROUND.has(id):
		return _make_ground(id)
	push_warning("KitMaterials: 알 수 없는 재질 ID " + String(id))
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(1.0, 0.0, 1.0)
	fallback.resource_name = String(id)
	return fallback


static func _make_trim(id: StringName) -> Material:
	var spec: Array = _TRIM[id]
	var extra: Dictionary = spec[3]
	var tag: String = "t%d" % int(spec[0])
	var m := ShaderMaterial.new()
	m.resource_name = String(id)
	m.shader = _shader(SHADER_TRIM)
	m.set_shader_parameter("albedo_tex", _tex(tag + "_albedo"))
	m.set_shader_parameter("orm_tex", _tex(tag + "_orm"))
	m.set_shader_parameter("normal_tex", _tex(tag + "_normal"))
	m.set_shader_parameter("mask_tex", _tex(tag + "_mask"))
	m.set_shader_parameter("detail_tex", _tex("detail_v2"))
	m.set_shader_parameter("paint_color", Color.WHITE)
	m.set_shader_parameter("base_tint", extra.get("tint", Color.WHITE))
	m.set_shader_parameter("roughness_scale", float(extra.get("rough", 1.0)))
	m.set_shader_parameter("metallic_scale", float(extra.get("metal", 1.0)))
	m.set_shader_parameter("normal_scale", float(extra.get("normal", 1.0)))
	m.set_shader_parameter("emission_color", extra.get("emit_color", LIGHT_FLUORESCENT))
	m.set_shader_parameter("emission_energy", float(extra.get("emit", 0.0)))
	return m


static func _make_flat(id: StringName) -> Material:
	var spec: Array = _FLAT[id]
	var m := ShaderMaterial.new()
	m.resource_name = String(id)
	m.shader = _shader(SHADER_FLAT)
	m.set_shader_parameter("detail_tex", _tex("detail_v2"))
	m.set_shader_parameter("albedo", Color.WHITE)
	m.set_shader_parameter("roughness", float(spec[1]))
	m.set_shader_parameter("metallic", 0.5 if float(spec[2]) > 0.25 else 0.0)
	return m


static func _make_ground(id: StringName) -> Material:
	var spec: Array = _GROUND[id]
	var stem: String = "ground_" + String(spec[0])
	var m := ShaderMaterial.new()
	m.resource_name = String(id)
	m.shader = _shader(SHADER_GROUND)
	m.set_shader_parameter("albedo_tex", _tex(stem + "_albedo"))
	m.set_shader_parameter("orm_tex", _tex(stem + "_orm"))
	m.set_shader_parameter("normal_tex", _tex(stem + "_normal"))
	m.set_shader_parameter("detail_tex", _tex("detail_v2"))
	m.set_shader_parameter("base_tint", spec[1])
	return m


static func _shader(path: String) -> Shader:
	if _shaders.has(path):
		return _shaders[path]
	var sh: Shader = load(path) as Shader
	if sh == null:
		push_warning("KitMaterials: 셰이더 없음 " + path)
		sh = Shader.new()
	_shaders[path] = sh
	return sh


static func _tex(stem: String) -> Texture2D:
	if _tex_cache.has(stem):
		return _tex_cache[stem]
	var path: String = DIR + stem + ".webp"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		push_warning("KitMaterials: 텍스처 없음 " + stem)
		tex = PlaceholderTexture2D.new()
	_tex_cache[stem] = tex
	return tex
