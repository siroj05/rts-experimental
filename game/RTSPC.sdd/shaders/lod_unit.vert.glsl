layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 4) in vec2 texcoord;
layout(location = 5) in float pieceIndex;
layout(location = 6) in uvec4 instance;

struct Transform {
    vec4 quat;
    vec4 trSc;
};
layout(std140, binding = 0) readonly buffer TransformBuffer {
    Transform transforms[];
};

out vec2 uv;
flat out vec3 tint;
out vec3 worldNormal;
out vec3 toCamera;
out vec4 shadowCoord;

Transform pose(uint index) {
    Transform a = transforms[index];
    Transform b = transforms[index + 1u];
    float blend = clamp(timeInfo.w, 0.0, 1.0);
    vec4 end = dot(a.quat, b.quat) < 0.0 ? -b.quat : b.quat;
    return Transform(normalize(mix(a.quat, end, blend)), mix(a.trSc, b.trSc, blend));
}

vec3 rotate(vec4 q, vec3 v) {
    return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

void main() {
    uint index = instance.x + 2u * (1u + uint(pieceIndex));
    // Track phases use Hide/Show in the native unit script.
    if (transforms[index + 1u].trSc.w <= 0.0) {
        gl_Position = vec4(0.0, 0.0, 2.0, 1.0);
        return;
    }
    Transform part = pose(index);
    Transform world = pose(instance.x);
    vec3 modelPos = part.trSc.xyz + rotate(part.quat, position * part.trSc.w);
    vec4 worldPos = vec4(world.trSc.xyz + rotate(world.quat, modelPos * world.trSc.w), 1.0);
    worldNormal = rotate(world.quat, rotate(part.quat, normal));
    uv = texcoord;
    tint = teamColor[instance.z & 0x07ffu].rgb;
    toCamera = cameraViewInv[3].xyz - worldPos.xyz;
    shadowCoord = shadowView * worldPos;
    shadowCoord.xy += vec2(0.5);
    gl_Position = cameraViewProj * worldPos;
}
