#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer BlockMatrixBuffer {
    float data[];
}
blockmatrix_buffer;

layout(set = 0, binding = 1, std430) restrict buffer SphereBuffer {
    float data[];
}
sphere_buffer;


layout(set = 0, binding = 2, std430) restrict buffer ElementFlowInBuffer {
    float data[];
}
element_flow_in;


layout(set = 0, binding = 3, std430) restrict buffer ElementFlowOutBuffer {
    float data[];
}
element_flow_out;

layout(set = 0, binding = 4, std430) restrict buffer ElementFlowOutBtwBuffer {
    float data[];
}
element_flow_out_btw;

layout(set = 0, binding = 5, std430) restrict buffer BlockMatrixBufferTemp {
    float data[];
}
blockmatrix_buffer_0;


layout(set = 0, binding = 6, std430) restrict buffer ElementFlowBtwMaxBuffer {
    float data[];
}
element_flow_out_btw_max;

layout(set = 0, binding = 7, std430) restrict buffer SphereBuffer0 {
    float data[];
}
sphere_buffer_0;



layout(set = 0, binding = 8, std430) restrict buffer mapsizeBuffer {
    int data[];
}
mapsize;



float horizontaltansfer = 1;
float numberblockadj = 4;
int lengthElement = 10;//element_size.data;


int lenghtX = 100;
int getArrayLength = blockmatrix_buffer.data.length(); 
//int lenghtX = mapsize.data[0]; 
//lenghtX = int(sqrt(float(getArrayLength)));


float total = 0 ;

// The code we want to execute in each invocation
void main(){
    

    uint gid = gl_GlobalInvocationID.x;



    //vertical transfer block to sphere
    float qtetogive = element_flow_in.data[gid % lengthElement]; 

    if ( (sphere_buffer_0.data[gid % lengthElement]-element_flow_in.data[gid % lengthElement]*getArrayLength) <0){
        qtetogive = 0;
    }

    //total += blockmatrix_buffer_0.data[gid];
    //sphere_buffer.data[gid % lengthElement] =  gid; // total; //element_flow_out.data[gid % lengthElement]*blockmatrix_buffer_0.data[gid]; // - qtetogive;
    //blockmatrix_buffer.data[gid] +=             qtetogive - element_flow_out.data[gid % lengthElement]*blockmatrix_buffer_0.data[gid]; 


    //Horizontal transfer, between block
    // one side go to the other side ->no border

    //top border

    if ((gid-(gid%lengthElement)) % (lenghtX*lengthElement) == 0 ){

        // left
        if(gid < lenghtX*lengthElement){
        numberblockadj = 2;

        //first axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] += 0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));
        //second axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] +=  0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
        } 
        else if(gid > (lenghtX*lenghtX*lengthElement - lenghtX*lengthElement -1) ){
        numberblockadj = 2;
        //first axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] += 0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));
        //second axis
        blockmatrix_buffer.data[gid] +=  0* max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] +=   max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
        }
        else{
        numberblockadj = 3;
        //first axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] += 0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));
        //second axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
        }
    }

    //bottom border
    else if((gid-(gid%lengthElement)+lengthElement) % (lenghtX*lengthElement) == 0){
        if(gid < lenghtX*lengthElement){
            numberblockadj = 2;
            //first axis
            blockmatrix_buffer.data[gid] += 0* max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
            blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));
            //second axis
            blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));
            blockmatrix_buffer.data[gid] +=  0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
        }

        else if(gid > (lenghtX*lenghtX*lengthElement - lenghtX*lengthElement) ){
            numberblockadj = 2;
            //first axis
            blockmatrix_buffer.data[gid] += 0* max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
            blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));
            //second axis
            blockmatrix_buffer.data[gid] +=  0* max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));
            blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
             }

        else{
            numberblockadj = 3;
            //first axis
            blockmatrix_buffer.data[gid] += 0* max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
            blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));            //second axis
            blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));
            blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
        }
    }

    //left border
    else if(gid < lenghtX*lengthElement){
        numberblockadj = 3;
        //first axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));
        //second axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));            blockmatrix_buffer.data[gid] +=  0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] += 0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
       

    } 
    
    //right border
    else if(gid > (lenghtX*lenghtX*lengthElement - lenghtX*lengthElement) ){
        numberblockadj = 3;
        //first axis
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));
        //second axis
        blockmatrix_buffer.data[gid] +=  0* max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));            blockmatrix_buffer.data[gid] +=  0* max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
        blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));
    }

    else{
    numberblockadj = 4;
    //first axis
    blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid+lengthElement]/4 * element_flow_out_btw.data[gid % lengthElement]));
    blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, blockmatrix_buffer_0.data[gid-lengthElement]/4* element_flow_out_btw.data[gid % lengthElement]));

    //second axis
    blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid+lengthElement*lenghtX]/4 ) * element_flow_out_btw.data[gid % lengthElement]));
    blockmatrix_buffer.data[gid] +=  max(0,min((blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) - element_flow_out_btw_max.data[gid % lengthElement]/4, (blockmatrix_buffer_0.data[gid-lengthElement*lenghtX]/4) * element_flow_out_btw.data[gid % lengthElement]));

    }


    //howmuch they gave
    blockmatrix_buffer.data[gid] -=  max(0,min(blockmatrix_buffer_0.data[gid]*numberblockadj/4 - element_flow_out_btw_max.data[gid % lengthElement]*numberblockadj/4, blockmatrix_buffer_0.data[gid]*numberblockadj/4 * element_flow_out_btw.data[gid % lengthElement]));


    }
  


