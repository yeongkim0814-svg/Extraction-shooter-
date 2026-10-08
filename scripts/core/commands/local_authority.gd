class_name LocalAuthority
extends GameAuthority
## 싱글플레이(PvE)용 권한자: 명령을 즉시 로컬에서 실행한다.


func execute(command: GameCommand) -> CommandResult:
	var result: CommandResult = command.execute(self)
	if result.ok and not result.events.is_empty():
		events_emitted.emit(result.events)
	return result
