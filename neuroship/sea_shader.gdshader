shader_type canvas_item;

uniform sampler2D NOISE;
uniform float noise_intensity = 0.25;
uniform float wave_width = 0.5;

uniform vec2 direction = vec2(1, 1);

uniform float ns = 0.5;
uniform float ts = 0.5;

uniform vec4 c1;
uniform vec4 c2;
uniform vec4 c3;

float edg(float in_) {
	return pow(1. - pow(1. - in_, 4), 2);
}

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	float b = dot(direction, direction);
	vec2 w = UV + direction / b * TIME * ns * ts;
	float h = TIME * ts + dot(direction, UV) + texture(NOISE, vec2(w.x - floor(w.x), w.y - floor(w.y))).x * noise_intensity;
	
	float i = h - floor(h);
	float j = max(0., 1. - (i / wave_width));
	float k = j * j;
	
	COLOR = c2 * k + c1 * (1. - k);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
