class_name RetroPost
extends CanvasLayer
## 스타일 C 후처리 층: 전체 화면 ColorRect에 retro_post.gdshader를 씌운다.
## HUD는 이 층보다 큰 layer에 두면 영향받지 않는다 (기본 layer 50). 유니폼은 set_param/apply로 따로 조절하고, enabled로 켜고 끈다.

const SHADER: String = "res://assets/shaders/retro_post.gdshader"
## 기본값 (셰이더 유니폼 이름 -> 값). 강도는 "느끼기엔 약하게" 맞춘 값이다.
const DEFAULTS: Dictionary[StringName, Variant] = {
	&"pixel_size": 1.0,
	&"color_levels": 40.0,
	&"quant_strength": 0.7,
	&"dither_strength": 0.35,
	&"grain_strength": 0.03,
	&"grain_scale": 1.0,
	&"vignette_strength": 0.32,
	&"vignette_radius": 0.9,
	&"shadow_tint": Color(0.9, 0.95, 1.06),
	&"highlight_tint": Color(1.08, 1.02, 0.9),
	&"split_strength": 0.45,
	&"split_pivot": 0.45,
	&"saturation": 0.92,
	&"contrast": 1.04,
	&"brightness": 1.0,
}

var _material: ShaderMaterial
var _rect: ColorRect

## 후처리를 켜고 끈다 (비교용).
var enabled: bool = true:
	set(value):
		enabled = value
		if _rect != null:
			_rect.visible = value


func _init() -> void:
	layer = 50
	name = "RetroPost"
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER) as Shader
	_rect = ColorRect.new()
	_rect.name = "Screen"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _material
	add_child(_rect)
	apply(DEFAULTS)


func set_param(param: StringName, value: Variant) -> void:
	_material.set_shader_parameter(param, value)


func get_param(param: StringName) -> Variant:
	return _material.get_shader_parameter(param)


## 여러 값을 한꺼번에 (일부만 담아도 된다).
func apply(values: Dictionary) -> void:
	for key: Variant in values:
		_material.set_shader_parameter(key as StringName, values[key])
