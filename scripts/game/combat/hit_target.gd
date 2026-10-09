class_name HitTarget
extends Node
## 맞을 수 있는 대상에 붙이는 컴포넌트. 코어 Health를 들고 있고, 충돌체(또는 그 조상)의 자식으로 둔다.
## 무기 컨트롤러가 레이캐스트 충돌체에서 find_for()로 찾는다.

signal damaged(result: DamageModel.HitResult)
signal died

var health: Health = Health.new(100.0)
var display_name: String = "target"


## collider에서 시작해 조상 방향으로 올라가며 HitTarget 자식을 가진 첫 노드의 컴포넌트를 돌려준다.
static func find_for(collider: Node) -> HitTarget:
	var node: Node = collider
	while node != null:
		for child: Node in node.get_children():
			if child is HitTarget:
				return child as HitTarget
		node = node.get_parent()
	return null


## 탄 하나를 맞힌다. 이미 죽었으면 null.
func apply_hit(ammo: AmmoDef, damage_mult: float, rng: RandomNumberGenerator) -> DamageModel.HitResult:
	if health.is_dead():
		return null
	var result: DamageModel.HitResult = health.take_hit(ammo, damage_mult, rng)
	damaged.emit(result)
	if health.is_dead():
		died.emit()
	return result
