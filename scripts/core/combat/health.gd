class_name Health
extends RefCounted
## MVP 체력 모델: 단일 HP + 방탄복(등급·내구도) + 출혈 1종.
## 관통하고 데미지가 BLEED_THRESHOLD 이상이면 출혈이 시작되어 초당 BLEED_DPS씩 줄어든다.

const BLEED_THRESHOLD := 20.0
const BLEED_DPS := 1.5

var max_hp: float
var hp: float
var bleeding: bool = false
var armor_class: int = 0
var armor_durability: float = 0.0
var armor_max_durability: float = 0.0


func _init(p_max_hp: float = 100.0) -> void:
	max_hp = p_max_hp
	hp = p_max_hp


func set_armor(p_class: int, max_durability: float) -> void:
	armor_class = p_class
	armor_max_durability = max_durability
	armor_durability = max_durability


func armor_ratio() -> float:
	if armor_class <= 0 or armor_max_durability <= 0.0:
		return 0.0
	return armor_durability / armor_max_durability


func is_dead() -> bool:
	return hp <= 0.0


## 발사체 하나를 맞는다. 방탄복 판정 → 내구도 감소 → HP 감소 → 출혈 판정.
func take_hit(ammo: AmmoDef, damage_mult: float, rng: RandomNumberGenerator) -> DamageModel.HitResult:
	var effective_class: int = armor_class if armor_durability > 0.0 else 0
	var result: DamageModel.HitResult = DamageModel.resolve_hit(
			ammo, damage_mult, effective_class, armor_ratio(), rng)
	armor_durability = maxf(armor_durability - result.armor_damage, 0.0)
	hp = maxf(hp - result.damage, 0.0)
	if result.penetrated and result.damage >= BLEED_THRESHOLD:
		bleeding = true
	return result


func tick(delta: float) -> void:
	if bleeding and not is_dead():
		hp = maxf(hp - BLEED_DPS * delta, 0.0)


func stop_bleeding() -> void:
	bleeding = false


func heal(amount: float) -> void:
	if not is_dead():
		hp = minf(hp + amount, max_hp)
