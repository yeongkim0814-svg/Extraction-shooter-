class_name SplitStackCommand
extends GameCommand
## 새 스택의 id는 권한자가 발급한다 (실패하면 소비하지 않음).

var item_id: int
var amount: int
var target_key: StringName
var cell: Vector2i
var rotated: bool


func _init(p_item_id: int, p_amount: int, p_target_key: StringName, p_cell: Vector2i,
		p_rotated: bool = false) -> void:
	item_id = p_item_id
	amount = p_amount
	target_key = p_target_key
	cell = p_cell
	rotated = p_rotated


func execute(authority: GameAuthority) -> CommandResult:
	var result: CommandResult = authority.inventory.split(
			item_id, amount, authority.ids.peek(), target_key, cell, rotated)
	if result.ok:
		authority.ids.next_id()
	return result
