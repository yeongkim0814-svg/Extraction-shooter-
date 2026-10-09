shader_type sky;
// 스타일 C 해질녘 하늘: 슬레이트 블루 천정 -> 청회색 -> 지평선의 따뜻한 번짐, 네모난 태양 원반, 덩어리진 픽셀 구름.
// 그라데이션은 몇 단계로 끊어 손으로 칠한 느낌을 낸다. 모든 값은 유니폼으로 따로 조절한다.
// Mobile·Compatibility 둘 다 컴파일되는 기능만 쓴다 (텍스처 없음).

group_uniforms palette;
uniform vec3 zenith_color : source_color = vec3(0.1, 0.15, 0.27);
uniform vec3 mid_color : source_color = vec3(0.22, 0.31, 0.47);
uniform vec3 horizon_cool : source_color = vec3(0.45, 0.52, 0.62);
uniform vec3 horizon_warm : source_color = vec3(0.95, 0.6, 0.32);
uniform vec3 ground_color : source_color = vec3(0.08, 0.1, 0.13);
uniform float band_steps : hint_range(2.0, 32.0) = 12.0;
group_uniforms sun;
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.55);
uniform float sun_half_size : hint_range(0.005, 0.2) = 0.045;
uniform float sun_energy = 6.0;
uniform float glow_power : hint_range(1.0, 64.0) = 9.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.7;
group_uniforms clouds;
uniform vec3 cloud_dark : source_color = vec3(0.26, 0.3, 0.42);
uniform vec3 cloud_lit : source_color = vec3(0.95, 0.68, 0.45);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_cells = 64.0;
uniform float cloud_levels : hint_range(2.0, 8.0) = 3.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 sd = vec3(0.0, 0.3, -1.0);
	float sun_on = 0.0;
	if (LIGHT0_ENABLED) {
		sd = LIGHT0_DIRECTION;
		sun_on = 1.0;
	}
	float t = clamp(up, 0.0, 1.0);
	float tq = floor(pow(t, 0.6) * band_steps) / band_steps;
	vec3 col = mix(horizon_cool, mid_color, smoothstep(0.0, 0.4, tq));
	col = mix(col, zenith_color, smoothstep(0.3, 0.95, tq));
	// 해 쪽 지평선의 따뜻한 번짐 (단계로 끊는다)
	float s = max(dot(dir, sd), 0.0);
	float glow = pow(s, glow_power) * (1.0 - smoothstep(0.0, 0.55, up)) * glow_strength * sun_on;
	glow = floor(clamp(glow, 0.0, 1.0) * 7.0) / 7.0;
	col = mix(col, horizon_warm, glow);
	// 덩어리진 구름: 방향을 평면에 투영해 칸 단위로 값을 낸다
	vec2 uv = dir.xz / (max(up, 0.0) + 0.18);
	vec2 cell = floor(uv * vec2(cloud_cells * 0.5, cloud_cells)) ;
	float n = 0.55 * vnoise(cell * 0.09) + 0.3 * vnoise(cell * 0.2 + 7.0) + 0.15 * vnoise(cell * 0.45 + 3.0);
	float dens = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.12, n);
	float shade = floor(clamp((n - (1.0 - cloud_cover)) * 5.0, 0.0, 0.999) * cloud_levels) / (cloud_levels - 1.0);
	float toward_sun = pow(s, 3.0) * sun_on;
	vec3 ccol = mix(cloud_dark, cloud_lit, clamp(shade * 0.55 + toward_sun * 0.9, 0.0, 1.0));
	float fade = smoothstep(0.02, 0.2, up);
	col = mix(col, ccol, dens * fade);
	if (up < 0.0) {
		col = mix(horizon_cool * 0.6, ground_color, clamp(-up * 4.0, 0.0, 1.0));
	}
	// 네모난 태양 원반 + 단계 후광 (구름이 가린다)
	if (sun_on > 0.5 && s > 0.0) {
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), sd));
		vec3 upv = cross(sd, right);
		vec2 q = vec2(dot(dir, right), dot(dir, upv));
		float sq = max(abs(q.x), abs(q.y));
		float open_sky = 1.0 - dens * 0.8;
		float halo = 1.0 - smoothstep(sun_half_size, sun_half_size * 5.0, sq);
		halo = floor(halo * 4.0) / 4.0;
		col += sun_color * halo * 0.35 * open_sky;
		if (sq < sun_half_size) {
			col = mix(col, sun_color * sun_energy, open_sky);
		}
	}
	COLOR = col;
}
