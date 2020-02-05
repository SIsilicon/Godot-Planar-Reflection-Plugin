tool
extends MeshInstance

enum FitMode {
	FIT_AREA,
	FIT_VIEW
}

# Exported variables
var extents := Vector2(2, 2) setget set_extents
var resolution := 256 setget set_resolution
var fit_mode : int = FitMode.FIT_AREA setget set_fit_mode
var roughness := 0.01 setget set_roughness
var transparent := false setget set_transparent
var cull_mask := 0xfffff setget set_cull_mask

# Internal variables
var plugin : EditorPlugin

var reflect_mesh : MeshInstance
var reflect_viewport : Viewport
var reflect_material : Material

var main_cam : Camera
var reflect_camera : Camera

func _set(property : String, value) -> bool:
	match property:
		"extents":
			set_extents(value)
		"resolution":
			set_resolution(value)
		"fit_mode":
			set_fit_mode(value)
		"roughness":
			set_roughness(value)
		"transparent":
			set_transparent(value)
		"cull_mask":
			set_cull_mask(value)
		_:
			return false
	return true

func _get(property : String):
	match property:
		"extents":
			return extents
		"resolution":
			return resolution
		"fit_mode":
			return fit_mode
		"roughness":
			return roughness
		"transparent":
			return transparent
		"cull_mask":
			return cull_mask

func _get_property_list() -> Array:
	var props := []
	
	props += [{"name": "extents", "type": TYPE_VECTOR2}]
	props += [{"name": "resolution", "type": TYPE_INT}]
	props += [{"name": "fit_mode", "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Fit Area, Fit View"}]
	props += [{"name": "roughness", "type": TYPE_REAL, "hint": PROPERTY_HINT_RANGE, "hint_string": "0, 1"}]
	props += [{"name": "transparent", "type": TYPE_BOOL}]
	props += [{"name": "cull_mask", "type": TYPE_INT, "hint": PROPERTY_HINT_LAYERS_3D_RENDER}]
	
	return props

func _ready() -> void:
	if Engine.editor_hint:
		plugin = get_node("/root/EditorNode/PlanarReflectionPlugin")
	
	# Create mirror surface
	reflect_mesh = MeshInstance.new()
	reflect_mesh.mesh = QuadMesh.new()
	reflect_mesh.mesh.size = extents
	add_child(reflect_mesh)
	
	#create mirror material
	reflect_material = preload("reflection.material").duplicate()
	reflect_material.resource_local_to_scene = true
	reflect_material.render_priority = -2
	reflect_mesh.set_surface_material(0, reflect_material)
	
	# add viewport
	reflect_viewport = Viewport.new()
	reflect_viewport.keep_3d_linear = true
	reflect_viewport.hdr = true
	reflect_viewport.msaa = Viewport.MSAA_4X
	reflect_viewport.shadow_atlas_size = 512
	reflect_viewport.name = "reflect_vp"
	add_child(reflect_viewport)
	
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	
	var reflect_tex = reflect_viewport.get_texture()
	reflect_tex.set_flags(Texture.FLAG_FILTER)
	reflect_material.set_shader_param("viewport", reflect_tex)
	
	if not Engine.is_editor_hint():
		reflect_tex.viewport_path = "/root/" + get_node("/root").get_path_to(reflect_viewport)
	
	initialize_camera()
	
	set_extents(extents)
	set_resolution(resolution)
	set_transparent(transparent)
	set_roughness(roughness)
	set_cull_mask(cull_mask)
	
	material_override = reflect_material

func _process(delta : float) -> void:
	if not reflect_camera or not reflect_viewport:
		return
	
	# Get main camera and viewport
	var main_viewport : Viewport
	if Engine.editor_hint:
		main_cam = plugin.editor_camera
		main_viewport = main_cam.get_parent()
	else:
		main_viewport = get_viewport()
		main_cam = main_viewport.get_camera()
	
	# Compute reflection plane and its global transform  (origin in the middle, 
	#  X and Y axis properly aligned with the viewport, -Z is the mirror's forward direction) 
	var reflection_transform := global_transform * Transform().rotated(Vector3.RIGHT, PI)
	var plane_origin := reflection_transform.origin
	var plane_normal := reflection_transform.basis.z.normalized()
	var reflection_plane := Plane(plane_normal, plane_origin.dot(plane_normal))
	
	# Main camera position
	var cam_pos := main_cam.global_transform.origin 
	
	# Calculate the area the viewport texture will fit into.
	var rect : Rect2
	if fit_mode == FitMode.FIT_VIEW:
		# Area of the plane that's visible
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var ray := main_cam.project_ray_normal(corner * main_viewport.size)
			var intersection = reflection_plane.intersects_ray(cam_pos, ray)
			if not intersection:
				intersection = reflection_plane.project(cam_pos + ray * main_cam.far)
			intersection = reflection_transform.xform_inv(intersection)
			intersection = Vector2(intersection.x, intersection.y)
			
			if not rect:
				rect = Rect2(intersection, Vector2())
			else:
				rect = rect.expand(intersection)
		rect = Rect2(-extents / 2.0, extents).clip(rect)
		
		# Aspect ratio of our extents must also be enforced.
		var aspect = rect.size.aspect()
		if aspect > extents.aspect():
			rect = scale_rect2(rect, Vector2(1.0, aspect / extents.aspect()))
		else:
			rect = scale_rect2(rect, Vector2(extents.aspect() / aspect, 1.0))
	else:
		# Area of the whole plane
		rect = Rect2(-extents / 2.0, extents)
	reflect_material.set_shader_param("rect", Plane(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	
	var rect_center := rect.position + rect.size / 2.0
	reflection_transform.origin += reflection_transform.basis.x * rect_center.x
	reflection_transform.origin += reflection_transform.basis.y * rect_center.y
	
	# The projected point of main camera's position onto the reflection plane
	var proj_pos := reflection_plane.project(cam_pos)
	
	# Main camera position reflected over the mirror's plane
	var mirrored_pos := cam_pos + (proj_pos - cam_pos) * 2.0
	
	# Compute mirror camera transform
	# - origin at the mirrored position
	# - looking perpedicularly into the relfection plane (this way the near clip plane will be 
	#      parallel to the reflection plane) 
	var t := Transform(Basis(), mirrored_pos)
	t = t.looking_at(proj_pos, reflection_transform.basis.y.normalized())
	reflect_camera.set_global_transform(t)
	
	# Compute the tilting offset for the frustum (the X and Y coordinates of the mirrored camera position
	# when expressed in the reflection plane coordinate system) 
	var offset = reflection_transform.xform_inv(cam_pos)
	offset = Vector2(offset.x, offset.y)
	
	# Set mirror camera frustum
	# - size 	-> mirror's width (camera is set to KEEP_WIDTH)
	# - offset 	-> previously computed tilting offset
	# - z_near 	-> distance between the mirror camera and the reflection plane (this ensures we won't
	#               be reflecting anything behind the mirror)
	# - z_far	-> large arbitrary value (render distance limit form th mirror camera position)
	var z_near := proj_pos.distance_to(cam_pos)
	reflect_camera.set_frustum(rect.size.y, -offset, z_near, main_cam.far)

func resize_viewport() -> void:
	var new_size : Vector2 = Vector2(extents.aspect(), 1.0) * resolution
	if new_size.x > new_size.y:
		new_size = new_size / new_size.x * resolution
	
	new_size = new_size.floor()
	if new_size != reflect_viewport.size:
		reflect_viewport.size = new_size

func initialize_camera() -> void:
	if !is_inside_tree():
		return
	
	# Free mirror camera if it already exists
	if reflect_camera != null:
		reflect_camera.queue_free()
	
	# Add a mirror camera
	reflect_camera = Camera.new()
	reflect_camera.name = "reflect_cam"
	reflect_viewport.add_child(reflect_camera)
	reflect_camera.keep_aspect = Camera.KEEP_HEIGHT
	reflect_camera.current = true

func set_extents(value : Vector2) -> void:
	extents = value
	if reflect_mesh:
		reflect_mesh.mesh.size = extents
		resize_viewport()

func set_resolution(value : int) -> void:
	resolution = max(value, 1)
	if reflect_viewport:
		resize_viewport()

func set_fit_mode(value : int) -> void:
	fit_mode = value

func set_roughness(value : float) -> void:
	roughness = value
	if reflect_material:
		reflect_material.set_shader_param("roughness", roughness)

func set_transparent(value : bool) -> void:
	transparent = value
	if reflect_material:
		reflect_material.set_shader_param("transparent", transparent)

func set_cull_mask(value : int) -> void:
	cull_mask = value
	if reflect_camera:
		reflect_camera.cull_mask = cull_mask

static func scale_rect2(rect : Rect2, scale : Vector2) -> Rect2:
	var center = rect.position + rect.size / 2.0;
	rect.position -= center
	rect.size *= scale
	rect.position *= scale
	rect.position += center
	
	return rect
