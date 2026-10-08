class_name SaveSerializer
extends RefCounted
## Inventory + IdGenerator ↔ JSON 안전 Dictionary (Dictionary/Array/String/int/float/bool만 사용).
## 불러올 때는 JSON.parse_string이 정수를 float로 바꾸므로 숫자는 int()로 되돌린다.
## 불러오기는 전부 성공하거나 전부 실패한다 (실패 시 일부만 만들어진 인벤토리를 돌려주지 않음).


class LoadResult:
	var ok: bool = false
	var error: String = ""
	var inventory: Inventory = null
	var ids: IdGenerator = null


## 불러오는 중 공유하는 상태.
class _Ctx:
	var db: ContentDatabase
	var error: String = ""
	var seen: Dictionary[int, bool] = {}
	var max_id: int = 0


# --- 저장 ---

static func to_dict(inventory: Inventory, ids: IdGenerator) -> Dictionary:
	var stash: ItemGrid = inventory.get_grid(Inventory.STASH)
	var roots: Array[ItemInstance] = []
	for item: ItemInstance in inventory.get_items():
		if not String(item.container_key).begins_with("item_"):
			roots.append(item)
	roots.sort_custom(_by_id)
	var items: Array = []
	for item: ItemInstance in roots:
		items.append(_item_to_dict(item))
	return {
		"version": SaveMigrations.CURRENT_VERSION,
		"next_id": ids.peek(),
		"stash_size": [stash.width, stash.height] if stash != null else [0, 0],
		"stash_locked": inventory.stash_locked,
		"items": items,
	}


static func _by_id(a: ItemInstance, b: ItemInstance) -> bool:
	return a.id < b.id


static func _item_to_dict(item: ItemInstance) -> Dictionary:
	var grids: Array = []
	for grid: ItemGrid in item.grids:
		var children: Array = []
		var sorted_children: Array[ItemInstance] = grid.get_items()
		sorted_children.sort_custom(_by_id)
		for child: ItemInstance in sorted_children:
			children.append(_item_to_dict(child))
		grids.append(children)
	var data: Dictionary = {
		"id": item.id,
		"def": String(item.def.id),
		"stack": item.stack_count,
		"fir": item.found_in_raid,
		"container": String(item.container_key),
		"cell": [item.position.x, item.position.y],
		"rotated": item.rotated,
		"grids": grids,
	}
	if item.weapon != null:
		data["weapon"] = _node_to_dict(item.weapon.root)
	if item.magazine != null:
		var rounds: Array = []
		for ammo_id: StringName in item.magazine.get_rounds():
			rounds.append(String(ammo_id))
		data["magazine"] = {
			"caliber": String(item.magazine.caliber),
			"capacity": item.magazine.capacity,
			"rounds": rounds,
		}
	return data


static func _node_to_dict(node: WeaponPartNode) -> Dictionary:
	var children: Dictionary = {}
	for socket: WeaponSocket in node.def.sockets:  # 소켓 정의 순서 → 결정적 출력
		var child: WeaponPartNode = node.children.get(socket.name)
		if child != null:
			children[String(socket.name)] = _node_to_dict(child)
	return {"part": String(node.def.id), "children": children}


# --- 불러오기 ---

static func from_dict(data: Dictionary, db: ContentDatabase) -> LoadResult:
	var version: int = SaveMigrations.version_of(data)
	if version < 1:
		return _fail("missing or invalid save version")
	if version > SaveMigrations.CURRENT_VERSION:
		return _fail("save version %d is newer than supported version %d"
				% [version, SaveMigrations.CURRENT_VERSION])
	var migrated: Dictionary = SaveMigrations.migrate(data)
	if SaveMigrations.version_of(migrated) != SaveMigrations.CURRENT_VERSION:
		return _fail("cannot migrate save version %d" % version)

	var ctx := _Ctx.new()
	ctx.db = db

	var stash_size: Vector2i = Vector2i.ZERO
	if migrated.has("stash_size"):
		var parsed: Variant = _vec(migrated["stash_size"])
		if parsed == null or parsed.x < 0 or parsed.y < 0 or (parsed.x == 0) != (parsed.y == 0):
			return _fail("invalid stash_size")
		stash_size = parsed
	var raw_items: Variant = migrated.get("items")
	if typeof(raw_items) != TYPE_ARRAY:
		return _fail("items must be an array")
	var next_id: int = 1
	if migrated.has("next_id"):
		if not _is_int(migrated["next_id"]):
			return _fail("invalid next_id")
		next_id = int(migrated["next_id"])
	var locked: bool = false
	if migrated.has("stash_locked"):
		if typeof(migrated["stash_locked"]) != TYPE_BOOL:
			return _fail("invalid stash_locked")
		locked = migrated["stash_locked"]

	var inventory := Inventory.new(stash_size)
	for raw: Variant in raw_items as Array:
		var item: ItemInstance = _build_item(raw, ctx)
		if item == null:
			return _fail(ctx.error)
		var error: String = _add_root(inventory, item, raw as Dictionary)
		if not error.is_empty():
			return _fail("item %d: %s" % [item.id, error])
	# 잠금은 모든 아이템을 넣은 뒤에 건다 (잠겨 있으면 스태시에 넣을 수 없다).
	inventory.stash_locked = locked

	var ids := IdGenerator.new()
	ids.ensure_above(maxi(ctx.max_id, next_id - 1))
	var result := LoadResult.new()
	result.ok = true
	result.inventory = inventory
	result.ids = ids
	return result


static func _fail(message: String) -> LoadResult:
	var result := LoadResult.new()
	result.ok = false
	result.error = message
	return result


static func _add_root(inventory: Inventory, item: ItemInstance, data: Dictionary) -> String:
	var key: StringName = item.container_key
	var key_text: String = String(key)
	if key_text.begins_with("item_"):
		return "root item cannot live in an item grid (%s)" % key_text
	var placed: CommandResult
	var slot: int = EquipmentSlots.slot_from_key(key)
	if slot >= 0:
		placed = inventory.add_equipped(item, slot as EquipmentSlots.Slot)
	else:
		var cell: Variant = _vec(data.get("cell"))
		if cell == null:
			return "invalid cell"
		placed = inventory.add_item(item, key, cell, item.rotated)
	if not placed.ok:
		return "cannot place in %s (%s)" % [key_text, placed.error]
	return ""


## 아이템 하나(와 내부 그리드·무기·탄창)를 만든다. 실패하면 ctx.error를 채우고 null.
## 루트 아이템의 container 키는 item.container_key에, 자식은 부모 그리드에 이미 배치된 상태로 돌려준다.
static func _build_item(raw: Variant, ctx: _Ctx) -> ItemInstance:
	if typeof(raw) != TYPE_DICTIONARY:
		ctx.error = "item must be an object"
		return null
	var d: Dictionary = raw
	if not _is_int(d.get("id")) or int(d["id"]) <= 0:
		ctx.error = "item has invalid id"
		return null
	var item_id: int = int(d["id"])
	if ctx.seen.has(item_id):
		ctx.error = "duplicate item id %d" % item_id
		return null
	ctx.seen[item_id] = true
	ctx.max_id = maxi(ctx.max_id, item_id)

	if typeof(d.get("def")) != TYPE_STRING:
		ctx.error = "item %d has no def" % item_id
		return null
	var def: ItemDef = ctx.db.get_item(StringName(d["def"]))
	if def == null:
		ctx.error = "item %d: unknown def '%s'" % [item_id, d["def"]]
		return null
	if not _is_int(d.get("stack")) or int(d["stack"]) < 1 or int(d["stack"]) > def.max_stack:
		ctx.error = "item %d: invalid stack" % item_id
		return null
	var item := ItemInstance.new(item_id, def, int(d["stack"]))
	if d.has("fir"):
		if typeof(d["fir"]) != TYPE_BOOL:
			ctx.error = "item %d: invalid fir" % item_id
			return null
		item.found_in_raid = d["fir"]
	if typeof(d.get("container")) != TYPE_STRING:
		ctx.error = "item %d: missing container" % item_id
		return null
	item.container_key = StringName(d["container"])
	if d.has("rotated"):
		if typeof(d["rotated"]) != TYPE_BOOL:
			ctx.error = "item %d: invalid rotated" % item_id
			return null
		item.rotated = d["rotated"]

	if d.has("weapon"):
		if def.category != ItemDef.Category.WEAPON:
			ctx.error = "item %d: weapon data on non-weapon def '%s'" % [item_id, def.id]
			return null
		item.weapon = _build_weapon(d["weapon"], item_id, ctx)
		if item.weapon == null:
			return null
	if d.has("magazine"):
		if def.category != ItemDef.Category.MAGAZINE:
			ctx.error = "item %d: magazine data on non-magazine def '%s'" % [item_id, def.id]
			return null
		item.magazine = _build_magazine(d["magazine"], item_id, ctx)
		if item.magazine == null:
			return null

	var raw_grids: Variant = d.get("grids", [])
	if typeof(raw_grids) != TYPE_ARRAY or (raw_grids as Array).size() != item.grids.size():
		ctx.error = "item %d: grids do not match def '%s'" % [item_id, def.id]
		return null
	for i: int in range(item.grids.size()):
		var children: Variant = (raw_grids as Array)[i]
		if typeof(children) != TYPE_ARRAY:
			ctx.error = "item %d: grid %d must be an array" % [item_id, i]
			return null
		var expected_key: StringName = Inventory.item_grid_key(item_id, i)
		for raw_child: Variant in children as Array:
			var child: ItemInstance = _build_item(raw_child, ctx)
			if child == null:
				return null
			if child.container_key != expected_key:
				ctx.error = "item %d: container '%s' does not match parent grid '%s'" \
						% [child.id, child.container_key, expected_key]
				return null
			var cell: Variant = _vec((raw_child as Dictionary).get("cell"))
			if cell == null or not item.grids[i].try_place(child, cell, child.rotated):
				ctx.error = "item %d: cannot place in %s" % [child.id, expected_key]
				return null
	return item


static func _build_weapon(raw: Variant, item_id: int, ctx: _Ctx) -> WeaponAssembly:
	if typeof(raw) != TYPE_DICTIONARY or typeof((raw as Dictionary).get("part")) != TYPE_STRING:
		ctx.error = "item %d: invalid weapon tree" % item_id
		return null
	var root_def: WeaponPartDef = ctx.db.get_part(StringName((raw as Dictionary)["part"]))
	if root_def == null:
		ctx.error = "item %d: unknown part '%s'" % [item_id, (raw as Dictionary)["part"]]
		return null
	var assembly := WeaponAssembly.new(root_def)
	var path: Array[StringName] = []
	if not _attach_children(assembly, path, raw as Dictionary, item_id, ctx):
		return null
	return assembly


static func _attach_children(assembly: WeaponAssembly, path: Array[StringName], node: Dictionary,
		item_id: int, ctx: _Ctx) -> bool:
	var children: Variant = node.get("children", {})
	if typeof(children) != TYPE_DICTIONARY:
		ctx.error = "item %d: weapon children must be an object" % item_id
		return false
	for socket_key: Variant in children as Dictionary:
		var socket_name := StringName(str(socket_key))
		var child: Variant = (children as Dictionary)[socket_key]
		if typeof(child) != TYPE_DICTIONARY or typeof((child as Dictionary).get("part")) != TYPE_STRING:
			ctx.error = "item %d: invalid weapon node at '%s'" % [item_id, socket_name]
			return false
		var part: WeaponPartDef = ctx.db.get_part(StringName((child as Dictionary)["part"]))
		if part == null:
			ctx.error = "item %d: unknown part '%s'" % [item_id, (child as Dictionary)["part"]]
			return false
		var error: StringName = assembly.attach(path, socket_name, part)
		if error != WeaponAssembly.OK:
			ctx.error = "item %d: cannot attach '%s' to socket '%s' (%s)" \
					% [item_id, part.id, socket_name, error]
			return false
		var child_path: Array[StringName] = path.duplicate()
		child_path.append(socket_name)
		if not _attach_children(assembly, child_path, child as Dictionary, item_id, ctx):
			return false
	return true


static func _build_magazine(raw: Variant, item_id: int, ctx: _Ctx) -> Magazine:
	if typeof(raw) != TYPE_DICTIONARY:
		ctx.error = "item %d: invalid magazine" % item_id
		return null
	var d: Dictionary = raw
	if typeof(d.get("caliber")) != TYPE_STRING or not _is_int(d.get("capacity")) \
			or int(d["capacity"]) <= 0 or typeof(d.get("rounds")) != TYPE_ARRAY:
		ctx.error = "item %d: invalid magazine fields" % item_id
		return null
	var mag := Magazine.new(StringName(d["caliber"]), int(d["capacity"]))
	for ammo_id: Variant in d["rounds"] as Array:
		var ammo: AmmoDef = null
		if typeof(ammo_id) == TYPE_STRING:
			ammo = ctx.db.get_ammo(StringName(ammo_id))
		if ammo == null:
			ctx.error = "item %d: unknown ammo '%s'" % [item_id, ammo_id]
			return null
		if mag.load_rounds(ammo, 1) != 1:
			ctx.error = "item %d: cannot load ammo '%s' (caliber or capacity)" % [item_id, ammo.id]
			return null
	return mag


# --- 값 변환 ---

## JSON을 거치면 int가 float가 되므로 정수 값의 float도 정수로 인정한다.
static func _is_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value)


## [x, y] → Vector2i, 형식이 틀리면 null.
static func _vec(value: Variant) -> Variant:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
		return null
	var pair: Array = value
	if not _is_int(pair[0]) or not _is_int(pair[1]):
		return null
	return Vector2i(int(pair[0]), int(pair[1]))
