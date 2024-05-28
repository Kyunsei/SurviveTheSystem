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



float numberblockadj = 4.0;
float dt = 0.5;
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

            //first axis
            block_buffer.data[gid] +=  1* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 0* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] +=  1* block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] +=  0*block_buffer_0.data[gid-1*worldsize]/4 * dt;
            }

        // bottom corner
        else if(gid > (worldsize*worldsize -worldsize-1)){
             numberblockadj = 2;

            //first axis
            block_buffer.data[gid] +=  1* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 0* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] +=  0*block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] +=  1*block_buffer_0.data[gid-1*worldsize]/4 * dt;
         }

        else{
            numberblockadj = 3;
            //first axis
            block_buffer.data[gid] += 1* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 0* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] += 1* block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1*worldsize]/4 * dt;
        }

    }

    //right border
    else if((gid + 1) % worldsize == 0){
        //top corner
        if(gid < (worldsize)){
            numberblockadj = 2;

            //first axis
            block_buffer.data[gid] +=  0* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] +=  1* block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] +=  0*block_buffer_0.data[gid-1*worldsize]/4 * dt;
            }

        //bottom corner
        else if(gid > (worldsize*worldsize -worldsize-1)){
             numberblockadj = 2;


            //first axis
            block_buffer.data[gid] +=  0* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] +=  0*block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] +=  1*block_buffer_0.data[gid-1*worldsize]/4 * dt;
         }

        else{
            numberblockadj = 3;
            //first axis
            block_buffer.data[gid] += 0* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] += 1* block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1*worldsize]/4 * dt;
        }
    }


    //left border
    else if(gid < worldsize){
           numberblockadj = 3;
            //first axis
            block_buffer.data[gid] += 1* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] += 1* block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] += 0* block_buffer_0.data[gid-1*worldsize]/4 * dt;
    }

    //right border
    else if(gid > (worldsize*worldsize - worldsize)){
           numberblockadj = 3;
            //first axis
            block_buffer.data[gid] += 1* block_buffer_0.data[gid+1]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1]/4* dt;

            //second axis
            block_buffer.data[gid] += 0* block_buffer_0.data[gid+1*worldsize]/4 * dt;
            block_buffer.data[gid] += 1* block_buffer_0.data[gid-1*worldsize]/4 * dt;

    }


    else{
    numberblockadj = 4;

    //first axis
    block_buffer.data[gid] +=  1*block_buffer_0.data[gid+1]/4 * dt;
    block_buffer.data[gid] +=  1*block_buffer_0.data[gid-1]/4* dt;

    //second axis
    block_buffer.data[gid] +=  1*block_buffer_0.data[gid+1*worldsize]/4 * dt;
    block_buffer.data[gid] +=  1*block_buffer_0.data[gid-1*worldsize]/4 * dt;
    }


    //howmuch they gave

    block_buffer.data[gid] -= block_buffer_0.data[gid]*numberblockadj/4 * dt;

    //block_buffer.data[gid] = gid;
}


        
