class_name CloseContainerCommand
extends GameCommand
## 열어 둔 월드 컨테이너를 닫는다. 남은 아이템은 컨테이너에 그대로 있다.

var key: StringName


func _init(p_key: StringName) -> void:
	key = p_key


func execute(authority: GameAuthority) -> CommandResult:
	return authority.inventory.detach_external(key)
