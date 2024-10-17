#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script

layout(set = 0, binding = 0, std430) restrict buffer BlockBuffer {
    float data[];
}
block_buffer;

layout(set = 0, binding = 1, std430) restrict buffer BlockBuffer_0 {
    float data[];
}
block_buffer_0;

layout(set = 0, binding = 3, std430) restrict buffer BlockBuffer_1 {
    float data[];
}
block_buffer_state;

layout(set = 0, binding = 2, std430) restrict buffer BlockArraybuffer_par {
    float data[];
}
block_buffer_par;

//  block_buffer_par = [diffusion_factor,diffusion_number,diffusion_min_limit,diffusion_block_limit]


float numberblockadj = 4.0;
float dt =  block_buffer_par.data[0]; //0.5;
float minvalue = block_buffer_par.data[2];
//int worldsize = 20;
int getArrayLength = block_buffer.data.length(); 

int worldsize = int(sqrt(float(getArrayLength)));


// The code we want to execute in each invocation
void main(){
    
    uint gid = gl_GlobalInvocationID.x;


    //Horizontal transfer, between block

    //left border
    if (gid % worldsize == 0 ){

        // top corner
        if(gid < worldsize){
            numberblockadj = 2;
            numberblockadj = 1*block_buffer_state.data[gid+1] + 0*block_buffer_state.data[gid-1] + 1*block_buffer_state.data[gid+1*worldsize] + 0*block_buffer_state.data[gid-1*worldsize];

            //first axis
            block_buffer.data[gid] += max(0, 1* (block_buffer_0.data[gid+1]- minvalue)/4 * dt) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] += max(0,0* (block_buffer_0.data[gid-1]- minvalue)/4* dt) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] += max(0, 1* (block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] += max(0, 0*(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];
            }

        // bottom corner
        else if(gid > (worldsize*worldsize -worldsize-1)){
            numberblockadj = 2;
            numberblockadj = 1*block_buffer_state.data[gid+1] + 0*block_buffer_state.data[gid-1] + 0*block_buffer_state.data[gid+1*worldsize] + 1*block_buffer_state.data[gid-1*worldsize];


            //first axis
            block_buffer.data[gid] += max(0, 1* (block_buffer_0.data[gid+1]- minvalue)/4 * dt) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] +=max(0, 0* (block_buffer_0.data[gid-1]- minvalue)/4* dt) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] +=  0*max(0,(block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] +=  1*max(0,(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];
         }

        else{
            numberblockadj = 3;
            numberblockadj = 1*block_buffer_state.data[gid+1] + 0*block_buffer_state.data[gid-1] + 1*block_buffer_state.data[gid+1*worldsize] + 1*block_buffer_state.data[gid-1*worldsize];

            //first axis
            block_buffer.data[gid] += max(0, 1* (block_buffer_0.data[gid+1]- minvalue)/4 * dt ) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] += max(0, 0* (block_buffer_0.data[gid-1]- minvalue)/4* dt ) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];
        }

    }

    //right border
    else if((gid + 1) % worldsize == 0){
        //top corner
        if(gid < (worldsize)){
            numberblockadj = 2;
            numberblockadj = 0*block_buffer_state.data[gid+1] + 1*block_buffer_state.data[gid-1] + 1*block_buffer_state.data[gid+1*worldsize] + 0*block_buffer_state.data[gid-1*worldsize];


            //first axis
            block_buffer.data[gid] +=  0* max(0,(block_buffer_0.data[gid+1]- minvalue)/4 * dt) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1]- minvalue)/4* dt) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] +=  1* max(0,(block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] +=  0*max(0,(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];
            }

        //bottom corner
        else if(gid > (worldsize*worldsize -worldsize-1)){
            numberblockadj = 2;
            numberblockadj = 0*block_buffer_state.data[gid+1] + 1*block_buffer_state.data[gid-1] + 0*block_buffer_state.data[gid+1*worldsize] + 1*block_buffer_state.data[gid-1*worldsize];


            //first axis
            block_buffer.data[gid] +=  0* max(0,(block_buffer_0.data[gid+1]- minvalue)/4 * dt) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1]- minvalue)/4* dt) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] +=  0*max(0,(block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] +=  1*max(0,(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];
         }

        else{
            numberblockadj = 3;
            numberblockadj = 0*block_buffer_state.data[gid+1] + 1*block_buffer_state.data[gid-1] + 1*block_buffer_state.data[gid+1*worldsize] + 1*block_buffer_state.data[gid-1*worldsize];

            //first axis
            block_buffer.data[gid] += 0* max(0,(block_buffer_0.data[gid+1]- minvalue)/4 * dt) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1]- minvalue)/4* dt) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];
        }
    }


    //left border
    else if(gid < worldsize){
           numberblockadj = 3;
            numberblockadj = 1*block_buffer_state.data[gid+1] + 1*block_buffer_state.data[gid-1] + 1*block_buffer_state.data[gid+1*worldsize] + 0*block_buffer_state.data[gid-1*worldsize];

            //first axis
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid+1]- minvalue)/4 * dt) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1]- minvalue)/4* dt) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] += 0* max(0,(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];
    }

    //right border
    else if(gid > (worldsize*worldsize - worldsize)){
            numberblockadj = 3;
            numberblockadj = 1*block_buffer_state.data[gid+1] + 1*block_buffer_state.data[gid-1] + 0*block_buffer_state.data[gid+1*worldsize] + 1*block_buffer_state.data[gid-1*worldsize];

            //first axis
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid+1]- minvalue)/4 * dt) * block_buffer_state.data[gid+1];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1]- minvalue)/4* dt) * block_buffer_state.data[gid-1];

            //second axis
            block_buffer.data[gid] += 0* max(0,(block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
            block_buffer.data[gid] += 1* max(0,(block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize];

    }


    else{
    numberblockadj = 4;
    numberblockadj = block_buffer_state.data[gid+1] + block_buffer_state.data[gid-1] + block_buffer_state.data[gid+1*worldsize] + block_buffer_state.data[gid-1*worldsize];

    //first axis
    block_buffer.data[gid] +=  max(0, (1*block_buffer_0.data[gid+1]- minvalue)/4 * dt ) * block_buffer_state.data[gid+1];
    block_buffer.data[gid] +=  max(0, (1*block_buffer_0.data[gid-1]- minvalue)/4* dt ) * block_buffer_state.data[gid-1];

    //second axis
    block_buffer.data[gid] +=  max(0, (1*block_buffer_0.data[gid+1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid+1*worldsize];
    block_buffer.data[gid] +=  max(0, (1*block_buffer_0.data[gid-1*worldsize]- minvalue)/4 * dt) * block_buffer_state.data[gid-1*worldsize] ;
    }


    // correct energy added for void

    block_buffer.data[gid] = block_buffer.data[gid] * block_buffer_state.data[gid];


    //howmuch they gave

    block_buffer.data[gid] -= max(0, (block_buffer_0.data[gid]- minvalue)*numberblockadj/4 * dt) ;

    //block_buffer.data[gid] = gid;
}


        
