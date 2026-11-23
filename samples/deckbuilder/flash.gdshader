shader_type canvas_item;
// The fighters' shader (ours, #47).
// flash: the hit flash; modulate only multiplies, so ink stays dark; this mixes every pixel toward white.
// rim > 0: a dark outline that far out (in sheet pixels), so a fighter stands off a background of the same brightness.
// r3 (founder note 0:04.6 "the characters look quite dark against a dark bg"):
//   lift, gamma: the fighter's own brightness (1 = as drawn; gamma lifts the shadows more than the lights); light_w/light_col/light_dir: a rim light on the edges that face the
//   light (the lighthouse lamp, behind them); glow_w/glow_col: a soft pale halo just outside the silhouette.
// dissolve 0..1: the death's exit, the body breaks up into sea foam from the edges in (glow on the burning edge).
uniform float flash = 0.0;
uniform float rim = 0.0;
uniform float lift = 1.0;
uniform float gamma = 1.0;
uniform float light_w = 0.0;
uniform vec4 light_col : source_color = vec4(0.85, 0.93, 1.0, 1.0);
uniform vec2 light_dir = vec2(-0.55, -0.83);
uniform float glow_w = 0.0;
uniform vec4 glow_col : source_color = vec4(0.8, 0.9, 1.0, 0.5);
uniform float dissolve = 0.0;
uniform vec2 cell = vec2(100000.0, 100000.0);   // one frame's size in the sheet
uniform vec4 foam_col : source_color = vec4(0.75, 0.95, 1.0, 1.0);

varying vec4 mod_col;
void vertex() { mod_col = COLOR; }   // the node's modulate alone: in fragment() COLOR already holds the texture sample

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = min(pow(c.rgb, vec3(gamma)) * lift, vec3(1.0));   // gamma < 1 opens the dark ink and shell
	if (light_w > 0.0) {   // lit edge: inside the body where the pixel toward the light is empty
		float open = 0.0;
		for (int i = 1; i <= 3; i++) {
			open += 1.0 - texture(TEXTURE, UV + light_dir * light_w * float(i) / 3.0 * TEXTURE_PIXEL_SIZE).a;
		}
		open = clamp(open / 2.0, 0.0, 1.0) * c.a;
		c.rgb = mix(c.rgb, light_col.rgb, open * light_col.a);
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	if (rim > 0.0 || glow_w > 0.0) {
		float a = 0.0; float g = 0.0;
		for (int i = 0; i < 12; i++) {
			vec2 d = vec2(cos(float(i) * 6.2831853 / 12.0), sin(float(i) * 6.2831853 / 12.0)) * TEXTURE_PIXEL_SIZE;
			if (rim > 0.0) a = max(a, texture(TEXTURE, UV + d * rim).a);
			if (glow_w > 0.0) {
				g = max(g, texture(TEXTURE, UV + d * glow_w * 0.35).a);
				g = max(g, 0.6 * texture(TEXTURE, UV + d * glow_w * 0.7).a);
				g = max(g, 0.3 * texture(TEXTURE, UV + d * glow_w).a);
			}
		}
		vec4 o = vec4(0.03, 0.03, 0.04, 0.9 * a);
		if (glow_w > 0.0) {   // the halo sits outside the dark rim when both are on
			vec4 h = vec4(glow_col.rgb, glow_col.a * g);
			o = vec4(mix(h.rgb, o.rgb, o.a), max(h.a, o.a));
		}
		c = mix(o, vec4(c.rgb, 1.0), c.a);
		c.a = max(c.a, o.a);
	}
	if (dissolve > 0.0) {
		vec2 q = mod(UV / TEXTURE_PIXEL_SIZE, cell);   // in the frame's own pixels: the pattern stays put while frames change
		float n = vnoise(q / 9.0) * 0.7 + vnoise(q / 3.0) * 0.3;
		float cut = dissolve * 1.15 - 0.075;
		float edge = smoothstep(cut, cut + 0.08, n);
		c.rgb = mix(foam_col.rgb, c.rgb, smoothstep(cut + 0.02, cut + 0.1, n));
		c.a *= edge;
	}
	COLOR = c * mod_col;   // keep the node's modulate (a dying fighter fades with its health bar, REVIEW-R2 must). r3: r2 wrote
	                       // c * COLOR, and COLOR already holds the texture: every fighter's colour was squared (drawn darker, the
	                       // founder's note 0:04.6) and nothing outside the silhouette (the anglerfish's rim) was ever drawn
}
