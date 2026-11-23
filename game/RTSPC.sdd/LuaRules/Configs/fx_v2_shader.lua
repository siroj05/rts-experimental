-- Port noise, palet dan mask dari FxAwan.shader/FxApiVolume.shader milik V2.
local cloud = {
    vertex = [[
        varying vec2 uv;
        varying vec3 data;
        void main() {
            uv = gl_MultiTexCoord0.xy;
            data = gl_MultiTexCoord1.xyz;
            gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        }
    ]],
    fragment = [[
        varying vec2 uv;
        varying vec3 data;
        float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
        float noise2(vec2 p) {
            vec2 i = floor(p), f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
            return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
                mix(hash2(i + vec2(0, 1)), hash2(i + 1.0), f.x), f.y);
        }
        void main() {
            vec2 p = uv * 2.0 - 1.0;
            float seed = data.x, tone = data.y;
            float n = noise2(p * 3.0 + seed) * .55 + noise2(p * 7.0 - seed) * .30 + noise2(p * 15.0 + seed * 2.0) * .15;
            float alpha = (1.0 - smoothstep(.25, 1.0, length(p) + (n - .5) * .4)) * data.z * (.6 + .4 * n);
            if (alpha < .004) discard;
            float g = n * .7 + uv.y * .3;
            vec3 smoke = mix(vec3(.19, .20, .21), vec3(.43, .44, .44), g);
            vec3 dark = mix(vec3(.045, .05, .055), vec3(.17, .175, .18), g);
            vec3 dust = mix(vec3(.24, .18, .115), vec3(.50, .40, .27), n * .65 + uv.y * .35);
            vec3 white = mix(vec3(.55, .57, .60), vec3(.86, .88, .90), n * .6 + uv.y * .4);
            vec3 col = tone > 1.5 ? white : (tone < 0.0 ? mix(smoke, dark, -tone) : mix(smoke, dust, tone));
            gl_FragColor = vec4(col * (.70 + .30 * uv.y), alpha);
        }
    ]],
}

local fire = {
    vertex = [[
        varying vec3 normal, view, p;
        void main() {
            vec4 eye = gl_ModelViewMatrix * gl_Vertex;
            view = -eye.xyz;
            normal = gl_NormalMatrix * gl_Normal;
            p = gl_Vertex.xyz;
            gl_Position = gl_ProjectionMatrix * eye;
        }
    ]],
    fragment = [[
        varying vec3 normal, view, p;
        uniform vec3 fx;
        float hash3(vec3 p) {
            p = fract(p * .3183099 + .1) * 17.0;
            return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
        }
        float noise3(vec3 p) {
            vec3 i = floor(p), f = smoothstep(vec3(0), vec3(1), fract(p));
            return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
                mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
                mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
                mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
        }
        float grains(vec3 p) {
            return .57 * noise3(p) + .28 * noise3(p * 2.03 + 3.1) + .15 * noise3(p * 4.12 + 7.7);
        }
        vec3 ramp(float h) {
            vec3 c0 = vec3(.012, .006, .004), c1 = vec3(.09, .012, .002), c2 = vec3(.75, .07, .004),
                c3 = vec3(1, .26, .02), c4 = vec3(1, .45, .07), c5 = vec3(1, .82, .41);
            if (h < .16) return mix(c0, c1, smoothstep(0.0, .16, h));
            if (h < .34) return mix(c1, c2, smoothstep(.16, .34, h));
            if (h < .55) return mix(c2, c3, smoothstep(.34, .55, h));
            if (h < .78) return mix(c3, c4, smoothstep(.55, .78, h));
            return mix(c4, c5, smoothstep(.78, 1.0, h));
        }
        void main() {
            float alpha = fx.x, kind = fx.y, seed = fx.z;
            float facing = clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0);
            float r = sqrt(1.0 - facing * facing);
            vec3 q = p * 4.2 + vec3(seed, seed * 1.37, seed * .71) + vec3(0, (1.0 - alpha) * .35, 0);
            q += (vec3(noise3(q), noise3(q + 5.2), noise3(q + 9.7)) - .5) * .9;
            float shape = r + (grains(q + alpha * 1.6) - .5) * 1.55 + (1.0 - alpha) * .55;
            float mask = 1.0 - smoothstep(kind < .5 ? .6 : .70, .99, shape);
            float heat = clamp((1.0 - smoothstep(.05, 1.02, shape) + (grains(q * 3.0 + 7.7) - .5) * .7)
                * (.25 + .75 * alpha) + (kind < .5 ? .30 : .14), 0.0, 1.0);
            float a = mask * smoothstep(0.0, .18, alpha);
            if (a < .01) discard;
            gl_FragColor = vec4(ramp(heat) * (.75 + pow(heat, 3.0) * .65), a);
        }
    ]],
}

return {cloud = cloud, fire = fire}
