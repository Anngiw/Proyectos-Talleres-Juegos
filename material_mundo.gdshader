shader_type spatial;

uniform vec3 color_bajo : source_color = vec3(0.05, 0.25, 0.5);
uniform float amplitud = 0.3;
uniform float longitud = 4.0;
uniform float periodo = 2.0;


uniform vec3 color_alto : source_color = vec3(0.6, 0.85, 0.95);
uniform float amplitud2 = 0.1;
uniform float longitud2 = 1.5;
uniform float periodo2 = 1.1;
varying float altura;

uniform float tiempo = 0.0;

float onda(float x, float t, float a, float l, float p) {
    return a * sin(TAU / l * x - TAU / p * t);
}

float pendiente(float x, float t, float a, float l, float p) {
    return a * (TAU / l) * cos(TAU / l * x - TAU / p * t);
}

void vertex() {
	
    float h = onda(VERTEX.x, TIME, amplitud, longitud, periodo)
            + onda(VERTEX.x, TIME, amplitud2, longitud2, periodo2);
            
    float s = pendiente(VERTEX.x, TIME, amplitud, longitud, periodo)
            + pendiente(VERTEX.x, TIME, amplitud2, longitud2, periodo2);
            
    VERTEX.y += h;
    NORMAL = normalize(vec3(-s, 1.0, 0.0));
    altura = h;
}

void fragment() {
   
    float m = clamp(altura / (2.0 * (amplitud + amplitud2)) + 0.5, 0.0, 1.0);
    ALBEDO = mix(color_bajo, color_alto, m);
    //EMISSION = ALBEDO * 1.5;mas adelante para hacerle un tipo lava
	ROUGHNESS = 0.4;
}