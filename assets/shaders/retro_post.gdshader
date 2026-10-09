shader_type canvas_item;
// 스타일 C 전체 화면 후처리: 약한 색 양자화 + 아주 약한 순서 디더링 + 필름 그레인 + 비네트 + 차가운 그림자/따뜻한 하이라이트 분리 톤.
// ColorRect(전체 화면)에 씌운다. 화면 텍스처만 읽으므로 Mobile·Compatibility 둘 다 된다. 모든 값은 유니폼.
// 강도 0이면 해당 단계는 사실상 꺼진다. HUD는 이 위 CanvasLayer(더 큰 layer)에 올려 영향받지 않게 한다.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms quantize;
uniform float pixel_size : hint_range(1.0, 6.0) = 1.0;
uniform float color_levels : hint_range(4.0, 256.0) = 40.0;
uniform float quant_strength : hint_range(0.0, 1.0) = 0.7;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;
group_uniforms film;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.03;
uniform float grain_scale : hint_range(1.0, 4.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.32;
uniform float vignette_radius : hint_range(0.3, 1.5) = 0.9;
group_uniforms grade;
uniform vec3 shadow_tint : source_color = vec3(0.9, 0.95, 1.06);
uniform vec3 highlight_tint : source_color = vec3(1.08, 1.02, 0.9);
uniform float split_strength : hint_range(0.0, 1.0) = 0.45;
uniform float split_pivot : hint_range(0.1, 0.9) = 0.45;
uniform float saturation : hint_range(0.0, 1.5) = 0.92;
uniform float contrast : hint_range(0.5, 1.5) = 1.04;
uniform float brightness : hint_range(0.5, 1.5) = 1.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 frag = floor(FRAGCOORD.xy / pixel_size) * pixel_size;
	vec2 suv = (frag + 0.5 * pixel_size) / res;
	vec3 c = texture(screen_tex, suv).rgb;
	// 색 단계 만들기: 디더링 임계값을 더한 뒤 반올림
	int bi = int(mod(floor(FRAGCOORD.x / pixel_size), 4.0)) + 4 * int(mod(floor(FRAGCOORD.y / pixel_size), 4.0));
	float bayer = BAYER[bi] / 16.0 - 0.5;
	vec3 q = floor(c * (color_levels - 1.0) + 0.5 + bayer * dither_strength) / (color_levels - 1.0);
	c = mix(c, q, quant_strength);
	// 차가운 그림자 / 따뜻한 하이라이트
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float w = smoothstep(split_pivot - 0.3, split_pivot + 0.3, l);
	vec3 tone = mix(shadow_tint, highlight_tint, w);
	c = mix(c, c * tone, split_strength);
	float l2 = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l2), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness;
	// 필름 그레인
	float g = hash12(floor(FRAGCOORD.xy / grain_scale) + fract(TIME * 7.0) * 100.0) - 0.5;
	c += g * grain_strength * (1.0 - 0.5 * l2);
	// 비네트
	vec2 d = (SCREEN_UV - 0.5) * vec2(res.x / res.y, 1.0);
	float v = smoothstep(vignette_radius * 0.35, vignette_radius, length(d));
	c *= 1.0 - vignette_strength * v;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
