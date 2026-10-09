class_name OpenContainerCommand
extends GameCommand
## 월드 컨테이너(시체·상자)를 연다: 권한자에 등록된 그리드를 인벤토리에 붙인다.

var key: StringName


func _init(p_key: StringName) -> void:
	key = p_key


func execute(authority: GameAuthority) -> CommandResult:
	var grid: ItemGrid = authority.containers.get(key)
	if grid == null:
		return CommandResult.failure(CommandResult.UNKNOWN_CONTAINER)
	return authority.inventory.attach_external(key, grid, authority.searches.get(key))
