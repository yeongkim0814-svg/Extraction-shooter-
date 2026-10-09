class_name DemoLoot
extends RefCounted
## 데모용 루팅 아이템 정의와 시체 루팅 테이블 (M8·M9). 아이템 정의는 콘텐츠 저장소에 등록한다.
## 기준가(base_price)가 수색 시간(SearchTimeCalculator)을 좌우한다: 5000 이상 ×1.3, 20000 이상 ×1.6, 50000 이상 ×2.0.


## 아이템 정의를 등록하고 시체 테이블을 만든다. 같은 content에 두 번 불러도 정의가 겹치지 않는다.
static func build_table(content: ContentDatabase) -> LootTable:
	var table := LootTable.new()
	table.min_items = 2
	table.max_items = 4
	register_items(content)
	table.entries = [
		LootEntry.create(content.get_item(&"bandage"), 4.0, 1, 2),
		LootEntry.create(content.get_item(&"painkillers"), 3.0, 1, 2),
		LootEntry.create(content.get_item(&"gold_necklace"), 1.5),
		LootEntry.create(content.get_item(&"battery"), 2.0),
	]
	return table


## 데모 아이템 전체를 content에 등록한다 (이미 있으면 그대로 둔다). 크기는 1×1~2×2.
static func register_items(content: ContentDatabase) -> void:
	# 기존 (M8)
	_def(content, &"bandage", "붕대", ItemDef.Category.MEDICAL, 1, 1, 4, 300)
	_def(content, &"painkillers", "진통제", ItemDef.Category.MEDICAL, 1, 1, 4, 700)
	_def(content, &"gold_necklace", "금목걸이", ItemDef.Category.VALUABLE, 2, 1, 1, 12000)
	_def(content, &"battery", "배터리", ItemDef.Category.VALUABLE, 1, 2, 1, 6500)
	# 잡동사니 (싸고 빨리 찾는다)
	_def(content, &"scrap_metal", "고철", ItemDef.Category.MISC, 1, 1, 5, 400)
	_def(content, &"duct_tape", "청테이프", ItemDef.Category.MISC, 1, 1, 3, 1200)
	_def(content, &"wire_spool", "전선 뭉치", ItemDef.Category.MISC, 2, 1, 1, 2500)
	_def(content, &"toolkit", "공구 세트", ItemDef.Category.MISC, 2, 2, 1, 8000)
	# 귀중품 (비쌀수록 오래 걸린다)
	_def(content, &"lighter", "지포 라이터", ItemDef.Category.VALUABLE, 1, 1, 1, 5500)
	_def(content, &"gold_watch", "금시계", ItemDef.Category.VALUABLE, 1, 1, 1, 24000)
	_def(content, &"hard_drive", "하드 드라이브", ItemDef.Category.VALUABLE, 1, 1, 1, 21000)
	_def(content, &"gold_bar", "금괴", ItemDef.Category.VALUABLE, 2, 1, 1, 60000)
	# 의료
	_def(content, &"tourniquet", "지혈대", ItemDef.Category.MEDICAL, 1, 1, 2, 1800)
	_def(content, &"medkit", "구급 상자", ItemDef.Category.MEDICAL, 2, 2, 1, 9000)
	_def(content, &"surgical_kit", "수술 키트", ItemDef.Category.MEDICAL, 2, 1, 1, 22000)
	# 탄약은 전투 로드아웃의 정의를 그대로 쓴다 (플레이어 탄약과 쌓이도록): RaidLoot가 content에서 꺼낸다


static func _def(content: ContentDatabase, id: StringName, display_name: String, category: ItemDef.Category,
		width: int, height: int, max_stack: int, price: int) -> ItemDef:
	var existing: ItemDef = content.get_item(id)
	if existing != null:
		return existing
	var def: ItemDef = ItemDef.create(id, width, height, max_stack)
	def.display_name = display_name
	def.category = category
	def.base_price = price
	content.add_item(def)
	return def
