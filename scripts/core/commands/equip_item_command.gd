class_name EquipItemCommand
extends GameCommand

var item_id: int
var slot: EquipmentSlots.Slot


func _init(p_item_id: int, p_slot: EquipmentSlots.Slot) -> void:
	item_id = p_item_id
	slot = p_slot


func execute(authority: GameAuthority) -> CommandResult:
	return authority.inventory.equip(item_id, slot)
