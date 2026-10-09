class_name TrimUv
extends RefCounted
## 트림시트 UV 사상(순수 계산). 모따기 박스의 면마다 시트의 한 줄(strip)을 골라 붙인다.
##   U: 면을 따라 월드 미터를 고정 텍셀 밀도로 센다 (TrimLayout.TILE_M = U 1.0). 줄은 가로로 이어 붙는다.
##   V: 면의 아래 끝 -> 줄의 아래 v1, 위 끝 -> 줄의 위 v0. 줄 가장자리(구워 둔 닳은 하이라이트·AO)가 면의 모서리, 곧 모따기에 닿는다.
## 면은 정점의 바깥 법선이 가리키는 주축으로 고른다. 모따기 띠의 두 가장자리 정점은 각자 이웃한 두 면의 사상을 따르므로
## 줄이 모따기를 지나 자연스럽게 이어진다.

## 면 번호.
const PX: int = 0
const NX: int = 1
const PY: int = 2
const NY: int = 3
const PZ: int = 4
const NZ: int = 5
const FACE_COUNT: int = 6


## 법선의 주축 면 (동률이면 Y, X, Z 순이 아니라 X, Y, Z 순서 우선).
static func face_of(n: Vector3) -> int:
	var ax: float = absf(n.x)
	var ay: float = absf(n.y)
	var az: float = absf(n.z)
	if ax >= ay and ax >= az:
		return PX if n.x >= 0.0 else NX
	if ay >= az:
		return PY if n.y >= 0.0 else NY
	return PZ if n.z >= 0.0 else NZ


## 면 6개에 같은 줄을 배정한 배열.
static func uniform_strips(v_range: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(FACE_COUNT)
	out.fill(v_range)
	return out


## 옆면 4개·윗면·아랫면에 따로 배정한 배열.
static func side_top_bottom(side: Vector2, top: Vector2, bottom: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(FACE_COUNT)
	out[PX] = side
	out[NX] = side
	out[PZ] = side
	out[NZ] = side
	out[PY] = top
	out[NY] = bottom
	return out


## 평면 사상. p = 도형 로컬 좌표, lo/hi = 도형 로컬 경계 상자, face = 면 번호, strip = (v0, v1), tile_m = U 1.0의 길이(m).
## 반환 U는 면의 낮은 쪽 끝에서 0 (마주 보는 방향에서 왼쪽 -> 오른쪽으로 증가).
static func map_planar(p: Vector3, lo: Vector3, hi: Vector3, face: int, strip: Vector2, tile_m: float) -> Vector2:
	var u: float
	var t: float  # 0 = 면 아래 (또는 윗면의 -Z 쪽), 1 = 면 위
	match face:
		PZ:
			u = (p.x - lo.x) / tile_m
			t = _frac(p.y, lo.y, hi.y)
		NZ:
			u = (hi.x - p.x) / tile_m
			t = _frac(p.y, lo.y, hi.y)
		PX:
			u = (hi.z - p.z) / tile_m
			t = _frac(p.y, lo.y, hi.y)
		NX:
			u = (p.z - lo.z) / tile_m
			t = _frac(p.y, lo.y, hi.y)
		PY:
			u = (p.x - lo.x) / tile_m
			return Vector2(u, lerpf(strip.x, strip.y, _frac(p.z, lo.z, hi.z)))
		_:
			u = (p.x - lo.x) / tile_m
			return Vector2(u, lerpf(strip.y, strip.x, _frac(p.z, lo.z, hi.z)))
	return Vector2(u, lerpf(strip.y, strip.x, t))


## 회전체 옆면 사상 (감기): U = 둘레를 정수 번 반복, V = 높이. frac = 0..1 둘레 위치, t = 0..1 높이.
static func map_wrap(frac: float, radius: float, t: float, strip: Vector2, tile_m: float) -> Vector2:
	var reps: float = maxf(1.0, roundf(TAU * radius / tile_m))
	return Vector2(frac * reps, lerpf(strip.y, strip.x, t))


## 회전체 옆면 사상 (축 방향): U = 축 길이(m) / tile_m, V = 둘레를 위·아래로 접어 대칭으로 쓴다 (긴 파이프용).
static func map_axial(frac: float, axis_len: float, strip: Vector2, tile_m: float) -> Vector2:
	var fold: float = absf(frac * 2.0 - 1.0)
	return Vector2(axis_len / tile_m, lerpf(strip.x, strip.y, fold))


## 회전체 마개 사상: 원판을 줄의 한 조각으로 평면 투영한다.
static func map_cap(x: float, z: float, radius: float, strip: Vector2, tile_m: float) -> Vector2:
	var r: float = maxf(radius, 0.0001)
	return Vector2((x + r) / tile_m, lerpf(strip.x, strip.y, clampf((z + r) / (2.0 * r), 0.0, 1.0)))


static func _frac(v: float, lo: float, hi: float) -> float:
	var span: float = hi - lo
	if span < 0.00001:
		return 0.5
	return clampf((v - lo) / span, 0.0, 1.0)
