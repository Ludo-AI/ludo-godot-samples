shader_type canvas_item;
// the hit flash: mix the sprite toward white, alpha kept
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
