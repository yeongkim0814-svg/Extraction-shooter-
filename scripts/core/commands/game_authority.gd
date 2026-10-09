class_name GameAuthority
extends RefCounted
## 게임 상태 변경의 유일한 통로. id 발급도 권한자만 한다.
## PvE에서는 LocalAuthority, 멀티 단계에서는 서버 권한 구현으로 교체한다.

## 성공한 명령의 이벤트. UI·사운드가 구독한다.
signal events_emitted(events: Array[DomainEvent])

var inventory: Inventory
var ids := IdGenerator.new()
## 탄종 등 정의 조회 (재장전에 필요). 없으면 재장전 불가.
var content: ContentDatabase = null
## 월드 컨테이너(시체·상자): 키(&"loot_<번호>") → 그리드. 권한자가 소유하고, 열면 인벤토리에 붙는다.
var containers: Dictionary[StringName, ItemGrid] = {}
## 월드 컨테이너의 화면 표시 이름.
var container_titles: Dictionary[StringName, String] = {}
## 수색이 필요한 월드 컨테이너의 수색 상태. 공개 여부의 판정은 권한자만 한다.
var searches: Dictionary[StringName, SearchState] = {}


func _init(p_inventory: Inventory) -> void:
	inventory = p_inventory


func execute(_command: GameCommand) -> CommandResult:
	return CommandResult.failure(CommandResult.NOT_IMPLEMENTED)


## 권한자 id로 새 아이템을 만든다 (루팅 스폰·상점 구매 등). 인벤토리에 넣지는 않는다.
func create_item(def: ItemDef, stack_count: int = 1) -> ItemInstance:
	return ItemInstance.new(ids.next_id(), def, stack_count)


## 월드 컨테이너를 등록하고 키를 발급한다 (아이템 id와 같은 발급기를 써서 겹치지 않는다).
## searchable이면 내용물이 "?"로 시작하고 수색해야 공개된다.
func register_container(grid: ItemGrid, title: String, searchable: bool = true) -> StringName:
	var key: StringName = Inventory.external_key(ids.next_id())
	containers[key] = grid
	container_titles[key] = title
	if searchable:
		searches[key] = SearchState.new(grid)
	return key


## 진행 중인 수색을 delta초 진행한다 (매 프레임 게임 계층이 부른다).
## 공개·완료 이벤트를 events_emitted로 내보내고, 이번에 발생한 수색 소음량 합을 돌려준다.
func tick_searches(delta: float) -> float:
	var events: Array[DomainEvent] = []
	var noise: float = 0.0
	for key: StringName in searches:
		var search: SearchState = searches[key]
		if not search.searching:
			continue
		var result: SearchState.TickResult = search.tick(delta)
		noise += result.noise
		for item: ItemInstance in result.revealed:
			events.append(DomainEvent.new(DomainEvent.ITEM_REVEALED, {"container": key, "item_id": item.id}))
		if not search.searching:
			events.append(search_event(key))
	if not events.is_empty():
		events_emitted.emit(events)
	return noise


func search_event(key: StringName) -> DomainEvent:
	var search: SearchState = searches.get(key)
	return DomainEvent.new(DomainEvent.SEARCH_CHANGED, {"container": key,
			"searching": search != null and search.searching,
			"complete": search == null or search.is_complete()})
