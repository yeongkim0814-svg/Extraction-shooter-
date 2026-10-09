class_name SemirealMaterials
extends StyleMaterialSet
## 스타일 A "반실사": tools/gen_textures.py가 만든 1024px PBR 타일(알베도·법선·거칠기)을 쓰는 재질.
## 텍스처 한 장의 실제 크기(m)를 TILE로 정해 uv1_scale에 반영한다 (MeshBuilder UV는 미터 단위).

const DIR: String = "res://assets/textures/semireal/"

static var _tex_cache: Dictionary[String, Texture2D] = {}


func _create(id: StringName) -> Material:
	var m := StandardMaterial3D.new()
	m.resource_name = String(id)
	match id:
		CONCRETE:
			_pbr(m, "concrete", "albedo", 2.4, 1.0)
		CONCRETE_DARK:
			_pbr(m, "concrete", "albedo", 2.4, 1.0)
			m.albedo_color = Color(0.62, 0.64, 0.68)
		GROUND:
			_pbr(m, "asphalt", "albedo", 4.0, 0.9)
			m.albedo_color = Color(1.25, 1.2, 1.1)
		ASPHALT:
			_pbr(m, "asphalt", "albedo", 3.0, 1.0)
			m.albedo_color = Color(1.4, 1.4, 1.45)
		BRICK:
			_pbr(m, "brick", "albedo", 2.0, 1.0)
			m.albedo_color = Color(0.82, 0.8, 0.82)
		CONT_RED:
			_pbr(m, "corrugated", "albedo_red", 2.0, 1.1)
			m.metallic = 0.25
		CONT_TEAL:
			_pbr(m, "corrugated", "albedo_teal", 2.0, 1.1)
			m.metallic = 0.25
		PAINT_RED, TRUCK_BODY:
			_pbr(m, "paint", "albedo_red", 2.0, 1.0)
			m.metallic = 0.2
			if id == TRUCK_BODY:
				m.albedo_texture = _tex("paint_albedo_teal")
				m.albedo_color = Color(0.85, 1.0, 0.7)
		PAINT_TEAL:
			_pbr(m, "paint", "albedo_teal", 2.0, 1.0)
			m.metallic = 0.2
		STEEL:
			_pbr(m, "steel", "albedo", 2.0, 1.0)
			m.albedo_color = Color(1.6, 1.6, 1.7)
			m.metallic = 0.55
		STEEL_DARK:
			_pbr(m, "steel", "albedo", 2.0, 1.0)
			m.metallic = 0.5
		RUST:
			_pbr(m, "steel", "albedo", 1.0, 1.0)
			m.albedo_color = Color(2.2, 1.7, 1.4)
			m.metallic = 0.3
		WOOD:
			_pbr(m, "wood", "albedo", 0.8, 1.0)
		WOOD_DARK:
			_pbr(m, "wood", "albedo", 0.8, 1.0)
			m.albedo_color = Color(0.62, 0.58, 0.55)
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
			m.emission = Color(1.0, 0.78, 0.45)
			m.emission_energy_multiplier = 4.0
		SHAFT:
			_shaft(m)
		PUDDLE:
			m.albedo_color = Color(0.045, 0.055, 0.065)
			m.roughness = 0.03
			m.metallic_specular = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		WEED:
			m.albedo_texture = _tex("weed")
			m.vertex_color_use_as_albedo = true
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.uv1_offset = Vector3(0.5, 1.0, 0.0)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 1.0
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		FORKLIFT:
			_pbr(m, "concrete", "albedo", 1.5, 0.8)
			m.albedo_color = Color(2.3, 1.5, 0.3)
			m.metallic = 0.2
		BARREL_BLUE:
			_pbr(m, "paint", "albedo_teal", 1.0, 1.0)
			m.albedo_color = Color(0.5, 0.8, 1.6)
			m.metallic = 0.3
		BARREL_RED:
			_pbr(m, "paint", "albedo_red", 1.0, 1.0)
			m.metallic = 0.3
		BARREL_OCHRE:
			_pbr(m, "paint", "albedo_red", 1.0, 1.0)
			m.albedo_color = Color(1.4, 1.5, 0.5)
			m.metallic = 0.3
		PIPE_ORANGE:
			_pbr(m, "steel", "albedo", 2.0, 1.0)
			m.albedo_color = Color(2.4, 1.5, 0.9)
			m.metallic = 0.4
		PIPE_GREY:
			_pbr(m, "steel", "albedo", 2.0, 1.0)
			m.albedo_color = Color(2.0, 2.1, 2.2)
			m.metallic = 0.5
		BAND_RED:
			_pbr(m, "paint", "albedo_red", 2.0, 1.0)
		BAND_WHITE:
			_pbr(m, "concrete", "albedo", 2.4, 1.0)
			m.albedo_color = Color(1.5, 1.5, 1.45)
		HAZARD:
			_pbr(m, "paint", "albedo_red", 2.0, 1.0)
			m.albedo_color = Color(1.5, 1.2, 0.3)
		SKY_NEAR, SKY_MID, SKY_FAR:
			# 먼 실루엣도 라이팅·안개를 받는다. 색만 단계별로 어둡고 푸르게.
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


## 알베도·법선·거칠기 세 장을 연결한다. tile_m = 텍스처 한 장의 실제 길이(m), normal = 법선 세기.
func _pbr(m: StandardMaterial3D, set_name: String, albedo: String, tile_m: float, normal: float) -> void:
	m.albedo_texture = _tex("%s_%s" % [set_name, albedo])
	m.roughness_texture = _tex("%s_rough" % set_name)
	m.roughness = 1.0
	m.normal_enabled = true
	m.normal_texture = _tex("%s_normal" % set_name)
	m.normal_scale = normal
	m.uv1_scale = Vector3(1.0 / tile_m, 1.0 / tile_m, 1.0 / tile_m)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func _shaft(m: StandardMaterial3D) -> void:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.75, 0.85, 1.0, 1.0)
	m.disable_receive_shadows = true


## 텍스처 파일을 불러 캐시한다 (webp·jpg·png 중 있는 것).
static func _tex(stem: String) -> Texture2D:
	if _tex_cache.has(stem):
		return _tex_cache[stem]
	var tex: Texture2D = null
	for ext: String in ["webp", "jpg", "png"]:
		var path: String = DIR + stem + "." + ext
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
			break
	if tex == null:
		push_warning("스타일 A 텍스처 없음: " + stem)
		tex = PlaceholderTexture2D.new()
	_tex_cache[stem] = tex
	return tex
