class_name GameCommand
extends RefCounted
## 상태 변경 요청. 직렬화 가능한 값(id·키·좌표)만 담고, 권한자(GameAuthority)가 실행한다.
## 멀티 단계에서는 클라이언트가 이 명령을 서버로 보내고 서버만 execute한다.


func execute(_authority: GameAuthority) -> CommandResult:
	return CommandResult.failure(CommandResult.NOT_IMPLEMENTED)
