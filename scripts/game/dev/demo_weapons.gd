class_name DemoWeapons
extends RefCounted
## 데모용 무기 부품 콘텐츠 (M7): 소총·샷건·권총의 리시버와 부품, 부품 아이템 정의.
## 부품 id는 ContentDatabase의 부품과 아이템 정의가 같은 id를 쓴다 (코어 규약).
## 외형은 WeaponLook 표(같은 id)가 정한다. 새 부품 = 여기에 정의 + WeaponLook에 한 줄.

const RIFLE_RECEIVER: StringName = &"rifle_receiver"
const SHOTGUN_RECEIVER: StringName = &"shotgun_receiver"
const PISTOL_RECEIVER: StringName = &"pistol_receiver"

const BARREL_SHORT: StringName = &"barrel_short"
const BARREL_LONG: StringName = &"barrel_long"
const HANDGUARD: StringName = &"handguard_rail"
const GRIP_VERTICAL: StringName = &"grip_vertical"
const STOCK_FIXED: StringName = &"stock_fixed"
const STOCK_FOLDING: StringName = &"stock_folding"
const MAG_30: StringName = &"mag_30"
const RED_DOT: StringName = &"optic_reddot"
const SCOPE_4X: StringName = &"optic_scope4x"
const SUPPRESSOR: StringName = &"suppressor"

## 소켓 종류 이름.
const T_BARREL: StringName = &"barrel"
const T_HANDGUARD: StringName = &"handguard"
const T_STOCK: StringName = &"stock"
const T_OPTIC: StringName = &"optic"
const T_MAGAZINE: StringName = &"magazine"
const T_MUZZLE: StringName = &"muzzle"
const T_GRIP: StringName = &"grip"

const RECEIVER_FOR_WEAPON: Dictionary[StringName, StringName] = {
	&"rifle": RIFLE_RECEIVER,
	&"shotgun": SHOTGUN_RECEIVER,
	&"pistol": PISTOL_RECEIVER,
}


## 리시버·부품 정의와 부품 아이템 정의를 콘텐츠 저장소에 등록한다.
static func register(content: ContentDatabase) -> void:
	_receiver(content, RIFLE_RECEIVER, [
			WeaponSocket.create(&"barrel", T_BARREL, true), WeaponSocket.create(&"handguard", T_HANDGUARD),
			WeaponSocket.create(&"stock", T_STOCK), WeaponSocket.create(&"optic", T_OPTIC),
			WeaponSocket.create(&"magazine", T_MAGAZINE)],
			{WeaponStats.FIRE_RATE: 600.0, WeaponStats.AUTO: 1.0, WeaponStats.DAMAGE_MULT: 1.0,
			WeaponStats.RECOIL: 35.0, WeaponStats.ERGONOMICS: 36.0, WeaponStats.SPREAD: 1.2,
			WeaponStats.WEIGHT: 2.4, WeaponStats.LOUDNESS: 1.0, WeaponStats.RANGE: 160.0})
	_receiver(content, SHOTGUN_RECEIVER, [WeaponSocket.create(&"optic", T_OPTIC)],
			{WeaponStats.FIRE_RATE: 70.0, WeaponStats.AUTO: 0.0, WeaponStats.DAMAGE_MULT: 1.0,
			WeaponStats.RECOIL: 80.0, WeaponStats.ERGONOMICS: 38.0, WeaponStats.SPREAD: 4.0,
			WeaponStats.WEIGHT: 3.3, WeaponStats.LOUDNESS: 1.0, WeaponStats.RANGE: 60.0})
	_receiver(content, PISTOL_RECEIVER, [
			WeaponSocket.create(&"muzzle", T_MUZZLE), WeaponSocket.create(&"optic", T_OPTIC)],
			{WeaponStats.FIRE_RATE: 400.0, WeaponStats.AUTO: 0.0, WeaponStats.DAMAGE_MULT: 1.0,
			WeaponStats.RECOIL: 20.0, WeaponStats.ERGONOMICS: 62.0, WeaponStats.SPREAD: 1.5,
			WeaponStats.WEIGHT: 0.9, WeaponStats.LOUDNESS: 1.0, WeaponStats.RANGE: 100.0})

	var muzzle_socket: Array[WeaponSocket] = [WeaponSocket.create(&"muzzle", T_MUZZLE)]
	_part(content, BARREL_SHORT, "숏 배럴", T_BARREL, Vector2i(2, 1), Vector2i.ZERO,
			{WeaponStats.RANGE: 40.0, WeaponStats.WEIGHT: 0.4}, {}, muzzle_socket)
	_part(content, BARREL_LONG, "롱 배럴", T_BARREL, Vector2i(3, 1), Vector2i(1, 0),
			{WeaponStats.RANGE: 100.0, WeaponStats.RECOIL: -2.0, WeaponStats.ERGONOMICS: -4.0,
			WeaponStats.SPREAD: -0.3, WeaponStats.WEIGHT: 0.7}, {}, muzzle_socket)
	_part(content, HANDGUARD, "레일 핸드가드", T_HANDGUARD, Vector2i(2, 1), Vector2i.ZERO,
			{WeaponStats.RECOIL: -2.0, WeaponStats.ERGONOMICS: 3.0, WeaponStats.WEIGHT: 0.3}, {},
			[WeaponSocket.create(&"grip", T_GRIP)])
	_part(content, GRIP_VERTICAL, "수직 손잡이", T_GRIP, Vector2i(1, 2), Vector2i.ZERO,
			{WeaponStats.RECOIL: -4.0, WeaponStats.ERGONOMICS: 1.0, WeaponStats.WEIGHT: 0.15})
	_part(content, STOCK_FIXED, "고정 개머리판", T_STOCK, Vector2i(2, 1), Vector2i.ZERO,
			{WeaponStats.RECOIL: -3.0, WeaponStats.ERGONOMICS: 5.0, WeaponStats.WEIGHT: 0.5})
	# 접으면 가로 −1칸. 확대 조준경과 함께 쓸 수 없다 (충돌 규칙 시연).
	_part(content, STOCK_FOLDING, "접이식 개머리판", T_STOCK, Vector2i(2, 1), Vector2i(-1, 0),
			{WeaponStats.RECOIL: -1.0, WeaponStats.ERGONOMICS: 2.0, WeaponStats.WEIGHT: 0.3}, {}, [],
			[SCOPE_4X])
	_part(content, MAG_30, "30발 탄창", T_MAGAZINE, Vector2i(1, 2), Vector2i.ZERO,
			{WeaponStats.WEIGHT: 0.3})
	_part(content, RED_DOT, "레드 도트", T_OPTIC, Vector2i(1, 1), Vector2i.ZERO,
			{WeaponMotion.ZOOM: 0.1, WeaponStats.ERGONOMICS: -1.0, WeaponStats.WEIGHT: 0.12})
	_part(content, SCOPE_4X, "4배율 조준경", T_OPTIC, Vector2i(2, 1), Vector2i.ZERO,
			{WeaponMotion.ZOOM: 1.5, WeaponStats.ERGONOMICS: -7.0, WeaponStats.WEIGHT: 0.5}, {}, [],
			[STOCK_FOLDING])
	_part(content, SUPPRESSOR, "소음기", T_MUZZLE, Vector2i(2, 1), Vector2i(1, 0),
			{WeaponStats.RECOIL: -1.0, WeaponStats.RANGE: -5.0, WeaponStats.ERGONOMICS: -2.0,
			WeaponStats.WEIGHT: 0.35},
			{WeaponStats.LOUDNESS: 0.4})


## 무기 아이템 id(rifle/shotgun/pistol)에 맞는 기본 부품이 달린 조립을 만든다. 없으면 null.
static func assemble(content: ContentDatabase, weapon_id: StringName) -> WeaponAssembly:
	var receiver_id: StringName = RECEIVER_FOR_WEAPON.get(weapon_id, &"")
	var receiver: WeaponPartDef = content.get_part(receiver_id) if receiver_id != &"" else null
	if receiver == null:
		return null
	var assembly := WeaponAssembly.new(receiver)
	var root: Array[StringName] = []
	if weapon_id == &"rifle":
		_default(assembly, content, root, &"barrel", BARREL_SHORT)
		_default(assembly, content, root, &"handguard", HANDGUARD)
		_default(assembly, content, root, &"stock", STOCK_FIXED)
		_default(assembly, content, root, &"magazine", MAG_30)
		_default(assembly, content, root, &"optic", RED_DOT)
	return assembly


## 기본으로 쥐여 줄 여분 부품 id (소총용). 호출자가 인벤토리에 나눠 넣는다.
static func spare_part_ids() -> Array[StringName]:
	return [BARREL_LONG, GRIP_VERTICAL, STOCK_FOLDING, SCOPE_4X, SUPPRESSOR, SUPPRESSOR, RED_DOT]


static func is_weapon_item(def: ItemDef) -> bool:
	return def.category == ItemDef.Category.WEAPON or def.category == ItemDef.Category.PISTOL


static func _default(assembly: WeaponAssembly, content: ContentDatabase, path: Array[StringName],
		socket_name: StringName, part_id: StringName) -> void:
	var error: StringName = assembly.attach(path, socket_name, content.get_part(part_id))
	assert(error == WeaponAssembly.OK, "default part attach failed: %s (%s)" % [part_id, error])


static func _receiver(content: ContentDatabase, id: StringName, sockets: Array[WeaponSocket],
		base: Dictionary[StringName, float]) -> void:
	var def: WeaponPartDef = WeaponPartDef.create(id, &"receiver")
	def.sockets = sockets
	def.base_stats = base
	content.add_part(def)


static func _part(content: ContentDatabase, id: StringName, display_name: String, part_type: StringName,
		item_size: Vector2i, size_delta: Vector2i, additive: Dictionary[StringName, float],
		multiplier: Dictionary[StringName, float] = {}, sockets: Array[WeaponSocket] = [],
		conflicts: Array[StringName] = []) -> void:
	var def: WeaponPartDef = WeaponPartDef.create(id, part_type)
	def.size_delta = size_delta
	def.sockets = sockets
	def.conflicts = conflicts
	def.modifiers = StatModifiers.new()
	def.modifiers.additive = additive
	def.modifiers.multiplier = multiplier
	content.add_part(def)
	var item_def: ItemDef = ItemDef.create(id, item_size.x, item_size.y)
	item_def.display_name = display_name
	item_def.category = ItemDef.Category.ATTACHMENT
	item_def.base_price = 3000   # 레이드에서 주우면 반출 가치가 있도록 (수색 시간에는 영향 없음: 5000 미만)
	content.add_item(item_def)
