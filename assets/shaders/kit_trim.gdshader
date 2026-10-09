shader_type spatial;
// 트림시트 v2 + 페인트 마스크 재칠 (LightmapGI 장면용). 텍스처 규약은 tools/gen_textures_v2.py 참고.
//   albedo sRGB / orm: R AO, G 거칠기, B 금속성 (선형) / normal: OpenGL(Y+) / mask: R 높이, G 페인트(1 = paint_color 곱), B 발광.
//   디테일 v2(detail_v2.webp, 선형 데이터)는 월드 좌표 주축 투영: R = 6 m 저주파 얼룩 (명도 +-8%), G = 1.5 m 때 (약하게), 거칠기도 같이 흔든다.
//   정점 베이크 입력은 없다. 옵션 use_vertex_ao만 COLOR.r을 AO로 곱한다. Mobile·Compatibility 렌더러 모두에서 컴파일되는 기능만 쓴다.

render_mode specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;

uniform vec4 paint_color : source_color = vec4(1.0);
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 1.0) = 1.0;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 emission_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
// 바닥 근처 때: 월드 y가 이 높이보다 낮을수록 어두워지고 거칠어진다.
uniform float ground_dirt_height : hint_range(0.0, 3.0) = 0.5;
uniform float ground_dirt_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool use_vertex_ao = false;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec4 alb = texture(albedo_tex, UV);
	vec4 orm = texture(orm_tex, UV);
	vec4 msk = texture(mask_tex, UV);

	// 월드 주축 투영
	vec3 an = abs(world_n);
	vec2 duv = world_pos.xy;
	if (an.y >= an.x && an.y >= an.z) {
		duv = world_pos.xz;
	} else if (an.x >= an.z) {
		duv = world_pos.zy;
	}
	vec3 d_low = texture(detail_tex, duv * (1.0 / 6.0)).rgb;
	vec3 d_mid = texture(detail_tex, duv * (1.0 / 1.5)).rgb;
	float low = clamp((d_low.r - 0.5) * 2.0, -1.0, 1.0);
	float mid = clamp((d_mid.g - 0.5) * 2.0, -1.0, 1.0);

	vec3 col = mix(alb.rgb, alb.rgb * paint_color.rgb, msk.g) * base_tint.rgb;
	col *= 1.0 + (low * 0.08 + mid * 0.03) * detail_strength;

	// 바닥 근처 때 (높이 경계는 디테일 G로 들쭉날쭉하게)
	float dirt_h = ground_dirt_height * (0.75 + 0.5 * d_mid.g);
	float dirt = (1.0 - smoothstep(0.0, max(dirt_h, 0.001), world_pos.y)) * ground_dirt_strength;
	col *= 1.0 - 0.45 * dirt;

	float rough = orm.g * roughness_scale + mid * -0.10 * detail_strength + 0.2 * dirt;

	float ao = orm.r;
	if (use_vertex_ao) {
		ao *= COLOR.r;
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = orm.b * metallic_scale;
	SPECULAR = specular_amount;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
	EMISSION = emission_color.rgb * msk.b * emission_energy;
}
