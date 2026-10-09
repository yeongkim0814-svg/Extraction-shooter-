class_name FireMath
extends RefCounted
## 사격 계산 (순수 함수, rng 주입): 탄 퍼짐 방향, ADS 보정, 반동 킥.

## ADS 중 퍼짐 배율.
const ADS_SPREAD_MULT: float = 0.4
## 반동 스탯 1당 피치 킥(도). 소총 RECOIL 30 → 1.5도.
const RECOIL_DEG_PER_POINT: float = 0.05
const ADS_RECOIL_MULT: float = 0.7
## 좌우 킥은 피치 킥의 이 비율 안에서 무작위.
const YAW_KICK_RATIO: float = 0.3


static func effective_spread_deg(spread_deg: float, ads: bool) -> float:
	return maxf(spread_deg, 0.0) * (ADS_SPREAD_MULT if ads else 1.0)


## basis의 앞쪽(-Z)을 중심으로 반각 spread_deg 원뿔 안에서 균일하게 고른 방향.
static func spread_direction(basis: Basis, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	var forward: Vector3 = -basis.z
	var half_angle: float = deg_to_rad(maxf(spread_deg, 0.0))
	if half_angle <= 0.0:
		return forward
	var theta: float = half_angle * sqrt(rng.randf())
	var phi: float = TAU * rng.randf()
	var side: Vector3 = basis.x * cos(phi) + basis.y * sin(phi)
	return (forward * cos(theta) + side * sin(theta)).normalized()


## 한 발의 카메라 킥 (라디안): x = 위로 올라가는 양, y = 좌우.
static func recoil_kick(recoil: float, ads: bool, rng: RandomNumberGenerator) -> Vector2:
	var pitch: float = deg_to_rad(maxf(recoil, 0.0) * RECOIL_DEG_PER_POINT)
	if ads:
		pitch *= ADS_RECOIL_MULT
	return Vector2(pitch, pitch * YAW_KICK_RATIO * rng.randf_range(-1.0, 1.0))
