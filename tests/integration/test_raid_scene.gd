extends GutTest
## 레이드 씬(산업단지)을 헤드리스로 띄워 맵·컨테이너·적·탈출 지점 구성을 확인한다 (M9).

var _scene: Node3D


func before_each() -> void:
	_scene = (load("res://scenes/raid/industrial.tscn") as PackedScene).instantiate() as Node3D
	add_child(_scene)
	await wait_physics_frames(12)


func after_each() -> void:
	_scene.queue_free()
	await wait_physics_frames(1)


func test_map_has_containers_extractions_and_cover() -> void:
	var map := _scene.get_node("Map") as IndustrialMap
	assert_gt(map.box_count, 100)
	assert_gte(map.containers.size(), 15)
	assert_eq(map.extraction_zones.size(), 3)
	assert_eq(map.enemy_routes.size(), 6)
	assert_not_null(map.lever)
	assert_gt(get_tree().get_nodes_in_group("cover_point").size(), 10)
	assert_lt(map.mesh_instance_count, 100, "메시는 재질별(구역 씬은 칸별)로 합쳐져 있어야 함")
	var flags: Array[StringName] = []
	for zone: ExtractionZone in map.extraction_zones:
		flags.append(zone.point.required_flag)
	assert_true(flags.has(&"power_on"))
	assert_eq(map.extraction_zones[0].point.wait_time, 7.0)


func test_world_starts_with_rolled_containers_and_enemies() -> void:
	var raid := _scene as RaidController
	assert_not_null(raid)
	var map := _scene.get_node("Map") as IndustrialMap
	assert_true(raid._world_ready)
	for container: LootContainer in map.containers:
		assert_ne(container.loot_key, &"")
		assert_gt(container.item_count(), 0)
	assert_eq(raid._enemies.size(), 6)
