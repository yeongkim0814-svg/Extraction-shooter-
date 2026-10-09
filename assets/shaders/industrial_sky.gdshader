shader_type sky;
// 흐린 산업단지 하늘 (M10): 회청색 지평선, 어두운 천정, 구름 덩어리, 구름 사이로 번지는 낮은 태양.
// 텍스처 없이 값 노이즈 fbm으로 구름을 만든다 (Mobile·Compatibility 둘 다 컴파일되는 기능만 사용).

uniform vec3 zenith_color : source_color = vec3(0.12, 0.17, 0.25);
uniform vec3 horizon_color : source_color = vec3(0.5, 0.56, 0.62);
uniform vec3 ground_color : source_color = vec3(0.1, 0.11, 0.13);
uniform vec3 cloud_dark : source_color = vec3(0.19, 0.23, 0.29);
uniform vec3 cloud_light : source_color = vec3(0.62, 0.66, 0.7);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.78, 0.55);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.66;
uniform float cloud_scale = 1.5;
uniform float sun_glow = 1.3;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * value_noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amp *= 0.5;
	}
	return sum;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 base = mix(horizon_color, zenith_color, pow(clamp(up, 0.0, 1.0), 0.5));
	if (up < 0.0) {
		base = mix(horizon_color * 0.85, ground_color, clamp(-up * 3.0, 0.0, 1.0));
	}
	vec2 uv = dir.xz / (max(up, 0.0) + 0.22);
	float shape = fbm(uv * cloud_scale + vec2(3.0, 1.0));
	float density = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.35, shape);
	float shade = fbm(uv * cloud_scale * 2.1 + vec2(11.0, 5.0));
	vec3 cloud = mix(cloud_dark, cloud_light, clamp(shade * 1.2 - 0.1 + (1.0 - density) * 0.2, 0.0, 1.0));
	float horizon_fade = smoothstep(-0.02, 0.16, up);
	vec3 col = mix(base, cloud, density * horizon_fade * 0.9);
	if (LIGHT0_ENABLED) {
		float s = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		float open_sky = 1.0 - density * 0.7;
		col += sun_tint * (pow(s, 6.0) * 0.35 + pow(s, 40.0) * 0.5) * sun_glow * (0.55 + 0.45 * open_sky);
		col += sun_tint * smoothstep(0.9993, 0.99985, s) * 3.0 * open_sky * open_sky;
	}
	COLOR = col;
}
