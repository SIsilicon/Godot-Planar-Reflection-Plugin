tool
extends MeshInstance

export(int) var pixels_per_unit = 200

var reflect_viewport : Viewport
var reflect_material : Material

var plugin : EditorPlugin

var main_cam = null
var reflect_camera = null

func _ready():
	
	#create mirror material
	reflect_material = get_surface_material(0)
#	reflect_material = SpatialMaterial.new()
#	reflect_material.flags_unshaded = true
#	reflect_material.texture
#	set_surface_material(0, reflect_material)
	
	if Engine.editor_hint:
		plugin = get_node("/root/EditorNode/PlanarReflectionPlugin")
	
	# add viewport
	reflect_viewport = Viewport.new()
	reflect_viewport.keep_3d_linear = true
	reflect_viewport.hdr = true
	reflect_viewport.transparent_bg = true
	reflect_viewport.msaa = Viewport.MSAA_DISABLED
	reflect_viewport.shadow_atlas_size = 512
	reflect_viewport.name = "reflect_vp"
	
	add_child(reflect_viewport)
	reflect_viewport.owner = self
	reflect_viewport.add_child(reflect_camera)
	
	reflect_material.resource_local_to_scene = true
	
	yield(get_tree(), 'idle_frame')
	yield(get_tree(), 'idle_frame')
	
	var reflect_tex = reflect_viewport.get_texture()
	reflect_tex.set_flags(Texture.FLAG_FILTER)
	if not Engine.is_editor_hint(): reflect_tex.viewport_path = "/root/" + get_node("/root").get_path_to(reflect_viewport)
	
	initialize_camera()

func _process(delta):
	resize_viewport()
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
	var plane_mark = global_transform * Transform().rotated(Vector3.RIGHT, PI)
	var plane_origin = plane_mark.origin
	var plane_normal = plane_mark.basis.z.normalized()
	var reflection_plane = Plane(plane_normal, plane_origin.dot(plane_normal))
	var reflection_transform = plane_mark
	
	# Main camera position
	var cam_pos = main_cam.global_transform.origin 
	
	# The projected point of main camera's position onto the reflection plane
	var proj_pos = reflection_plane.project(cam_pos)
	
	# Main camera position reflected over the mirror's plane
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
	# Compute mirror camera transform
	# - origin at the mirrored position
	# - looking perpedicularly into the relfection plane (this way the near clip plane will be 
	#      parallel to the reflection plane) 
	var t = Transform(Basis(), mirrored_pos)
	t = t.looking_at(proj_pos, reflection_transform.basis.y.normalized())
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
	reflect_camera.set_frustum(mesh.size.y, -offset, proj_pos.distance_to(cam_pos), 1000.0)

func resize_viewport() -> void:
	var new_size : Vector2 = Vector2(mesh.size.x, mesh.size.y) * pixels_per_unit
	
#	if Engine.is_editor_hint():
#		plugin = get_node("/root/EditorNode/PlanarReflectionPlugin")
#		new_size = plugin.editor_camera.get_parent().size
#	else:
#		new_size = get_viewport().size
	new_size = new_size.floor()
	if new_size != reflect_viewport.size:
		reflect_viewport.size = new_size

func initialize_camera():
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
	
#	if Engine.editor_hint:
#		reflect_viewport.owner = get_tree().edited_scene_root
#		reflect_camera.owner = get_tree().edited_scene_root
	
	# Set material texture
	get_surface_material(0).set_shader_param("viewport", reflect_viewport.get_texture())
	print(reflect_viewport.get_texture())

