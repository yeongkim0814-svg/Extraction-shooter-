extends GutTest
## KitLayout 표가 tools/gen_textures_v2.py가 쓴 kit_layout.json과 같은지, 줄이 겹치거나 시트를 넘지 않는지 확인한다.

const JSON_PATH: String = "res://assets/textures/v2/kit_layout.json"


func _load_json() -> Dictionary:
	var f: FileAccess = FileAccess.open(JSON_PATH, FileAccess.READ)
	assert_not_null(f, "kit_layout.json을 열 수 있어야 한다")
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert_true(parsed is Dictionary, "JSON 최상위는 객체")
	return parsed if parsed is Dictionary else {}


func test_constants_match_json_header() -> void:
	var data: Dictionary = _load_json()
	assert_eq(int(data.get("size", 0)), KitLayout.SIZE)
	assert_eq(float(data.get("texels_per_m", 0)), KitLayout.TEXELS_PER_M)


func test_table_matches_json() -> void:
	var data: Dictionary = _load_json()
	var sheets: Dictionary = data.get("sheets", {})
	assert_eq(sheets.size(), KitLayout.STRIPS.size(), "시트 수")
	for sheet: int in KitLayout.STRIPS:
		var table: Dictionary = KitLayout.STRIPS[sheet]
		var jt: Dictionary = sheets.get(str(sheet), {})
		assert_eq(jt.size(), table.size(), "시트 %d 줄 수" % sheet)
		for strip_name: StringName in table:
			assert_true(jt.has(String(strip_name)), "JSON에 %s 있음" % strip_name)
			if not jt.has(String(strip_name)):
				continue
			var span: Vector2i = table[strip_name]
			var j: Dictionary = jt[String(strip_name)]
			assert_eq(int(j["y"]), span.x, "%d.%s y" % [sheet, strip_name])
			assert_eq(int(j["h"]), span.y, "%d.%s h" % [sheet, strip_name])
			var v: Vector2 = KitLayout.v_range(sheet, strip_name)
			assert_almost_eq(float(j["v0"]), v.x, 0.00001)
			assert_almost_eq(float(j["v1"]), v.y, 0.00001)


func test_no_overlap_and_within_sheet() -> void:
	for sheet: int in KitLayout.STRIPS:
		var spans: Array[Vector2i] = []
		for strip_name: StringName in KitLayout.STRIPS[sheet]:
			var span: Vector2i = KitLayout.STRIPS[sheet][strip_name]
			assert_true(span.x >= 0 and span.x + span.y <= KitLayout.SIZE, "%d.%s 시트 안" % [sheet, strip_name])
			spans.append(span)
		spans.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		for i: int in range(1, spans.size()):
			assert_true(spans[i].x >= spans[i - 1].x + spans[i - 1].y, "시트 %d 줄 겹침" % sheet)


func test_helpers() -> void:
	assert_true(KitLayout.has_strip(KitLayout.SHEET_FIXTURES, KitLayout.CABINET))
	assert_false(KitLayout.has_strip(KitLayout.SHEET_METAL, KitLayout.CABINET))
	assert_almost_eq(KitLayout.strip_height_m(KitLayout.SHEET_STRUCTURE, KitLayout.WALL), 160.0 / 256.0, 0.0001)
	assert_eq(KitLayout.v_range(9, &"x"), Vector2(0.0, 1.0))
