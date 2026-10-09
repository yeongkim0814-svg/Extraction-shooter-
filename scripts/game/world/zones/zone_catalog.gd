class_name ZoneCatalog
extends RefCounted
## 구역 목록 (라이트맵 굽기 단위). 구역 이름 -> 정의. tools/build_zones.gd가 scenes/raid/zones/<구역>.tscn으로 굽고,
## IndustrialMap이 그 씬이 있으면 옛 코드 지오메트리 대신 붙인다.

const ZONES: Array[StringName] = [&"ground", &"factory_hall", &"factory_block"]


static func names() -> Array[StringName]:
	return ZONES.duplicate()


static func scene_path(zone: StringName) -> String:
	return "res://scenes/raid/zones/%s.tscn" % zone


static func build(zone: StringName, zb: ZoneBuilder) -> bool:
	match zone:
		&"ground":
			ZoneGround.build(zb)
		&"factory_hall":
			ZoneFactoryHall.build(zb)
		&"factory_block":
			ZoneFactoryBlock.build(zb)
		_:
			return false
	return true
