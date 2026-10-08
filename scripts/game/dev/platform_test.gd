extends Node3D
## M4 platform verification scene (overlay text is ASCII: web default font lacks Hangul). Compatibility(웹)·Mobile(안드로이드) 양쪽에서 동작하는 기능만 사용한다.

const ORBIT_RADIUS: float = 9.0
const ORBIT_HEIGHT: float = 4.0
const ORBIT_SPEED: float = 0.25

var _camera: Camera3D
var _label: Label
var _angle: float = 0.0
var _info_timer: float = 0.0


func _ready() -> void:
	_build_environment()
	_build_light()
	_build_camera()
	_build_overlay()
	_update_label()
	print("PLATFORM_TEST: " + _info_line())


func _process(delta: float) -> void:
	_angle += delta * ORBIT_SPEED
	_camera.position = Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_angle) * ORBIT_RADIUS)
	_camera.look_at(Vector3(0.0, 0.8, 0.0))
	_info_timer += delta
	if _info_timer >= 0.5:
		_info_timer = 0.0
		_update_label()


func _info_line() -> String:
	var method: String = RenderingServer.get_current_rendering_method()
	var vp: Vector2i = get_viewport().get_visible_rect().size
	return "renderer=%s os=%s adapter=%s viewport=%dx%d fps=%d" % [
		method, OS.get_name(), RenderingServer.get_video_adapter_name(), vp.x, vp.y,
		Engine.get_frames_per_second()]


func _update_label() -> void:
	var method: String = RenderingServer.get_current_rendering_method()
	var vp: Vector2i = get_viewport().get_visible_rect().size
	_label.text = "FPS: %d\nRenderer: %s\nOS: %s\nAdapter: %s\nViewport: %dx%d" % [
		Engine.get_frames_per_second(), method, OS.get_name(),
		RenderingServer.get_video_adapter_name(), vp.x, vp.y]


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.75, 0.8)
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.7
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	add_child(sun)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(ORBIT_RADIUS, ORBIT_HEIGHT, 0.0)
	_camera.current = true
	add_child(_camera)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16.0, 16.0)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	add_child(layer)
