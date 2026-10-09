extends Control
## M5 인벤토리 UI 데모: 샘플 아이템으로 인벤토리를 만들고 화면을 붙인다.
## 웹 스모크 테스트가 읽는 로그 (모든 좌표는 창 픽셀, 스트레치 반영):
##   "INVENTORY_DEMO: ready"
##   "INVENTORY_DEMO: event <type> <item_id> [to=<container>@x,y rot=0|1]"
##   "INVENTORY_DEMO: scroll left=N right=N"                        스크롤 위치가 바뀔 때마다
##   "INVENTORY_DEMO: stash origin=x,y cell=N"
##   "INVENTORY_DEMO: item <id> at x,y size WxH (<def id>)"       화면에 그려진 모든 아이템
##   "INVENTORY_DEMO: slot <NAME> at x,y size WxH"                 모든 장비 슬롯 박스
##   "INVENTORY_DEMO: role <name> id=<n>"                          스모크가 쓰는 아이템 id (glasses, backpack)
##   "INVENTORY_DEMO: scale S"                                     논리 → 창 픽셀 배율
##   "INVENTORY_DEMO: selected <id>" + "INVENTORY_DEMO: button <key> at x,y size WxH"   선택 직후 액션 바
##   "INVENTORY_DEMO: deselected"

const SCREEN_SCENE: PackedScene = preload("res://scenes/ui/inventory_screen.tscn")

var _authority: LocalAuthority
var _screen: InventoryScreen
var _glasses_id: int = 0
var _pack_id: int = 0
var _last_scroll: Vector2i = Vector2i.ZERO


func _ready() -> void:
	_authority = LocalAuthority.new(Inventory.new(Vector2i(10, 30)))
	_populate(_authority)
	_screen = SCREEN_SCENE.instantiate() as InventoryScreen
	add_child(_screen)
	_screen.setup(_authority)
	_authority.events_emitted.connect(_on_events)
	_screen.selection_changed.connect(_on_selection_changed)
	# 레이아웃이 확정된 뒤 좌표를 출력하고 ready 신호를 낸다
	await get_tree().process_frame
	await get_tree().process_frame
	_print_layout()
	print("INVENTORY_DEMO: ready")


func _process(_delta: float) -> void:
	if _screen == null:
		return
	var scroll: Vector2i = _screen.scroll_positions()
	if scroll != _last_scroll:
		_last_scroll = scroll
		print("INVENTORY_DEMO: scroll left=%d right=%d" % [scroll.x, scroll.y])


func _on_events(events: Array[DomainEvent]) -> void:
	for event: DomainEvent in events:
		var line: String = "INVENTORY_DEMO: event %s %d" % [event.type, int(event.data.get("item_id", 0))]
		var to: Variant = event.data.get("to")
		if to is Dictionary:
			var cell: Vector2i = (to as Dictionary).get("cell", Vector2i.ZERO)
			line += " to=%s@%d,%d rot=%d" % [(to as Dictionary).get("container", ""), cell.x, cell.y,
					int((to as Dictionary).get("rotated", false))]
		print(line)


func _on_selection_changed(item_id: int) -> void:
	# 액션 바 레이아웃이 확정된 뒤에 버튼 좌표를 출력한다 (그 사이 선택이 바뀌었으면 건너뜀)
	await get_tree().process_frame
	await get_tree().process_frame
	if _screen.selected_item_id() != item_id:
		return
	if item_id == 0:
		print("INVENTORY_DEMO: deselected")
		return
	print("INVENTORY_DEMO: selected %d" % item_id)
	for key: String in _screen.action_button_rects():
		print("INVENTORY_DEMO: button %s at %s" % [key, _win_rect(_screen.action_button_rects()[key])])


func _win_rect(rect: Rect2) -> String:
	var to_window: Transform2D = get_viewport().get_screen_transform()
	var top_left: Vector2 = to_window * rect.position
	var win_size: Vector2 = rect.size * to_window.get_scale()
	return "%d,%d size %dx%d" % [top_left.x, top_left.y, win_size.x, win_size.y]


## 스모크 테스트용: 창 픽셀 좌표로 스태시 기준점, 슬롯 박스, 아이템 위치를 출력한다.
func _print_layout() -> void:
	var to_window: Transform2D = get_viewport().get_screen_transform()
	var cell: float = float(_screen.cell_size()) * to_window.get_scale().x
	var origin: Vector2 = to_window * _screen.stash_view().global_position
	print("INVENTORY_DEMO: scale %f" % to_window.get_scale().x)
	print("INVENTORY_DEMO: stash origin=%d,%d cell=%d" % [origin.x, origin.y, cell])
	for slot: EquipmentSlots.Slot in _screen.all_slots():
		print("INVENTORY_DEMO: slot %s at %s" % [EquipmentSlots.Slot.keys()[slot], _win_rect(_screen.slot_global_rect(slot))])
	for item: ItemInstance in _authority.inventory.get_items():
		var rect: Rect2 = _screen.item_global_rect(item.id)
		if rect.has_area():
			print("INVENTORY_DEMO: item %d at %s (%s)" % [item.id, _win_rect(rect), item.def.id])
	print("INVENTORY_DEMO: role glasses id=%d" % _glasses_id)
	print("INVENTORY_DEMO: role backpack id=%d" % _pack_id)


func _populate(authority: LocalAuthority) -> void:
	var inv: Inventory = authority.inventory
	var pistol: ItemDef = _def(&"pistol", "권총", ItemDef.Category.PISTOL, 2, 1)
	var rifle: ItemDef = _def(&"rifle", "소총", ItemDef.Category.WEAPON, 5, 2)
	var shotgun: ItemDef = _def(&"shotgun", "샷건", ItemDef.Category.WEAPON, 5, 2)
	var knife: ItemDef = _def(&"knife", "단검", ItemDef.Category.MELEE, 1, 2)
	var balaclava: ItemDef = _def(&"balaclava", "발라클라바", ItemDef.Category.FACE_COVER, 1, 1)
	var headset: ItemDef = _def(&"headset", "헤드셋", ItemDef.Category.HEADSET, 2, 2)
	var glasses: ItemDef = _def(&"glasses", "안경", ItemDef.Category.EYEWEAR, 2, 1)
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
	rig.grids = [Vector2i(2, 2), Vector2i(2, 2), Vector2i(1, 3), Vector2i(1, 3), Vector2i(1, 3), Vector2i(1, 3)]
	rig.grid_offsets = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
	var safe: ItemDef = _def(&"safe_case", "보안 케이스", ItemDef.Category.SECURE_CONTAINER, 2, 2)
	safe.grids = [Vector2i(2, 2)]

	# id 1~: 스모크 테스트가 id로 찾는다 (1 = 스태시 권총, 3 = 스태시 소총). 스태시 배치.
	_put(authority, pistol, 1, Inventory.STASH, Vector2i(0, 0))
	var holstered: ItemInstance = _put(authority, pistol, 1, Inventory.STASH, Vector2i(2, 0))
	_put(authority, rifle, 1, Inventory.STASH, Vector2i(4, 0))
	_put(authority, medkit, 1, Inventory.STASH, Vector2i(0, 1))
	_put(authority, chain, 1, Inventory.STASH, Vector2i(2, 1))
	_put(authority, bandage, 3, Inventory.STASH, Vector2i(3, 1))
	_put(authority, gpu, 1, Inventory.STASH, Vector2i(2, 2))
	_put(authority, ammo_9, 30, Inventory.STASH, Vector2i(0, 3))
	_put(authority, ammo_9, 45, Inventory.STASH, Vector2i(1, 3))
	_put(authority, ammo_556, 60, Inventory.STASH, Vector2i(2, 3))
	_put(authority, ammo_556, 25, Inventory.STASH, Vector2i(3, 3))
	var worn_helmet: ItemInstance = _put(authority, helmet, 1, Inventory.STASH, Vector2i(0, 5))
	var worn_armor: ItemInstance = _put(authority, armor, 1, Inventory.STASH, Vector2i(2, 5))
	var pack: ItemInstance = _put(authority, backpack, 1, Inventory.STASH, Vector2i(6, 3))
	var vest: ItemInstance = _put(authority, rig, 1, Inventory.STASH, Vector2i(6, 8))
	# 장비 슬롯에 샘플 하나씩 (이벤트 없이 초기 상태로 만든다). 안경만 스태시에 남겨 둬서 "장착"을 해 볼 수 있다.
	inv.equip(holstered.id, EquipmentSlots.Slot.SECONDARY)
	inv.equip(worn_helmet.id, EquipmentSlots.Slot.HELMET)
	inv.equip(worn_armor.id, EquipmentSlots.Slot.ARMOR)
	inv.equip(pack.id, EquipmentSlots.Slot.BACKPACK)
	inv.equip(vest.id, EquipmentSlots.Slot.RIG)
	_equip_new(authority, rifle, EquipmentSlots.Slot.PRIMARY_1)
	_equip_new(authority, shotgun, EquipmentSlots.Slot.PRIMARY_2)
	_equip_new(authority, knife, EquipmentSlots.Slot.MELEE)
	_equip_new(authority, balaclava, EquipmentSlots.Slot.FACE)
	_equip_new(authority, headset, EquipmentSlots.Slot.EAR)
	var safe_item: ItemInstance = _equip_new(authority, safe, EquipmentSlots.Slot.SECURE_CONTAINER)
	_glasses_id = _put(authority, glasses, 1, Inventory.STASH, Vector2i(4, 3)).id
	# 주머니와 컨테이너 안에 몇 개
	_put(authority, bandage, 2, Inventory.pocket_key(0), Vector2i.ZERO)
	_put(authority, ammo_9, 20, Inventory.pocket_key(1), Vector2i.ZERO)
	_put(authority, medkit, 1, Inventory.item_grid_key(pack.id, 0), Vector2i(0, 0))
	_put(authority, gpu, 1, Inventory.item_grid_key(pack.id, 0), Vector2i(2, 0))
	_put(authority, ammo_556, 30, Inventory.item_grid_key(vest.id, 0), Vector2i(0, 0))
	_put(authority, chain, 1, Inventory.item_grid_key(vest.id, 2), Vector2i(0, 1))
	_put(authority, chain, 1, Inventory.item_grid_key(safe_item.id, 0), Vector2i(0, 0))
	_put(authority, bandage, 2, Inventory.item_grid_key(vest.id, 1), Vector2i(1, 0))
	_put(authority, ammo_9, 15, Inventory.item_grid_key(vest.id, 3), Vector2i(0, 0))
	_pack_id = pack.id


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


func _equip_new(authority: LocalAuthority, def: ItemDef, slot: EquipmentSlots.Slot) -> ItemInstance:
	var item: ItemInstance = authority.create_item(def, 1)
	var result: CommandResult = authority.inventory.add_equipped(item, slot)
	assert(result.ok, "demo equip failed: %s" % def.id)
	return item
