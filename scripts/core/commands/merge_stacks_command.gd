class_name MergeStacksCommand
extends GameCommand

var source_id: int
var target_id: int


func _init(p_source_id: int, p_target_id: int) -> void:
	source_id = p_source_id
	target_id = p_target_id


func execute(authority: GameAuthority) -> CommandResult:
	return authority.inventory.merge(source_id, target_id)
