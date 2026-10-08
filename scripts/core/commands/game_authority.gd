class_name GameAuthority
extends RefCounted
## 게임 상태 변경의 유일한 통로. id 발급도 권한자만 한다.
## PvE에서는 LocalAuthority, 멀티 단계에서는 서버 권한 구현으로 교체한다.

## 성공한 명령의 이벤트. UI·사운드가 구독한다.
signal events_emitted(events: Array[DomainEvent])

var inventory: Inventory
var ids := IdGenerator.new()


func _init(p_inventory: Inventory) -> void:
	inventory = p_inventory


func execute(_command: GameCommand) -> CommandResult:
	return CommandResult.failure(CommandResult.NOT_IMPLEMENTED)


## 권한자 id로 새 아이템을 만든다 (루팅 스폰·상점 구매 등). 인벤토리에 넣지는 않는다.
func create_item(def: ItemDef, stack_count: int = 1) -> ItemInstance:
	return ItemInstance.new(ids.next_id(), def, stack_count)
