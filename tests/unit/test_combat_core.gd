extends GutTest
## M6 핵심 규칙: 소비, 재장전, 사격 속도, 체력·방탄·출혈.

var _auth: LocalAuthority
var _inv: Inventory
var _ammo556: ItemDef
var _ammo9: ItemDef
var _rifle: ItemInstance


func before_each() -> void:
	_inv = Inventory.new(Vector2i(10, 10))
	_auth = LocalAuthority.new(_inv)
	_auth.content = ContentDatabase.new()
	_ammo556 = ItemDef.create(&"ammo_556", 1, 1, 60)
	_ammo556.category = ItemDef.Category.AMMO
	_ammo9 = ItemDef.create(&"ammo_9", 1, 1, 50)
	_ammo9.category = ItemDef.Category.AMMO
	_auth.content.add_ammo(AmmoDef.create(&"ammo_556", &"5.56", 45.0, 30.0))
	_auth.content.add_ammo(AmmoDef.create(&"ammo_9", &"9mm", 35.0, 15.0))
	var rifle_def := ItemDef.create(&"rifle", 5, 2)
	rifle_def.category = ItemDef.Category.WEAPON
	_rifle = _auth.create_item(rifle_def)
	_rifle.magazine = Magazine.new(&"5.56", 30)
	var receiver := WeaponPartDef.create(&"rifle_receiver", &"receiver")
	receiver.base_stats = {WeaponStats.FIRE_RATE: 600.0, WeaponStats.AUTO: 1.0, WeaponStats.DAMAGE_MULT: 1.0}
	_rifle.weapon = WeaponAssembly.new(receiver)


func _rig() -> ItemInstance:
	var def := ItemDef.create(&"rig", 2, 2)
	def.category = ItemDef.Category.RIG
	def.grids = [Vector2i(2, 1)]
	return _auth.create_item(def)


func _backpack() -> ItemInstance:
	var def := ItemDef.create(&"pack", 3, 3)
	def.category = ItemDef.Category.BACKPACK
	def.grids = [Vector2i(3, 3)]
	return _auth.create_item(def)


# --- consume ---

func test_consume_reduces_and_removes_at_zero() -> void:
	var stack: ItemInstance = _auth.create_item(_ammo556, 10)
	assert_true(_inv.add_item(stack, Inventory.STASH, Vector2i.ZERO, false).ok)
	var r: CommandResult = _inv.consume(stack.id, 4)
	assert_true(r.ok)
	assert_eq(stack.stack_count, 6)
	assert_eq(r.events[0].type, DomainEvent.STACK_CHANGED)
	r = _inv.consume(stack.id, 6)
	assert_eq(r.events[0].type, DomainEvent.ITEM_REMOVED)
	assert_null(_inv.get_item(stack.id))
	assert_true(_inv.is_consistent())


func test_consume_rejects_invalid_amounts_and_locked_stash() -> void:
	var stack: ItemInstance = _auth.create_item(_ammo556, 10)
	_inv.add_item(stack, Inventory.STASH, Vector2i.ZERO, false)
	assert_eq(_inv.consume(stack.id, 0).error, CommandResult.INVALID_AMOUNT)
	assert_eq(_inv.consume(stack.id, 11).error, CommandResult.INVALID_AMOUNT)
	_inv.stash_locked = true
	assert_eq(_inv.consume(stack.id, 1).error, CommandResult.STASH_LOCKED)
	assert_eq(stack.stack_count, 10)


# --- reload ---

func test_reload_takes_rig_then_pockets_then_backpack_matching_caliber() -> void:
	var rig := _rig()
	var pack := _backpack()
	assert_true(_inv.add_equipped(rig, EquipmentSlots.Slot.RIG).ok)
	assert_true(_inv.add_equipped(pack, EquipmentSlots.Slot.BACKPACK).ok)
	assert_true(_inv.add_equipped(_rifle, EquipmentSlots.Slot.PRIMARY_1).ok)
	var in_rig: ItemInstance = _auth.create_item(_ammo556, 10)
	var wrong: ItemInstance = _auth.create_item(_ammo9, 40)
	var in_pocket: ItemInstance = _auth.create_item(_ammo556, 12)
	var in_pack: ItemInstance = _auth.create_item(_ammo556, 50)
	var in_stash: ItemInstance = _auth.create_item(_ammo556, 60)
	_inv.add_item(wrong, Inventory.item_grid_key(rig.id, 0), Vector2i(0, 0), false)
	_inv.add_item(in_rig, Inventory.item_grid_key(rig.id, 0), Vector2i(1, 0), false)
	_inv.add_item(in_pocket, Inventory.pocket_key(2), Vector2i.ZERO, false)
	_inv.add_item(in_pack, Inventory.item_grid_key(pack.id, 0), Vector2i.ZERO, false)
	_inv.add_item(in_stash, Inventory.STASH, Vector2i.ZERO, false)
	var r: CommandResult = _auth.execute(ReloadCommand.new(_rifle.id))
	assert_true(r.ok)
	assert_eq(_rifle.magazine.count(), 30)
	assert_null(_inv.get_item(in_rig.id))
	assert_null(_inv.get_item(in_pocket.id))
	assert_eq(in_pack.stack_count, 42)
	assert_eq(in_stash.stack_count, 60)
	assert_eq(wrong.stack_count, 40)
	assert_eq(r.events.back().type, DomainEvent.MAGAZINE_CHANGED)
	assert_eq(r.events.back().data["count"], 30)
	assert_true(_inv.is_consistent())


func test_reload_failures_change_nothing() -> void:
	assert_eq(_auth.execute(ReloadCommand.new(999)).error, CommandResult.UNKNOWN_ITEM)
	_inv.add_item(_rifle, Inventory.STASH, Vector2i.ZERO, false)
	assert_eq(_auth.execute(ReloadCommand.new(_rifle.id)).error, CommandResult.WEAPON_NOT_EQUIPPED)
	_inv.equip(_rifle.id, EquipmentSlots.Slot.PRIMARY_1)
	assert_eq(_auth.execute(ReloadCommand.new(_rifle.id)).error, CommandResult.NO_AMMO)
	_rifle.magazine.load_rounds(_auth.content.get_ammo(&"ammo_556"), 30)
	assert_eq(_auth.execute(ReloadCommand.new(_rifle.id)).error, CommandResult.MAGAZINE_FULL)
	var bandage := ItemDef.create(&"bandage", 1, 1)
	var not_weapon: ItemInstance = _auth.create_item(bandage)
	_inv.add_item(not_weapon, Inventory.pocket_key(0), Vector2i.ZERO, false)
	assert_eq(_auth.execute(ReloadCommand.new(not_weapon.id)).error, CommandResult.NOT_A_WEAPON)


func test_reload_without_content_database_has_no_ammo() -> void:
	_auth.content = null
	_inv.add_equipped(_rifle, EquipmentSlots.Slot.PRIMARY_1)
	assert_eq(_auth.execute(ReloadCommand.new(_rifle.id)).error, CommandResult.NO_AMMO)


# --- weapon runtime ---

func test_fire_rate_limits_shots_and_consumes_rounds() -> void:
	_rifle.magazine.load_rounds(_auth.content.get_ammo(&"ammo_556"), 3)
	var w := WeaponRuntime.new(_rifle)
	assert_almost_eq(w.fire_interval(), 0.1, 0.0001)
	assert_true(w.is_automatic())
	assert_eq(w.try_fire(0.0), &"ammo_556")
	assert_eq(w.try_fire(0.05), &"")
	assert_eq(w.try_fire(0.1), &"ammo_556")
	assert_eq(w.try_fire(0.2), &"ammo_556")
	assert_eq(w.try_fire(5.0), &"")
	assert_eq(w.rounds(), 0)


func test_semi_auto_and_defaults_without_assembly() -> void:
	var pistol_def := ItemDef.create(&"pistol", 2, 1)
	var pistol: ItemInstance = _auth.create_item(pistol_def)
	pistol.magazine = Magazine.new(&"9mm", 15)
	var w := WeaponRuntime.new(pistol)
	assert_false(w.is_automatic())
	assert_almost_eq(w.fire_rate(), WeaponRuntime.DEFAULT_FIRE_RATE, 0.001)
	assert_eq(w.try_fire(0.0), &"")


# --- health ---

func test_unarmored_hit_full_damage_and_bleeds() -> void:
	var h := Health.new(100.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r: DamageModel.HitResult = h.take_hit(_auth.content.get_ammo(&"ammo_556"), 1.0, rng)
	assert_true(r.penetrated)
	assert_almost_eq(h.hp, 55.0, 0.001)
	assert_true(h.bleeding)
	h.tick(2.0)
	assert_almost_eq(h.hp, 55.0 - Health.BLEED_DPS * 2.0, 0.001)
	h.stop_bleeding()
	h.heal(1000.0)
	assert_almost_eq(h.hp, 100.0, 0.001)


func test_armor_blocks_weak_rounds_and_wears_down() -> void:
	var h := Health.new(100.0)
	h.set_armor(6, 50.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var weak: AmmoDef = _auth.content.get_ammo(&"ammo_9")
	var r: DamageModel.HitResult = h.take_hit(weak, 1.0, rng)
	assert_false(r.penetrated)
	assert_almost_eq(h.hp, 100.0 - 35.0 * DamageModel.BLUNT_RATIO, 0.001)
	assert_false(h.bleeding)
	assert_lt(h.armor_durability, 50.0)
	for i: int in range(20):
		h.take_hit(weak, 1.0, rng)
	assert_eq(h.armor_durability, 0.0)
	assert_true(h.is_dead())


func test_dead_does_not_bleed_or_heal() -> void:
	var h := Health.new(10.0)
	var rng := RandomNumberGenerator.new()
	h.take_hit(_auth.content.get_ammo(&"ammo_556"), 1.0, rng)
	assert_true(h.is_dead())
	h.heal(50.0)
	h.tick(1.0)
	assert_eq(h.hp, 0.0)
