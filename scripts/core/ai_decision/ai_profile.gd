class_name AiProfile
extends Resource
## AI 성향 수치 (초 단위). 적 종류별로 .tres로 만든다.

## 목표를 계속 봐야 교전으로 넘어가는 시간.
@export var reaction_time: float = 0.6
## 의심 상태를 유지하는 시간.
@export var suspicion_time: float = 6.0
## 교전 중 목표를 놓친 채 버티는 시간.
@export var lose_target_time: float = 4.0
@export var search_duration: float = 15.0
## 체력 비율이 이 값 미만이면 엄폐한다.
@export_range(0.0, 1.0) var cover_health_ratio: float = 0.35
## 엄폐 최대 유지 시간.
@export var cover_time: float = 5.0

# --- M8: 감지·사격·이동 수치 (위 필드 뒤에 추가) ---

## 시야 최대 거리 (m). 대상이 앉거나 달리면 AiPerception.sight_distance가 보정한다.
@export var view_distance: float = 45.0
## 시야각 전체 (도). 정면 기준 좌우·상하 반각은 이 값의 절반.
@export var fov_deg: float = 110.0
## 청각 배율. 소음 반경에 곱해서 들리는 거리를 정한다.
@export var hearing_mult: float = 1.0
## 시야를 새로 잡았을 때의 조준 퍼짐 (도).
@export var aim_spread_start_deg: float = 6.0
## 충분히 조준했을 때의 최소 퍼짐 (도).
@export var aim_spread_min_deg: float = 1.5
## 퍼짐이 시작값에서 최소값까지 줄어드는 데 걸리는 연속 시야 시간 (초).
@export var aim_settle_time: float = 2.0
## 한 번에 쏘는 연사 발수 범위.
@export var burst_min: int = 2
@export var burst_max: int = 4
## 연사와 연사 사이 쉬는 시간 (초).
@export var burst_pause: float = 0.7
## 재장전에 걸리는 시간 (초).
@export var reload_time: float = 2.5
## 적이 쏜 탄의 데미지 배율 (플레이어가 너무 빨리 죽지 않게 낮춘다).
@export var damage_mult: float = 0.6
## 순찰·수색 걸음 속도 (m/s).
@export var walk_speed: float = 2.2
## 교전·엄폐 이동 속도 (m/s).
@export var run_speed: float = 4.2
## 몸이 목표 방향으로 도는 속도 (rad/s).
@export var turn_speed: float = 6.0
