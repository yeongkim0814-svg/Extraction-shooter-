class_name GraphicsQuality
extends Node
## 그래픽 품질 단계(GraphicsTier)를 실제 씬에 적용한다 (M10). 레이드 씬에 붙여 쓴다.
## 적용 대상: 뷰포트 3D 렌더 배율·MSAA, 태양 그림자(분할·거리), 환경(글로우·높이 안개·태양 산란),
## 그룹으로 찾는 연기(gfx_smoke)·잡초(gfx_weeds)·반사 프로브(gfx_probe).
## 개발 토글: 레이드 컨트롤러가 F2(또는 터치 네 손가락)로 cycle()을 부른다. 정식 설정 메뉴는 M11.

signal tier_changed(tier: GraphicsTier.Tier)

## 환경의 높이 안개 밀도 기준값 (환경 리소스에서 읽어 둔다).
var _base_height_density: float = 0.03
var _env: Environment
var _sun: DirectionalLight3D
var _viewport: Viewport
var tier: GraphicsTier.Tier = GraphicsTier.Tier.HIGH


## 환경은 공유 리소스를 건드리지 않게 복제해서 쓴다.
func setup(world_env: WorldEnvironment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	_sun = sun
	_viewport = viewport
	if world_env != null and world_env.environment != null:
		_env = world_env.environment.duplicate() as Environment
		world_env.environment = _env
		_base_height_density = _env.fog_height_density


## 기기 기본 단계: 안드로이드 MID, 데스크톱 웹 HIGH. URL ?quality=low|mid|high 또는 --quality=...가 있으면 그것.
static func detect_default() -> GraphicsTier.Tier:
	var requested: String = _requested_name()
	if requested != "":
		return GraphicsTier.from_name(requested)
	var mobile_web: bool = OS.has_feature("web_android") or OS.has_feature("web_ios")
	return GraphicsTier.default_tier(OS.has_feature("android"), mobile_web)


static func _requested_name() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			return arg.substr("--quality=".length())
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search")
		if query is String:
			for pair: String in (query as String).trim_prefix("?").split("&"):
				if pair.begins_with("quality="):
					return pair.substr("quality=".length())
	return ""


func apply(new_tier: GraphicsTier.Tier) -> void:
	tier = new_tier
	var s: GraphicsTier.Settings = GraphicsTier.settings_for(new_tier)
	if _viewport != null:
		_viewport.scaling_3d_scale = s.render_scale
		_viewport.msaa_3d = Viewport.MSAA_2X if s.msaa == GraphicsTier.MSAA_2X else Viewport.MSAA_DISABLED
	if _sun != null:
		_sun.shadow_enabled = s.shadows
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if s.shadow_splits >= 2 \
				else DirectionalLight3D.SHADOW_ORTHOGONAL
		if s.shadows:
			_sun.directional_shadow_max_distance = s.shadow_distance
	if _env != null:
		_env.glow_enabled = s.glow
		_env.fog_height_density = _base_height_density if s.height_fog else 0.0
		_env.fog_sun_scatter = s.fog_sun_scatter
	for plume: Node in get_tree().get_nodes_in_group(SmokePlume.GROUP):
		(plume as SmokePlume).set_amount_ratio(s.particle_ratio)
	for weeds: Node in get_tree().get_nodes_in_group(IndustrialAtmosphere.WEED_GROUP):
		var instance := weeds as MultiMeshInstance3D
		var base: int = int(instance.get_meta(&"base_count", instance.multimesh.instance_count))
		instance.multimesh.visible_instance_count = int(round(float(base) * s.weed_density))
	for probe: Node in get_tree().get_nodes_in_group(IndustrialAtmosphere.PROBE_GROUP):
		(probe as ReflectionProbe).visible = s.reflection_probe
	tier_changed.emit(new_tier)


## 다음 단계로 넘기고 적용한다. 새 단계를 돌려준다.
func cycle() -> GraphicsTier.Tier:
	apply(GraphicsTier.next(tier))
	return tier
