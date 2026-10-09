class_name InteractionFinder
extends RefCounted
## 플레이어 근처에서 상호작용할 대상(시체·루팅 컨테이너·스위치)을 하나 고른다.
## 선택 규칙은 정적 함수(pick_index)에 있어 씬 없이 테스트할 수 있다.

enum Kind { CORPSE, CONTAINER, SWITCH }

## 상호작용 가능 거리 (m).
const RANGE: float = 2.5
## 대상이 정면에서 이 각도(코사인) 안에 있어야 한다.
const FACING_DOT: float = 0.5
## 이 거리 안이면 시선과 상관없이 대상이 된다 (발밑의 시체 등).
const POINT_BLANK: float = 0.8


class Target:
	var kind: Kind = Kind.CORPSE
	## 루팅 컨테이너 키 (스위치는 &"").
	var key: StringName = &""
	var position: Vector3 = Vector3.ZERO
	var node: Node = null
	## HUD 버튼 문구 ("루팅", "열기", "작동").
	var prompt: String = ""


## 후보 위치 중 상호작용할 인덱스. 없으면 -1.
## 수평 거리가 range_ 이하이고 (POINT_BLANK 안이거나) 시선과 이루는 코사인이 facing_dot 이상인 것 중 가장 가까운 것.
static func pick_index(origin: Vector3, forward: Vector3, positions: Array[Vector3],
		range_: float = RANGE, facing_dot: float = FACING_DOT) -> int:
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	flat_forward = flat_forward.normalized() if flat_forward.length() > 0.001 else Vector3.ZERO
	var best: int = -1
	var best_dist: float = range_
	for i: int in range(positions.size()):
		var offset: Vector3 = positions[i] - origin
		offset.y = 0.0
		var dist: float = offset.length()
		if dist > best_dist:
			continue
		if dist > POINT_BLANK and flat_forward.dot(offset / dist) < facing_dot:
			continue
		best = i
		best_dist = dist
	return best


## 시체(죽고 루팅 키가 있는 적)·컨테이너·스위치 중 가장 가까운 대상. 없으면 null.
static func find(origin: Vector3, forward: Vector3, enemies: Array[EnemyAgent],
		containers: Array[LootContainer], switches: Array[PowerLever]) -> Target:
	var targets: Array[Target] = []
	for enemy: EnemyAgent in enemies:
		if not enemy.is_dead() or enemy.loot_key() == &"":
			continue
		targets.append(_make(Kind.CORPSE, enemy.loot_key(), enemy.corpse_position(), enemy, "루팅"))
	for container: LootContainer in containers:
		if container.loot_key == &"":
			continue
		targets.append(_make(Kind.CONTAINER, container.loot_key, container.interact_position(), container, "열기"))
	for lever: PowerLever in switches:
		if lever.activated:
			continue
		targets.append(_make(Kind.SWITCH, &"", lever.interact_position(), lever, "작동"))
	var positions: Array[Vector3] = []
	for target: Target in targets:
		positions.append(target.position)
	var index: int = pick_index(origin, forward, positions)
	return targets[index] if index >= 0 else null


static func _make(kind: Kind, key: StringName, position: Vector3, node: Node, prompt: String) -> Target:
	var target := Target.new()
	target.kind = kind
	target.key = key
	target.position = position
	target.node = node
	target.prompt = prompt
	return target
