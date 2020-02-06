tool
extends Node

var materials := []
var reflectors := []
var mat_ref_counts := []
#
#func _enter_tree() -> void:
#	VisualServer.connect("frame_pre_draw", self,"_pre_draw")

func _material_changed(index : int) -> void:
	var material = materials[index]
	prints(index, material)
	if material is SpatialMaterial:
		# We'll be right back. :P
		pass
	else: # is ShaderMaterial
		
		pass

func add_material(material : Material, planar) -> ShaderMaterial:
	if not material:
		return null
	
	var idx := materials.find(material)
	
	if idx == -1:
		material.connect("changed", self, "_material_changed", [materials.size()])
		materials.append(material)
		mat_ref_counts.append(1)
		
		var reflector := ShaderMaterial.new()
		reflector.shader = convert_material(material)
		reflectors.append({planar: reflector})
		return reflector
	else:
		mat_ref_counts[idx] += 1
		if reflectors[idx].has(planar):
			return reflectors[idx][planar]
		else:
			var reflector := ShaderMaterial.new()
			reflector.shader = convert_material(material)
			reflectors[idx][planar] = reflector
			return reflector

func remove_material(material : Material, planar) -> void:
	var idx := materials.find(material)
	if idx != -1:
		if mat_ref_counts[idx] <= 1:
			materials.remove(idx)
			reflectors.remove(idx)
			mat_ref_counts.remove(idx)
		else:
			mat_ref_counts[idx] -= 1
			reflectors[idx].erase(planar)

static func convert_material(material : Material) -> Shader:
	var base := preload("base_reflection.shader").code
	var code := VisualServer.shader_get_code(
			VisualServer.material_get_shader(material.get_rid())
	)
	
	var uni_func_start := base.find("//PR__UNIFORMS_AND_FUNCTIONS__PR//")
	var uni_func_length := base.find("//PR__UNIFORMS_AND_FUNCTIONS__PR//", uni_func_start + 1) - uni_func_start
	var uni_funcs = base.substr(uni_func_start, uni_func_length)
	
	code = code.insert(code.find(";") + 1, "\n" + uni_funcs)
	
	var frag_start := base.find("//PR__FRAGMENT_CODE__PR//")
	var frag_length := base.find("//PR__FRAGMENT_CODE__PR//", frag_start + 1) - frag_start
	var frag_code = base.substr(frag_start, frag_length)
	
	var regex := RegEx.new()
	regex.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*{")
	var has_fragment := regex.search(code)
	if has_fragment:
		var end := has_fragment.get_end() - 1
		var frag_end := find_closing_bracket(code, end)
		code = code.insert(frag_end, frag_code)
	else:
		code += "void fragment() {" + frag_code + "}"
	
	var shader := Shader.new()
	shader.code = code
	return shader

static func find_closing_bracket(string : String, open_bracket_idx : int) -> int:
	var bracket_count := 1
	var open_bracket := string.substr(open_bracket_idx, 1)
	var close_bracket := "}" if open_bracket == "{" else ")" if open_bracket == "(" else "]"
	var index := open_bracket_idx
	
	while index < string.length():
		var open_index = string.find(open_bracket, index+1)
		var close_index = string.find(close_bracket, index+1)
		
		prints(open_index, close_index)
		
		if close_index != -1 and (open_index == -1 or close_index < open_index):
			index = close_index
			bracket_count -= 1
		elif open_index != -1 and (close_index == -1 or open_index < close_index):
			index = open_index
			bracket_count += 1
		else:
			return -1
		
		if bracket_count <= 0:
			return index
	
	return -1
