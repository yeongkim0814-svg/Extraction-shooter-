class_name TrimMaterials
extends StyleMaterialSet
## 스타일 D "트림시트 스타일라이즈드 PBR": 모든 소품이 트림시트 두 장(tools/gen_trim_sheets.py)을 나눠 쓰고, 소품마다 페인트 색만 다르다.
## 기법 출처: Godot 4 데모 "Abandoned Spaceship" (Perfoon, MIT)의 트림시트 + 페인트 마스크 재칠 방식. 셰이더는 assets/shaders/trim_recolor.gdshader.
## 재질 ID마다 (시트, 옆면 줄, 윗면 줄, 아랫면 줄, 페인트 색, 추가 설정)이 정해져 있고, apply가 MeshBuilder에 줄 배정을 넘긴다
## (UV는 MeshBuilder + TrimUv가 줄 범위로 낸다). 줄은 StyleKit.use_strips로 덮어쓸 수 있다.
## 트림이 아닌 재질(유리·램프·빛줄기·웅덩이·고무·하늘)은 단순한 StandardMaterial3D다.

const DIR: String = "res://assets/textures/trim/"
const SHADER_PATH: String = "res://assets/shaders/trim_recolor.gdshader"
## 정점 베이크 값(COLOR)을 셰이더가 읽을지. 라이트맵을 쓰는 씬에서는 false로 두고 재질을 만든다.
static var vertex_bake_enabled: bool = true
## 바운스 램프색·세기, 인테리어 어둡기 같은 장면 조절값 (재질 생성 시 읽는다).
static var ao_strength: float = 1.0
static var albedo_ao_mix: float = 0.35
static var interior_floor: float = 0.62
static var bounce_energy: float = 0.8
static var detail_strength: float = 0.8

## 페인트 팔레트 (콘셉트 보드: 녹슨 빨강, 청회색, 올리브, 따뜻한 노랑, 바랜 흰색). 옅은 바탕(~0.8)에 곱해진다.
const PAINT_RUST_RED: Color = Color(0.70, 0.27, 0.17)
const PAINT_TEAL_GREY: Color = Color(0.36, 0.52, 0.54)
const PAINT_OLIVE: Color = Color(0.46, 0.50, 0.27)
const PAINT_WARM_YELLOW: Color = Color(1.0, 0.70, 0.18)
const PAINT_FADED_WHITE: Color = Color(0.92, 0.9, 0.82)
const PAINT_STEEL: Color = Color(0.42, 0.45, 0.49)
const PAINT_DARK: Color = Color(0.2, 0.22, 0.25)
const PAINT_BLUE: Color = Color(0.28, 0.4, 0.52)
const PAINT_OCHRE: Color = Color(0.74, 0.52, 0.2)
const PAINT_ORANGE: Color = Color(0.85, 0.42, 0.14)

static var _tex_cache: Dictionary[String, Texture2D] = {}
static var _shader: Shader

## ID별 사양: [시트, 옆면 줄, 윗면 줄, 아랫면 줄, 페인트 색, 추가 설정 Dictionary]. 추가 설정 키:
##   tint(Color) 전체 곱, rough(float) 거칠기 배율, metal(float) 금속 배율, axial(bool) 회전체 축 방향 사상,
##   ground(bool) 월드 평면 사상 (큰 바닥), detail(float) 디테일 세기, normal(float) 법선 세기.
const _SPEC: Dictionary[StringName, Array] = {
	CONCRETE: [1, &"wall", &"wall", &"wall", Color.WHITE, {"tint": Color(0.94, 0.93, 0.9)}],
	CONCRETE_DARK: [1, &"wall", &"wall", &"wall", Color.WHITE, {"ground": true, "tint": Color(0.72, 0.73, 0.76), "rough": 1.1}],
	BRICK: [1, &"brick", &"wall", &"wall", Color.WHITE, {"tint": Color(0.92, 0.9, 0.9)}],
	PAVING: [1, &"wall", &"wall", &"wall", Color.WHITE, {"ground": true, "tint": Color(0.6, 0.61, 0.63)}],
	ASPHALT: [1, &"wall", &"wall", &"wall", Color.WHITE, {"ground": true, "tint": Color(0.46, 0.48, 0.52), "rough": 1.1, "detail": 0.5}],
	GROUND: [1, &"wall", &"wall", &"wall", Color.WHITE, {"ground": true, "tint": Color(0.16, 0.17, 0.2), "rough": 1.2}],
	CONT_RED: [2, &"corrugated", &"plate", &"plate", PAINT_RUST_RED, {}],
	CONT_TEAL: [2, &"corrugated", &"plate", &"plate", PAINT_TEAL_GREY, {}],
	PAINT_RED: [2, &"plate", &"plate", &"plate", PAINT_RUST_RED, {}],
	PAINT_TEAL: [2, &"plate", &"plate", &"plate", PAINT_TEAL_GREY, {}],
	TRUCK_BODY: [2, &"chipped", &"chipped", &"plate", PAINT_OLIVE, {}],
	STEEL: [2, &"plate", &"plate", &"plate", PAINT_STEEL, {}],
	STEEL_DARK: [2, &"plate", &"plate", &"plate", PAINT_DARK, {}],
	RUST: [2, &"rust", &"rust", &"rust", Color.WHITE, {}],
	FORKLIFT: [2, &"plate", &"plate", &"chipped", PAINT_WARM_YELLOW, {}],
	BARREL_BLUE: [2, &"chipped", &"plate", &"plate", PAINT_BLUE, {}],
	BARREL_RED: [2, &"chipped", &"plate", &"plate", PAINT_RUST_RED, {}],
	BARREL_OCHRE: [2, &"chipped", &"plate", &"plate", PAINT_OCHRE, {}],
	PIPE_ORANGE: [2, &"pipe", &"pipe", &"pipe", PAINT_ORANGE, {"axial": true}],
	PIPE_GREY: [2, &"pipe", &"pipe", &"pipe", PAINT_TEAL_GREY, {"axial": true}],
	BAND_RED: [1, &"band", &"band", &"band", PAINT_RUST_RED, {}],
	BAND_WHITE: [1, &"band", &"band", &"band", PAINT_FADED_WHITE, {}],
	HAZARD: [1, &"hazard", &"hazard", &"hazard", Color.WHITE, {}],
	CRATE: [2, &"plate", &"plate", &"plate", PAINT_OLIVE, {}],
	CRATE_DARK: [2, &"chipped", &"chipped", &"chipped", PAINT_DARK, {}],
	PALLET: [2, &"rust", &"rust", &"rust", Color.WHITE, {"tint": Color(1.1, 0.95, 0.75), "metal": 0.0}],
	PALLET_DARK: [2, &"rust", &"rust", &"rust", Color.WHITE, {"tint": Color(0.7, 0.6, 0.5), "metal": 0.0}],
	WINDOW_STRIP: [1, &"window", &"wall", &"wall", PAINT_DARK, {"emit": 1.0}],
	WINDOW_DARK: [1, &"window", &"wall", &"wall", PAINT_DARK, {}],
	VENT_STRIP: [1, &"vent", &"wall", &"wall", PAINT_STEEL, {}],
}


func _create(id: StringName) -> Material:
	if _SPEC.has(id):
		return _make_trim(id)
	var m := StandardMaterial3D.new()
	m.resource_name = String(id)
	match id:
		RUBBER:
			m.albedo_color = Color(0.05, 0.05, 0.055)
			m.roughness = 0.9
		GLASS:
			m.albedo_color = Color(0.05, 0.07, 0.09)
			m.roughness = 0.08
			m.metallic_specular = 1.0
			m.emission_enabled = true
			m.emission = Color(0.4, 0.5, 0.6)
			m.emission_energy_multiplier = 0.25
		GLASS_LIT:
			m.albedo_color = Color(0.1, 0.12, 0.14)
			m.roughness = 0.1
			m.emission_enabled = true
			m.emission = Color(0.82, 0.9, 1.0)
			m.emission_energy_multiplier = 1.6
		LAMP:
			m.albedo_color = Color(0.1, 0.09, 0.07)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.26)
			m.emission_energy_multiplier = 5.0
		SHAFT, SHAFT_WARM:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.75, 0.85, 1.0, 1.0) if id == SHAFT else Color(1.0, 0.78, 0.5, 1.0)
			m.disable_receive_shadows = true
		PUDDLE:
			m.albedo_color = Color(0.045, 0.055, 0.065)
			m.roughness = 0.03
			m.metallic_specular = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		WEED, FERN, IVY:
			m.albedo_texture = _tex("foliage")
			m.vertex_color_use_as_albedo = true
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.9
			m.albedo_color = Color(0.62, 0.7, 0.55)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if id == IVY:
				m.uv1_scale = Vector3(0.5, 1.0, 1.0)
				m.uv1_offset = Vector3(0.25, 1.0, 0.0)
			else:
				# 고사리: 아틀라스 오른쪽 절반. 빌더 UV는 (x, -y)이고 판은 x -0.5..0.5, y 0..1이다
				m.uv1_scale = Vector3(0.5, 1.0, 1.0)
				m.uv1_offset = Vector3(0.75, 1.0, 0.0)
		SKY_NEAR, SKY_MID, SKY_FAR:
			var shade: float = 0.5 if id == SKY_NEAR else (0.4 if id == SKY_MID else 0.32)
			m.albedo_color = Color(shade * 0.8, shade * 0.88, shade)
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		HILL:
			m.albedo_color = Color(0.09, 0.115, 0.12)
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		HILL_FAR:
			m.albedo_color = Color(0.13, 0.16, 0.19)
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _make_trim(id: StringName) -> Material:
	var spec: Array = _SPEC[id]
	var sheet: int = spec[0]
	var extra: Dictionary = spec[5]
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	var m := ShaderMaterial.new()
	m.resource_name = String(id)
	m.shader = _shader
	var tag: String = "trim%d" % sheet
	m.set_shader_parameter("albedo_tex", _tex(tag + "_albedo"))
	m.set_shader_parameter("orm_tex", _tex(tag + "_orm"))
	m.set_shader_parameter("normal_tex", _tex(tag + "_normal"))
	m.set_shader_parameter("mask_tex", _tex(tag + "_mask"))
	m.set_shader_parameter("detail_tex", _tex("trim_detail"))
	m.set_shader_parameter("paint_color", spec[4])
	m.set_shader_parameter("base_tint", extra.get("tint", Color.WHITE))
	m.set_shader_parameter("roughness_scale", float(extra.get("rough", 1.0)))
	m.set_shader_parameter("metallic_scale", float(extra.get("metal", 1.0)))
	m.set_shader_parameter("normal_scale", float(extra.get("normal", 1.0)))
	m.set_shader_parameter("detail_strength", float(extra.get("detail", detail_strength)))
	m.set_shader_parameter("emission_energy", float(extra.get("emit", 0.0)) * 0.9)
	m.set_shader_parameter("vertex_bake", 1.0 if vertex_bake_enabled else 0.0)
	m.set_shader_parameter("vertex_ao_strength", ao_strength)
	m.set_shader_parameter("albedo_ao_mix", albedo_ao_mix)
	m.set_shader_parameter("interior_floor", interior_floor)
	m.set_shader_parameter("bounce_energy", bounce_energy)
	if bool(extra.get("ground", false)):
		var v: Vector2 = TrimLayout.v_range(sheet, spec[1])
		m.set_shader_parameter("ground_mode", true)
		m.set_shader_parameter("ground_v", v)
	return m


## 빌더의 표면·줄 배정을 이 ID에 맞춘다. 트림이 아닌 ID면 트림 사상을 끈다.
func apply(builder: MeshBuilder, id: StringName) -> void:
	super.apply(builder, id)
	if not _SPEC.has(id):
		builder.trim_strips = PackedVector2Array()
		return
	var spec: Array = _SPEC[id]
	var sheet: int = spec[0]
	builder.trim_strips = TrimUv.side_top_bottom(TrimLayout.v_range(sheet, spec[1]), TrimLayout.v_range(sheet, spec[2]),
			TrimLayout.v_range(sheet, spec[3]))
	builder.trim_axial = bool((spec[5] as Dictionary).get("axial", false))


## 이 재질의 기본 옆면 줄 이름.
func default_side(id: StringName) -> StringName:
	return (_SPEC[id] as Array)[1] if _SPEC.has(id) else &""


## 큰 바닥(월드 평면 사상)인가.
func is_ground(id: StringName) -> bool:
	return _SPEC.has(id) and bool((_SPEC[id][5] as Dictionary).get("ground", false))


## 이 재질에서 줄 하나의 자연 높이 (m).
func strip_height_m(id: StringName, strip_name: StringName) -> float:
	return TrimLayout.strip_height_m(sheet_of(id), strip_name)


## 시트 번호 (트림 재질이 아니면 0).
func sheet_of(id: StringName) -> int:
	if _SPEC.has(id):
		return (_SPEC[id] as Array)[0]
	return 0


## 줄 이름 -> V 범위 (재질 ID의 시트 기준).
func strip_range(id: StringName, strip_name: StringName) -> Vector2:
	return TrimLayout.v_range(sheet_of(id), strip_name)


static func _tex(stem: String) -> Texture2D:
	if _tex_cache.has(stem):
		return _tex_cache[stem]
	var path: String = DIR + stem + ".webp"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		push_warning("스타일 D 텍스처 없음: " + stem)
		tex = PlaceholderTexture2D.new()
	_tex_cache[stem] = tex
	return tex
