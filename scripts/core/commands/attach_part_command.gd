class_name AttachPartCommand
extends GameCommand
## 인벤토리의 부품 아이템을 무기의 소켓에 장착한다 (총기 모딩).
## 부품 아이템은 인벤토리에서 빠져 부품 트리 노드에 붙는다. 무기 크기가 커져 그리드에 안 들어가면 실패.

var weapon_item_id: int
var parent_path: Array[StringName]
var socket_name: StringName
var part_item_id: int


func _init(p_weapon_item_id: int, p_parent_path: Array[StringName], p_socket_name: StringName,
		p_part_item_id: int) -> void:
	weapon_item_id = p_weapon_item_id
	parent_path = p_parent_path
	socket_name = p_socket_name
	part_item_id = p_part_item_id


func execute(authority: GameAuthority) -> CommandResult:
	var inv: Inventory = authority.inventory
	var weapon: ItemInstance = inv.get_item(weapon_item_id)
	var part_item: ItemInstance = inv.get_item(part_item_id)
	if weapon == null or part_item == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	if weapon.weapon == null:
		return CommandResult.failure(CommandResult.NOT_A_WEAPON)
	var part_def: WeaponPartDef = authority.content.get_part(part_item.def.id) \
			if authority.content != null else null
	if part_def == null:
		return CommandResult.failure(CommandResult.NOT_A_PART)
	if inv.is_locked(weapon) or inv.is_locked(part_item):
		return CommandResult.failure(CommandResult.STASH_LOCKED)
	var node := WeaponPartNode.new(part_def)
	node.item = part_item
	var error: StringName = weapon.weapon.can_attach_node(parent_path, socket_name, node)
	if error != WeaponAssembly.OK:
		return CommandResult.failure(error)

	# 부품을 먼저 빼서 그 자리가 비면 커진 무기가 들어갈 수도 있다. 실패하면 원위치로 되돌린다.
	var old_key: StringName = part_item.container_key
	var old_cell: Vector2i = part_item.position
	var old_rotated: bool = part_item.rotated
	var events: Array[DomainEvent] = inv.discard(part_item.id).events
	var assembly: WeaponAssembly = weapon.weapon
	var fitted: bool = inv.try_reshape(weapon.id,
			func() -> void: assembly.attach_node(parent_path, socket_name, node),
			func() -> void: assembly.detach(parent_path, socket_name))
	if not fitted:
		inv.add_item(part_item, old_key, old_cell, old_rotated)
		return CommandResult.failure(CommandResult.NO_SPACE)
	events.append(_weapon_changed(weapon))
	return CommandResult.success(events)


static func _weapon_changed(weapon: ItemInstance) -> DomainEvent:
	var size: Vector2i = weapon.size_for(false)
	return DomainEvent.new(DomainEvent.WEAPON_CHANGED,
			{"item_id": weapon.id, "size": [size.x, size.y]})
