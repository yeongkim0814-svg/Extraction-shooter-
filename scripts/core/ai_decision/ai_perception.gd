class_name AiPerception
extends RefCounted
## AI 감지 계산 (순수 함수): 시야 원뿔·시야 거리 보정·소음 반경과 청각.

const CROUCH_SIGHT_MULT: float = 0.6
const SPRINT_SIGHT_MULT: float = 1.25
## 총소리 반경 = 이 값 × 소음 스탯 (소음기 0.4배면 36 m).
const SHOT_NOISE_BASE: float = 90.0
const FOOTSTEP_SPRINT: float = 15.0
const FOOTSTEP_WALK: float = 7.0
const FOOTSTEP_CROUCH: float = 2.0


## target이 eye에서 forward 방향 시야각(전체 fov_deg, 가로·세로 모두 반각 적용) 안에 있고 max_distance 이내인가.
## 거리 0이면 보이는 것으로 친다. 벽 가림은 판단하지 않는다 (게임 계층의 레이캐스트 몫).
static func in_view_cone(eye: Vector3, forward: Vector3, target: Vector3, fov_deg: float,
		max_distance: float) -> bool:
	var to_target: Vector3 = target - eye
	var distance: float = to_target.length()
	if distance <= 0.0001:
		return true
	if distance > max_distance:
		return false
	var fwd: Vector3 = forward.normalized()
	if fwd == Vector3.ZERO:
		return false
	var half: float = deg_to_rad(clampf(fov_deg, 0.0, 360.0) * 0.5)
	var dir: Vector3 = to_target / distance
	# 가로: 수평면으로 투영한 방향끼리의 각도, 세로: 피치 차이
	var flat_f := Vector2(fwd.x, fwd.z)
	var flat_d := Vector2(dir.x, dir.z)
	if flat_f.length() > 0.0001 and flat_d.length() > 0.0001:
		if absf(flat_f.angle_to(flat_d)) > half:
			return false
	var pitch_f: float = asin(clampf(fwd.y, -1.0, 1.0))
	var pitch_d: float = asin(clampf(dir.y, -1.0, 1.0))
	return absf(pitch_d - pitch_f) <= half


## 대상 자세에 따라 보정한 시야 거리. 앉으면 ×0.6, 달리면 ×1.25 (둘 다면 앉기가 우선).
static func sight_distance(base: float, target_crouching: bool, target_sprinting: bool) -> float:
	if target_crouching:
		return base * CROUCH_SIGHT_MULT
	if target_sprinting:
		return base * SPRINT_SIGHT_MULT
	return base


## 소음이 listener에게 들리는가: 거리 <= 반경 × 청각 배율.
static func hears(noise_pos: Vector3, radius: float, listener: Vector3, hearing_mult: float) -> bool:
	return noise_pos.distance_to(listener) <= radius * hearing_mult


static func shot_noise_radius(loudness: float) -> float:
	return SHOT_NOISE_BASE * maxf(loudness, 0.0)


## 발소리 반경: 달리기 15, 걷기 7, 앉아 걷기 2, 정지 0.
static func footstep_noise_radius(sprinting: bool, crouching: bool, moving: bool) -> float:
	if not moving:
		return 0.0
	if crouching:
		return FOOTSTEP_CROUCH
	return FOOTSTEP_SPRINT if sprinting else FOOTSTEP_WALK
