class_name StatModifiers
extends Resource
## 부품 하나가 무기 스탯에 주는 영향. 최종값 = (기본 + 가산 합) × 배율 곱.

@export var additive: Dictionary[StringName, float] = {}
@export var multiplier: Dictionary[StringName, float] = {}
