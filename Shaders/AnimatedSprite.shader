shader_type canvas_item;
render_mode unshaded;

uniform sampler2D frame1: hint_albedo;
uniform sampler2D frame2: hint_albedo;
uniform sampler2D frame3: hint_albedo;
uniform sampler2D frame4: hint_albedo;
uniform sampler2D frame5: hint_albedo;
uniform float speed = 1.0;

void fragment() {
	float time = fract(TIME*speed);
	vec4 col;
	if (time < 0.2) {
		col = texture(frame1, UV);
	} else if (time < 0.4) {
		col = texture(frame2, UV);
	} else if (time < 0.6) {
		col = texture(frame3, UV);
	}  else if (time < 0.8) {
		col = texture(frame4, UV);
	} else {
		col = texture(frame5, UV);
	}
	COLOR = col;
}