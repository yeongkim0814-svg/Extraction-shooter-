class_name DamageModel
extends RefCounted
## 탄 관통력 vs 방탄 등급 판정 (MVP: 단일 HP).
## 방탄 수치 = 등급 × 10 × 내구도 비율. 관통 확률 = 0.5 + (관통력 − 방탄 수치) / 20, 0~1로 제한.
## 관통하면 전체 데미지, 막히면 둔기 피해(BLUNT_RATIO)만 들어간다.

const BLUNT_RATIO := 0.25
const PENETRATION_SPREAD := 20.0


class HitResult:
	var damage: float
	var penetrated: bool
	var armor_damage: float


static func penetration_chance(penetration: float, armor_class: int, durability_ratio: float) -> float:
	if armor_class <= 0 or durability_ratio <= 0.0:
		return 1.0
	var armor: float = armor_class * 10.0 * clampf(durability_ratio, 0.0, 1.0)
	return clampf(0.5 + (penetration - armor) / PENETRATION_SPREAD, 0.0, 1.0)


## 발사체 하나의 명중 판정. damage_mult는 무기 스탯 WeaponStats.DAMAGE_MULT.
static func resolve_hit(ammo: AmmoDef, damage_mult: float, armor_class: int,
		durability_ratio: float, rng: RandomNumberGenerator) -> HitResult:
	var result := HitResult.new()
	var full: float = ammo.damage * damage_mult
	var chance: float = penetration_chance(ammo.penetration, armor_class, durability_ratio)
	result.penetrated = chance >= 1.0 or rng.randf() < chance
	result.damage = full if result.penetrated else full * BLUNT_RATIO
	result.armor_damage = ammo.damage * ammo.armor_damage if armor_class > 0 else 0.0
	return result
