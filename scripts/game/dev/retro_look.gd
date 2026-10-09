class_name RetroLook
extends RefCounted
## 스타일 C "레트로 로우폴리"의 룩 구성 도구. 환경(하늘·안개·앰비언트), 태양, 후처리를 서로 독립으로 만들고 조절한다.
##   환경: assets/env/retro_env.tres (복제해서 쓴다) + set_fog
##   태양: make_sun (방향·색·세기·그림자 부드러움)
##   후처리: RetroPost (retro_post.gdshader)
##   재질/필터: RetroMaterials
## 모두 Mobile·Compatibility 둘 다 되는 기능만 쓴다 (볼류메트릭 안개·SSAO·글로우 없음).

const ENV_PATH: String = "res://assets/env/retro_env.tres"
## 태양 쪽 방향 (장면 -> 해). 낮게 깔린 해가 카메라 앞 왼쪽에서 비스듬히 비춘다 (긴 그림자가 오른쪽·카메라 쪽으로 눕는다).
const SUN_DIRECTION: Vector3 = Vector3(-0.65, 0.26, -0.72)
const SUN_COLOR: Color = Color(1.0, 0.72, 0.42)
const SUN_ENERGY: float = 4.2
## 카메라 쪽에서 비스듬히 오는 차가운 보조광(하늘·바닥 반사 대신): 역광이어도 정면이 읽히게 한다. 그림자 없음.
const FILL_DIRECTION: Vector3 = Vector3(0.35, 0.55, 0.75)
const FILL_COLOR: Color = Color(0.62, 0.72, 0.9)
const FILL_ENERGY: float = 0.55


## 환경 복제본.
static func make_environment() -> Environment:
	return (load(ENV_PATH) as Environment).duplicate() as Environment


## 안개: 밀도·색(청회색)·해 쪽 따뜻한 산란·하늘에 미치는 정도·높이 안개를 따로 정한다.
static func set_fog(env: Environment, density: float, color: Color, sun_scatter: float, sky_affect: float = 0.55,
		height_density: float = 0.0) -> void:
	env.fog_enabled = true
	env.fog_density = density
	env.fog_light_color = color
	env.fog_sun_scatter = sun_scatter
	env.fog_sky_affect = sky_affect
	env.fog_height_density = height_density


## 낮은 따뜻한 태양. to_sun은 장면에서 해로 향하는 방향.
static func make_sun(to_sun: Vector3 = SUN_DIRECTION, color: Color = SUN_COLOR, energy: float = SUN_ENERGY) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.add_to_group(&"sun")
	sun.position = Vector3(0.0, 12.0, 0.0)
	sun.basis = Basis.looking_at(-to_sun.normalized(), Vector3.UP)
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = true
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.6
	sun.light_angular_distance = 1.4
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.3
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 70.0
	return sun


## 차가운 보조 방향광 (그림자 없음).
static func make_fill(to_light: Vector3 = FILL_DIRECTION, color: Color = FILL_COLOR, energy: float = FILL_ENERGY) -> DirectionalLight3D:
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.basis = Basis.looking_at(-to_light.normalized(), Vector3.UP)
	fill.light_color = color
	fill.light_energy = energy
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	return fill
