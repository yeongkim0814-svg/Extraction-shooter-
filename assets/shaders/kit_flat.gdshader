shader_type spatial;
// 단색 넓은 면 (큰 벽·천장·탱크·지붕). 알베도 텍스처 없이 재질 색만 쓰고, 디테일 v2로 아주 약한 변화만 준다.
//   R (6 m) + G (1.5 m): 명도 +-6% 이하. 바닥 근처 때, 위에서 흐른 비 줄무늬(디테일 G를 세로로 늘려 샘플)는 약한 어두움으로만.
//   빛 그라데이션(라이트맵)이 주인공이라 고주파는 넣지 않는다. Mobile·Compatibility 모두 컴파일되는 기능만 쓴다.

render_mode specular_schlick_ggx;

uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;

uniform vec4 albedo : source_color = vec4(0.55, 0.54, 0.52, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// 정점 색 RGB = 색, A = 거칠기 (KitMaterials.vertex_color). 금속/비금속 재질 둘을 모든 단색 면이 나눠 쓴다.
uniform bool use_vertex_color = true;

// 정점 색은 sRGB로 저장한다. 선형으로 계산하는 렌더러(Forward+·Mobile)에서만 선형으로 바꾼다
// (BaseMaterial3D의 vertex_color_is_srgb와 같은 방식, Compatibility는 OUTPUT_IS_SRGB가 참이라 그대로 쓴다).
vec3 vertex_srgb_to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

uniform float specular_amount : hint_range(0.0, 1.0) = 0.3;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float ground_dirt_height : hint_range(0.0, 3.0) = 0.5;
uniform float ground_dirt_strength : hint_range(0.0, 1.0) = 0.3;
uniform float rain_streak_strength : hint_range(0.0, 1.0) = 0.25;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 an = abs(world_n);
	vec2 duv = world_pos.xy;
	if (an.y >= an.x && an.y >= an.z) {
		duv = world_pos.xz;
	} else if (an.x >= an.z) {
		duv = world_pos.zy;
	}
	float low = clamp((texture(detail_tex, duv * (1.0 / 6.0)).r - 0.5) * 2.0, -1.0, 1.0);
	vec3 d_mid = texture(detail_tex, duv * (1.0 / 1.5)).rgb;
	float mid = clamp((d_mid.g - 0.5) * 2.0, -1.0, 1.0);
	vec3 vc = OUTPUT_IS_SRGB ? COLOR.rgb : vertex_srgb_to_linear(COLOR.rgb);
	vec3 base = use_vertex_color ? vc * albedo.rgb : albedo.rgb;
	float base_rough = use_vertex_color ? COLOR.a : roughness;
	vec3 col = base * (1.0 + (low * 0.045 + mid * 0.02) * detail_strength);

	// 바닥 근처 때
	float dirt_h = ground_dirt_height * (0.75 + 0.5 * d_mid.g);
	float dirt = (1.0 - smoothstep(0.0, max(dirt_h, 0.001), world_pos.y)) * ground_dirt_strength;
	col *= 1.0 - 0.4 * dirt;

	// 비 줄무늬: 벽면(수직)에서만. 수평 좌표를 늘리고 높이는 크게 줄여 세로로 길쭉한 얼룩을 만든다.
	float wall = 1.0 - smoothstep(0.5, 0.85, an.y);
	float h_coord = an.x > an.z ? world_pos.z : world_pos.x;
	float streak = texture(detail_tex, vec2(h_coord * 0.5, world_pos.y * (1.0 / 12.0))).g;
	float streak_m = smoothstep(0.52, 0.7, streak);
	col *= 1.0 - 0.18 * rain_streak_strength * streak_m * wall;

	ALBEDO = col;
	ROUGHNESS = clamp(base_rough - 0.05 * mid * detail_strength + 0.15 * dirt, 0.04, 1.0);
	METALLIC = metallic;
	SPECULAR = specular_amount;
}
