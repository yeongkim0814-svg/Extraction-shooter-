class_name GraphicsTier
extends RefCounted
## 그래픽 품질 단계(LOW/MID/HIGH)와 단계별 설정값 표 (M10). 순수 데이터라 노드·씬에 의존하지 않는다.
## 실제로 뷰포트·조명·환경에 적용하는 쪽은 scripts/game/settings/graphics_quality.gd.

enum Tier { LOW, MID, HIGH }

## 멀티샘플 안티앨리어싱 단계 (Viewport.MSAA 값과 같은 번호).
const MSAA_OFF: int = 0
const MSAA_2X: int = 1

const TIER_NAMES: Dictionary[Tier, String] = {
	Tier.LOW: "LOW", Tier.MID: "MID", Tier.HIGH: "HIGH",
}


class Settings:
	## 3D 렌더 해상도 배율 (뷰포트 scaling_3d_scale).
	var render_scale: float = 1.0
	## 방향광 그림자 사용 여부.
	var shadows: bool = true
	## 그림자 분할 수 (1 또는 2). shadows가 false면 의미 없다.
	var shadow_splits: int = 2
	## 그림자 최대 거리 (m).
	var shadow_distance: float = 40.0
	var glow: bool = true
	## 높이 안개를 쓰는지 (깊이 안개는 항상 켠다).
	var height_fog: bool = true
	## 태양 방향 안개 산란 세기 (0이면 끔).
	var fog_sun_scatter: float = 0.0
	## 연기 파티클 양 배율 (0~1).
	var particle_ratio: float = 1.0
	## 잡초 밀도 배율 (0~1).
	var weed_density: float = 1.0
	var msaa: int = MSAA_OFF
	## 반사 프로브(웅덩이 반사) 사용 여부.
	var reflection_probe: bool = true


static func settings_for(tier: Tier) -> Settings:
	var s := Settings.new()
	match tier:
		Tier.LOW:
			s.render_scale = 0.7
			s.shadows = false
			s.shadow_splits = 1
			s.shadow_distance = 0.0
			s.glow = false
			s.height_fog = false
			s.fog_sun_scatter = 0.0
			s.particle_ratio = 0.4
			s.weed_density = 0.3
			s.msaa = MSAA_OFF
			s.reflection_probe = false
		Tier.MID:
			s.render_scale = 0.85
			s.shadows = true
			s.shadow_splits = 1
			s.shadow_distance = 30.0
			s.glow = true
			s.height_fog = true
			s.fog_sun_scatter = 0.0
			s.particle_ratio = 0.7
			s.weed_density = 0.65
			s.msaa = MSAA_2X
			s.reflection_probe = true
		Tier.HIGH:
			s.render_scale = 1.0
			s.shadows = true
			s.shadow_splits = 2
			s.shadow_distance = 45.0
			s.glow = true
			s.height_fog = true
			s.fog_sun_scatter = 0.25
			s.particle_ratio = 1.0
			s.weed_density = 1.0
			s.msaa = MSAA_2X
			s.reflection_probe = true
	return s


static func next(tier: Tier) -> Tier:
	return ((int(tier) + 1) % Tier.size()) as Tier


static func tier_name(tier: Tier) -> String:
	return TIER_NAMES[tier]


## 이름("low", "MID" 등)으로 단계를 찾는다. 모르는 이름이면 fallback.
static func from_name(text: String, fallback: Tier = Tier.MID) -> Tier:
	var upper: String = text.strip_edges().to_upper()
	for tier: Tier in TIER_NAMES:
		if TIER_NAMES[tier] == upper:
			return tier
	return fallback


## 기기별 기본 단계: 안드로이드(네이티브·모바일 웹) MID, 그 밖(데스크톱 웹·PC) HIGH.
static func default_tier(is_android: bool, is_mobile_web: bool) -> Tier:
	if is_android or is_mobile_web:
		return Tier.MID
	return Tier.HIGH
