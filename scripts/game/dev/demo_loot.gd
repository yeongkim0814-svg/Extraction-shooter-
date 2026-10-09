class_name DemoLoot
extends RefCounted
## 데모용 시체 루팅 테이블 (M8): 붕대·진통제·귀중품·배터리. 아이템 정의는 콘텐츠 저장소에 등록한다.


## 아이템 정의를 등록하고 테이블을 만든다. 같은 content에 두 번 불러도 정의가 겹치지 않는다.
static func build_table(content: ContentDatabase) -> LootTable:
	var table := LootTable.new()
	table.min_items = 2
	table.max_items = 4
	var bandage: ItemDef = _def(content, &"bandage", "붕대", ItemDef.Category.MEDICAL, 1, 1, 4)
	var painkillers: ItemDef = _def(content, &"painkillers", "진통제", ItemDef.Category.MEDICAL, 1, 1, 4)
	var necklace: ItemDef = _def(content, &"gold_necklace", "금목걸이", ItemDef.Category.VALUABLE, 2, 1, 1)
	var battery: ItemDef = _def(content, &"battery", "배터리", ItemDef.Category.VALUABLE, 1, 2, 1)
	table.entries = [
		LootEntry.create(bandage, 4.0, 1, 2),
		LootEntry.create(painkillers, 3.0, 1, 2),
		LootEntry.create(necklace, 1.5),
		LootEntry.create(battery, 2.0),
	]
	return table


static func _def(content: ContentDatabase, id: StringName, display_name: String, category: ItemDef.Category,
		width: int, height: int, max_stack: int) -> ItemDef:
	var existing: ItemDef = content.get_item(id)
	if existing != null:
		return existing
	var def: ItemDef = ItemDef.create(id, width, height, max_stack)
	def.display_name = display_name
	def.category = category
	content.add_item(def)
	return def
