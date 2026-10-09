class_name VertexAo
extends RefCounted
## 정점 단위 베이크 AO·하늘 가시성·램프 따뜻함의 순수 계산 (레이 캐스트 자체는 게임 쪽 StyleBake가 한다).
## LightmapGI를 못 굽는 환경(Vulkan 없음, 웹)에서 라이트맵 대신 쓰는 값이다. 결과는 정점 색 COLOR에 저장한다:
##   R = AO (1 = 열림), G = 하늘 가시성 (1 = 하늘이 다 보임), B = 램프 따뜻함 (0 = 영향 없음), A = 1.

## 코사인 가중 반구 방향 count개 (로컬: +Z가 위). 피보나치 나선이라 개수가 적어도 고르다.
static func hemisphere_dirs(count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var golden: float = PI * (3.0 - sqrt(5.0))
	for i: int in range(count):
		var r2: float = (float(i) + 0.5) / float(count)
		var radius: float = sqrt(r2)
		var theta: float = golden * float(i)
		out.append(Vector3(cos(theta) * radius, sin(theta) * radius, sqrt(maxf(0.0, 1.0 - r2))))
	return out


## 로컬 방향(+Z = 법선)을 실제 법선 둘레로 돌려 놓는다. spin은 법선 축 회전(라디안)으로 정점마다 달리 줘 줄무늬를 깬다.
static func orient(local_dir: Vector3, normal: Vector3, spin: float) -> Vector3:
	var n: Vector3 = normal.normalized()
	var helper: Vector3 = Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	var t: Vector3 = helper.cross(n).normalized()
	var b: Vector3 = n.cross(t)
	var cs: float = cos(spin)
	var sn: float = sin(spin)
	var lx: float = local_dir.x * cs - local_dir.y * sn
	var ly: float = local_dir.x * sn + local_dir.y * cs
	return (t * lx + b * ly + n * local_dir.z).normalized()


## 레이 하나가 distance에서 부딪혔을 때의 가림 정도 (가까울수록 크다, max_dist 밖이면 0).
static func hit_weight(distance: float, max_dist: float) -> float:
	if distance >= max_dist:
		return 0.0
	var t: float = 1.0 - distance / max_dist
	return t * t * (3.0 - 2.0 * t)


## 가림 합계 -> AO 값. strength 1이면 완전히 막힌 정점이 0.
static func ao_value(weight_sum: float, ray_count: int, strength: float) -> float:
	if ray_count <= 0:
		return 1.0
	return clampf(1.0 - strength * weight_sum / float(ray_count), 0.0, 1.0)


## 램프 하나가 정점에 주는 따뜻함 (0..1). 거리 감쇠 x 법선이 램프를 향하는 정도. 가림은 호출 쪽이 판단해 visible로 넘긴다.
static func lamp_warmth(pos: Vector3, normal: Vector3, lamp_pos: Vector3, radius: float, visible: bool) -> float:
	if not visible:
		return 0.0
	var to_lamp: Vector3 = lamp_pos - pos
	var d: float = to_lamp.length()
	if d >= radius or d < 0.0001:
		return 0.0
	var fall: float = 1.0 - d / radius
	var facing: float = clampf(normal.dot(to_lamp / d) * 0.5 + 0.5, 0.0, 1.0)
	return fall * fall * facing


static func pack(ao: float, sky: float, warm: float) -> Color:
	return Color(clampf(ao, 0.0, 1.0), clampf(sky, 0.0, 1.0), clampf(warm, 0.0, 1.0), 1.0)


## 같은 자리·같은 법선의 정점을 합치는 키 (위치 5 mm, 법선 약 0.2 격자). 쪼갠 삼각형들이 이웃과 같은 값을 공유한다.
static func key(pos: Vector3, normal: Vector3) -> int:
	var px: int = roundi(pos.x * 200.0)
	var py: int = roundi(pos.y * 200.0)
	var pz: int = roundi(pos.z * 200.0)
	var nx: int = roundi(normal.x * 4.0) + 4
	var ny: int = roundi(normal.y * 4.0) + 4
	var nz: int = roundi(normal.z * 4.0) + 4
	var h: int = px * 73856093 ^ py * 19349663 ^ pz * 83492791
	h = h * 31 + nx * 9 + ny * 81 + nz * 729
	return h
