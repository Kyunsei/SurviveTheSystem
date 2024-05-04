#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer BlockMatrixBuffer {
    float data[];
}
blockmatrix_buffer;

layout(set = 0, binding = 1, std430) restrict buffer LifeMatrixBuffer {
    float data[];
}
life_matrix_buffer;


layout(set = 0, binding = 2, std430) restrict buffer bufferX {
    int data[];
}
position_x;


layout(set = 0, binding = 3, std430) restrict buffer bufferY {
    int data[];
}
position_y;

layout(set = 0, binding = 4, std430) restrict buffer bufferIN {
    float data[];
}
elements_in;

layout(set = 0, binding = 5, std430) restrict buffer bufferBT {
    float data[];
}
elements_built;

layout(set = 0, binding = 6, std430) restrict buffer bufferOUT {
    float data[];
}
elements_out;


layout(set = 0, binding = 7, std430) restrict buffer bufferPar {
    float data[];
}
life_par;


layout(set = 0, binding = 8, std430) restrict buffer bufferCheck {
    float data[];
}
life_check;

layout(set = 0, binding = 9, std430) restrict buffer bufferGene{
    float data[];
}
gene_rules;


int worldsize = 100;
int elementsize = 10;
int parnumber = 8;
int rulenumber = 3; //0= age, 1= growthcycle, 2= movespeed
int growthcyclenumber = 5;
int number_life = position_y.data.length();



// The code we want to execute in each invocation
void main(){

    uint gid = gl_GlobalInvocationID.x;

    int x = position_x.data[gid];
    int y = position_y.data[gid];

    float total_built = 0.0;
    float total_in = 0.0;
    float total_in_min = 10.0;

    float total_elements = 0.0;
    float total_built_elements = 0.0;


    int cycle = 0; 


if(life_check.data[gid]!=0){

    float pvmax = 10.0; 
    float pvfactor = 1.0;


//Calculate diverse factor : Age, Built, PV


    for (int i = 0; i < elementsize; i++) {
        total_built += elements_built.data[gid*elementsize+i];
        if(elements_in.data[gid*elementsize+i] > 0){
                total_in += life_matrix_buffer.data[gid*elementsize + i];
                total_in_min = min( total_in_min, min(elements_in.data[gid*elementsize+i], life_matrix_buffer.data[gid*elementsize + i] ));
        }
    }



    //Write log function here   
    float oldfactor = 1; // max(0,  (gene_rules.data[gid*rulenumber*growthcyclenumber + 0*growthcyclenumber + cycle] - life_par.data[gid*parnumber + 2])/gene_rules.data[gid*rulenumber*growthcyclenumber + 0*growthcyclenumber + cycle]) ;

    if(life_par.data[gid*parnumber + 2] > gene_rules.data[gid*rulenumber*growthcyclenumber + 0*growthcyclenumber + cycle]){
        oldfactor = 0.;
    }

    if (life_par.data[gid*parnumber + 1] <= 0){
        pvfactor = 0;  //      pvfactor = life_par.data[gid*parnumber + 1]/pvmax;

    }




//ELEMENT LOOP

    for (int e = 0; e < elementsize; e++) {

        float valueforlife = 0.0;
        float valueforblock = 0.0;





//TAKE BLOCK ELEMENT
        valueforlife   += min(elements_in.data[gid*elementsize+e],blockmatrix_buffer.data[x*worldsize*elementsize+y*elementsize+e]);
        valueforblock -=  min(elements_in.data[gid*elementsize+e], blockmatrix_buffer.data[x*worldsize*elementsize+y*elementsize+e]) ;




//TRANSFORM ELEMENT
        valueforlife += elements_built.data[gid*elementsize+e] * total_in_min / total_built;
        valueforlife -= min(elements_in.data[gid*elementsize+e],total_in_min);


//WASTE
        valueforlife -= min(elements_out.data[gid*elementsize+e],life_matrix_buffer.data[gid*elementsize + e]);
        valueforblock +=  min(elements_out.data[gid*elementsize+e],life_matrix_buffer.data[gid*elementsize + e]);


//FINAL
        blockmatrix_buffer.data[x*worldsize*elementsize+(y)*elementsize + e] += valueforblock * oldfactor *pvfactor;
        life_matrix_buffer.data[gid*elementsize + e] += valueforlife * oldfactor * pvfactor;

//METABO COST
       blockmatrix_buffer.data[x*worldsize*elementsize+(y)*elementsize + e]  += min(life_matrix_buffer.data[gid*elementsize+e], max(0.1, 0.1*life_matrix_buffer.data[gid*elementsize+e])); 
       life_matrix_buffer.data[gid*elementsize+e] -= min(life_matrix_buffer.data[gid*elementsize+e], max(0.1, 0.1*life_matrix_buffer.data[gid*elementsize+e])); 

//STARVING DMG and HEALING v1

        cycle = int(life_par.data[gid*parnumber + 7]);
        life_par.data[gid*parnumber + 1]  += (life_matrix_buffer.data[gid*elementsize + e] - gene_rules.data[gid*rulenumber*growthcyclenumber + 1*growthcyclenumber + cycle])*(elements_built.data[gid*elementsize+e] - elements_out.data[gid*elementsize+e]);

        life_par.data[gid*parnumber + 1] = max(0,min(life_par.data[gid*parnumber + 1],pvmax));



    // get the total element in the life entities

        total_elements += life_matrix_buffer.data[gid*elementsize+e];
        total_built_elements += life_matrix_buffer.data[gid*elementsize + e]*(elements_built.data[gid*elementsize+e] - elements_out.data[gid*elementsize+e]);
        
    }



// CHANGE LIFE CYCLE

    int index_current_cycle = int(life_par.data[gid*parnumber + 7]) ;

    float element_needed_for_next_cycle  =  gene_rules.data[gid*rulenumber*growthcyclenumber + 1*growthcyclenumber + index_current_cycle + 1];

    if(total_built_elements >= element_needed_for_next_cycle &&  element_needed_for_next_cycle > 0 &&  index_current_cycle < growthcyclenumber){
        life_par.data[gid*parnumber + 7] += 1;
        //cycle = int(life_par.data[gid*parnumber + 7]);
    }
    life_par.data[gid*parnumber + 1] =total_built_elements;


//CheckDeath
    if( total_elements <= 0 ){
        life_check.data[gid] = -1;
  }


//CheckReproduce

    if(element_needed_for_next_cycle == 0 || index_current_cycle == growthcyclenumber-1){
        if(total_built_elements >= (gene_rules.data[gid*rulenumber*growthcyclenumber + 1*growthcyclenumber + index_current_cycle] + gene_rules.data[gid*rulenumber*growthcyclenumber + 1*growthcyclenumber + 0]) ){
            life_check.data[gid] = 2;
           // life_par.data[gid*parnumber + 7] -= 1;



        }

    }

  //  if(life_matrix_buffer.data[gid*elementsize + 1] > 1){
    //    life_check.data[gid] = 2;
   // }


//Age
    life_par.data[gid*parnumber + 2] +=1;

}
    }
  

