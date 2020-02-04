tool
extends MeshInstance

# Exported variables
var extents := Vector2(2, 2) setget set_extents
var resolution := 256 setget set_resolution
var clip_distance := 0.1 setget set_clip_distance
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
		"clip_distance":
			set_clip_distance(value)
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
		"clip_distance":
			return clip_distance
		"transparent":
			return transparent
		"cull_mask":
			return cull_mask

func _get_property_list() -> Array:
	var props := []
	
	props += [{"name": "extents", "type": TYPE_VECTOR2}]
	props += [{"name": "resolution", "type": TYPE_INT}]
	props += [{"name": "clip_distance", "type": TYPE_REAL}]
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
	reflect_mesh.set_surface_material(0, reflect_material)
	
	# add viewport
	reflect_viewport = Viewport.new()
	reflect_viewport.keep_3d_linear = true
	reflect_viewport.hdr = true
	reflect_viewport.transparent_bg = true
	reflect_viewport.msaa = Viewport.MSAA_4X
	reflect_viewport.shadow_atlas_size = 512
	reflect_viewport.name = "reflect_vp"
	add_child(reflect_viewport)
	
	reflect_material.resource_local_to_scene = true
	
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
	set_clip_distance(clip_distance)
	set_cull_mask(cull_mask)

func _process(delta : float) -> void:
	if not reflect_camera or not reflect_viewport:
		return
	
	# Get main camera
	if Engine.editor_hint:
		main_cam = plugin.editor_camera
	else:
		var root_viewport = get_tree().root
		main_cam = root_viewport.get_camera()
	
	# Compute reflection plane and its global transform  (origin in the middle, 
	#  X and Y axis properly aligned with the viewport, -Z is the mirror's forward direction) 
	var plane_mark := global_transform * Transform().rotated(Vector3.RIGHT, PI)
	var plane_origin := plane_mark.origin
	var plane_normal := plane_mark.basis.z.normalized()
	var reflection_plane := Plane(plane_normal, plane_origin.dot(plane_normal))
	var reflection_transform := plane_mark
	
	# Main camera position
	var cam_pos := main_cam.global_transform.origin 
	
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
	t = t.translated(Vector3.FORWARD * clip_distance * 1.0)
	reflect_camera.set_global_transform(t)
	
	# Compute the tilting offset for the frustum (the X and Y coordinates of the mirrored camera position
	#	when expressed in the reflection plane coordinate system) 
	var offset = reflection_transform.xform_inv(cam_pos)
	offset = Vector2(offset.x, offset.y)
	
	# Set mirror camera frustum
	# - size 	-> mirror's width (camera is set to KEEP_WIDTH)
	# - offset 	-> previously computed tilting offset
	# - z_near 	-> distance between the mirror camera and the reflection plane (this ensures we won't
	#               be reflecting anything behind the mirror)
	# - z_far	-> large arbitrary value (render distance limit form th mirror camera position)
	var z_near := proj_pos.distance_to(cam_pos)
	z_near += clip_distance
	reflect_camera.set_frustum(extents.y, -offset, z_near, 1000.0)

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

func set_clip_distance(value : float) -> void:
	clip_distance = max(value, 0)

func set_transparent(value : bool) -> void:
	transparent = value
	if reflect_material:
		reflect_material.set_shader_param("transparent", transparent)

func set_cull_mask(value : int) -> void:
	cull_mask = value
	if reflect_camera:
		reflect_camera.cull_mask = cull_mask
