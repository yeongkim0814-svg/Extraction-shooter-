class_name SearchContainerCommand
extends GameCommand
## 열어 둔 월드 컨테이너의 수색을 시작(start=true)하거나 중단한다.
## 중단 사유(이동·피격·사격)는 게임 계층이 판단해 start=false로 보낸다.

var key: StringName
var start: bool


func _init(p_key: StringName, p_start: bool = true) -> void:
	key = p_key
	start = p_start


func execute(authority: GameAuthority) -> CommandResult:
	var search: SearchState = authority.searches.get(key)
	if search == null or authority.inventory.get_grid(key) == null:
		return CommandResult.failure(CommandResult.UNKNOWN_CONTAINER)
	if start == search.searching:
		return CommandResult.success()
	if start:
		if search.is_complete():
			return CommandResult.success()
		search.start()
	else:
		search.interrupt()
	return CommandResult.success([authority.search_event(key)])
