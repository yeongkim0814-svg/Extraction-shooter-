class_name LowpolyMaterials
extends StyleMaterialSet
## 스타일 B "스타일라이즈드 로우폴리": 텍스처 없이 정점 색(팔레트)만 쓴다.
## 팔레트는 컨셉 보드에서 뽑았다: 차가운 청회색, 녹 주황, 청록 회색, 어두운 강철, 따뜻한 창 불빛.
## 재질은 거칠기·금속성이 다른 몇 종류로 합치고, 색은 정점 색으로 구분한다 (재질 수 최소 = 그리기 호출 최소).

# 팔레트 (sRGB)
const WALL: Color = Color("5f7184")
const WALL_DARK: Color = Color("3e4b5b")
const CONCRETE_C: Color = Color("74818e")
const CONCRETE_D: Color = Color("4a5663")
const ASPHALT_C: Color = Color("38424f")
const GROUND_C: Color = Color("3d4650")
const RUST_C: Color = Color("b5562b")
const RUST_DARK: Color = Color("7d3b23")
const RED_C: Color = Color("a63f30")
const TEAL_C: Color = Color("4d7a80")
const STEEL_C: Color = Color("6f8190")
const STEEL_D: Color = Color("2c3441")
const OCHRE: Color = Color("e0a132")
const WOOD_C: Color = Color("a07a4a")
const WOOD_D: Color = Color("7a5a38")
const GLOW: Color = Color("ffc67a")
const PALE: Color = Color("cfe3f2")
const WEED_C: Color = Color("728b3c")
const BLUE_C: Color = Color("3f6c9c")
const RUBBER_C: Color = Color("1c2027")
const HILL_C: Color = Color("27323f")
const HILL_FAR_C: Color = Color("4c6074")

const _TINTS: Dictionary[StringName, Color] = {
	CONCRETE: CONCRETE_C, CONCRETE_DARK: CONCRETE_D, GROUND: GROUND_C, ASPHALT: ASPHALT_C,
	BRICK: WALL, CONT_RED: RED_C, CONT_TEAL: TEAL_C, PAINT_RED: RED_C, PAINT_TEAL: TEAL_C,
	STEEL: STEEL_C, STEEL_DARK: STEEL_D, RUST: RUST_C, WOOD: WOOD_C, WOOD_DARK: WOOD_D,
	RUBBER: RUBBER_C, FORKLIFT: OCHRE, TRUCK_BODY: Color("6c7f7a"), BARREL_BLUE: BLUE_C,
	BARREL_RED: RED_C, BARREL_OCHRE: OCHRE, PIPE_ORANGE: RUST_C, PIPE_GREY: Color("8a9cab"),
	BAND_RED: Color("b3382c"), BAND_WHITE: Color("d6dde3"), HAZARD: OCHRE, WEED: WEED_C,
	SKY_NEAR: Color("3a4756"), SKY_MID: Color("4a5a6c"), SKY_FAR: Color("5f7389"),
	HILL: HILL_C, HILL_FAR: HILL_FAR_C, GLASS: Color("273546"), GLASS_LIT: GLOW,
	LAMP: Color.WHITE, SHAFT: Color(0.8, 0.9, 1.0, 1.0), PUDDLE: Color("1d3447"),
}


func tint(id: StringName) -> Color:
	return _TINTS.get(id, Color.WHITE)


func _create(id: StringName) -> Material:
	# 같은 성질의 재질은 하나를 공유한다
	match id:
		STEEL, STEEL_DARK, PIPE_GREY, PIPE_ORANGE, RUST, CONT_RED, CONT_TEAL, PAINT_RED, PAINT_TEAL, FORKLIFT, \
		TRUCK_BODY, BARREL_BLUE, BARREL_RED, BARREL_OCHRE, BAND_RED, HAZARD:
			return _shared(&"metal_paint", 0.42, 0.35)
		GLASS:
			var g: StandardMaterial3D = _base(&"glass", 0.12, 0.2)
			g.emission_enabled = true
			g.emission = Color(0.3, 0.45, 0.6)
			g.emission_energy_multiplier = 0.35
			return g
		GLASS_LIT:
			var g2: StandardMaterial3D = _base(&"glass_lit", 0.3, 0.0)
			g2.emission_enabled = true
			g2.emission = Color(1.0, 0.78, 0.45)
			g2.emission_energy_multiplier = 2.2
			return g2
		LAMP:
			var l: StandardMaterial3D = _base(&"lamp", 0.5, 0.0)
			l.vertex_color_use_as_albedo = false
			l.albedo_color = Color(0.2, 0.17, 0.12)
			l.emission_enabled = true
			l.emission = Color(1.0, 0.78, 0.45)
			l.emission_energy_multiplier = 4.0
			return l
		SHAFT:
			var s: StandardMaterial3D = _base(&"shaft", 1.0, 0.0)
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.disable_receive_shadows = true
			return s
		PUDDLE:
			var p: StandardMaterial3D = _base(&"puddle", 0.04, 0.0)
			p.metallic_specular = 1.0
			p.cull_mode = BaseMaterial3D.CULL_DISABLED
			return p
		WEED:
			var w: StandardMaterial3D = _base(&"weed", 0.9, 0.0)
			w.cull_mode = BaseMaterial3D.CULL_DISABLED
			return w
		SKY_NEAR, SKY_MID, SKY_FAR, HILL, HILL_FAR:
			var h: StandardMaterial3D = _base(&"far", 1.0, 0.0)
			h.cull_mode = BaseMaterial3D.CULL_DISABLED
			return h
		RUBBER:
			return _shared(&"matte_soft", 0.8, 0.0)
		_:
			return _shared(&"matte", 0.88, 0.0)


func _shared(key: StringName, rough: float, metal: float) -> StandardMaterial3D:
	# _cache는 ID 키라 공유용 별칭 키를 따로 둔다
	var alias: StringName = StringName("alias_" + String(key))
	if _cache.has(alias):
		return _cache[alias] as StandardMaterial3D
	var m: StandardMaterial3D = _base(key, rough, metal)
	_cache[alias] = m
	return m


func _base(key: StringName, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = String(key)
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
	return m
