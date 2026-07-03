#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer PosBuffer { float v[]; } pos;
layout(set = 0, binding = 1, std430) restrict buffer Active { int v[]; } active_buf;

layout(push_constant, std430) uniform Params {
    float spd;
    float world_size_x;
    float world_size_y;
    float world_size_z;
    uint boundary;
    uint agent_count;
    uint frame_seed;
    uint _pad;
} params;

uint hash(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

float rand01(uint seed) {
    return float(hash(seed)) / 4294967295.0;
}

void main() {
    uint i = gl_GlobalInvocationID.x;
    uint n = params.agent_count;
    if (i >= n) return;
    if (active_buf.v[i] == 0) return;

    uint agent_seed = i * 0x9E3779B9u ^ params.frame_seed * 0x85EBCA6Bu;

    vec3 r = vec3(
        rand01(agent_seed + 0u) * 2.0 - 1.0,
        rand01(agent_seed + 1u) * 2.0 - 1.0,
        rand01(agent_seed + 2u) * 2.0 - 1.0
    );


    vec3 p = vec3(pos.v[i], pos.v[n + i], pos.v[2u * n + i]) + r * params.spd;

    if (params.boundary != 0u) {
        p = clamp(p, vec3(0.0), vec3(params.world_size_x, params.world_size_y, params.world_size_z));
    }

    pos.v[i] = p.x;
    pos.v[n + i] = p.y;
    pos.v[2u * n + i] = p.z;
}