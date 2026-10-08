class_name DiscardItemCommand
extends GameCommand

var item_id: int


func _init(p_item_id: int) -> void:
	item_id = p_item_id


func execute(authority: GameAuthority) -> CommandResult:
	return authority.inventory.discard(item_id)
