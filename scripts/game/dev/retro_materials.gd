class_name RetroMaterials
extends StyleMaterialSet
## 스타일 C "레트로 로우폴리": tools/gen_pixel_textures.py가 칠한 32~64 px 픽셀 텍스처를 최근접 필터로 입힌 재질.
## - 월드 텍셀 밀도는 TEXELS_PER_M로 고정이다: 텍스처 한 장의 실제 길이(m) = 픽셀 수 / TEXELS_PER_M. 지오메트리는 MeshBuilder.world_uv로
##   월드 기준 UV를 내므로 큰 벽이든 드럼통이든 픽셀 크기가 같다.
## - 거칠기 1, 금속성 0, 스페큘러 끔, 법선 맵 없음. 색 변주는 정점 색(tint)이 곱해진다 (같은 텍스처로 여러 색).
## - 필터·밀도·방출은 아래 정적 값으로 따로 조절한다 (밉맵은 최근접: 멀리서 반짝임만 줄이고 가까이선 칸이 그대로 보인다).

const DIR: String = "res://assets/textures/retro/"
const TEXELS_PER_M: float = 16.0
## 텍스처 필터. NEAREST로 바꾸면 밉맵 없이 순수 최근접.
static var texture_filter: BaseMaterial3D.TextureFilter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
## 불 켜진 창의 발광 세기.
static var window_glow: float = 1.25

static var _tex_cache: Dictionary[String, Texture2D] = {}

## ID별 (텍스처 이름 또는 "" = 무늬 없음, 정점 색). 정점 색은 sRGB가 아니라 선형 곱셈이라 1 부근의 값으로 색조만 준다.
const _SPEC: Dictionary[StringName, Array] = {
	CONCRETE: ["concrete", Color(1.0, 1.0, 1.0)],
	CONCRETE_DARK: ["concrete", Color(0.7, 0.74, 0.82)],
	GROUND: ["", Color(0.2, 0.22, 0.26)],
	ASPHALT: ["asphalt", Color(1.1, 1.1, 1.14)],
	BRICK: ["brick", Color(1.0, 0.98, 1.0)],
	CONT_RED: ["corrugated_red", Color(1.0, 1.0, 1.0)],
	CONT_TEAL: ["corrugated_slate", Color(0.8, 0.84, 0.82)],
	PAINT_RED: ["door_red", Color(1.0, 1.0, 1.0)],
	PAINT_TEAL: ["door_slate", Color(0.8, 0.84, 0.82)],
	STEEL: ["steel", Color(1.2, 1.2, 1.25)],
	STEEL_DARK: ["steel", Color(0.72, 0.74, 0.8)],
	RUST: ["rust", Color(1.0, 1.0, 1.0)],
	WOOD: ["wood", Color(1.0, 1.0, 1.0)],
	WOOD_DARK: ["wood", Color(0.7, 0.68, 0.66)],
	RUBBER: ["", Color(0.1, 0.11, 0.13)],
	GLASS: ["window", Color(1.0, 1.0, 1.0)],
	GLASS_LIT: ["window_lit", Color(1.0, 1.0, 1.0)],
	LAMP: ["", Color.WHITE],
	SHAFT: ["", Color(0.6, 0.52, 0.38)],
	PUDDLE: ["", Color(0.1, 0.14, 0.19)],
	WEED: ["", Color(0.4, 0.42, 0.24)],
	FORKLIFT: ["paint", Color(0.82, 0.62, 0.24)],
	TRUCK_BODY: ["paint", Color(0.46, 0.5, 0.36)],
	BARREL_BLUE: ["paint", Color(0.42, 0.55, 0.72)],
	BARREL_RED: ["paint", Color(0.72, 0.38, 0.33)],
	BARREL_OCHRE: ["paint", Color(0.78, 0.6, 0.3)],
	PIPE_ORANGE: ["rust", Color(1.0, 0.95, 0.9)],
	PIPE_GREY: ["steel", Color(1.35, 1.35, 1.4)],
	BAND_RED: ["", Color(0.5, 0.23, 0.2)],
	BAND_WHITE: ["lane", Color(1.05, 1.0, 0.92)],
	HAZARD: ["hazard", Color(1.0, 1.0, 1.0)],
	SKY_NEAR: ["", Color(0.2, 0.23, 0.29)],
	SKY_MID: ["", Color(0.27, 0.31, 0.38)],
	SKY_FAR: ["", Color(0.36, 0.41, 0.49)],
	HILL: ["", Color(0.14, 0.17, 0.22)],
	HILL_FAR: ["", Color(0.28, 0.33, 0.41)],
}


func tint(id: StringName) -> Color:
	var spec: Array = _SPEC.get(id, ["", Color.WHITE])
	return spec[1] as Color


func _create(id: StringName) -> Material:
	var spec: Array = _SPEC.get(id, ["", Color.WHITE])
	var tex_name: String = spec[0] as String
	var m := StandardMaterial3D.new()
	m.resource_name = String(id)
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	if tex_name != "":
		var tex: Texture2D = _tex(tex_name)
		m.albedo_texture = tex
		m.texture_filter = texture_filter
		var tile_m: float = float(tex.get_width()) / TEXELS_PER_M
		m.uv1_scale = Vector3(1.0 / tile_m, 1.0 / tile_m, 1.0 / tile_m)
	match id:
		GLASS_LIT:
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission_energy_multiplier = window_glow
		LAMP:
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.2, 0.17, 0.12)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.76, 0.42)
			m.emission_energy_multiplier = 3.0
		SHAFT:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.disable_receive_shadows = true
		PUDDLE, WEED, SKY_NEAR, SKY_MID, SKY_FAR, HILL, HILL_FAR:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## 텍스처 불러오기 (캐시). 없으면 경고 후 자리표시.
static func _tex(stem: String) -> Texture2D:
	if _tex_cache.has(stem):
		return _tex_cache[stem]
	var path: String = DIR + stem + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		push_warning("스타일 C 텍스처 없음: " + stem)
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		img.fill(Color(0.4, 0.4, 0.45))
		tex = ImageTexture.create_from_image(img)
	_tex_cache[stem] = tex
	return tex
