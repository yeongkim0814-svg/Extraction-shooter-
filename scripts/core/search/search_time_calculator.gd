class_name SearchTimeCalculator
extends RefCounted
## 아이템 하나를 공개하는 데 걸리는 시간.
## 시간 = 기본값 × (1 + 칸당 계수 × (칸 수 − 1)) × 희귀도 배율 ÷ 수색 속도, MIN~MAX초로 제한.
## 희귀도는 기준가(base_price)로 판단한다.

const MIN_TIME := 0.5
const MAX_TIME := 3.0

var base_time: float = 0.8
var per_cell_factor: float = 0.15
## 스킬·장비 보정 (1 = 기본, 클수록 빠름).
var speed_multiplier: float = 1.0
## [기준가 하한, 배율] — 위에서부터 처음 만족하는 값을 쓴다.
var rarity_tiers: Array[Vector2] = [
	Vector2(50000, 2.0),
	Vector2(20000, 1.6),
	Vector2(5000, 1.3),
	Vector2(0, 1.0),
]


func time_for(def: ItemDef) -> float:
	var cells: int = def.width * def.height
	var t: float = base_time * (1.0 + per_cell_factor * (cells - 1)) * rarity_multiplier(def.base_price)
	return clampf(t / maxf(speed_multiplier, 0.01), MIN_TIME, MAX_TIME)


func rarity_multiplier(base_price: int) -> float:
	for tier: Vector2 in rarity_tiers:
		if base_price >= tier.x:
			return tier.y
	return 1.0
