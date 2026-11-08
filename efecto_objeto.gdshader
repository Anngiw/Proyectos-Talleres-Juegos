shader_type spatial;

uniform vec3 color_base : source_color = vec3(0.0, 0.96, 0.83);
uniform vec3 color_flash : source_color = vec3(1.0, 0.72, 0.01);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = mix(color_base, color_flash, flash);
	EMISSION = color_flash * flash;
}
