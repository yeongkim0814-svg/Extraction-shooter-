class_name AmmoCounter
extends RefCounted
## HUD용: 몸에 지닌(조끼·주머니·배낭) 같은 구경 탄약의 총수. ReloadCommand와 같은 탐색 범위를 쓴다.


static func count_carried(inv: Inventory, content: ContentDatabase, caliber: StringName) -> int:
	if inv == null or content == null:
		return 0
	var total: int = 0
	for key: StringName in ReloadCommand.search_keys(inv):
		var grid: ItemGrid = inv.get_grid(key)
		if grid == null:
			continue
		for item: ItemInstance in grid.get_items():
			var ammo: AmmoDef = content.get_ammo(item.def.id)
			if ammo != null and ammo.caliber == caliber:
				total += item.stack_count
	return total
