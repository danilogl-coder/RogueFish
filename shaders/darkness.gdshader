shader_type canvas_item;
// Depth darkness with up to 16 soft lights, quantised + dithered for a pixel-art look.
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.01, 0.02, 0.07, 1.0);
uniform int light_count = 0;
uniform vec4 lights[16];
uniform vec2 rect_size = vec2(640.0, 360.0);
uniform float pixel = 3.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 pp = floor(p);
	float lit = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= light_count) { break; }
		vec4 L = lights[i];
		float d = length(pp - L.xy) / max(L.z, 1.0);
		lit = max(lit, (1.0 - smoothstep(0.35, 1.0, d)) * L.w);
	}
	float a = darkness * (1.0 - clamp(lit, 0.0, 1.0));
	float steps = 6.0;
	a = floor(a * steps + bayer4(pp)) / steps;
	COLOR = vec4(tint.rgb, clamp(a, 0.0, 0.96));
}
