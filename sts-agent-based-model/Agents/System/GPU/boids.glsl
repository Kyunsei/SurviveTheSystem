#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer PosBuffer { float v[]; } pos;
layout(set = 0, binding = 1, std430) restrict buffer VelBuffer { float v[]; } vel;
layout(set = 0, binding = 2, std430) restrict buffer Active { int v[]; } active_buf;

layout(push_constant, std430) uniform Params {
    float delta;
    float max_speed;
    float max_force;
    float perception_radius;
    float sep_weight;
    float align_weight;
    float cohesion_weight;
    float world_size_x;
    float world_size_y;
    float world_size_z;
    uint boundary;
    uint agent_count;
    uint _pad0;
    uint _pad1;
    uint _pad2;
    uint _pad3;
} params;

vec3 get_pos(uint i, uint n) { return vec3(pos.v[i], pos.v[n + i], pos.v[2u * n + i]); }
vec3 get_vel(uint i, uint n) { return vec3(vel.v[i], vel.v[n + i], vel.v[2u * n + i]); }

void set_pos(uint i, uint n, vec3 p) {
    pos.v[i] = p.x; pos.v[n + i] = p.y; pos.v[2u * n + i] = p.z;
}
void set_vel(uint i, uint n, vec3 v) {
    vel.v[i] = v.x; vel.v[n + i] = v.y; vel.v[2u * n + i] = v.z;
}

void main() {
    uint i = gl_GlobalInvocationID.x;
    uint n = params.agent_count;
    if (i >= n) return;
    if (active_buf.v[i] == 0) return;

    vec3 my_pos = get_pos(i, n);
    vec3 my_vel = get_vel(i, n);

    vec3 separation = vec3(0.0);
    vec3 avg_vel = vec3(0.0);
    vec3 avg_pos = vec3(0.0);
    int neighbor_count = 0;

    float r2 = params.perception_radius * params.perception_radius;

    for (uint j = 0u; j < n; j++) {
        if (j == i) continue;
        if (active_buf.v[j] == 0) continue;

        vec3 other_pos = get_pos(j, n);
        vec3 diff = my_pos - other_pos;
        float d2 = dot(diff, diff);
        if (d2 > r2 || d2 < 0.0001) continue;

        float d = sqrt(d2);
        separation += diff / d;
        avg_vel += get_vel(j, n);
        avg_pos += other_pos;
        neighbor_count++;
    }

    vec3 accel = vec3(0.0);
    if (neighbor_count > 0) {
        separation /= float(neighbor_count);
        avg_vel /= float(neighbor_count);
        avg_pos /= float(neighbor_count);

        accel += separation * params.sep_weight;
        accel += (avg_vel - my_vel) * params.align_weight;
        accel += (avg_pos - my_pos) * params.cohesion_weight;
    }

    float accel_len = length(accel);
    if (accel_len > params.max_force) {
        accel = accel / accel_len * params.max_force;
    }

    vec3 new_vel = my_vel + accel * params.delta;
    float speed = length(new_vel);
    if (speed > params.max_speed) {
        new_vel = new_vel / speed * params.max_speed;
    } else if (speed < 0.001) {
        new_vel = vec3(0.001, 0.0, 0.0);
    }

    vec3 new_pos = my_pos + new_vel * params.delta;

    if (params.boundary != 0u) {
        vec3 world_max = vec3(params.world_size_x, params.world_size_y, params.world_size_z);
        if (new_pos.x < 0.0 || new_pos.x > world_max.x) new_vel.x = -new_vel.x;
        if (new_pos.y < 0.0 || new_pos.y > world_max.y) new_vel.y = -new_vel.y;
        if (new_pos.z < 0.0 || new_pos.z > world_max.z) new_vel.z = -new_vel.z;
        new_pos = clamp(new_pos, vec3(0.0), world_max);
    }

    set_pos(i, n, new_pos);
    set_vel(i, n, new_vel);
}