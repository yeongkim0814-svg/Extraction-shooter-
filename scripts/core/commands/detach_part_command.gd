class_name DetachPartCommand
extends GameCommand
## 무기 소켓의 부품을 떼어 인벤토리에 넣는다. 아래에 다른 부품이 달려 있으면 먼저 그것부터 떼야 한다.
## 넣을 곳 순서: 스태시(잠기지 않았으면) → 조끼 → 주머니 → 배낭. 자리가 없으면 실패하고 그대로 둔다.

var weapon_item_id: int
var parent_path: Array[StringName]
var socket_name: StringName


func _init(p_weapon_item_id: int, p_parent_path: Array[StringName], p_socket_name: StringName) -> void:
	weapon_item_id = p_weapon_item_id
	parent_path = p_parent_path
	socket_name = p_socket_name


func execute(authority: GameAuthority) -> CommandResult:
	var inv: Inventory = authority.inventory
	var weapon: ItemInstance = inv.get_item(weapon_item_id)
	if weapon == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	if weapon.weapon == null:
		return CommandResult.failure(CommandResult.NOT_A_WEAPON)
	if inv.is_locked(weapon):
		return CommandResult.failure(CommandResult.STASH_LOCKED)
	var path: Array[StringName] = parent_path.duplicate()
	path.append(socket_name)
	var node: WeaponPartNode = weapon.weapon.find_node(path)
	if node == null or path.is_empty():
		return CommandResult.failure(WeaponAssembly.UNKNOWN_SOCKET)
	if not node.children.is_empty():
		return CommandResult.failure(CommandResult.HAS_ATTACHMENTS)
	var part_item: ItemInstance = node.item
	if part_item == null:
		# 데이터에 기본으로 달린 부품: 같은 id의 아이템 정의가 있어야 뗄 수 있다.
		var item_def: ItemDef = authority.content.get_item(node.def.id) if authority.content != null else null
		if item_def == null:
			return CommandResult.failure(CommandResult.NOT_A_PART)
		part_item = authority.create_item(item_def)

	var assembly: WeaponAssembly = weapon.weapon
	inv.try_reshape(weapon.id,
			func() -> void: assembly.detach(parent_path, socket_name),
			func() -> void: assembly.attach_node(parent_path, socket_name, node))
	var keys: Array[StringName] = []
	if inv.get_grid(Inventory.STASH) != null and not inv.stash_locked:
		keys.append(Inventory.STASH)
	keys.append_array(ReloadCommand.search_keys(inv))
	var added: CommandResult = inv.auto_add_item(part_item, keys)
	if not added.ok:
		# 작아진 무기를 원래 크기로 되돌린다 (방금까지 그 크기로 있었으므로 항상 들어간다).
		inv.try_reshape(weapon.id,
				func() -> void: assembly.attach_node(parent_path, socket_name, node),
				func() -> void: assembly.detach(parent_path, socket_name))
		return CommandResult.failure(CommandResult.NO_SPACE)
	node.item = null
	var events: Array[DomainEvent] = added.events
	events.append(AttachPartCommand._weapon_changed(weapon))
	return CommandResult.success(events)
