class_name RaidLoot
extends RefCounted
## 산업단지 레이드의 루팅 컨테이너 종류별 루팅 테이블 (M9). 굴림은 호출하는 쪽이 주입한 난수로 한다.
## 아이템 정의는 DemoLoot.register_items와 전투 로드아웃(탄약)·DemoWeapons(부품)가 content에 넣어 둔 것을 쓴다.


## 종류별 테이블. 컨테이너 크기에 비해 아이템 수가 넘치지 않게 min/max를 잡았다.
static func table_for(kind: LootContainer.Kind, content: ContentDatabase) -> LootTable:
	DemoLoot.register_items(content)
	var table := LootTable.new()
	match kind:
		LootContainer.Kind.CRATE:   # 나무 상자 4x3: 잡동사니 + 가끔 귀중품
			table.min_items = 3
			table.max_items = 5
			table.entries = _entries(content, [
				[&"scrap_metal", 4.0, 1, 3], [&"duct_tape", 3.0, 1, 2], [&"wire_spool", 2.0, 1, 1],
				[&"toolkit", 1.0, 1, 1], [&"lighter", 1.0, 1, 1], [&"battery", 1.0, 1, 1],
				[&"bandage", 1.5, 1, 2], [CombatLoadout.AMMO_9MM, 1.5, 10, 30]])
		LootContainer.Kind.TOOLBOX:   # 공구함 3x2: 공구·전선
			table.min_items = 2
			table.max_items = 3
			table.entries = _entries(content, [
				[&"toolkit", 3.0, 1, 1], [&"wire_spool", 3.0, 1, 1], [&"duct_tape", 3.0, 1, 3],
				[&"scrap_metal", 2.0, 1, 3], [&"battery", 1.5, 1, 1], [&"hard_drive", 0.6, 1, 1]])
		LootContainer.Kind.DRAWER:   # 서랍장 4x2: 사무용품·귀중품
			table.min_items = 2
			table.max_items = 4
			table.entries = _entries(content, [
				[&"hard_drive", 1.5, 1, 1], [&"gold_watch", 1.0, 1, 1], [&"lighter", 2.0, 1, 1],
				[&"gold_necklace", 1.0, 1, 1], [&"duct_tape", 2.0, 1, 2], [&"painkillers", 2.0, 1, 2],
				[&"gold_bar", 0.3, 1, 1]])
		LootContainer.Kind.WEAPON_BOX:   # 무기 상자 5x3: 탄약·부품
			table.min_items = 3
			table.max_items = 5
			table.entries = _entries(content, [
				[CombatLoadout.AMMO_556, 4.0, 20, 45], [CombatLoadout.AMMO_9MM, 3.0, 15, 30],
				[CombatLoadout.AMMO_12GA, 2.5, 6, 12], [&"toolkit", 1.0, 1, 1], [&"gold_bar", 0.4, 1, 1],
				[DemoWeapons.SUPPRESSOR, 0.8, 1, 1], [DemoWeapons.RED_DOT, 0.8, 1, 1],
				[DemoWeapons.GRIP_VERTICAL, 0.8, 1, 1]])
		LootContainer.Kind.MEDBAG:   # 의료 가방 3x3: 의료품
			table.min_items = 3
			table.max_items = 5
			table.entries = _entries(content, [
				[&"bandage", 4.0, 1, 3], [&"painkillers", 3.0, 1, 2], [&"tourniquet", 2.5, 1, 2],
				[&"medkit", 1.5, 1, 1], [&"surgical_kit", 0.8, 1, 1]])
	return table


## [[아이템 id, 가중치, 최소 수량, 최대 수량], ...] → LootEntry 목록. content에 없는 id는 건너뛴다.
static func _entries(content: ContentDatabase, rows: Array) -> Array[LootEntry]:
	var entries: Array[LootEntry] = []
	for row: Array in rows:
		var def: ItemDef = content.get_item(row[0] as StringName)
		if def == null:
			continue
		entries.append(LootEntry.create(def, float(row[1]), int(row[2]), int(row[3])))
	return entries
