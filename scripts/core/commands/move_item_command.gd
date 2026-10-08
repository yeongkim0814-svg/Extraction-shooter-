class_name MoveItemCommand
extends GameCommand

var item_id: int
var target_key: StringName
var cell: Vector2i
var rotated: bool


func _init(p_item_id: int, p_target_key: StringName, p_cell: Vector2i, p_rotated: bool = false) -> void:
	item_id = p_item_id
	target_key = p_target_key
	cell = p_cell
	rotated = p_rotated


func execute(authority: GameAuthority) -> CommandResult:
	return authority.inventory.move_item(item_id, target_key, cell, rotated)
