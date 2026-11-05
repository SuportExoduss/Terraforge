shader_type spatial;
// Superfície do planeta (porta do PlanetSurface.shader do Unity). Mantém a textura do modelo onde
// ninguém conquistou e, onde há território, mostra o BIOMA da civilização dona (DD-114..122):
//  - mapa de posse equirretangular (rgb = cor do solo, a = cobertura) + mapa de ids (R = dono);
//  - borda ondulada por ruído, piso em triplanar (atlas de texturas) com relevo UDN;
//  - a camada de bioma SOBE sobre a terra neutra (DD-121): o vértice é levantado em vertex(),
//    com a MESMA conta do TerritoryPainter.get_elevation_at (que sustenta os pés do corredor);
//  - bioma morto (DD-122): ficha em ground_tint.a = 0 → piso morto ou cor dessaturada e escurecida.
// Convenção de uv: u = atan(z,x)/2pi + 0.5 ; v = asin(y)/pi + 0.5 (linha 0 da imagem = polo sul).

uniform sampler2D model_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 model_color : source_color = vec4(1.0);

uniform sampler2D ownership_map : source_color, filter_linear, repeat_enable;
uniform sampler2D id_map : filter_nearest, repeat_enable;
uniform sampler2DArray ground_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray ground_normal : filter_linear_mipmap, repeat_enable;

uniform vec3 planet_center = vec3(0.0);
uniform float terra_seed = 0.0;

// Uma posição por civilização (índice = id - 1), até 16.
uniform vec4 ground_params[16];   // x = tiling, y = fatia do atlas (-1 sem textura), z = relevo, w = altura
uniform vec4 ground_tint[16];     // rgb = correção de cor, a = 1 vivo / 0 morto
uniform vec4 dead_tint[16];       // rgb = correção do piso morto, a = fatia do piso morto (-1 sem)

varying vec3 v_world;
varying vec3 v_normal;

vec2 dir_to_uv(vec3 d) {
	return vec2(atan(d.z, d.x) * 0.15915494 + 0.5, asin(clamp(d.y, -1.0, 1.0)) * 0.31830989 + 0.5);
}

// Texel inteiro do mapa (mesma conta do GDScript: x dá a volta, y é preso).
ivec2 texel_of(vec2 uv, ivec2 size) {
	return ivec2(int(floor(uv.x * float(size.x))), clamp(int(floor(uv.y * float(size.y))), 0, size.y - 1));
}

float own_alpha(ivec2 p, ivec2 size) {
	return texelFetch(ownership_map, ivec2(((p.x % size.x) + size.x) % size.x, clamp(p.y, 0, size.y - 1)), 0).a;
}

int owner_index_at(ivec2 p, ivec2 size) {
	float r = texelFetch(id_map, ivec2(((p.x % size.x) + size.x) % size.x, clamp(p.y, 0, size.y - 1)), 0).r;
	return int(r * 255.0 + 0.5) - 1;
}

// Altura da camada de bioma sob esta direção (DD-121). 0 fora do território.
float layer_height(vec3 dir) {
	ivec2 size = textureSize(ownership_map, 0);
	ivec2 c = texel_of(dir_to_uv(dir), size);
	const int R = 5;
	float a = 2.0 * own_alpha(c, size) + own_alpha(c + ivec2(R, 0), size) + own_alpha(c - ivec2(R, 0), size)
			+ own_alpha(c + ivec2(0, R), size) + own_alpha(c - ivec2(0, R), size);
	if (a <= 0.0) {
		return 0.0;
	}
	float fill = smoothstep(0.06, 0.9, a / 6.0);
	float top = 0.0;
	ivec2 offs[5] = ivec2[5](ivec2(0), ivec2(R, 0), ivec2(-R, 0), ivec2(0, R), ivec2(0, -R));
	for (int i = 0; i < 5; i++) {
		int idx = owner_index_at(c + offs[i], size);
		if (idx >= 0 && idx < 16) {
			top = max(top, ground_params[idx].w);
		}
	}
	return fill * top;
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec4 own_at(vec2 uv, vec2 half_texel) {
	return texture(ownership_map, vec2(uv.x, clamp(uv.y, half_texel.y, 1.0 - half_texel.y)));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = normalize(wp - planet_center);
	float h = layer_height(dir);
	if (h > 0.0) {
		// desloca em mundo, converte para o espaço local (escala uniforme + rotação)
		VERTEX += (transpose(mat3(MODEL_MATRIX)) * (dir * h)) / dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
		wp += dir * h;
	}
	v_world = wp;
	v_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 geo_n = normalize(v_normal);
	vec3 dir = normalize(v_world - planet_center);
	vec3 albedo = (texture(model_albedo, UV) * model_color).rgb;
	vec3 shading_n = geo_n;

	vec2 uv = dir_to_uv(dir);
	vec2 texel = 1.0 / vec2(textureSize(ownership_map, 0));
	vec2 ht = texel * 0.5;
	vec2 t = texel * 8.0;
	// 10 amostras em anel: centro (peso 2) + 4 eixos + 4 diagonais (peso 1)
	vec4 blend = own_at(uv, ht) * 2.0
			+ own_at(uv + vec2(t.x, 0.0), ht) + own_at(uv - vec2(t.x, 0.0), ht)
			+ own_at(uv + vec2(0.0, t.y), ht) + own_at(uv - vec2(0.0, t.y), ht)
			+ own_at(uv + t * 0.7071, ht) + own_at(uv - t * 0.7071, ht)
			+ own_at(uv + vec2(t.x, -t.y) * 0.7071, ht) + own_at(uv + vec2(-t.x, t.y) * 0.7071, ht);
	blend *= 0.1;
	float fill = smoothstep(0.06, 0.9, blend.a);

	if (fill > 0.0) {
		float crumble = vnoise(dir * 40.0 + terra_seed) * 0.6 + vnoise(dir * 120.0 + terra_seed) * 0.4;
		float coverage = smoothstep(0.12, 0.8, fill + (0.5 - crumble) * 0.35);
		if (coverage > 0.001) {
			vec3 soil = blend.rgb / max(blend.a, 0.001);
			float relief = 0.0;
			vec3 tn_w = vec3(0.0);
			int idx = owner_index_at(texel_of(uv, textureSize(ownership_map, 0)), textureSize(ownership_map, 0));
			if (idx >= 0 && idx < 16) {
				vec4 gp = ground_params[idx];
				bool dead = ground_tint[idx].a < 0.5;
				float slice = dead ? dead_tint[idx].a : gp.y;
				if (slice >= -0.5) {
					vec3 tint = dead ? dead_tint[idx].rgb : ground_tint[idx].rgb;
					vec3 p = (v_world - planet_center) * (gp.x * 0.01);
					vec3 w = abs(geo_n);
					w /= (w.x + w.y + w.z);
					vec3 tex = texture(ground_albedo, vec3(p.zy, slice)).rgb * w.x
							+ texture(ground_albedo, vec3(p.xz, slice)).rgb * w.y
							+ texture(ground_albedo, vec3(p.xy, slice)).rgb * w.z;
					soil = tex * tint * 2.0;   // cinza 0,5 = neutro
					// relevo triplanar (UDN, Golus)
					vec3 nx = (texture(ground_normal, vec3(p.zy, slice)).xyz * 2.0 - 1.0) * vec3(gp.z, gp.z, 1.0);
					vec3 ny = (texture(ground_normal, vec3(p.xz, slice)).xyz * 2.0 - 1.0) * vec3(gp.z, gp.z, 1.0);
					vec3 nz = (texture(ground_normal, vec3(p.xy, slice)).xyz * 2.0 - 1.0) * vec3(gp.z, gp.z, 1.0);
					nx = vec3(nx.xy + geo_n.zy, geo_n.x);
					ny = vec3(ny.xy + geo_n.xz, geo_n.y);
					nz = vec3(nz.xy + geo_n.xy, geo_n.z);
					tn_w = normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
					relief = 1.0;
				} else if (dead) {
					soil = mix(soil, vec3(dot(soil, vec3(0.299, 0.587, 0.114))), 0.6) * 0.45;
				}
			}
			albedo = mix(albedo, soil, coverage);
			if (relief > 0.0) {
				shading_n = normalize(mix(geo_n, tn_w, coverage));
			}
		}
	}

	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(shading_n, 0.0)).xyz);
}
