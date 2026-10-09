class_name StyleCompare
extends Node3D
## 그래픽 스타일 비교 비네트 (약 24 x 24 m): 같은 배치를 두 가지 아트 스타일로 만든다.
##   A "반실사"      : tools/gen_textures.py의 PBR 텍스처 + 모따기 지오메트리 + 데칼
##   B "스타일라이즈드": 텍스처 없는 팔레트 + 로우폴리 모따기 + 조금 더 짙은 안개·또렷한 빛
##   C "레트로 로우폴리": tools/gen_pixel_textures.py의 32~64 px 픽셀 텍스처(최근접) + 로우폴리 지오메트리 + 해질녘 하늘·안개·낮은 태양
##                      + 전체 화면 후처리(retro_post.gdshader). 룩 구성은 RetroLook, 재질은 RetroMaterials.
##                D "트림시트 스타일라이즈드 PBR": tools/gen_trim_sheets.py의 트림시트 두 장 + 재칠 셰이더(trim_recolor) + 굵고 둥근 모따기
##                      + 정점 베이크 AO(StyleBake, 라이트맵 대용) + 따뜻한 램프·차가운 낮빛 + 담쟁이·고사리 알파 카드 + 먼지 입자.
##                      기법은 Godot 4 데모 "Abandoned Spaceship"(Perfoon, MIT)을 따른다. 재질은 TrimMaterials, 소품 배치는 A·B·C와 공유하되 D 분기가 있다.
## A·B의 하늘·환경·안개·태양은 산업단지 맵(M10) 것을 그대로 쓴다. 스타일은 URL ?scene=style_a|style_b|style_c|style_d
## (또는 실행 인자 --scene=style_b)로 고르고, 없으면 내보낸 값(style)을 쓴다.
## 고정 카메라 3컷: 1 개요(공장·더미 뒤), 2 컨테이너·웅덩이·트럭 클로즈업, 3 문 안쪽 어두운 내부.
## N 키(또는 터치/클릭)로 다음 컷, 1·2·3 키로 직접 이동, 스타일 C에선 P 키로 후처리 켜기/끄기. 로그 접두사 "STYLE: " (ready / shot / render).

enum Style { A, B, C, D }

const PREFIX: String = "STYLE: "
const ENV_PATH: String = "res://assets/env/industrial_env.tres"
## 컷 목록: 이름, 카메라 위치, 바라볼 점, 시야각(도).
const SHOTS: Array[Dictionary] = [
	{"name": "overview", "pos": Vector3(2.6, 1.7, 11.4), "target": Vector3(-0.6, 3.9, -12.0), "fov": 72.0},
	{"name": "closeup", "pos": Vector3(-1.0, 1.05, 7.0), "target": Vector3(2.0, 1.1, -1.5), "fov": 80.0},
	{"name": "interior", "pos": Vector3(0.3, 1.65, -3.2), "target": Vector3(-2.0, 2.4, -19.0), "fov": 66.0},
]

@export var style: Style = Style.A

## 개발 메뉴 버튼이 고른 스타일 (-1이면 URL·실행 인자·내보낸 값을 따른다).
static var forced_style: int = -1
## 라이트맵 굽기용 씬을 만드는 모드 (tools/build_style_d_bake_scene.gd): 정점 베이크를 끄고 입자·카메라를 만들지 않는다.
static var bake_scene_mode: bool = false
## 정점 베이크 값을 바꾼 조절 손잡이 (튜닝용 로그에 찍힌다).
const BAKE_RAYS: int = 6

var _kit: StyleKit
var _camera: Camera3D
var _sun: DirectionalLight3D
var _shot: int = 0
var _decals_ok: bool = false
var _post: RetroPost
## 스타일 D 램프 위치 (정점 따뜻함·빛 번짐용): [{pos, radius}].
var _lamps: Array[Dictionary] = []


func _ready() -> void:
	style = requested_style(style)
	if style == Style.D:
		TrimMaterials.vertex_bake_enabled = not bake_scene_mode
		_lamps = StyleFactory.D_LAMPS.duplicate()
		_lamps.append_array(StyleFactory.D_GLOW_ONLY)
	_kit = StyleKit.new(style as int)
	_build_environment()
	_build_ground()
	_build_yard()
	_build_factory()
	StyleSkyline.build(_kit)
	if style == Style.D and not bake_scene_mode and not StyleBake.lightmap_present(self):
		await StyleBake.run(self, _kit, _lamps, BAKE_RAYS)
	_kit.commit(self)
	_build_lights()
	_build_smoke()
	_build_decals()
	if style == Style.D:
		_build_extras_d()
	_build_camera()
	if style == Style.C:
		_post = RetroPost.new()
		add_child(_post)
	print(PREFIX + "ready " + style_letter())
	print(PREFIX + "geometry triangles=%d groups=%d" % [_kit.triangle_total(), _kit.groups.size()])
	if OS.get_cmdline_user_args().has("--verbose-groups"):
		for gname: StringName in _kit.groups:
			print(PREFIX + "group %s tris=%d" % [gname, (_kit.groups[gname] as MeshBuilder).triangle_count])
	if bake_scene_mode:
		return
	for _i: int in range(3):
		await get_tree().process_frame
	_go_shot(0)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_N, KEY_SPACE, KEY_TAB:
				_go_shot((_shot + 1) % SHOTS.size())
			KEY_1:
				_go_shot(0)
			KEY_2:
				_go_shot(1)
			KEY_3:
				_go_shot(2)
			KEY_P:
				if _post != null:
					_post.enabled = not _post.enabled
					print(PREFIX + "post " + ("on" if _post.enabled else "off"))
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		_go_shot((_shot + 1) % SHOTS.size())


func style_letter() -> String:
	match style:
		Style.A:
			return "a"
		Style.B:
			return "b"
		Style.D:
			return "d"
	return "c"


## URL ?scene=style_a|style_b 또는 --scene=style_b가 있으면 그것, 없으면 기본값.
static func requested_style(default_style: Style) -> Style:
	if forced_style >= 0:
		return forced_style as Style
	var requested: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			requested = arg.substr("--scene=".length())
	if requested == "" and OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search")
		if query is String:
			for pair: String in (query as String).trim_prefix("?").split("&"):
				if pair.begins_with("scene="):
					requested = pair.substr("scene=".length())
	match requested:
		"style_a":
			return Style.A
		"style_b":
			return Style.B
		"style_c":
			return Style.C
		"style_d":
			return Style.D
	return default_style


# --- 환경·빛·카메라 ---

func _build_environment() -> void:
	if style == Style.C:
		_build_environment_retro()
		return
	if style == Style.D:
		_build_environment_trim()
		return
	var env: Environment = (load(ENV_PATH) as Environment).duplicate() as Environment
	if style == Style.B:
		# 조금 더 짙은 안개와 높이 그라데이션
		env.fog_density *= 1.35
		env.fog_height_density *= 1.8
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.add_to_group(&"sun")
	# 산업단지 맵과 같은 고도·색, 방향만 바꿔 카메라 왼쪽 뒤에서 비춘다 (맵의 역광은 이 작은 장면에서 모든 면이 그늘이 된다)
	_sun.position = Vector3(0.0, 12.0, 0.0)
	_sun.basis = Basis.looking_at(Vector3(0.62, -0.5, -0.6).normalized(), Vector3.UP)
	_sun.light_color = Color(1.0, 0.84, 0.68)
	_sun.light_energy = 1.5
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.4
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_split_1 = 0.28
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = 45.0
	if style == Style.B:
		# 또렷한 빛: 그림자 가장자리를 좁히고 태양을 조금 세게
		_sun.light_angular_distance = 0.25
		_sun.shadow_blur = 0.6
		_sun.shadow_bias = 0.09
		_sun.shadow_normal_bias = 2.2
		_sun.light_energy = 1.65
	else:
		_sun.light_angular_distance = 1.2
		_sun.shadow_blur = 1.6
	add_child(_sun)


## 스타일 D: M10 흐린 산업단지 환경 + 은은한 글로우 + 차가운 낮빛 태양. 실내는 따뜻한 램프가 대비를 만든다.
func _build_environment_trim() -> void:
	var env: Environment = (load(ENV_PATH) as Environment).duplicate() as Environment
	env.glow_intensity = 0.28
	env.glow_strength = 0.8
	env.glow_hdr_threshold = 1.15
	env.ambient_light_energy = 0.8
	env.fog_light_color = Color(0.42, 0.5, 0.56)
	env.adjustment_saturation = 0.9
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.add_to_group(&"sun")
	_sun.position = Vector3(0.0, 12.0, 0.0)
	_sun.basis = Basis.looking_at(Vector3(0.62, -0.5, -0.6).normalized(), Vector3.UP)
	_sun.light_color = Color(0.86, 0.92, 1.0)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.4
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_split_1 = 0.28
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = 45.0
	_sun.light_angular_distance = 1.2
	_sun.shadow_blur = 1.6
	# 라이트맵 굽기 씬에서는 직접광은 실시간, 간접광만 굽는다
	_sun.light_bake_mode = Light3D.BAKE_DYNAMIC
	add_child(_sun)


## 스타일 C: 해질녘 하늘 + 청회색 안개 + 차가운 앰비언트 + 낮은 따뜻한 태양.
func _build_environment_retro() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = RetroLook.make_environment()
	add_child(we)
	_sun = RetroLook.make_sun()
	add_child(_sun)
	add_child(RetroLook.make_fill())


func _build_lights() -> void:
	if style == Style.D:
		_build_lights_trim()
		return
	# 매단 램프 (공장 안)
	var lamp := OmniLight3D.new()
	lamp.name = "HangingLamp"
	lamp.position = Vector3(1.2, 5.75, -15.5)
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 3.2
	lamp.omni_range = 11.0
	lamp.omni_attenuation = 1.2
	add_child(lamp)
	# 공장 안 차가운 보조광 (그림자 없음): 실내가 새까맣게 죽지 않게
	var fill := OmniLight3D.new()
	fill.name = "InteriorFill"
	fill.position = Vector3(0.0, 7.0, -17.0)
	fill.light_color = Color(0.62, 0.74, 0.9)
	fill.light_energy = 1.1
	fill.omni_range = 22.0
	add_child(fill)
	# 옆 창으로 들어오는 빛줄기가 바닥에 만드는 밝은 자리
	var spot := SpotLight3D.new()
	spot.name = "WindowLight"
	spot.position = Vector3(-11.4, 6.3, -16.2)
	spot.light_color = Color(0.82, 0.9, 1.0)
	spot.light_energy = 5.0
	spot.spot_range = 16.0
	spot.spot_angle = 22.0
	add_child(spot)
	spot.look_at(Vector3(-5.2, 0.0, -15.6), Vector3.UP)


## 스타일 D 조명: 따뜻한 램프 실제 빛 둘(정적 베이크 대상, 그림자 없음). 나머지 실내 밝기는 정점 베이크·바운스·빛줄기 카드가 맡는다.
func _build_lights_trim() -> void:
	for i: int in range(StyleFactory.D_LAMPS.size()):
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp%d" % (i + 1)
		lamp.position = (StyleFactory.D_LAMPS[i]["pos"] as Vector3) + Vector3(0.0, 0.1, 0.0)
		lamp.light_color = Color(1.0, 0.64, 0.32)
		lamp.light_energy = 7.0 if i == 0 else 5.0
		lamp.omni_range = 13.0 if i == 0 else 10.0
		lamp.omni_attenuation = 1.3
		lamp.shadow_enabled = false
		lamp.light_bake_mode = Light3D.BAKE_STATIC
		add_child(lamp)


func _build_smoke() -> void:
	if style == Style.C:
		return  # C의 연기는 StyleSkyline이 각진 덩어리로 만든다
	for p: Vector3 in [Vector3(-44.0, 46.5, -78.0), Vector3(-37.0, 36.5, -74.0)]:
		var plume := SmokePlume.new()
		plume.name = "Smoke%d" % int(p.x)
		plume.position = p
		add_child(plume)


## 스타일 D 덧붙임: 반사 프로브(한 번만 갱신), 떠다니는 먼지.
func _build_extras_d() -> void:
	for spec: Array in [[Vector3(0.0, 3.0, 2.0), Vector3(30.0, 8.0, 26.0)], [Vector3(0.0, 4.5, -18.0), Vector3(23.0, 9.0, 14.0)]]:
		var probe := ReflectionProbe.new()
		probe.name = "ReflectionProbe"
		probe.position = spec[0]
		probe.size = spec[1]
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.intensity = 0.7
		probe.box_projection = true
		add_child(probe)
	if not bake_scene_mode:
		add_child(StyleDust.make(Vector3(-5.2, 3.2, -16.0), Vector3(4.2, 3.0, 3.4)))
		add_child(StyleDust.make(Vector3(-1.4, 4.0, -21.4), Vector3(1.4, 3.0, 1.4)))


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.far = 700.0
	_camera.current = true
	add_child(_camera)


## 컷으로 이동하고 로그를 남긴다 (렌더 통계는 새 화면이 그려진 뒤).
func _go_shot(index: int) -> void:
	_shot = index
	var s: Dictionary = SHOTS[index]
	_camera.position = s["pos"] as Vector3
	_camera.fov = float(s["fov"])
	_camera.look_at(s["target"] as Vector3, Vector3.UP)
	for _i: int in range(4):
		await get_tree().process_frame
	print(PREFIX + "shot %d" % (index + 1))
	print(PREFIX + "render draw_calls=%d primitives=%d" % [
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))])


# --- 지면 ---

func _build_ground() -> void:
	var k: StyleKit = _kit
	var far: MeshBuilder = k.g(&"far_ground")
	k.mats.apply(far, StyleMaterialSet.GROUND)
	far.add_quad(Transform3D.IDENTITY, Vector3(-600, -0.05, 600), Vector3(600, -0.05, 600), Vector3(600, -0.05, -600),
			Vector3(-600, -0.05, -600), Vector3.UP)
	var gr: MeshBuilder = k.g(&"ground")
	# 마당 아스팔트, 공장 앞 콘크리트 포장
	StyleFactory.slab(k, gr, StyleMaterialSet.ASPHALT, Vector3(-12.0, -0.3, -11.0), Vector3(12.0, 0.0, 12.0))
	var paving: StringName = StyleMaterialSet.PAVING if style == Style.D else StyleMaterialSet.CONCRETE
	StyleFactory.slab(k, gr, paving, Vector3(-12.0, -0.3, -11.0), Vector3(12.0, 0.025, -7.6), 0.012)
	# 마당 가장자리 연석과 차선 띠
	StyleFactory.slab(k, gr, StyleMaterialSet.CONCRETE, Vector3(-12.2, -0.3, -7.6), Vector3(-11.9, 0.14, 12.0), 0.02)
	if style == Style.B:
		_dress_ground_lowpoly(k, gr)
	elif style == Style.C:
		_dress_ground_retro(k, gr)
	elif style == Style.D:
		_dress_ground_trim(k, gr)
	for i: int in range(6):
		StyleFactory.slab(k, gr, StyleMaterialSet.BAND_WHITE, Vector3(-0.1, 0.0, 10.4 - i * 2.2), Vector3(0.1, 0.012, 11.6 - i * 2.2))


## 스타일 B 바닥 장식: 텍스처 대신 보수 패치·균열 띠·맨홀·타이어로 "손으로 만든" 디테일을 준다.
func _dress_ground_lowpoly(k: StyleKit, gr: MeshBuilder) -> void:
	var patches: Array[Array] = [
		[Vector3(-6.5, 0.0, 9.0), Vector3(-2.0, 0.012, 11.8), Color("3b4755")],
		[Vector3(4.0, 0.0, -0.8), Vector3(8.5, 0.012, 1.8), Color("2a323c")],
		[Vector3(-10.0, 0.0, -3.0), Vector3(-5.5, 0.012, -0.5), Color("404c5a")],
		[Vector3(0.0, 0.0, 6.0), Vector3(3.2, 0.012, 8.4), Color("2b333d")],
	]
	for p: Array in patches:
		k.mats.apply(gr, StyleMaterialSet.ASPHALT)
		gr.color(p[2] as Color)
		gr.add_box(Transform3D(Basis.IDENTITY, ((p[0] as Vector3) + (p[1] as Vector3)) * 0.5), (p[1] as Vector3) - (p[0] as Vector3), 0.0, 1)
	# 균열 띠 (납작한 사각형 이음)
	var cracks: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(-9.0, 0, 5.0), Vector3(-7.4, 0, 6.2), Vector3(-6.9, 0, 7.8), Vector3(-5.2, 0, 8.6)]),
		PackedVector3Array([Vector3(8.6, 0, 9.4), Vector3(7.2, 0, 8.0), Vector3(7.5, 0, 6.5), Vector3(5.8, 0, 5.2)]),
		PackedVector3Array([Vector3(-3.0, 0, -4.8), Vector3(-1.4, 0, -4.2), Vector3(-0.8, 0, -2.7)]),
	]
	k.mats.apply(gr, StyleMaterialSet.STEEL_DARK)
	for c: PackedVector3Array in cracks:
		for i: int in range(c.size() - 1):
			var a: Vector3 = c[i] + Vector3(0, 0.02, 0)
			var b: Vector3 = c[i + 1] + Vector3(0, 0.02, 0)
			var side: Vector3 = (b - a).cross(Vector3.UP).normalized() * 0.04
			gr.add_quad(Transform3D.IDENTITY, a - side, b - side, b + side, a + side, Vector3.UP)
	# 맨홀과 배수구
	k.cyl(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(-3.4, 0.02, -3.4)), 0.5, 0.04, 8, 8)
	k.cyl(gr, StyleMaterialSet.STEEL, Transform3D(Basis.IDENTITY, Vector3(-3.4, 0.045, -3.4)), 0.34, 0.02, 8, 8)
	k.box(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(4.6, 0.015, 9.8)), Vector3(1.0, 0.03, 0.5), 0.0)
	# 타이어 더미
	for i: int in range(3):
		k.cyl(gr, StyleMaterialSet.RUBBER, Transform3D(Basis.IDENTITY, Vector3(-11.0 + (i % 2) * 0.1, 0.12 + i * 0.24, 9.8)), 0.4, 0.24, 8, 8, 0.05)


## 스타일 C 바닥 장식: 보수 패치(정점 색 변주)·맨홀·타이어. 균열·차선 흔적은 아스팔트 텍스처가 맡는다.
func _dress_ground_retro(k: StyleKit, gr: MeshBuilder) -> void:
	var patches: Array[Array] = [
		[Vector3(-6.5, 0.0, 9.0), Vector3(-2.0, 0.012, 11.8), Color(0.78, 0.82, 0.92)],
		[Vector3(4.0, 0.0, -0.8), Vector3(8.5, 0.012, 1.8), Color(0.6, 0.62, 0.7)],
		[Vector3(-10.0, 0.0, -3.0), Vector3(-5.5, 0.012, -0.5), Color(1.0, 0.98, 0.95)],
		[Vector3(0.0, 0.0, 6.0), Vector3(3.2, 0.012, 8.4), Color(0.66, 0.7, 0.78)],
	]
	for p: Array in patches:
		k.mats.apply(gr, StyleMaterialSet.ASPHALT)
		gr.color(p[2] as Color)
		gr.add_box(Transform3D(Basis.IDENTITY, ((p[0] as Vector3) + (p[1] as Vector3)) * 0.5), (p[1] as Vector3) - (p[0] as Vector3), 0.0, 1)
	k.cyl(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(-3.4, 0.02, -3.4)), 0.5, 0.04, 8, 8)
	k.cyl(gr, StyleMaterialSet.STEEL, Transform3D(Basis.IDENTITY, Vector3(-3.4, 0.045, -3.4)), 0.34, 0.02, 8, 8)
	for i: int in range(3):
		k.cyl(gr, StyleMaterialSet.RUBBER, Transform3D(Basis.IDENTITY, Vector3(-11.0 + (i % 2) * 0.1, 0.12 + i * 0.24, 9.8)), 0.4, 0.24, 8, 8, 0.05)


## 스타일 D 바닥 장식: 밝은 포장 보수 패치·맨홀·타이어. 색 변주는 텍스처(디테일)와 재질 색이 맡는다.
func _dress_ground_trim(k: StyleKit, gr: MeshBuilder) -> void:
	var patches: Array[Array] = [
		[Vector3(-6.5, 0.0, 9.0), Vector3(-2.0, 0.012, 11.8)],
		[Vector3(4.0, 0.0, -0.8), Vector3(8.5, 0.012, 1.8)],
		[Vector3(-10.0, 0.0, -3.0), Vector3(-5.5, 0.012, -0.5)],
		[Vector3(0.0, 0.0, 6.0), Vector3(3.2, 0.012, 8.4)],
	]
	for p: Array in patches:
		k.box(gr, StyleMaterialSet.PAVING, Transform3D(Basis.IDENTITY, ((p[0] as Vector3) + (p[1] as Vector3)) * 0.5),
				(p[1] as Vector3) - (p[0] as Vector3), 0.004)
	k.cyl(gr, StyleMaterialSet.STEEL_DARK, Transform3D(Basis.IDENTITY, Vector3(-3.4, 0.02, -3.4)), 0.5, 0.04, 14, 8, 0.012)
	k.cyl(gr, StyleMaterialSet.STEEL, Transform3D(Basis.IDENTITY, Vector3(-3.4, 0.045, -3.4)), 0.34, 0.02, 14, 8)
	for i: int in range(3):
		k.cyl(gr, StyleMaterialSet.RUBBER, Transform3D(Basis.IDENTITY, Vector3(-11.0 + (i % 2) * 0.1, 0.12 + i * 0.24, 9.8)), 0.4, 0.24, 14, 8, 0.05)


# --- 마당 ---

func _build_yard() -> void:
	var k: StyleKit = _kit
	# 컨테이너 5개 (오른쪽 더미 2+1, 왼쪽 더미 1+1)
	StyleYard.container(k, Vector3(6.8, 0.0, -4.6), 0.0, false)
	StyleYard.container(k, Vector3(6.9, 0.0, -2.0), -0.03, true)
	StyleYard.container(k, Vector3(6.75, StyleYard.CONT_H, -4.5), 0.05, true)
	StyleYard.container(k, Vector3(-8.4, 0.0, -5.4), PI * 0.5 + 0.05, false)
	StyleYard.container(k, Vector3(-8.35, StyleYard.CONT_H, -5.3), PI * 0.5 - 0.03, true)
	StyleYard.truck(k, Vector3(-4.4, 0.0, 1.2), PI + 0.55)
	StyleYard.barrier(k, Vector3(6.3, 0.0, 3.4), 1.5)
	StyleYard.barrier(k, Vector3(6.4, 0.0, 6.6), 1.62)
	StyleYard.barrier(k, Vector3(-1.2, 0.0, -1.2), 0.35)
	StyleYard.pallet_stack(k, Vector3(2.7, 0.0, -6.9), 0.25)
	StyleYard.barrel_group(k, Vector3(-9.8, 0.0, 0.6))
	StyleYard.pipe_rack(k, -8.4)
	StyleYard.lamp_post(k, Vector3(-10.6, 0.0, 7.0), 0.0)
	StyleYard.fence(k, 12.3, -7.6, 12.0)
	StyleYard.puddle(k, Vector3(1.0, 0.0, 2.6), 2.3, 1.45)
	var spots: Array[Vector3] = [Vector3(-11.2, 0.0, -1.8), Vector3(10.2, 0.0, -6.8), Vector3(9.6, 0.0, 6.0),
			Vector3(-6.8, 0.0, 8.2), Vector3(3.4, 0.0, -8.2), Vector3(-2.6, 0.0, -8.0), Vector3(11.0, 0.0, 1.6)]
	if style == Style.D:
		# 울타리·컨테이너·방벽 발치 (가장자리를 따라)
		spots.append_array([Vector3(11.6, 0.0, -3.0), Vector3(11.7, 0.0, 3.5), Vector3(11.5, 0.0, 9.0), Vector3(3.8, 0.0, -1.0),
				Vector3(8.7, 0.0, -0.6), Vector3(-5.0, 0.0, -7.2), Vector3(-9.6, 0.0, -8.6), Vector3(7.7, 0.0, 4.2), Vector3(-0.2, 0.0, -9.8),
				Vector3(-3.4, 0.0, -9.9), Vector3(5.6, 0.0, -9.9), Vector3(-7.8, 0.0, -9.8)])
	for i: int in range(spots.size()):
		StyleYard.weed_clump(k, spots[i], 100 + i, 1.0 + 0.2 * (i % 3))


func _build_factory() -> void:
	StyleFactory.build_shell(_kit)
	StyleFactory.build_interior_structure(_kit)
	StyleFactory.build_interior_props(_kit)
	StyleFactory.build_light_shaft(_kit)
	if style == Style.D:
		StyleFactory.build_ivy(_kit)


# --- 데칼 (스타일 A) ---

## Mobile 렌더러는 데칼을 지원한다. 웹(Compatibility)에서 안 그려지거나 깨지면 이 함수만 건너뛰게 한다.
func _build_decals() -> void:
	_decals_ok = style == Style.A and _renderer_supports_decals()
	print(PREFIX + "decals %s renderer=%s" % ["on" if _decals_ok else "off", RenderingServer.get_current_rendering_method()])
	if not _decals_ok:
		return
	var dir: String = "res://assets/textures/semireal/"
	var grime: Texture2D = load(dir + "decal_grime.webp") as Texture2D
	var stain: Texture2D = load(dir + "decal_stain.webp") as Texture2D
	var rust: Texture2D = load(dir + "decal_rust.webp") as Texture2D
	var wall_basis := Basis(Vector3.RIGHT, PI / 2.0)
	# 공장 앞 벽: 창 아래 그을음, 문 위 얼룩
	for x: float in [-8.9, -5.1, 1.6, 5.2, 8.9]:
		_add_decal(grime, Vector3(x, 5.5, -10.45), Vector3(2.8, 0.7, 4.2), wall_basis, Color(1, 1, 1, 0.8))
	_add_decal(grime, Vector3(-1.0, 8.6, -10.45), Vector3(3.6, 0.7, 3.2), wall_basis, Color(1, 1, 1, 0.6))
	# 컨테이너 옆면 녹물
	_add_decal(rust, Vector3(5.4, 1.4, -0.5), Vector3(1.7, 0.7, 2.4), wall_basis, Color(1, 1, 1, 0.85))
	_add_decal(rust, Vector3(8.4, 1.5, -0.5), Vector3(1.4, 0.7, 2.2), wall_basis, Color(1, 1, 1, 0.7))
	# 바닥: 웅덩이 둘레 젖은 자국, 기름, 문 앞 때
	_add_decal(stain, Vector3(1.0, 0.5, 2.6), Vector3(6.4, 1.2, 4.6), Basis.IDENTITY, Color(1, 1, 1, 0.9))
	_add_decal(stain, Vector3(-2.8, 0.5, 5.6), Vector3(2.4, 1.2, 1.9), Basis(Vector3.UP, 0.8), Color(1, 1, 1, 0.8))
	_add_decal(stain, Vector3(-8.2, 0.5, 2.6), Vector3(2.8, 1.2, 2.4), Basis(Vector3.UP, 2.0), Color(1, 1, 1, 0.7))
	_add_decal(stain, Vector3(0.2, 0.5, -8.6), Vector3(6.0, 1.2, 3.4), Basis(Vector3.UP, 0.3), Color(1, 1, 1, 0.65))


func _add_decal(tex: Texture2D, pos: Vector3, size: Vector3, basis: Basis, tint: Color) -> void:
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = size
	d.modulate = tint
	d.position = pos
	d.basis = basis
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	add_child(d)


## 데칼을 그릴 수 있는 렌더러인가. 웹(Compatibility)은 시험 결과에 따라 여기서 막는다.
func _renderer_supports_decals() -> bool:
	var method: String = RenderingServer.get_current_rendering_method()
	return method == "mobile" or method == "forward_plus" or DECALS_IN_COMPATIBILITY


const DECALS_IN_COMPATIBILITY: bool = false
