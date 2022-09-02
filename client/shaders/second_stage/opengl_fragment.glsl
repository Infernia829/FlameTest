uniform sampler2D baseTexture;
uniform sampler2D normalTexture;
uniform sampler2D ShadowMapSampler;

uniform vec3 sunPositionScreen;
uniform float sunBrightness;
uniform vec3 moonPositionScreen;
uniform float moonBrightness;

uniform vec3 dayLight;

#define rendered baseTexture
#define normalmap normalTexture
#define depthmap ShadowMapSampler

#ifdef GL_ES
varying mediump vec2 varTexCoord;
#else
centroid varying vec2 varTexCoord;
#endif

const float far = 1000.;
const float near = 1.;
float mapDepth(float depth)
{
	return min(1., 1. / (1.00001 - depth) / far);
}

#if ENABLE_TONE_MAPPING

/* Hable's UC2 Tone mapping parameters
	A = 0.22;
	B = 0.30;
	C = 0.10;
	D = 0.20;
	E = 0.01;
	F = 0.30;
	W = 11.2;
	equation used:  ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F
*/

vec3 uncharted2Tonemap(vec3 x)
{
	return ((x * (0.22 * x + 0.03) + 0.002) / (x * (0.22 * x + 0.3) + 0.06)) - 0.03333;
}

vec4 applyToneMapping(vec4 color)
{
	color = vec4(pow(color.rgb, vec3(2.2)), color.a);
	const float gamma = 1.6;
	const float exposureBias = 5.5;
	color.rgb = uncharted2Tonemap(exposureBias * color.rgb);
	// Precalculated white_scale from
	//vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
	vec3 whiteScale = vec3(1.036015346);
	color.rgb *= whiteScale;
	return vec4(pow(color.rgb, vec3(1.0 / gamma)), color.a);
}
#endif

float noise(vec3 uvd) {
	return fract(dot(sin(uvd * vec3(13041.19699, 27723.29171, 61029.77801)), vec3(73137.11101, 37312.92319, 10108.89991)));
}

float sampleVolumetricLight(vec2 uv, vec3 lightVec, float rawDepth)
{
	lightVec = 0.5 * lightVec / lightVec.z + 0.5;
	float samples = 13.;
	float result = 0.;
	float bias = noise(vec3(uv, rawDepth));
	vec2 samplepos;
	for (float i = 0.; i < samples; i++) {
		samplepos = mix(uv, lightVec.xy, (i + bias) / samples);
		result += texture2D(depthmap, samplepos).r < 1. ? 0.0 : 1.0;
	}
	return result / samples;
}

void main(void)
{
	vec2 uv = varTexCoord.st;
	vec4 color = texture2D(rendered, uv).rgba;

	vec4 normal_and_sunlight = texture2D(normalmap, uv);
	float rawDepth = texture2D(depthmap, uv).r;
	float depth = mapDepth(rawDepth);
	vec3 lookDirection = normalize(vec3(uv.x * 2. - 1., uv.y * 2. - 1., 1. / tan(36. / 180. * 3.141596)));
	vec3 lightColor = pow(normal_and_sunlight.w, 2.) * dayLight;
	float lightFactor = 0.;

	if (sunPositionScreen.z > 0. && sunBrightness > 0.) {
		lightFactor = sunBrightness * sampleVolumetricLight(uv, sunPositionScreen, rawDepth) * pow(clamp(dot(sunPositionScreen, vec3(0., 0., 1.)), 0.0, 0.7), 2.5);
	}
	else if (moonPositionScreen.z > 0. && moonBrightness > 0.) {
		lightFactor = moonBrightness * sampleVolumetricLight(uv, moonPositionScreen, rawDepth) * pow(clamp(dot(moonPositionScreen, vec3(0., 0., 1.)), 0.0, 0.7), 2.5);
	}
	color.rgb = mix(color.rgb, lightColor, lightFactor);

	// if (sunPositionScreen.z < 0.)
	// 	color.rg += 1. - clamp(abs((2. * uv.xy - 1.) - sunPositionScreen.xy / sunPositionScreen.z) * 1000., 0., 1.);
	// if (moonPositionScreen.z < 0.)
	// 	color.rg += 1. - clamp(abs((2. * uv.xy - 1.) - moonPositionScreen.xy / moonPositionScreen.z) * 1000., 0., 1.);

#if ENABLE_TONE_MAPPING
	color = applyToneMapping(color);
#endif

	gl_FragColor = vec4(color.rgb, 1.0); // force full alpha to avoid holes in the image.
}
