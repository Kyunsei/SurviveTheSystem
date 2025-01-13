#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script

layout(set = 0, binding = 0, std430) restrict buffer Occupation_Buffer_0 {
    float data[];
}
occupation_buffer_0;

layout(set = 0, binding = 1, std430) restrict buffer Energy_Buffer_0 {
    float data[];
}
energy_buffer_0;


layout(set = 0, binding = 2, std430) restrict buffer Occupation_Buffer_1 {
    float data[];
}
occupation_buffer_1;

layout(set = 0, binding = 3, std430) restrict buffer Energy_Buffer_1 {
    float data[];
}
energy_buffer_1;


layout(set = 0, binding = 4, std430) restrict buffer Occupation_Buffer_2 {
    float data[];
}
occupation_buffer_2;

layout(set = 0, binding = 5, std430) restrict buffer Energy_Buffer_2 {
    float data[];
}
energy_buffer_2;





// The code we want to execute in each invocation
void main(){
    
    uint gid = gl_GlobalInvocationID.x;

    energy_buffer_1.data[gid] = energy_buffer_0.data[gid] - occupation_buffer_0.data[gid];
    energy_buffer_2.data[gid] = energy_buffer_0.data[gid] - occupation_buffer_1.data[gid] - occupation_buffer_0.data[gid];


}


   
