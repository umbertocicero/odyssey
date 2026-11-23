// Profilo della riva del livello 1, condiviso da mare e sabbia.
// DEVE restare identico a scripts/rendering/shore_profile.gd (stesse costanti e formule).
// Il mare ricava da qui la profondità dell'acqua (niente depth texture), la sabbia la quota
// sul pelo dell'acqua per il bagnato e la risacca.

const float WATER_Y = -0.1;     // quota del pelo dell'acqua (cima del box del mare)
const float SEABED_Y = -0.6;    // fondale al largo
const float Z_MIN = -19.0;      // estremi nord e sud del bacino
const float Z_MAX = 22.0;
uniform float shore_base_x = -21.75;   // x media della linea di riva

float smooth01(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// x mondiale della linea d'acqua (golfi e promontori) alla coordinata z.
float shore_line(float z) {
	return shore_base_x + 0.50 * sin(z * 0.29 + 0.9) + 0.28 * sin(z * 0.71 + 3.1) + 0.12 * sin(z * 1.63 + 5.0);
}

// Quota del fondale/sabbia sotto il pelo dell'acqua (vale solo dove è < WATER_Y; a terra torna >= WATER_Y).
float shore_floor(float x, float z) {
	float s = x - shore_line(z);
	float h = SEABED_Y + 0.5 * exp(0.6 * min(s, 0.0));
	if (s > 0.0) {
		h = WATER_Y + 0.19 * (1.0 - exp(-0.85 * s));
	}
	// Testa nord del bacino: il fondale risale a quota 0 contro il terreno, con un bordo ondulato
	// (a sud il bacino finisce sul bordo del diorama).
	float wob = 0.30 * sin(x * 0.55 + 1.0) + 0.15 * sin(x * 1.37 + 2.0);
	float rn = SEABED_Y + 0.6 * smooth01(-16.3, -19.2, z + wob);
	return max(h, rn);
}

// Peso del terreno originale (0 = sabbia generata, 1 = terreno) con un po' di rumore `warp` (-0.5..0.5)
// che rende irregolare il confine. Gemello di ShoreProfile.terrain_weight().
float shore_terrain_weight(vec2 p, float warp) {
	float wx = smooth01(-20.5, -19.2, p.x + warp * 1.0);
	float wn = smooth01(-19.2, -20.9, p.y + warp * 1.2);
	return max(wx, wn);
}

// Quota (m) fino alla quale arriva l'onda di risacca in un dato punto e istante: sale e scende
// con ritmo diverso lungo la riva, così le onde non arrivano tutte insieme.
float swash_level(vec2 p, float t) {
	float w = sin(t * 0.85 + p.y * 0.33 + sin(p.y * 0.9) * 1.2);
	float w2 = sin(t * 1.9 + p.y * 0.61 + 1.3);
	return WATER_Y + 0.035 + 0.075 * (0.5 + 0.5 * w) + 0.015 * w2;
}
