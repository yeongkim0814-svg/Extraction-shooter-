class_name StyleDust
extends RefCounted
## 스타일 D의 떠다니는 먼지 입자 (빛줄기 안). 웹은 CPUParticles3D, 그 밖(모바일 등)은 GPUParticles3D. 개수는 적게.

const COUNT: int = 36


static func make(center: Vector3, extents: Vector3) -> Node3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.9, 0.82, 0.68, 0.55)
	mat.disable_receive_shadows = true
	quad.material = mat
	if OS.has_feature("web"):
		var cpu := CPUParticles3D.new()
		cpu.name = "Dust"
		cpu.position = center
		cpu.amount = COUNT
		cpu.lifetime = 9.0
		cpu.preprocess = 9.0
		cpu.mesh = quad
		cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		cpu.emission_box_extents = extents
		cpu.direction = Vector3(0.3, 1.0, 0.1)
		cpu.spread = 60.0
		cpu.initial_velocity_min = 0.02
		cpu.initial_velocity_max = 0.09
		cpu.gravity = Vector3(0.0, -0.005, 0.0)
		cpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return cpu
	var gpu := GPUParticles3D.new()
	gpu.name = "Dust"
	gpu.position = center
	gpu.amount = COUNT
	gpu.lifetime = 9.0
	gpu.preprocess = 9.0
	gpu.visibility_aabb = AABB(-extents * 1.6, extents * 3.2)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3(0.3, 1.0, 0.1)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.09
	pm.gravity = Vector3(0.0, -0.005, 0.0)
	gpu.process_material = pm
	gpu.draw_pass_1 = quad
	gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return gpu
