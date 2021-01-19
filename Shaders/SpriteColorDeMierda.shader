shader_type canvas_item;
uniform vec4 new:hint_color;
uniform bool enabled:bool;
void fragment() {
    vec4 current_pixel = texture(TEXTURE, UV);
	if (enabled) {
    	COLOR.r = new.r;
		COLOR.g = new.g;
		COLOR.b = new.b;
		COLOR.a = current_pixel.a;
	} else {
		COLOR = current_pixel
	}
}