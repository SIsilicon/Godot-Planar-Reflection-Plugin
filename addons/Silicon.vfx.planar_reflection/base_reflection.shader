shader_type spatial;

//PR__UNIFORMS_AND_FUNCTIONS__PR//
uniform sampler2D viewport;
uniform vec4 viewport_rect = vec4(-2.0, -2.0, 4.0, 4.0);

vec3 fresnel(vec3 f0, float cos_theta) {
	vec3 fres = f0 + (vec3(1.0) - f0)*pow(1.0 - abs(cos_theta), 5.0);
	return fres;
}

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0/6.0);
}

vec4 texture_bicubic(sampler2D sampler, vec2 tex_coords) {
	vec2 tex_size = vec2(textureSize(sampler, 0));
	vec2 inv_tex_size = 1.0 / tex_size;
	
	tex_coords = tex_coords * tex_size - 0.5;
	
	vec2 fxy = fract(tex_coords);
	tex_coords -= fxy;
	
	vec4 xcubic = cubic(fxy.x);
	vec4 ycubic = cubic(fxy.y);
	
	vec4 c = tex_coords.xxyy + vec2 (-0.5, +1.5).xyxy;
	
	vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;
	
	offset *= inv_tex_size.xxyy;
	
	vec4 sample0 = texture(sampler, offset.xz);
	vec4 sample1 = texture(sampler, offset.yz);
	vec4 sample2 = texture(sampler, offset.xw);
	vec4 sample3 = texture(sampler, offset.yw);
	
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	
	return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}
//PR__UNIFORMS_AND_FUNCTIONS__PR//

void fragment() {
	
	//PR__FRAGMENT_CODE__PR//
	vec3 reflectiveness = fresnel(mix(vec3(0.08), ALBEDO, METALLIC), dot(normalize(VERTEX), NORMAL));
	
	vec4 model_pos = inverse(WORLD_MATRIX) * CAMERA_MATRIX * vec4(VERTEX, 1.0);
	vec2 uv = (vec2(model_pos.x, -model_pos.y) - viewport_rect.xy) / viewport_rect.zw;
	vec4 reflection = texture_bicubic(viewport, uv);
	if(any(isnan(reflection))) {
		reflection = vec4(1.0);
	}
	reflectiveness *= pow(1.0 - ROUGHNESS, 4.0);
	EMISSION = reflection.rgb * reflectiveness * reflection.a;
	ALBEDO = mix(ALBEDO, vec3(0.0), reflection.a * reflectiveness);
	ROUGHNESS = mix(ROUGHNESS, 1.0, pow(reflection.a, 4.0) * mix(reflectiveness.g, 1.0, METALLIC));
	METALLIC = mix(METALLIC, 1.0, pow(reflection.a, 4.0) * mix(reflectiveness.g, 1.0, METALLIC));
	//PR__FRAGMENT_CODE__PR//
	
}
