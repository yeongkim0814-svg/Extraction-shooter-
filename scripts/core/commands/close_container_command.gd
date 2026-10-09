class_name CloseContainerCommand
extends GameCommand
## 열어 둔 월드 컨테이너를 닫는다. 남은 아이템은 컨테이너에 그대로 있다.

var key: StringName


func _init(p_key: StringName) -> void:
	key = p_key


## 수색 중이었다면 중단된다 (진행 중이던 아이템의 진행도만 잃는다).
func execute(authority: GameAuthority) -> CommandResult:
	var result: CommandResult = authority.inventory.detach_external(key)
	var search: SearchState = authority.searches.get(key)
	if result.ok and search != null and search.searching:
		search.interrupt()
		result.events.append(authority.search_event(key))
	return result
