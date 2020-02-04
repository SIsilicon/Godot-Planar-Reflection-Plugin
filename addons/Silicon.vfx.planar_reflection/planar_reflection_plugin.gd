tool
extends EditorPlugin

var editor_camera : Camera
var viewport_size : Vector2

func _enter_tree() -> void:
	name = "PlanarReflectionPlugin"
	print("planar reflection plugin enter tree")

func _ready() -> void:
	viewport_size = get_viewport().size

func _exit_tree():
	print("planar reflection plugin enter tree")

func forward_spatial_gui_input(p_camera : Camera, p_event : InputEvent) -> bool:
	if not editor_camera:
		editor_camera = p_camera
	return false

func handles(object):
	return true
