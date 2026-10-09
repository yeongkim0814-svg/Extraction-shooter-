class_name ModCandidates
extends RefCounted
## 소켓 하나에 꽂을 수 있는 부품 후보 목록 (순수 로직). 플레이어가 접근할 수 있는 컨테이너
## (스태시(잠기지 않았을 때)·주머니·조끼·배낭)에 든 부품 아이템을 모두 모으고, 안 되는 것은 이유와 함께 비활성으로 보인다.

const SOURCE_KO: Dictionary[StringName, String] = {
	Inventory.STASH: "스태시",
	&"slot_rig": "조끼",
	&"slot_backpack": "배낭",
}
const ERROR_KO: Dictionary[StringName, String] = {
	WeaponAssembly.WRONG_PART_TYPE: "종류 불일치",
	WeaponAssembly.PART_NOT_ALLOWED: "이 소켓에는 쓸 수 없음",
	WeaponAssembly.SOCKET_OCCUPIED: "이미 장착됨",
	WeaponAssembly.CONFLICT: "충돌",
	CommandResult.NO_SPACE: "공간 부족",
	CommandResult.STASH_LOCKED: "스태시 잠김",
}


## 후보 한 줄.
class Candidate:
	var item: ItemInstance
	var part: WeaponPartDef
	## 비어 있으면 장착 가능. 아니면 WeaponAssembly의 오류 코드 또는 NO_SPACE.
	var error: StringName = &""
	var reason: String = ""
	var source: String = ""

	func enabled() -> bool:
		return error == &""


static func reason_text(error: StringName) -> String:
	return ERROR_KO.get(error, String(error))


## 후보를 모은다. 사용 가능한 것이 앞, 같은 그룹에서는 이름순.
static func collect(inventory: Inventory, content: ContentDatabase, weapon: ItemInstance,
		parent_path: Array[StringName], socket_name: StringName) -> Array[Candidate]:
	var result: Array[Candidate] = []
	if weapon == null or weapon.weapon == null or content == null:
		return result
	for item: ItemInstance in inventory.get_items():
		if item == weapon or item.def.category != ItemDef.Category.ATTACHMENT:
			continue
		var part: WeaponPartDef = content.get_part(item.def.id)
		if part == null:
			continue
		var source: String = source_of(inventory, item)
		if source.is_empty():
			continue
		var candidate := Candidate.new()
		candidate.item = item
		candidate.part = part
		candidate.source = source
		candidate.error = weapon.weapon.can_attach_node(parent_path, socket_name, WeaponPartNode.new(part))
		if candidate.error == WeaponAssembly.OK:
			candidate.error = &""
			if not has_space(inventory, weapon, item, parent_path, socket_name, part):
				candidate.error = CommandResult.NO_SPACE
		candidate.reason = _reason(candidate, weapon, content)
		result.append(candidate)
	result.sort_custom(func(a: Candidate, b: Candidate) -> bool:
		if a.enabled() != b.enabled():
			return a.enabled()
		var name_a: String = ModTree.part_name(a.part, content)
		var name_b: String = ModTree.part_name(b.part, content)
		if name_a != name_b:
			return name_a < name_b
		return a.item.id < b.item.id)
	return result


## 부품 아이템이 놓인 곳의 이름 ("스태시"·"주머니"·"조끼"·"배낭"). 접근할 수 없는 곳(보안 컨테이너, 잠긴 스태시, 장비 칸)이면 빈 문자열.
static func source_of(inventory: Inventory, item: ItemInstance) -> String:
	if inventory.is_locked(item):
		return ""
	var key: StringName = item.container_key
	for _depth: int in range(8):
		var parsed: PackedStringArray = String(key).split("_")
		if parsed.size() == 3 and parsed[0] == "item" and parsed[1].is_valid_int():
			var owner: ItemInstance = inventory.get_item(parsed[1].to_int())
			if owner == null:
				return ""
			key = owner.container_key
		else:
			break
	if String(key).begins_with("pocket"):
		return "주머니"
	return SOURCE_KO.get(key, "")


## 부품을 달아서 커진 무기가 지금 자리에 들어가는지 (그리드 밖 장비 칸이면 항상 true). 아무것도 바꾸지 않는다.
static func has_space(inventory: Inventory, weapon: ItemInstance, part_item: ItemInstance,
		parent_path: Array[StringName], socket_name: StringName, part: WeaponPartDef) -> bool:
	var grid: ItemGrid = inventory.get_grid(weapon.container_key)
	if grid == null:
		return true
	var preview: ModStats.Preview = ModStats.preview_attach(weapon, parent_path, socket_name, part)
	if preview.error != WeaponAssembly.OK:
		return false
	for dx: int in range(preview.size.x):
		for dy: int in range(preview.size.y):
			var cell: Vector2i = weapon.position + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= grid.width or cell.y >= grid.height:
				return false
			var occupant: ItemInstance = grid.get_item_at(cell)
			if occupant != null and occupant != weapon and occupant != part_item:
				return false
	return true


static func _reason(candidate: Candidate, weapon: ItemInstance, content: ContentDatabase) -> String:
	if candidate.enabled():
		return ""
	var text: String = reason_text(candidate.error)
	if candidate.error == WeaponAssembly.CONFLICT:
		var other: String = _conflicting_part_name(weapon, candidate.part, content)
		if not other.is_empty():
			text += ": " + other
	return text


static func _conflicting_part_name(weapon: ItemInstance, part: WeaponPartDef, content: ContentDatabase) -> String:
	for existing: WeaponPartNode in weapon.weapon.get_parts():
		if existing.def.conflicts.has(part.id) or part.conflicts.has(existing.def.id):
			return ModTree.part_name(existing.def, content)
	return ""
