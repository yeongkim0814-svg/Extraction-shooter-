class_name SmokePlume
extends Node3D
## 굴뚝 연기 기둥 (느리게 올라가며 퍼지는 어두운 회색 연기).
## 모바일/데스크톱 렌더러(Mobile·Forward+)는 GPUParticles3D, 웹의 Compatibility 렌더러는 CPUParticles3D를 쓴다.
## 파티클 양은 품질 단계의 배율(set_amount_ratio)로 줄인다. 시작할 때 이미 연기가 피어 있도록 preprocess를 준다.

const GROUP: StringName = &"gfx_smoke"
const LIFETIME: float = 18.0
const BASE_AMOUNT: int = 26
const DIRECTION := Vector3(0.28, 1.0, 0.06)
const WIND := Vector3(0.7, 0.12, 0.1)
const VISIBILITY := AABB(Vector3(-30.0, -4.0, -30.0), Vector3(150.0, 90.0, 60.0))

static var _material: StandardMaterial3D
static var _color_ramp: Gradient
static var _scale_curve: Curve

var _gpu: GPUParticles3D
var _cpu: CPUParticles3D


## 이 렌더러에서 GPU 파티클을 쓰는가 (웹·Compatibility는 CPU 파티클).
static func uses_gpu() -> bool:
	if OS.has_feature("web"):
		return false
	var method: String = RenderingServer.get_current_rendering_method()
	return method == "mobile" or method == "forward_plus"


func _ready() -> void:
	add_to_group(GROUP)
	if uses_gpu():
		_build_gpu()
	else:
		_build_cpu()


## 품질 단계의 연기 양 배율 (0~1).
func set_amount_ratio(ratio: float) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	if _gpu != null:
		_gpu.amount_ratio = clamped
	if _cpu != null:
		_cpu.amount = maxi(1, int(round(float(BASE_AMOUNT) * clamped)))


func is_gpu() -> bool:
	return _gpu != null


func particle_amount() -> int:
	if _gpu != null:
		return int(round(float(_gpu.amount) * _gpu.amount_ratio))
	return _cpu.amount if _cpu != null else 0


static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		var blob := Gradient.new()
		blob.set_color(0, Color(1, 1, 1, 1))
		blob.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = blob
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.vertex_color_use_as_albedo = true
		_material.albedo_texture = tex
		_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_material.billboard_keep_scale = true
		_material.particles_anim_h_frames = 1
		_material.particles_anim_v_frames = 1
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


static func _ramp() -> Gradient:
	if _color_ramp == null:
		_color_ramp = Gradient.new()
		_color_ramp.offsets = PackedFloat32Array([0.0, 0.1, 0.55, 1.0])
		_color_ramp.colors = PackedColorArray([Color(0.14, 0.15, 0.17, 0.0), Color(0.17, 0.18, 0.2, 0.5),
				Color(0.26, 0.28, 0.31, 0.32), Color(0.34, 0.36, 0.4, 0.0)])
	return _color_ramp


static func _growth() -> Curve:
	if _scale_curve == null:
		_scale_curve = Curve.new()
		_scale_curve.add_point(Vector2(0.0, 0.4))
		_scale_curve.add_point(Vector2(1.0, 1.0))
	return _scale_curve


func _quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = _shared_material()
	return quad


func _build_gpu() -> void:
	_gpu = GPUParticles3D.new()
	_gpu.amount = BASE_AMOUNT
	_gpu.lifetime = LIFETIME
	_gpu.preprocess = LIFETIME * 0.85
	_gpu.visibility_aabb = VISIBILITY
	_gpu.local_coords = false
	_gpu.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	_gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.8
	proc.direction = DIRECTION
	proc.spread = 10.0
	proc.initial_velocity_min = 2.4
	proc.initial_velocity_max = 3.6
	proc.gravity = WIND
	proc.damping_min = 0.15
	proc.damping_max = 0.3
	proc.scale_min = 7.0
	proc.scale_max = 11.0
	var curve_tex := CurveTexture.new()
	curve_tex.curve = _growth()
	proc.scale_curve = curve_tex
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = _ramp()
	proc.color_ramp = ramp_tex
	proc.angle_min = 0.0
	proc.angle_max = 360.0
	_gpu.process_material = proc
	_gpu.draw_pass_1 = _quad()
	add_child(_gpu)


func _build_cpu() -> void:
	_cpu = CPUParticles3D.new()
	_cpu.amount = BASE_AMOUNT
	_cpu.lifetime = LIFETIME
	_cpu.preprocess = LIFETIME * 0.85
	_cpu.visibility_aabb = VISIBILITY
	_cpu.local_coords = false
	_cpu.draw_order = CPUParticles3D.DRAW_ORDER_LIFETIME
	_cpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_cpu.emission_sphere_radius = 0.8
	_cpu.direction = DIRECTION
	_cpu.spread = 10.0
	_cpu.initial_velocity_min = 2.4
	_cpu.initial_velocity_max = 3.6
	_cpu.gravity = WIND
	_cpu.damping_min = 0.15
	_cpu.damping_max = 0.3
	_cpu.scale_amount_min = 7.0
	_cpu.scale_amount_max = 11.0
	_cpu.scale_amount_curve = _growth()
	_cpu.color_ramp = _ramp()
	_cpu.angle_min = 0.0
	_cpu.angle_max = 360.0
	_cpu.mesh = _quad()
	add_child(_cpu)
