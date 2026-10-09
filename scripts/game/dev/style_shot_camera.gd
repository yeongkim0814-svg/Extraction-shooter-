class_name StyleShotCamera
extends Camera3D
## 스타일 비교 씬을 굽기용으로 저장한 씬(style_d_bake.tscn)의 카메라: StyleCompare.SHOTS 3컷을 N·1·2·3 키 또는 터치로 넘긴다.
## 시작할 때 LightmapGI의 라이트맵 데이터가 있는지 로그로 알린다 (없으면 에디터에서 굽기 전이다).

const PREFIX: String = "STYLE: "

var _shot: int = 0


func _ready() -> void:
	current = true
	far = 700.0
	_go(0)
	var present: bool = false
	for node: Node in get_tree().current_scene.find_children("*", "LightmapGI", true, false):
		if (node as LightmapGI).light_data != null:
			present = true
	print(PREFIX + "bake scene lightmap=" + ("present" if present else "missing (LightmapGI > Bake Lightmaps)"))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_N, KEY_SPACE, KEY_TAB:
				_go((_shot + 1) % StyleCompare.SHOTS.size())
			KEY_1:
				_go(0)
			KEY_2:
				_go(1)
			KEY_3:
				_go(2)
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed:
		_go((_shot + 1) % StyleCompare.SHOTS.size())


func _go(index: int) -> void:
	_shot = index
	var s: Dictionary = StyleCompare.SHOTS[index]
	position = s["pos"] as Vector3
	fov = float(s["fov"])
	look_at(s["target"] as Vector3, Vector3.UP)
	print(PREFIX + "bake shot %d" % (index + 1))
