extends GutTest
## 전투 테스트 로드아웃과 WeaponRuntime/ReloadCommand/Health 연결.


func test_loadout_equips_three_weapons_with_full_mags() -> void:
	var auth: LocalAuthority = CombatLoadout.build()
	var rifle: ItemInstance = auth.inventory.equipment.get_item(EquipmentSlots.Slot.PRIMARY_1)
	var shotgun: ItemInstance = auth.inventory.equipment.get_item(EquipmentSlots.Slot.PRIMARY_2)
	var pistol: ItemInstance = auth.inventory.equipment.get_item(EquipmentSlots.Slot.SECONDARY)
	assert_not_null(rifle)
	assert_not_null(shotgun)
	assert_not_null(pistol)
	assert_eq(rifle.magazine.count(), 30)
	assert_eq(shotgun.magazine.capacity, 6)
	assert_eq(pistol.magazine.capacity, 15)
	assert_true(WeaponRuntime.new(rifle).is_automatic())
	assert_false(WeaponRuntime.new(shotgun).is_automatic())
	assert_almost_eq(WeaponRuntime.new(shotgun).fire_interval(), 60.0 / 70.0, 0.0001)
	assert_eq(auth.content.get_ammo(CombatLoadout.AMMO_12GA).projectile_count, 8)
	assert_true(auth.inventory.is_consistent())


func test_reload_after_firing_uses_carried_ammo() -> void:
	var auth: LocalAuthority = CombatLoadout.build()
	var rifle: ItemInstance = auth.inventory.equipment.get_item(EquipmentSlots.Slot.PRIMARY_1)
	var runtime := WeaponRuntime.new(rifle)
	for i: int in range(10):
		assert_eq(runtime.try_fire(float(i)), CombatLoadout.AMMO_556)
	assert_eq(runtime.rounds(), 20)
	assert_true(auth.execute(ReloadCommand.new(rifle.id)).ok)
	assert_eq(rifle.magazine.count(), 30)
	assert_eq(AmmoCounter.count_carried(auth.inventory, auth.content, &"5.56"), 50)
	assert_eq(auth.execute(ReloadCommand.new(rifle.id)).error, CommandResult.MAGAZINE_FULL)


func test_class5_armor_stops_556_but_class3_often_does_not() -> void:
	var auth: LocalAuthority = CombatLoadout.build()
	var ammo: AmmoDef = auth.content.get_ammo(CombatLoadout.AMMO_556)
	assert_eq(DamageModel.penetration_chance(ammo.penetration, 5, 1.0), 0.0)
	assert_almost_eq(DamageModel.penetration_chance(ammo.penetration, 3, 1.0), 0.5, 0.0001)
	assert_eq(DamageModel.penetration_chance(ammo.penetration, 0, 1.0), 1.0)
