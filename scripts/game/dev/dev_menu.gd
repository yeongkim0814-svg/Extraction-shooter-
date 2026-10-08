extends Control
## 개발용 시작 메뉴. 버튼으로 데모 씬을 열거나, 실행 인자로 바로 연다:
##   네이티브: godot -- --scene=inventory | --scene=platform
##   웹:      index.html?scene=inventory | ?scene=platform

const SCENES: Dictionary[String, String] = {
	"platform": "res://scenes/dev/platform_test.tscn",
	"inventory": "res://scenes/dev/inventory_demo.tscn",
}


func _ready() -> void:
	%PlatformButton.pressed.connect(_open.bind("platform"))
	%InventoryButton.pressed.connect(_open.bind("inventory"))
	var requested: String = _requested_scene()
	if SCENES.has(requested):
		# 씬 트리가 준비된 뒤에 전환한다
		_open.call_deferred(requested)


func _open(scene_name: String) -> void:
	get_tree().change_scene_to_file(SCENES[scene_name])


static func _requested_scene() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			return arg.substr("--scene=".length())
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search")
		if query is String:
			for pair: String in (query as String).trim_prefix("?").split("&"):
				if pair.begins_with("scene="):
					return pair.substr("scene=".length())
	return ""
