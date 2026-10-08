class_name AmmoDef
extends Resource
## 탄종 정의. id는 대응하는 탄약 ItemDef.id와 같다.

@export var id: StringName = &""
@export var caliber: StringName = &""
@export var damage: float = 40.0
## 방탄 등급 1당 10으로 비교한다 (DamageModel 참고).
@export var penetration: float = 20.0
## 맞힌 방탄복 내구도를 damage × 이 비율만큼 깎는다.
@export var armor_damage: float = 0.4
## 산탄은 1발에 여러 발사체 (각각 따로 판정).
@export var projectile_count: int = 1


static func create(p_id: StringName, p_caliber: StringName, p_damage: float,
		p_penetration: float) -> AmmoDef:
	var def := AmmoDef.new()
	def.id = p_id
	def.caliber = p_caliber
	def.damage = p_damage
	def.penetration = p_penetration
	return def
