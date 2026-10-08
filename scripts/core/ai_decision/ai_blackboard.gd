class_name AiBlackboard
extends RefCounted
## 게임 계층이 채우고 AiBrain이 읽는 감지·상태 값 모음.

var can_see_target: bool = false
## 1회성: 두뇌가 읽은 뒤 false로 되돌린다.
var heard_noise: bool = false
var health_ratio: float = 1.0
var ammo_in_mag: int = 30
var in_cover: bool = false
var at_patrol_route: bool = false
var target_position: Vector3 = Vector3.ZERO
var last_known_position: Vector3 = Vector3.ZERO
var noise_position: Vector3 = Vector3.ZERO
