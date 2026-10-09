extends Control
## 개발용 시작 메뉴. 버튼으로 데모 씬을 열거나, 실행 인자로 바로 연다:
##   네이티브: godot -- --scene=inventory | --scene=platform | --scene=combat | --scene=ai | --scene=raid | --scene=style_a | --scene=style_b
##   웹:      index.html?scene=inventory | ?scene=platform | ?scene=combat | ?scene=ai | ?scene=raid | ?scene=style_a | ?scene=style_b

const SCENES: Dictionary[String, String] = {
	"platform": "res://scenes/dev/platform_test.tscn",
	"inventory": "res://scenes/dev/inventory_demo.tscn",
	"combat": "res://scenes/dev/combat_test.tscn",
	"ai": "res://scenes/dev/ai_test.tscn",
	"raid": "res://scenes/raid/industrial.tscn",
	"style_a": "res://scenes/dev/style_compare.tscn",
	"style_b": "res://scenes/dev/style_compare.tscn",
}


func _ready() -> void:
	%PlatformButton.pressed.connect(_open.bind("platform"))
	%InventoryButton.pressed.connect(_open.bind("inventory"))
	%CombatButton.pressed.connect(_open.bind("combat"))
	%AiButton.pressed.connect(_open.bind("ai"))
	%RaidButton.pressed.connect(_open.bind("raid"))
	%StyleAButton.pressed.connect(_open.bind("style_a"))
	%StyleBButton.pressed.connect(_open.bind("style_b"))
	var requested: String = _requested_scene()
	if SCENES.has(requested):
		# 씬 트리가 준비된 뒤에 전환한다
		_open.call_deferred(requested)


func _open(scene_name: String) -> void:
	# 스타일 비교 씬은 한 씬 파일을 두 스타일로 쓴다 (URL 인자가 없으면 여기서 고른 값을 따른다)
	StyleCompare.forced_style = StyleCompare.Style.B if scene_name == "style_b" else (StyleCompare.Style.A if scene_name == "style_a" else -1)
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
