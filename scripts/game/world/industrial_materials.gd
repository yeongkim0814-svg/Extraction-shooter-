class_name IndustrialMaterials
extends RefCounted
## 산업단지 머티리얼 라이브러리 (M10). 외부 텍스처 없이 코드로 만든다.
## 텍스처는 FastNoiseLite 이미지(동기 생성)로 만들어 한 번만 캐시하고, 재질끼리 공유한다 (모두 512 이하).
## 박스를 재질별로 합친 메시(UV 없음)에도 붙도록 StandardMaterial3D의 삼면(triplanar) 매핑을 쓴다.
## 창문·잡초처럼 UV가 있는 도형만 삼면 매핑을 쓰지 않는다.
## 재질 수를 작게 유지해야 재질별 메시 합치기(그리기 호출 절감)가 먹힌다 → 목록은 ID_* 상수가 전부다.

const CONCRETE: StringName = &"concrete"
const CONCRETE_DARK: StringName = &"concrete_dark"
const GROUND: StringName = &"ground"
const ASPHALT: StringName = &"asphalt"
const RUST: StringName = &"rust"
const STEEL: StringName = &"steel"
const CORRUGATED: StringName = &"corrugated"
const CONT_RED: StringName = &"cont_red"
const CONT_RUST: StringName = &"cont_rust"
const CONT_TEAL: StringName = &"cont_teal"
const CONT_BLUE: StringName = &"cont_blue"
const CONT_OCHRE: StringName = &"cont_ochre"
const BRICK: StringName = &"brick"
const GLASS_LIT: StringName = &"glass_lit"
const GLASS_DARK: StringName = &"glass_dark"
const PUDDLE: StringName = &"puddle"
const WOOD: StringName = &"wood"
const LAMP: StringName = &"lamp"
const SHAFT: StringName = &"shaft"
const WEED: StringName = &"weed"
const BAND_RED: StringName = &"band_red"
const BAND_WHITE: StringName = &"band_white"
const PAINT_WHITE: StringName = &"paint_white"
const SILHOUETTE: StringName = &"silhouette"
const SILHOUETTE_FAR: StringName = &"silhouette_far"

const MATERIAL_IDS: Array[StringName] = [
	CONCRETE, CONCRETE_DARK, GROUND, ASPHALT, RUST, STEEL, CORRUGATED, CONT_RED, CONT_RUST, CONT_TEAL, CONT_BLUE,
	CONT_OCHRE, BRICK, GLASS_LIT, GLASS_DARK, PUDDLE, WOOD, LAMP, SHAFT, WEED, BAND_RED, BAND_WHITE, PAINT_WHITE,
	SILHOUETTE, SILHOUETTE_FAR,
]

## 텍스처 한 장의 한 변 (px). 512를 넘기지 않는다.
const TEX_SIZE: int = 256

static var _materials: Dictionary[StringName, StandardMaterial3D] = {}
static var _textures: Dictionary[StringName, Texture2D] = {}


## 재질 ID로 공유 재질을 얻는다 (처음 부르면 만든다).
static func get_material(id: StringName) -> StandardMaterial3D:
	if not _materials.has(id):
		_materials[id] = _create(id)
	return _materials[id]


## 만들어 둔 재질 수 (테스트·로그용).
static func material_count() -> int:
	return _materials.size()


## 캐시한 텍스처 수 (테스트·로그용).
static func texture_count() -> int:
	return _textures.size()


## 한 텍스처의 가장 긴 변 (px).
static func max_texture_edge() -> int:
	var edge: int = 0
	for tex: Texture2D in _textures.values():
		edge = maxi(edge, maxi(tex.get_width(), tex.get_height()))
	return edge


## 개발 씬(combat_test·ai_test)의 CSG 지오메트리에 같은 콘크리트·아스팔트 재질을 입힌다.
## 씬 파일의 임시 재질 색으로 용도를 구분한다 (바닥·벽·엄폐물·경사로).
static func restyle_csg(root: Node) -> void:
	for node: Node in root.find_children("*", "CSGPrimitive3D", true, false):
		var shape := node as CSGPrimitive3D
		var mat := shape.material as StandardMaterial3D
		if mat == null:
			continue
		var c: Color = mat.albedo_color
		if c.b > 0.38 and c.r < 0.4 and c.g < 0.4:
			shape.material = get_material(ASPHALT)
		elif c.r > 0.48 and c.g > 0.48:
			shape.material = get_material(CONCRETE)
		elif c.r > 0.5:
			shape.material = get_material(WOOD)
		else:
			shape.material = get_material(CONCRETE_DARK)


# --- 재질 정의 ---

static func _create(id: StringName) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = String(id)
	match id:
		CONCRETE:
			_triplanar(m, 0.22)
			m.albedo_color = Color(0.5, 0.51, 0.52)
			m.albedo_texture = _tex(&"grime_blotch")
			m.roughness_texture = _tex(&"rough_streak")
			m.roughness = 0.95
			_normal(m, &"n_fine", 0.6)
		CONCRETE_DARK:
			_triplanar(m, 0.22)
			m.albedo_color = Color(0.28, 0.29, 0.31)
			m.albedo_texture = _tex(&"grime_blotch")
			m.roughness_texture = _tex(&"rough_streak")
			m.roughness = 0.95
			_normal(m, &"n_fine", 0.6)
		GROUND:
			_triplanar(m, 0.2)
			m.albedo_color = Color(0.22, 0.23, 0.24)
			m.albedo_texture = _tex(&"grime_blotch")
			m.roughness = 0.95
			_normal(m, &"n_fine", 0.25)
		ASPHALT:
			_triplanar(m, 0.16)
			m.albedo_color = Color(0.2, 0.21, 0.23)
			m.albedo_texture = _tex(&"asphalt_cracks")
			m.roughness_texture = _tex(&"rough_wet")
			m.roughness = 1.0
			m.metallic_specular = 0.7
			_normal(m, &"n_fine", 0.4)
		RUST:
			_triplanar(m, 0.25)
			m.albedo_color = Color(0.5, 0.26, 0.15)
			m.albedo_texture = _tex(&"grime_streak")
			m.roughness_texture = _tex(&"rough_streak")
			m.roughness = 0.9
			m.metallic = 0.35
			_normal(m, &"n_fine", 0.8)
		STEEL:
			_triplanar(m, 0.25)
			m.albedo_color = Color(0.17, 0.18, 0.2)
			m.albedo_texture = _tex(&"grime_streak")
			m.roughness_texture = _tex(&"rough_streak")
			m.roughness = 0.8
			m.metallic = 0.55
		CORRUGATED:
			_corrugated(m, Color(0.44, 0.46, 0.45))
		CONT_RED:
			_corrugated(m, Color(0.5, 0.14, 0.1))
		CONT_RUST:
			_corrugated(m, Color(0.5, 0.27, 0.14))
		CONT_TEAL:
			_corrugated(m, Color(0.2, 0.36, 0.36))
		CONT_BLUE:
			_corrugated(m, Color(0.17, 0.25, 0.38))
		CONT_OCHRE:
			_corrugated(m, Color(0.62, 0.45, 0.14))
		BRICK:
			_triplanar(m, 0.5)
			m.albedo_color = Color(0.36, 0.3, 0.28)
			m.albedo_texture = _tex(&"brick")
			m.roughness = 0.95
			_normal(m, &"n_brick", 1.0)
		GLASS_LIT:
			m.albedo_color = Color(0.02, 0.03, 0.04)
			m.albedo_texture = _tex(&"pane")
			m.emission_enabled = true
			m.emission = Color(0.82, 0.9, 1.0)
			m.emission_texture = _tex(&"pane")
			m.emission_energy_multiplier = 1.5
			m.uv1_scale = Vector3(1.0, 1.0, 1.0)
		GLASS_DARK:
			m.albedo_color = Color(0.05, 0.07, 0.09)
			m.albedo_texture = _tex(&"pane")
			m.roughness = 0.15
			m.metallic_specular = 0.9
			m.emission_enabled = true
			m.emission = Color(0.55, 0.65, 0.75)
			m.emission_texture = _tex(&"pane")
			m.emission_energy_multiplier = 0.22
		PUDDLE:
			m.albedo_color = Color(0.055, 0.065, 0.075)
			m.roughness = 0.03
			m.metallic_specular = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		WOOD:
			_triplanar(m, 0.9)
			m.albedo_color = Color(0.42, 0.31, 0.19)
			m.albedo_texture = _tex(&"grime_streak")
			m.roughness = 0.95
		LAMP:
			m.albedo_color = Color(0.1, 0.09, 0.07)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.78, 0.45)
			m.emission_energy_multiplier = 4.0
		SHAFT:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.75, 0.85, 1.0, 1.0)
			m.disable_receive_shadows = true
		WEED:
			m.albedo_texture = _tex(&"weed")
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(1, 1, 1, 1)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 1.0
		BAND_RED:
			_triplanar(m, 0.25)
			m.albedo_color = Color(0.5, 0.1, 0.08)
			m.albedo_texture = _tex(&"grime_blotch")
			m.roughness = 0.9
		BAND_WHITE:
			_triplanar(m, 0.25)
			m.albedo_color = Color(0.62, 0.62, 0.6)
			m.albedo_texture = _tex(&"grime_blotch")
			m.roughness = 0.9
		PAINT_WHITE:
			_triplanar(m, 0.5)
			m.albedo_color = Color(0.6, 0.6, 0.57)
			m.albedo_texture = _tex(&"grime_blotch")
			m.roughness = 0.85
		SILHOUETTE:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.13, 0.16, 0.2)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		SILHOUETTE_FAR:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.3, 0.35, 0.4)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _triplanar(m: StandardMaterial3D, scale: float) -> void:
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.uv1_triplanar_sharpness = 2.0


static func _normal(m: StandardMaterial3D, tex_id: StringName, strength: float) -> void:
	m.normal_enabled = true
	m.normal_texture = _tex(tex_id)
	m.normal_scale = strength


## 골판(세로 주름) 재질: 주름 법선 + 얼룩. 텍스처 한 장이 가로 4 m (주름 16개).
static func _corrugated(m: StandardMaterial3D, color: Color) -> void:
	_triplanar(m, 0.25)
	m.albedo_color = color
	m.albedo_texture = _tex(&"grime_blotch")
	m.roughness_texture = _tex(&"rough_streak")
	m.roughness = 0.82
	m.metallic = 0.3
	_normal(m, &"n_corrugated", 0.6)


# --- 텍스처 생성 (동기, 캐시) ---

static func _tex(id: StringName) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var img: Image
	match id:
		&"grime_blotch":
			img = _levels(_noise(11, 0.012, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH), 0.7, 1.0)
		&"grime_streak":
			img = _levels(_streak_noise(23), 0.5, 1.0)
		&"rough_streak":
			img = _levels(_streak_noise(37), 0.55, 1.0)
		&"rough_wet":
			img = _wet_roughness()
		&"asphalt_cracks":
			img = _cracks()
		&"n_fine":
			img = _normal_from(_noise(51, 0.035, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH), 1.6)
		&"n_brick":
			img = _normal_from(_brick_image(), 2.0)
		&"n_corrugated":
			img = _corrugation()
		&"brick":
			img = _brick_image()
		&"pane":
			img = _pane()
		&"weed":
			img = _weed()
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[id] = tex
	return tex


static func _noise(seed_value: int, freq: float, octaves: int, type: FastNoiseLite.NoiseType) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = type
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	var img: Image = n.get_seamless_image(TEX_SIZE, TEX_SIZE, false, false, 0.1, true)
	img.convert(Image.FORMAT_RGB8)
	return img


## 세로로 길게 늘어진 얼룩: 가로 해상도를 낮게 만들어 늘린다.
static func _streak_noise(seed_value: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.03
	n.fractal_octaves = 3
	var img: Image = n.get_seamless_image(32, TEX_SIZE, false, false, 0.1, true)
	img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	return img


## 노이즈 값(대략 0.2~0.8)을 [lo, hi] 밝기 범위로 옮긴다.
static func _levels(img: Image, lo: float, hi: float) -> Image:
	var contrast: float = (hi - lo) / 0.6
	var brightness: float = (lo + hi) * 0.5 / 0.5
	img.adjust_bcs(brightness, contrast, 1.0)
	return img


## 젖은 자리(거칠기 낮음)와 마른 자리가 얼룩덜룩 섞인 거칠기 맵.
static func _wet_roughness() -> Image:
	var img: Image = _noise(61, 0.018, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	img.adjust_bcs(1.15, 1.9, 1.0)
	return img


## 아스팔트 균열: 셀 경계 거리 노이즈에서 경계(값이 낮은 곳)만 어둡게.
static func _cracks() -> Image:
	var n := FastNoiseLite.new()
	n.seed = 71
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.frequency = 0.03
	var img: Image = n.get_seamless_image(TEX_SIZE, TEX_SIZE, false, false, 0.1, true)
	img.convert(Image.FORMAT_RGB8)
	img.adjust_bcs(1.5, 3.0, 1.0)
	return img


## 범프(높이) 이미지를 법선 맵으로 바꾼다.
static func _normal_from(bump: Image, strength: float) -> Image:
	bump.bump_map_to_normal_map(strength)
	return bump


## 세로 골판 법선 맵: 256 x 4 px, 주름 16개. 높이 변화는 가로 방향(x)만.
static func _corrugation() -> Image:
	var w: int = TEX_SIZE
	var img := Image.create(w, 4, false, Image.FORMAT_RGB8)
	var ribs: float = 16.0
	for x: int in range(w):
		var phase: float = float(x) / float(w) * ribs * TAU
		var slope: float = cos(phase) * 0.55
		var n := Vector3(-slope, 0.0, 1.0).normalized()
		var c := Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5)
		for y: int in range(4):
			img.set_pixel(x, y, c)
	return img


## 어두운 벽돌 무늬 (128 x 128, 가로 8장 x 세로 16줄).
static func _brick_image() -> Image:
	var size: int = 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.4, 0.38))   # 줄눈
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var bw: int = 16
	var bh: int = 8
	for row: int in range(size / bh):
		var offset: int = (bw / 2) if row % 2 == 1 else 0
		for col: int in range(-1, size / bw + 1):
			var shade: float = rng.randf_range(0.62, 1.0)
			var tint: float = rng.randf_range(-0.04, 0.04)
			var c := Color(shade + tint, shade, shade - tint)
			var x0: int = col * bw + offset
			var rect := Rect2i(x0 + 1, row * bh + 1, bw - 2, bh - 2)
			var clipped: Rect2i = rect.intersection(Rect2i(0, 0, size, size))
			if clipped.has_area():
				img.fill_rect(clipped, c)
	# 가로로 벽돌이 가장자리를 넘는 부분은 반대쪽에 이어 그려 타일이 이어지게 한다
	for row: int in range(size / bh):
		if row % 2 == 1:
			var shade: float = rng.randf_range(0.62, 1.0)
			img.fill_rect(Rect2i(0, row * bh + 1, bw / 2 - 1, bh - 2), Color(shade, shade, shade))
	return img


## 창 한 칸 (64 x 32): 어두운 틀 + 밝은 유리 + 세로 중간 문설주.
static func _pane() -> Image:
	var img := Image.create(64, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(0.03, 0.03, 0.035))
	var glass := Color(1.0, 1.0, 1.0)
	img.fill_rect(Rect2i(3, 3, 26, 26), glass)
	img.fill_rect(Rect2i(35, 3, 26, 26), glass)
	# 위쪽 칸은 약간 덜 밝게 (유리마다 밝기 차이)
	img.fill_rect(Rect2i(3, 3, 26, 5), Color(0.78, 0.8, 0.85))
	img.fill_rect(Rect2i(35, 3, 26, 5), Color(0.9, 0.92, 0.95))
	return img


## 잡초 한 덤불 (64 x 64 RGBA): 휜 잎 여러 장.
static func _weed() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.65, 0.3, 0.0))   # 투명 부분에도 잎 색을 깔아 밉맵에서 검게 번지지 않게 한다
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in range(11):
		var x: float = 32.0 + rng.randf_range(-10.0, 10.0)
		var lean: float = rng.randf_range(-0.55, 0.55)
		var height: float = rng.randf_range(34.0, 62.0)
		var shade: float = rng.randf_range(0.55, 1.0)
		var color := Color(0.5 * shade, 0.65 * shade, 0.3 * shade, 1.0)
		var steps: int = int(height)
		for s: int in range(steps):
			var t: float = float(s) / float(steps)
			var px: int = int(x + lean * t * 24.0 + lean * lean * t * t * 14.0)
			var py: int = 63 - s
			var half_width: int = maxi(0, int(round((1.0 - t) * 2.0)))
			for dx: int in range(-half_width, half_width + 1):
				var qx: int = px + dx
				if qx >= 0 and qx < 64 and py >= 0:
					img.set_pixel(qx, py, color)
	return img
