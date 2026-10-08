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
