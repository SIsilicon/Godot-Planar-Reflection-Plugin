tool
extends EditorPlugin

var editor_camera : Camera

func _enter_tree() -> void:
	name = "PlanarReflectionPlugin"
	
	add_autoload_singleton("ReflectMaterialManager", "res://addons/Silicon.vfx.planar_reflection/reflect_material_manager.gd")
	add_custom_type("PlanarReflector", "MeshInstance", preload("planar_reflector.gd"), preload("planar_reflector_icon.svg"))
	
	print("planar reflection plugin enter tree")

func _exit_tree():
	remove_custom_type("PlanarReflector")
	remove_autoload_singleton("ReflectMaterialManager")
	
	print("planar reflection plugin exit tree")

func forward_spatial_gui_input(p_camera : Camera, p_event : InputEvent) -> bool:
	if not editor_camera:
		editor_camera = p_camera
	return false

func handles(object):
	return true
