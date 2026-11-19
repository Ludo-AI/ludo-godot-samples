shader_type canvas_item;
// chapter 4 only: the hit flash plus a left-to-right reveal of the outlined sheet (cols = frames per row)
uniform float flash = 0.0;
uniform float reveal = 2.0;
uniform float cols = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (fract(UV.x * cols) > reveal) { c.a = 0.0; }
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
