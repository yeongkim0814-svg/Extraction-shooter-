shader_type spatial;
// 바닥 3종 (아스팔트·콘크리트·자갈) 반복 숨김 셰이더. 월드 XZ 평면 투영, 타일 1장 = tile_size m (기본 4 m).
//   - 같은 텍스처 세트를 두 번 샘플한다: 두 번째는 약 37도 회전 + 0.73배 + 오프셋. 섞는 비율은 detail_v2.R을 1/20 m^-1로 읽은 저주파 노이즈.
//   - 법선: 월드 좌표 투영이라 메시 탄젠트와 맞지 않는다. 텍스처 공간 법선(OpenGL, Y+ = 이미지 위쪽 = 월드 -Z)을 월드 기울기로 바꿔
//     메시 법선에 더하고, 최종 NORMAL은 VIEW_MATRIX로 뷰 공간에 옮긴다. 두 번째 샘플의 기울기는 회전의 역으로 되돌린다.
//   - 정점 색 규약 (정점 색이 없으면 Godot는 COLOR = 흰색 (1,1,1)이므로 반전 채널을 쓴다):
//       젖음  = 1 - COLOR.r  (알베도 약 40% 어둡게, 거칠기 -> 0.08, 법선 납작하게)
//       흙    = 1 - COLOR.g  (어두운 갈색으로, 더 거칠게)
//       이끼  = 1 - COLOR.b  (탁한 녹색 #4A5236으로)
//     즉 정점 색 (1,1,1) = 마른 맨바닥, 웅덩이는 R을 0으로, 흙은 G를, 이끼는 B를 0으로 칠한다.
//   Mobile·Compatibility 모두에서 컴파일되는 기능만 쓴다.

render_mode specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;

uniform float tile_size : hint_range(0.5, 16.0) = 4.0;
uniform float second_angle_deg : hint_range(0.0, 90.0) = 37.0;
uniform float second_scale : hint_range(0.3, 2.0) = 0.73;
uniform vec2 second_offset = vec2(0.31, 0.17);
uniform float blend_contrast : hint_range(1.0, 12.0) = 5.0;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.3;
uniform vec4 base_tint : source_color = vec4(1.0);

uniform float wet_darken : hint_range(0.0, 1.0) = 0.4;
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.08;
uniform vec4 dirt_color : source_color = vec4(0.23, 0.17, 0.12, 1.0);
uniform vec4 moss_color : source_color = vec4(0.29, 0.32, 0.21, 1.0);
uniform float breakup : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// 텍스처 법선 -> 월드 XZ 기울기. 텍스처 u = 월드 +X, v = 월드 +Z, 법선 Y+ = 이미지 위쪽 = 월드 -Z.
vec2 slope_of(vec3 n_tex) {
	vec3 n = n_tex * 2.0 - 1.0;
	float nz = max(n.z, 0.2);
	return vec2(n.x, -n.y) / nz;
}

void fragment() {
	vec2 p1 = world_pos.xz / tile_size;
	float ang = radians(second_angle_deg);
	float ca = cos(ang);
	float sa = sin(ang);
	mat2 rot = mat2(vec2(ca, sa), vec2(-sa, ca)); // 열 우선: rot * v = (ca*x - sa*y, sa*x + ca*y)
	vec2 p2 = (rot * p1) * second_scale + second_offset;

	// 저주파 섞기 가중치 (디테일 R, 약 20 m 주기에 한 번 = 512 px가 20 m)
	float nb = texture(detail_tex, world_pos.xz * (1.0 / 20.0)).r;
	float w = clamp((nb - 0.5) * blend_contrast + 0.5, 0.0, 1.0);

	vec3 a1 = texture(albedo_tex, p1).rgb;
	vec3 a2 = texture(albedo_tex, p2).rgb;
	vec4 o1 = texture(orm_tex, p1);
	vec4 o2 = texture(orm_tex, p2);
	vec2 s1 = slope_of(texture(normal_tex, p1).rgb);
	vec2 s2 = slope_of(texture(normal_tex, p2).rgb);
	// 두 번째 샘플 기울기를 첫 번째 좌표계로: p2 = M * p1 이므로 기울기는 M^T로 변환 (회전은 역회전, 배율은 second_scale)
	s2 = (transpose(rot) * s2) * second_scale;

	vec3 col = mix(a1, a2, w) * base_tint.rgb;
	vec4 orm = mix(o1, o2, w);
	vec2 slope = mix(s1, s2, w) * normal_scale;

	// 정점 색 (반전 채널): 가장자리가 깨끗하지 않도록 디테일 G로 약간 흔든다
	float jitter = (texture(detail_tex, world_pos.xz * (1.0 / 1.5)).g - 0.5) * 2.0 * breakup;
	float wet = smoothstep(0.3, 0.7, (1.0 - COLOR.r) + jitter * 0.5);
	float dirt = smoothstep(0.2, 0.8, (1.0 - COLOR.g) + jitter * 0.4);
	float moss = smoothstep(0.3, 0.7, (1.0 - COLOR.b) + jitter * 0.5);

	float rough = orm.g;
	col = mix(col, dirt_color.rgb, dirt * 0.75);
	rough = mix(rough, 1.0, dirt * 0.4);
	col = mix(col, moss_color.rgb * (0.7 + 0.5 * a1.g), moss * 0.85);
	rough = mix(rough, 0.95, moss);
	col *= 1.0 - wet_darken * wet;
	rough = mix(rough, wet_roughness, wet);
	slope *= 1.0 - 0.9 * wet;

	// 월드 법선 = 메시 법선 + 기울기 (평평한 바닥이면 (sx, 1, sz)). 뷰 공간으로 옮긴다.
	vec3 nw = normalize(world_n + vec3(slope.x, 0.0, slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = 0.0;
	SPECULAR = specular_amount;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.25;
}
