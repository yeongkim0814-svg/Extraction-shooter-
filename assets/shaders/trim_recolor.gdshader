shader_type spatial;
// 트림시트 재칠 셰이더 (스타일 D). 기법 출처: Godot 4 데모 "Abandoned Spaceship" (Perfoon, MIT)의 트림시트 + 페인트 마스크 방식.
// 이 파일은 그 접근을 새로 쓴 것이며 데모의 셰이더·에셋을 복사하지 않았다.
//   - 소품은 모두 같은 텍스처 한 벌(albedo, ORM, normal, mask)을 나눠 쓰고, 마스크 G(페인트)가 1인 곳만 paint_color로 칠한다.
//   - 마스크 R = 높이(여기선 미사용), B = 발광 마스크 (불 켜진 유리).
//   - 디테일: 이음매 없는 때·얼룩 텍스처를 월드 좌표 주축 투영으로 입힌다 (소품마다 크기가 같다). detail_scale 3.7 = 4 m당 3.7번.
//   - 정점 색 COLOR(StyleBake가 굽는다): R = AO, G = 하늘 가시성, B = 램프 따뜻함. vertex_bake = 0이면 모두 무시 (라이트맵을 쓸 때).

render_mode specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 paint_color : source_color = vec4(1.0);
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform float metallic_scale : hint_range(0.0, 1.0) = 1.0;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float detail_scale : hint_range(0.1, 12.0) = 3.7;
uniform float detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 emission_color : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;

// 큰 바닥: 메시 UV 대신 월드 xz로 줄 하나를 반사 반복한다 (줄 안쪽만 써서 구워 둔 가장자리 띠가 안 보이게).
uniform bool ground_mode = false;
uniform vec2 ground_v = vec2(0.0, 1.0);
uniform float ground_period : hint_range(0.5, 12.0) = 3.0;

// 정점 베이크
uniform float vertex_bake : hint_range(0.0, 1.0) = 1.0;
uniform float vertex_ao_strength : hint_range(0.0, 1.5) = 1.0;
uniform float albedo_ao_mix : hint_range(0.0, 1.0) = 0.35;
uniform float interior_floor : hint_range(0.0, 1.0) = 0.45;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.25;
uniform vec4 warm_color : source_color = vec4(1.0, 0.62, 0.28, 1.0);
uniform float bounce_energy : hint_range(0.0, 2.0) = 0.35;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec2 uv = UV;
	if (ground_mode) {
		float t = abs(fract(world_pos.z / (ground_period * 2.0)) * 2.0 - 1.0);
		float margin = (ground_v.y - ground_v.x) * 0.2;
		uv = vec2(world_pos.x * 0.07 + world_pos.z * 0.02, mix(ground_v.x + margin, ground_v.y - margin, t));
	}
	vec4 alb = texture(albedo_tex, uv);
	vec4 orm = texture(orm_tex, uv);
	vec4 msk = texture(mask_tex, uv);

	vec3 an = abs(world_n);
	vec2 duv = world_pos.xy;
	if (an.y >= an.x && an.y >= an.z) {
		duv = world_pos.xz;
	} else if (an.x >= an.z) {
		duv = world_pos.zy;
	}
	vec4 det = texture(detail_tex, duv * (detail_scale * 0.25));
	vec3 detail = mix(vec3(1.0), det.rgb, detail_strength);

	float bake = vertex_bake;
	float vao = mix(1.0, COLOR.r, bake * vertex_ao_strength);
	float sky = mix(1.0, COLOR.g, bake);
	float warm = COLOR.b * bake;

	vec3 col = mix(alb.rgb, alb.rgb * paint_color.rgb, msk.g) * base_tint.rgb * detail;
	col *= mix(1.0, vao, albedo_ao_mix);

	ALBEDO = col;
	ROUGHNESS = clamp(orm.g * roughness_scale + (1.0 - det.r) * detail_strength, 0.0, 1.0);
	METALLIC = orm.b * metallic_scale;
	SPECULAR = specular_amount;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	// AO는 주변광과 반사에만 걸린다. 지붕 아래(하늘이 안 보이는 곳)는 interior_floor까지 어두워진다.
	AO = orm.r * vao * mix(interior_floor, 1.0, smoothstep(0.0, 0.6, sky));
	AO_LIGHT_AFFECT = ao_light_affect;
	// 램프 바운스: 램프 근처 면에 따뜻한 빛이 번진다 (알베도 x 램프색). 불 켜진 유리는 emission_energy로 빛난다.
	EMISSION = col * warm_color.rgb * warm * bounce_energy + emission_color.rgb * msk.b * emission_energy;
}
