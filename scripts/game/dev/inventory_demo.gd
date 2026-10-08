extends Control
## M5 인벤토리 UI 데모: 샘플 아이템으로 인벤토리를 만들고 화면을 붙인다.
## 웹 스모크 테스트가 읽는 로그: "INVENTORY_DEMO: ready", "... event <type> <item_id>", "... item <id> at x,y size WxH"

const SCREEN_SCENE: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")

var _authority: LocalAuthority
var _screen: InventoryScreen


func _ready() -> void:
	_authority = LocalAuthority.new(Inventory.new(Vector2i(10, 30)))
	_populate(_authority)
	_screen = SCREEN_SCENE.instantiate() as InventoryScreen
	add_child(_screen)
	_screen.setup(_authority)
	_authority.events_emitted.connect(_on_events)
	# 레이아웃이 확정된 뒤 좌표를 출력하고 ready 신호를 낸다
	await get_tree().process_frame
	await get_tree().process_frame
	_print_layout()
	print("INVENTORY_DEMO: ready")


func _on_events(events: Array[DomainEvent]) -> void:
	for event: DomainEvent in events:
		print("INVENTORY_DEMO: event %s %d" % [event.type, int(event.data.get("item_id", 0))])


## 스모크 테스트용: 창 픽셀 좌표(스트레치 반영)로 스태시 기준점과 몇몇 아이템 위치를 출력한다.
func _print_layout() -> void:
	var to_window: Transform2D = get_viewport().get_screen_transform()
	var cell: float = float(InventoryItemPainter.CELL_SIZE) * to_window.get_scale().x
	var origin: Vector2 = to_window * _screen.stash_view().global_position
	print("INVENTORY_DEMO: stash origin=%d,%d cell=%d" % [origin.x, origin.y, cell])
	for item_id: int in [1, 2, 3, 6, 10]:
		var item: ItemInstance = _authority.inventory.get_item(item_id)
		var rect: Rect2 = _screen.item_global_rect(item_id)
		var top_left: Vector2 = to_window * rect.position
		var win_size: Vector2 = rect.size * to_window.get_scale()
		print("INVENTORY_DEMO: item %d at %d,%d size %dx%d (%s)" % [
				item_id, top_left.x, top_left.y, win_size.x, win_size.y, item.def.id])


func _populate(authority: LocalAuthority) -> void:
	var inv: Inventory = authority.inventory
	var pistol: ItemDef = _def(&"pistol", "권총", ItemDef.Category.WEAPON, 2, 1)
	var rifle: ItemDef = _def(&"rifle", "소총", ItemDef.Category.WEAPON, 5, 2)
	var ammo_9: ItemDef = _def(&"ammo_9mm", "9mm 탄", ItemDef.Category.AMMO, 1, 1, 60)
	var ammo_556: ItemDef = _def(&"ammo_556", "5.56 탄", ItemDef.Category.AMMO, 1, 1, 60)
	var bandage: ItemDef = _def(&"bandage", "붕대", ItemDef.Category.MEDICAL, 1, 1, 4)
	var medkit: ItemDef = _def(&"medkit", "구급상자", ItemDef.Category.MEDICAL, 2, 2)
	var chain: ItemDef = _def(&"gold_chain", "금 사슬", ItemDef.Category.VALUABLE, 1, 1)
	var gpu: ItemDef = _def(&"gpu", "그래픽카드", ItemDef.Category.VALUABLE, 2, 1)
	var helmet: ItemDef = _def(&"helmet", "헬멧", ItemDef.Category.HELMET, 2, 2)
	var armor: ItemDef = _def(&"armor", "방탄복", ItemDef.Category.ARMOR, 3, 3)
	var backpack: ItemDef = _def(&"backpack", "배낭", ItemDef.Category.BACKPACK, 4, 5)
	backpack.grids = [Vector2i(5, 6)]
	var rig: ItemDef = _def(&"rig", "전술 조끼", ItemDef.Category.RIG, 3, 3)
	rig.grids = [Vector2i(1, 2), Vector2i(1, 2), Vector2i(1, 2), Vector2i(1, 2)]

	# id 1~: 스모크 테스트가 id로 찾는다 (1 = 권총). 스태시 배치.
	_put(authority, pistol, 1, Inventory.STASH, Vector2i(0, 0))
	_put(authority, pistol, 1, Inventory.STASH, Vector2i(2, 0))
	_put(authority, rifle, 1, Inventory.STASH, Vector2i(4, 0))
	_put(authority, medkit, 1, Inventory.STASH, Vector2i(0, 1))
	_put(authority, chain, 1, Inventory.STASH, Vector2i(2, 1))
	_put(authority, bandage, 3, Inventory.STASH, Vector2i(3, 1))
	_put(authority, gpu, 1, Inventory.STASH, Vector2i(2, 2))
	_put(authority, ammo_9, 30, Inventory.STASH, Vector2i(0, 3))
	_put(authority, ammo_9, 45, Inventory.STASH, Vector2i(1, 3))
	_put(authority, ammo_556, 60, Inventory.STASH, Vector2i(2, 3))
	_put(authority, ammo_556, 25, Inventory.STASH, Vector2i(3, 3))
	_put(authority, helmet, 1, Inventory.STASH, Vector2i(0, 5))
	_put(authority, armor, 1, Inventory.STASH, Vector2i(2, 5))
	var pack: ItemInstance = _put(authority, backpack, 1, Inventory.STASH, Vector2i(6, 3))
	var vest: ItemInstance = _put(authority, rig, 1, Inventory.STASH, Vector2i(6, 8))
	# 배낭·리그 장착 (이벤트 없이 초기 상태로 만든다), 그 안과 주머니에 몇 개
	inv.equip(pack.id, EquipmentSlots.Slot.BACKPACK)
	inv.equip(vest.id, EquipmentSlots.Slot.RIG)
	_put(authority, bandage, 2, Inventory.pocket_key(0), Vector2i.ZERO)
	_put(authority, ammo_9, 20, Inventory.pocket_key(1), Vector2i.ZERO)
	_put(authority, medkit, 1, Inventory.item_grid_key(pack.id, 0), Vector2i(0, 0))
	_put(authority, gpu, 1, Inventory.item_grid_key(pack.id, 0), Vector2i(2, 0))
	_put(authority, ammo_556, 30, Inventory.item_grid_key(vest.id, 0), Vector2i(0, 0))
	_put(authority, chain, 1, Inventory.item_grid_key(vest.id, 2), Vector2i(0, 1))


func _def(id: StringName, display_name: String, category: ItemDef.Category, width: int, height: int,
		max_stack: int = 1) -> ItemDef:
	var def: ItemDef = ItemDef.create(id, width, height, max_stack)
	def.display_name = display_name
	def.category = category
	return def


func _put(authority: LocalAuthority, def: ItemDef, count: int, key: StringName, cell: Vector2i) -> ItemInstance:
	var item: ItemInstance = authority.create_item(def, count)
	var result: CommandResult = authority.inventory.add_item(item, key, cell, false)
	assert(result.ok, "demo item placement failed: %s" % def.id)
	return item
