in vec2 uv;
flat in vec3 tint;
in vec3 worldNormal;
in vec3 toCamera;
in vec4 shadowCoord;

uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2DShadow shadowTex;
uniform sampler2D shadowColorTex;
uniform samplerCube reflectTex;
uniform int withShadows;

out vec4 color;

void main() {
    vec4 base = texture(tex1, uv);
    vec4 surface = texture(tex2, uv);
    if (surface.a < 0.5) discard;
    vec3 normal = normalize(worldNormal);
    vec3 sun = normalize(sunDir.xyz);
    vec3 view = normalize(toCamera);
    float diffuse = max(dot(normal, sun), 0.0);
    float halfAngle = max(dot(normal, normalize(sun + view)), 0.0);
    vec3 lightMod = vec3(1.0);
    if (withShadows != 0) {
        vec3 uvz = shadowCoord.xyz / shadowCoord.w;
        float shadow = min(texture(shadowTex, uvz), smoothstep(0.0, 0.35, diffuse));
        lightMod = mix(1.0, shadow, shadowDensity.y) * texture(shadowColorTex, uvz.xy).rgb;
    }
    vec3 light = sunAmbientModel.rgb + diffuse * sunDiffuseModel.rgb * lightMod;
    light = mix(light, texture(reflectTex, reflect(-view, normal)).rgb, surface.g) + surface.rrr;
    float shine = min(pow(halfAngle, 2.5 * sunSpecularModel.a) + 0.3 * pow(halfAngle, 6.0), 1.0);
    vec3 specular = sunSpecularModel.rgb * (4.0 * surface.g * shine) * lightMod;
    float fog = clamp((fogParams.y - length(toCamera)) * fogParams.w, 0.0, 1.0);
    color = vec4(mix(fogColor.rgb, mix(base.rgb, tint, base.a) * light + specular, fog), 1.0);
}
